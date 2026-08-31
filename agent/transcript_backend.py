"""Transcript acquisition boundaries for YouTube and TikTok videos.

Platform captions are attempted first. Speech-to-text is a separate operation so
the macOS client can expose the fallback phase before any media is downloaded.
"""

from __future__ import annotations

import html
import importlib.util
import json
import os
import re
import shutil
import subprocess
import tempfile
import urllib.parse
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


def _collapse_cues(cues: Iterable[Cue]) -> list[Cue]:
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
    return collapsed


def sentences_from_cues(cues: Iterable[Cue]) -> list[str]:
    """Convert ordered cues into complete sentences without rolling-caption duplicates."""
    collapsed = _collapse_cues(cues)

    combined = _normalize_text(" ".join(cue.text for cue in collapsed))
    if not combined:
        return []

    pattern = re.compile(r".+?(?:[.!?]+(?:[\"'”’]+)?(?=\s|$)|$)")
    return [sentence.strip() for sentence in pattern.findall(combined) if sentence.strip()]


def _canonical_characters(value: str) -> str:
    return "".join(character.lower() for character in value if character.isalnum())


def _ensure_terminal_punctuation(value: str) -> str:
    normalized = _normalize_text(value)
    if normalized and normalized[-1] not in ".!?\"'”’":
        normalized += "."
    return normalized


def _capitalize_sentence(value: str) -> str:
    value = re.sub(r"\bi\b", "I", value)
    for index, character in enumerate(value):
        if character.isalpha():
            return value[:index] + character.upper() + value[index + 1 :]
    return value


def _heuristic_punctuation(cues: Sequence[Cue]) -> list[str]:
    words = _normalize_text(" ".join(cue.text for cue in _collapse_cues(cues))).split()
    if not words:
        return []

    boundary_words = {
        "after",
        "before",
        "during",
        "finally",
        "however",
        "meanwhile",
        "next",
        "often",
        "sometimes",
        "then",
        "therefore",
        "today",
        "usually",
        "when",
    }
    chunks: list[list[str]] = []
    current: list[str] = []
    for word in words:
        normalized_word = re.sub(r"[^\w]", "", word).lower()
        if current and len(current) >= 12 and normalized_word in boundary_words:
            chunks.append(current)
            current = []
        current.append(word)
        if len(current) >= 22:
            chunks.append(current)
            current = []
    if current:
        chunks.append(current)

    return [
        _ensure_terminal_punctuation(_capitalize_sentence(" ".join(chunk)))
        for chunk in chunks
        if chunk
    ]


class PunctuationRestorer:
    """Restore sentence boundaries while enforcing exact spoken-word preservation."""

    def __init__(self, completion: Optional[Callable[[str], Sequence[str]]] = None):
        self.completion = completion or _default_punctuation_completion
        self.uses_default_completion = completion is None

    def restore(self, cues: Iterable[Cue]) -> list[str]:
        cue_list = list(cues)
        existing = sentences_from_cues(cue_list)
        text = _normalize_text(" ".join(cue.text for cue in _collapse_cues(cue_list)))
        word_count = len(text.split())
        if not text or word_count < 20 or len(existing) >= max(2, word_count // 30):
            return existing

        mode = os.getenv("TRANSCRIPT_PUNCTUATION_MODE", "auto").lower()
        if mode == "off":
            return existing
        if mode != "local" and (not self.uses_default_completion or _has_openai_key()):
            try:
                candidate = [
                    _ensure_terminal_punctuation(sentence)
                    for sentence in self.completion(text)
                    if _normalize_text(sentence)
                ]
                if len(candidate) > 1 and _canonical_characters(" ".join(candidate)) == _canonical_characters(text):
                    return candidate
            except Exception:
                pass
        return _heuristic_punctuation(cue_list)


def _load_agent_environment() -> None:
    from dotenv import load_dotenv

    agent_directory = Path(__file__).resolve().parent
    load_dotenv(agent_directory / ".env")
    load_dotenv(agent_directory.parent / ".env")


def _has_openai_key() -> bool:
    try:
        _load_agent_environment()
    except ImportError:
        return False
    return bool(os.getenv("OPENAI_API_KEY"))


def _default_punctuation_completion(text: str) -> Sequence[str]:
    from openai import OpenAI

    _load_agent_environment()
    response = OpenAI(api_key=os.getenv("OPENAI_API_KEY")).responses.create(
        model=os.getenv("OPENAI_PUNCTUATION_MODEL", "gpt-4o-mini"),
        instructions=(
            "Restore capitalization, punctuation, and sentence boundaries in the transcript. "
            "Do not add, remove, replace, reorder, or correct any spoken word. Keep repetitions. "
            "Return each complete sentence as one array item."
        ),
        input=text,
        text={
            "format": {
                "type": "json_schema",
                "name": "punctuated_transcript",
                "strict": True,
                "schema": {
                    "type": "object",
                    "properties": {
                        "sentences": {"type": "array", "items": {"type": "string"}}
                    },
                    "required": ["sentences"],
                    "additionalProperties": False,
                },
            }
        },
        max_output_tokens=min(max(512, len(text) // 2), 12000),
        store=False,
    )
    return json.loads(response.output_text)["sentences"]


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


def _youtube_javascript_options(url: str) -> dict[str, Any]:
    host = urllib.parse.urlparse(url).hostname or ""
    if host.lower() not in {"youtu.be", "youtube.com", "www.youtube.com", "m.youtube.com"}:
        return {}

    runtime = None
    for name, fallback_paths in (
        ("deno", ("/opt/homebrew/bin/deno", "/usr/local/bin/deno")),
        ("node", ("/opt/homebrew/bin/node", "/usr/local/bin/node")),
    ):
        executable = shutil.which(name) or next(
            (path for path in fallback_paths if Path(path).is_file()),
            None,
        )
        if executable:
            runtime = (name, executable)
            break

    if not runtime:
        raise BackendError(
            "backend_unavailable",
            "YouTube processing requires Node.js 22+ or Deno 2.3+. Install one and try again.",
        )

    name, executable = runtime
    options: dict[str, Any] = {"js_runtimes": {name: {"path": executable}}}
    if importlib.util.find_spec("yt_dlp_ejs") is None:
        options["remote_components"] = ["ejs:github"]
    return options


def _default_extract_info(url: str) -> dict[str, Any]:
    try:
        import yt_dlp

        options = {"quiet": True, "no_warnings": True, "skip_download": True, "noplaylist": True}
        options.update(_youtube_javascript_options(url))
        with yt_dlp.YoutubeDL(options) as downloader:
            return downloader.extract_info(url, download=False)
    except BackendError:
        raise
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
        punctuation_restorer: Optional[PunctuationRestorer] = None,
    ):
        self.extract_info = extract_info
        self.download_text = download_text
        self.punctuation_restorer = punctuation_restorer or PunctuationRestorer()

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
            sentences = self.punctuation_restorer.restore(
                parse_caption_payload(payload, selected.get("ext", "vtt"))
            )
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
            "socket_timeout": float(os.getenv("TRANSCRIPT_DOWNLOAD_TIMEOUT_SECONDS", "20")),
            "retries": 2,
            "fragment_retries": 2,
        }
        options.update(_youtube_javascript_options(exact_url))
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
            [
                ffmpeg,
                "-nostdin",
                "-y",
                "-i",
                str(media_path),
                "-vn",
                "-codec:a",
                "libmp3lame",
                "-q:a",
                "4",
                str(audio_path),
            ],
            check=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=float(os.getenv("TRANSCRIPT_AUDIO_TIMEOUT_SECONDS", "60")),
        )
    except subprocess.TimeoutExpired as error:
        raise BackendError("audio_extraction_failed", "Preparing this video’s audio took too long.") from error
    except (OSError, subprocess.CalledProcessError) as error:
        raise BackendError("audio_extraction_failed", "We couldn’t prepare this video’s audio for transcription.") from error
    return audio_path


def _default_transcriber(audio_path: Path) -> list[Cue]:
    try:
        from openai import OpenAI

        _load_agent_environment()
        client = OpenAI(
            api_key=os.getenv("OPENAI_API_KEY"),
            timeout=float(os.getenv("OPENAI_TRANSCRIPTION_TIMEOUT_SECONDS", "120")),
            max_retries=1,
        )
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
        punctuation_restorer: Optional[PunctuationRestorer] = None,
        progress: Optional[Callable[[str], None]] = None,
    ):
        self.media_acquirer = media_acquirer
        self.audio_extractor = audio_extractor
        self.transcriber = transcriber
        self.temporary_directory = temporary_directory
        self.cleanup = cleanup
        self.punctuation_restorer = punctuation_restorer or PunctuationRestorer()
        self.progress = progress or (lambda _stage: None)

    def _report(self, stage: str) -> None:
        try:
            self.progress(stage)
        except Exception:
            pass

    def transcribe(self, exact_url: str) -> TranscriptResult:
        try:
            directory = self.temporary_directory()
        except Exception as error:
            raise BackendError("temporary_storage_failed", "Temporary storage is unavailable.") from error
        result = None
        primary_error = None
        try:
            try:
                self._report("downloading_audio")
                try:
                    media_path = self.media_acquirer(exact_url, directory)
                except BackendError as error:
                    should_retry = (
                        "tiktok.com" in exact_url.lower()
                        and error.kind in {"download_failed", "network_failed"}
                    )
                    if not should_retry:
                        raise
                    self._report("retrying_download")
                    media_path = self.media_acquirer(exact_url, directory)
            except BackendError:
                raise
            except Exception as error:
                raise BackendError("download_failed", "We couldn’t download audio for this video.") from error

            try:
                self._report("preparing_audio")
                audio_path = self.audio_extractor(media_path, directory)
            except BackendError:
                raise
            except Exception as error:
                raise BackendError(
                    "audio_extraction_failed", "We couldn’t prepare this video’s audio for transcription."
                ) from error

            try:
                self._report("transcribing_audio")
                cues = self.transcriber(audio_path)
            except BackendError:
                raise
            except Exception as error:
                raise BackendError("transcription_failed", "We couldn’t transcribe this video. Try again.") from error

            self._report("formatting_transcript")
            sentences = self.punctuation_restorer.restore(cues)
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
