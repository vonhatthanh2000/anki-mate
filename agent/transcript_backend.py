"""Transcript acquisition boundaries for YouTube and TikTok videos.

Platform captions are attempted first. Speech-to-text is a separate operation so
the macOS client can expose the fallback phase before any media is downloaded.
"""

from __future__ import annotations

import html
import json
import os
import re
import shutil
import subprocess
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any, Callable, Iterable, Optional, Sequence


@dataclass(frozen=True)
class Cue:
    text: str
    start: float
    end: float


@dataclass(frozen=True)
class TranscriptResult:
    source: str
    sentences: list[str]
    cleanup_warning: Optional[str] = None


class BackendError(Exception):
    def __init__(self, kind: str, message: str):
        super().__init__(message)
        self.kind = kind
        self.message = message


class CaptionUnavailable(BackendError):
    def __init__(self, message: str = "No usable English captions are available."):
        super().__init__("captions_unavailable", message)


def _normalize_text(value: str) -> str:
    value = re.sub(r"<[^>]+>", "", html.unescape(value))
    return re.sub(r"\s+", " ", value).strip()


def _is_prefix(shorter: str, longer: str) -> bool:
    return longer == shorter or longer.startswith(shorter + " ")


def sentences_from_cues(cues: Iterable[Cue]) -> list[str]:
    """Convert ordered cues into complete sentences without rolling-caption duplicates."""
    collapsed: list[Cue] = []
    for cue in cues:
        normalized = Cue(_normalize_text(cue.text), cue.start, max(cue.start, cue.end))
        if not normalized.text:
            continue
        if collapsed and normalized.start < collapsed[-1].end:
            previous = collapsed[-1]
            if _is_prefix(previous.text, normalized.text):
                collapsed[-1] = normalized
                continue
            if _is_prefix(normalized.text, previous.text):
                continue
        collapsed.append(normalized)

    combined = _normalize_text(" ".join(cue.text for cue in collapsed))
    if not combined:
        return []

    pattern = re.compile(r".+?(?:[.!?]+(?:[\"'”’]+)?(?=\s|$)|$)")
    return [sentence.strip() for sentence in pattern.findall(combined) if sentence.strip()]


def _parse_time(value: str) -> float:
    parts = value.replace(",", ".").split(":")
    try:
        if len(parts) == 3:
            return float(parts[0]) * 3600 + float(parts[1]) * 60 + float(parts[2])
        if len(parts) == 2:
            return float(parts[0]) * 60 + float(parts[1])
    except ValueError:
        pass
    return 0.0


def _parse_json3(payload: str) -> list[Cue]:
    data = json.loads(payload)
    cues = []
    for event in data.get("events", []):
        text = "".join(segment.get("utf8", "") for segment in event.get("segs", []))
        start = float(event.get("tStartMs", 0)) / 1000
        duration = float(event.get("dDurationMs", 0)) / 1000
        cues.append(Cue(text, start, start + duration))
    return cues


def _parse_vtt(payload: str) -> list[Cue]:
    cues = []
    blocks = re.split(r"\n\s*\n", payload.replace("\r\n", "\n"))
    for block in blocks:
        lines = [line.strip() for line in block.splitlines() if line.strip()]
        timing_index = next((index for index, line in enumerate(lines) if "-->" in line), None)
        if timing_index is None:
            continue
        timing = lines[timing_index].split("-->", 1)
        start = _parse_time(timing[0].strip())
        end = _parse_time(timing[1].strip().split()[0])
        text_lines = []
        for line in lines[timing_index + 1 :]:
            normalized = _normalize_text(line)
            if text_lines and _is_prefix(text_lines[-1], normalized):
                text_lines[-1] = normalized
            elif not text_lines or not _is_prefix(normalized, text_lines[-1]):
                text_lines.append(normalized)
        text = " ".join(text_lines)
        cues.append(Cue(text, start, end))
    return cues


def _parse_ttml(payload: str) -> list[Cue]:
    root = ET.fromstring(payload)
    cues = []
    for element in root.iter():
        if element.tag.rsplit("}", 1)[-1] != "p":
            continue
        start = _parse_time(element.attrib.get("begin", "0"))
        end = _parse_time(element.attrib.get("end", element.attrib.get("begin", "0")))
        cues.append(Cue("".join(element.itertext()), start, end))
    return cues


def parse_caption_payload(payload: str, extension: str) -> list[Cue]:
    if extension == "json3":
        return _parse_json3(payload)
    if extension in {"ttml", "srv3", "xml"}:
        return _parse_ttml(payload)
    return _parse_vtt(payload)


def _english_keys(tracks: dict[str, Any]) -> list[str]:
    def score(key: str) -> tuple[int, str]:
        lowered = key.lower()
        if lowered == "en":
            return (0, lowered)
        if lowered in {"en-us", "en-gb", "en_us", "en_gb"}:
            return (1, lowered)
        return (2, lowered)

    keys = [key for key in tracks if key.lower() == "en" or key.lower().startswith(("en-", "en_"))]
    return sorted(keys, key=score)


def _choose_format(formats: Sequence[dict[str, Any]]) -> Optional[dict[str, Any]]:
    priorities = {"json3": 0, "vtt": 1, "ttml": 2, "srv3": 3}
    candidates = [item for item in formats if item.get("url")]
    return min(candidates, key=lambda item: priorities.get(item.get("ext", ""), 99), default=None)


def _default_extract_info(url: str) -> dict[str, Any]:
    try:
        import yt_dlp

        options = {"quiet": True, "no_warnings": True, "skip_download": True, "noplaylist": True}
        with yt_dlp.YoutubeDL(options) as downloader:
            return downloader.extract_info(url, download=False)
    except Exception as error:
        raise classify_platform_error(error) from error


def _default_download_text(url: str, headers: dict[str, str]) -> str:
    try:
        request = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read().decode("utf-8", errors="replace")
    except Exception as error:
        raise BackendError("network_failed", "Check your internet connection and try again.") from error


def classify_platform_error(error: Exception) -> BackendError:
    message = str(error).lower()
    if any(term in message for term in ("private", "unavailable", "login required", "not available")):
        return BackendError("video_unavailable", "This video is unavailable or private. Try another link.")
    if any(term in message for term in ("unsupported url", "no suitable extractor", "not a valid url")):
        return BackendError("unsupported_url", "Use a supported YouTube or TikTok link.")
    if any(term in message for term in ("network", "timed out", "connection", "http error")):
        return BackendError("network_failed", "Check your internet connection and try again.")
    return BackendError("acquisition_failed", "We couldn’t retrieve captions for this video. Try again.")


class CaptionAcquirer:
    def __init__(
        self,
        extract_info: Callable[[str], dict[str, Any]] = _default_extract_info,
        download_text: Callable[[str, dict[str, str]], str] = _default_download_text,
    ):
        self.extract_info = extract_info
        self.download_text = download_text

    def acquire(self, exact_url: str) -> TranscriptResult:
        try:
            info = self.extract_info(exact_url)
        except BackendError:
            raise
        except Exception as error:
            raise classify_platform_error(error) from error

        selected = None
        for group_name in ("subtitles", "automatic_captions"):
            tracks = info.get(group_name) or {}
            for key in _english_keys(tracks):
                selected = _choose_format(tracks.get(key) or [])
                if selected:
                    break
            if selected:
                break
        if not selected:
            raise CaptionUnavailable()

        payload = self.download_text(selected["url"], info.get("http_headers") or {})
        try:
            sentences = sentences_from_cues(parse_caption_payload(payload, selected.get("ext", "vtt")))
        except (ET.ParseError, ValueError, KeyError, json.JSONDecodeError) as error:
            raise CaptionUnavailable("The available English caption track could not be read.") from error
        if not sentences:
            raise CaptionUnavailable("The available English caption track is empty.")

        extractor = str(info.get("extractor_key") or info.get("extractor") or "").lower()
        source = "tiktok_captions" if "tiktok" in extractor or "tiktok.com" in exact_url else "youtube_captions"
        return TranscriptResult(source=source, sentences=sentences)


def _default_temporary_directory() -> Path:
    return Path(tempfile.mkdtemp(prefix="anki-mate-transcript-"))


def _default_cleanup(path: Path) -> None:
    shutil.rmtree(path)


def _default_media_acquirer(exact_url: str, directory: Path) -> Path:
    try:
        import yt_dlp

        options = {
            "format": "bestaudio/best",
            "outtmpl": str(directory / "source.%(ext)s"),
            "quiet": True,
            "no_warnings": True,
            "noplaylist": True,
        }
        with yt_dlp.YoutubeDL(options) as downloader:
            info = downloader.extract_info(exact_url, download=True)
            requested = info.get("requested_downloads") or []
            if requested and requested[0].get("filepath"):
                path = Path(requested[0]["filepath"])
                if path.exists():
                    return path
        files = [path for path in directory.iterdir() if path.is_file()]
        if files:
            return files[0]
        raise FileNotFoundError("yt-dlp did not create a media file")
    except BackendError:
        raise
    except Exception as error:
        classified = classify_platform_error(error)
        if classified.kind == "acquisition_failed":
            classified = BackendError("download_failed", "We couldn’t download audio for this video.")
        raise classified from error


def _default_audio_extractor(media_path: Path, directory: Path) -> Path:
    audio_path = directory / "audio.mp3"
    ffmpeg = next(
        (
            candidate
            for candidate in (shutil.which("ffmpeg"), "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg")
            if candidate and Path(candidate).is_file()
        ),
        None,
    )
    if not ffmpeg:
        raise BackendError("audio_extraction_failed", "ffmpeg is required to prepare audio for transcription.")
    try:
        subprocess.run(
            [ffmpeg, "-y", "-i", str(media_path), "-vn", "-codec:a", "libmp3lame", "-q:a", "4", str(audio_path)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise BackendError("audio_extraction_failed", "We couldn’t prepare this video’s audio for transcription.") from error
    return audio_path


def _default_transcriber(audio_path: Path) -> list[Cue]:
    try:
        from dotenv import load_dotenv
        from openai import OpenAI

        agent_directory = Path(__file__).resolve().parent
        load_dotenv(agent_directory / ".env")
        load_dotenv(agent_directory.parent / ".env")
        client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        with audio_path.open("rb") as audio:
            response = client.audio.transcriptions.create(
                model=os.getenv("OPENAI_TRANSCRIPTION_MODEL", "whisper-1"),
                file=audio,
                response_format="verbose_json",
                timestamp_granularities=["segment"],
            )
        segments = getattr(response, "segments", None) or []
        if segments:
            return [
                Cue(
                    _object_value(segment, "text", ""),
                    float(_object_value(segment, "start", 0)),
                    float(_object_value(segment, "end", 0)),
                )
                for segment in segments
            ]
        return [Cue(getattr(response, "text", ""), 0, 0)]
    except BackendError:
        raise
    except Exception as error:
        message = str(error).lower()
        if any(term in message for term in ("network", "connection", "timed out")):
            raise BackendError("network_failed", "Check your internet connection and try again.") from error
        raise BackendError("transcription_failed", "We couldn’t transcribe this video. Try again.") from error


def _object_value(value: Any, key: str, default: Any) -> Any:
    if isinstance(value, dict):
        return value.get(key, default)
    return getattr(value, key, default)


class SpeechToTextFallback:
    def __init__(
        self,
        media_acquirer: Callable[[str, Path], Path] = _default_media_acquirer,
        audio_extractor: Callable[[Path, Path], Path] = _default_audio_extractor,
        transcriber: Callable[[Path], list[Cue]] = _default_transcriber,
        temporary_directory: Callable[[], Path] = _default_temporary_directory,
        cleanup: Callable[[Path], None] = _default_cleanup,
    ):
        self.media_acquirer = media_acquirer
        self.audio_extractor = audio_extractor
        self.transcriber = transcriber
        self.temporary_directory = temporary_directory
        self.cleanup = cleanup

    def transcribe(self, exact_url: str) -> TranscriptResult:
        try:
            directory = self.temporary_directory()
        except Exception as error:
            raise BackendError("temporary_storage_failed", "Temporary storage is unavailable.") from error
        result = None
        primary_error = None
        try:
            try:
                media_path = self.media_acquirer(exact_url, directory)
            except BackendError:
                raise
            except Exception as error:
                raise BackendError("download_failed", "We couldn’t download audio for this video.") from error

            try:
                audio_path = self.audio_extractor(media_path, directory)
            except BackendError:
                raise
            except Exception as error:
                raise BackendError(
                    "audio_extraction_failed", "We couldn’t prepare this video’s audio for transcription."
                ) from error

            try:
                cues = self.transcriber(audio_path)
            except BackendError:
                raise
            except Exception as error:
                raise BackendError("transcription_failed", "We couldn’t transcribe this video. Try again.") from error

            sentences = sentences_from_cues(cues)
            if not sentences:
                raise BackendError("transcription_failed", "Speech-to-text returned an empty transcript.")
            result = TranscriptResult(source="speech_to_text", sentences=sentences)
        except BackendError as error:
            primary_error = error

        cleanup_warning = None
        try:
            self.cleanup(directory)
        except Exception as error:
            cleanup_warning = f"Temporary files could not be fully removed: {error}"

        if primary_error:
            if cleanup_warning:
                raise BackendError(primary_error.kind, f"{primary_error.message} {cleanup_warning}")
            raise primary_error
        if cleanup_warning:
            result = replace(result, cleanup_warning=cleanup_warning)
        return result
