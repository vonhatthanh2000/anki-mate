#!/usr/bin/env python3
"""Best-effort personal-use transcript acquisition for short videos."""

from __future__ import annotations

import html
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
from typing import Any
from urllib.request import Request, urlopen

from dotenv import load_dotenv


MAX_DURATION_SECONDS = 300.0


class AcquisitionError(Exception):
    def __init__(self, stage: str, message: str, retryable: bool = True):
        super().__init__(message)
        self.stage = stage
        self.message = message
        self.retryable = retryable


class AcquisitionCancelled(AcquisitionError):
    def __init__(self) -> None:
        super().__init__("acquisition", "Acquisition was cancelled.", True)


def _handle_termination(_signum: int, _frame: Any) -> None:
    raise AcquisitionCancelled()


def _safe_message(error: BaseException) -> str:
    message = str(error).strip() or error.__class__.__name__
    api_key = os.getenv("OPENAI_API_KEY")
    if api_key:
        message = message.replace(api_key, "[REDACTED]")
    return re.sub(r"sk-[A-Za-z0-9_-]+", "[REDACTED]", message)


def _load_dependencies() -> tuple[Any, Any]:
    try:
        from yt_dlp import YoutubeDL
    except ImportError as error:
        raise AcquisitionError(
            "configuration",
            "Install the bundled Python dependencies (`pip install -r agent/requirements.txt`) so yt-dlp is available.",
            False,
        ) from error
    try:
        from openai import OpenAI
    except ImportError as error:
        raise AcquisitionError(
            "configuration",
            "Install the bundled Python dependencies (`pip install -r agent/requirements.txt`) so OpenAI speech-to-text is available.",
            False,
        ) from error
    return YoutubeDL, OpenAI


def _extract_metadata(youtube_dl: Any, url: str) -> dict[str, Any]:
    options = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "noplaylist": True,
        "socket_timeout": 20,
        "retries": 2,
        "fragment_retries": 2,
    }
    try:
        with youtube_dl(options) as client:
            info = client.extract_info(url, download=False)
    except Exception as error:
        raise AcquisitionError(
            "acquisition",
            f"Could not read this public video: {_safe_message(error)}. Try a local file or manual transcript.",
        ) from error
    if not isinstance(info, dict):
        raise AcquisitionError("acquisition", "The platform returned malformed video metadata.")
    duration = info.get("duration")
    if not isinstance(duration, (int, float)) or duration <= 0:
        raise AcquisitionError(
            "acquisition",
            "The video duration could not be confirmed, so the five-minute safety limit cannot be enforced. Try an authorized local file or paste a transcript.",
            False,
        )
    if isinstance(duration, (int, float)) and duration > MAX_DURATION_SECONDS:
        raise AcquisitionError(
            "acquisition",
            f"This video is {round(duration)} seconds long; the maximum is five minutes.",
            False,
        )
    return info


def _english_caption(info: dict[str, Any]) -> tuple[dict[str, Any], bool] | None:
    for group_name in ("subtitles", "automatic_captions"):
        group = info.get(group_name) or {}
        for language, candidates in group.items():
            normalized = language.lower()
            if normalized == "en" or normalized.startswith("en-"):
                preferred = sorted(
                    candidates or [],
                    key=lambda candidate: {"json3": 0, "vtt": 1}.get(
                        candidate.get("ext"), 2
                    ),
                )
                if preferred:
                    return preferred[0], normalized.endswith("-orig")
    return None


def _download_caption(candidate: dict[str, Any]) -> str:
    url = candidate.get("url")
    if not url:
        return ""
    request = Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urlopen(request, timeout=20) as response:
            payload = response.read().decode("utf-8", errors="replace")
    except Exception:
        return ""
    return _caption_text(payload, candidate.get("ext", ""))


def _caption_text(payload: str, extension: str) -> str:
    if extension == "json3":
        try:
            document = json.loads(payload)
            chunks = []
            for event in document.get("events", []):
                text = "".join(segment.get("utf8", "") for segment in event.get("segs", []))
                if text.strip():
                    chunks.append(text.strip())
            return _normalize_caption_lines(chunks)
        except (TypeError, ValueError):
            return ""

    lines: list[str] = []
    for line in payload.splitlines():
        stripped = line.strip()
        if (
            not stripped
            or stripped == "WEBVTT"
            or "-->" in stripped
            or stripped.isdigit()
            or stripped.startswith(("Kind:", "Language:", "NOTE"))
        ):
            continue
        cleaned = re.sub(r"<[^>]+>", "", html.unescape(stripped))
        if cleaned:
            lines.append(cleaned)
    return _normalize_caption_lines(lines)


def _normalize_caption_lines(lines: list[str]) -> str:
    merged_words: list[str] = []
    for line in lines:
        normalized = re.sub(r"\s+", " ", line).strip()
        if not normalized:
            continue
        words = normalized.split(" ")
        overlap = 0
        for count in range(min(len(merged_words), len(words)), 0, -1):
            if merged_words[-count:] == words[:count]:
                overlap = count
                break
        merged_words.extend(words[overlap:])
    return " ".join(merged_words).strip()


def _download_audio(youtube_dl: Any, url: str, job_directory: Path) -> Path:
    output_template = str(job_directory / "source.%(ext)s")
    options = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "format": "bestaudio/best",
        "outtmpl": output_template,
        "max_filesize": 25 * 1024 * 1024,
        "socket_timeout": 20,
        "retries": 2,
        "fragment_retries": 2,
    }
    try:
        with youtube_dl(options) as client:
            client.download([url])
    except Exception as error:
        raise AcquisitionError(
            "acquisition",
            f"Captions were unavailable and temporary media acquisition failed: {_safe_message(error)}. Upload an authorized file or paste a transcript.",
        ) from error
    candidates = [path for path in job_directory.iterdir() if path.is_file()]
    if not candidates:
        raise AcquisitionError("acquisition", "No temporary audio file was produced.")
    return candidates[0]


def _probe_duration(path: Path) -> float:
    executable = shutil.which("ffprobe")
    if not executable:
        raise AcquisitionError(
            "configuration",
            "Install ffmpeg (including ffprobe) before transcribing local audio or video files.",
            False,
        )
    try:
        result = subprocess.run(
            [
                executable,
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(path),
            ],
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
        duration = float(result.stdout.strip()) if result.returncode == 0 else 0
    except (ValueError, subprocess.TimeoutExpired) as error:
        raise AcquisitionError(
            "acquisition",
            "The selected media duration could not be read safely. Try another file or paste a transcript.",
            False,
        ) from error
    if duration <= 0:
        raise AcquisitionError(
            "acquisition",
            "The selected media duration could not be read safely. Try another file or paste a transcript.",
            False,
        )
    return duration


def _extract_audio(path: Path, job_directory: Path) -> Path:
    executable = shutil.which("ffmpeg")
    if not executable:
        raise AcquisitionError(
            "configuration",
            "Install ffmpeg before transcribing local video files.",
            False,
        )
    audio_path = job_directory / "speech.mp3"
    try:
        result = subprocess.run(
            [
                executable,
                "-nostdin",
                "-v",
                "error",
                "-y",
                "-i",
                str(path),
                "-vn",
                "-ac",
                "1",
                "-ar",
                "16000",
                "-b:a",
                "64k",
                str(audio_path),
            ],
            capture_output=True,
            check=False,
            timeout=90,
        )
    except subprocess.TimeoutExpired as error:
        raise AcquisitionError("transcription", "Audio extraction timed out. Try another file.") from error
    if result.returncode != 0 or not audio_path.is_file():
        raise AcquisitionError(
            "transcription",
            "The selected media audio could not be extracted. Install a current ffmpeg build or choose another file.",
        )
    return audio_path


def _transcribe(openai_type: Any, path: Path) -> tuple[str, str | None]:
    if not os.getenv("OPENAI_API_KEY"):
        raise AcquisitionError(
            "configuration",
            "Set OPENAI_API_KEY in agent/.env before using speech-to-text.",
            False,
        )
    try:
        client = openai_type(timeout=120.0, max_retries=1)
        with path.open("rb") as media:
            response = client.audio.transcriptions.create(
                model="whisper-1",
                file=media,
                response_format="verbose_json",
            )
    except Exception as error:
        raise AcquisitionError(
            "transcription",
            f"OpenAI could not transcribe the audio: {_safe_message(error)}. You can retry or paste the transcript.",
        ) from error
    text = getattr(response, "text", None)
    language = getattr(response, "language", None)
    if not isinstance(text, str) or not text.strip():
        raise AcquisitionError("transcription", "Speech-to-text returned an empty transcript.")
    return text.strip(), language if isinstance(language, str) else None


def _source_payload(source: dict[str, Any], info: dict[str, Any], language: str | None) -> dict[str, Any]:
    return {
        "canonicalURL": source["canonicalURL"],
        "platform": source["platform"],
        "title": info.get("title"),
        "durationSeconds": info.get("duration"),
        "primaryLanguage": language,
    }


def lookup_captions(command: dict[str, Any], youtube_dl: Any) -> dict[str, Any]:
    source = command.get("source") or {}
    url = source.get("canonicalURL")
    if not url:
        raise AcquisitionError("acquisition", "The canonical video URL is missing.", False)
    info = _extract_metadata(youtube_dl, url)
    caption_match = _english_caption(info)
    if caption_match:
        caption, is_original = caption_match
        transcript = _download_caption(caption)
        if transcript:
            language = info.get("language") or ("en" if is_original else None)
            if language is None:
                # Translated/manual caption text cannot prove the spoken language.
                # Fall through to speech-to-text, which reports the audio language.
                return {"acquisition": None}
            return {
                "acquisition": {
                    "transcript": transcript,
                    "source": _source_payload(source, info, language),
                    "method": "captions",
                    "detectedLanguage": language,
                    "durationSeconds": info.get("duration"),
                }
            }
    return {"acquisition": None}


def transcribe_url(command: dict[str, Any], youtube_dl: Any, openai_type: Any) -> dict[str, Any]:
    source = command.get("source") or {}
    url = source.get("canonicalURL")
    if not url:
        raise AcquisitionError("acquisition", "The canonical video URL is missing.", False)
    info = _extract_metadata(youtube_dl, url)
    with tempfile.TemporaryDirectory(prefix="anki-mate-transcript-") as directory:
        job_directory = Path(directory)
        media_path = _download_audio(youtube_dl, url, job_directory)
        audio_path = _extract_audio(media_path, job_directory)
        transcript, language = _transcribe(openai_type, audio_path)
        return {
            "transcript": transcript,
            "source": _source_payload(source, info, language),
            "method": "speech_to_text",
            "detectedLanguage": language,
            "durationSeconds": info.get("duration"),
        }


def acquire_url(command: dict[str, Any], youtube_dl: Any, openai_type: Any) -> dict[str, Any]:
    caption_result = lookup_captions(command, youtube_dl)
    if caption_result["acquisition"] is not None:
        return caption_result["acquisition"]
    return transcribe_url(command, youtube_dl, openai_type)


def transcribe_file(command: dict[str, Any], openai_type: Any) -> dict[str, Any]:
    raw_path = command.get("localFilePath")
    if not raw_path:
        raise AcquisitionError("acquisition", "Choose an authorized local audio or video file.", False)
    source_path = Path(raw_path)
    if not source_path.is_file():
        raise AcquisitionError("acquisition", "The selected local file is no longer available.", True)

    with tempfile.TemporaryDirectory(prefix="anki-mate-transcript-") as directory:
        copied_path = Path(directory) / ("upload" + source_path.suffix.lower())
        shutil.copy2(source_path, copied_path)
        duration = _probe_duration(copied_path)
        if duration > MAX_DURATION_SECONDS:
            raise AcquisitionError(
                "acquisition",
                f"This file is {round(duration)} seconds long; the maximum is five minutes.",
                False,
            )
        audio_path = _extract_audio(copied_path, Path(directory))
        transcript, language = _transcribe(openai_type, audio_path)
        source = command.get("source")
        if source:
            source = {**source, "durationSeconds": duration, "primaryLanguage": language}
        return {
            "transcript": transcript,
            "source": source,
            "method": "speech_to_text",
            "detectedLanguage": language,
            "durationSeconds": duration,
        }


def main() -> int:
    signal.signal(signal.SIGTERM, _handle_termination)
    load_dotenv(Path(__file__).with_name(".env"))
    try:
        command = json.load(sys.stdin)
        youtube_dl, openai_type = _load_dependencies()
        action = command.get("action")
        if action == "lookup_captions":
            result = lookup_captions(command, youtube_dl)
        elif action == "transcribe_url":
            result = transcribe_url(command, youtube_dl, openai_type)
        elif action == "acquire_url":
            result = acquire_url(command, youtube_dl, openai_type)
        elif action == "transcribe_file":
            result = transcribe_file(command, openai_type)
        else:
            raise AcquisitionError("acquisition", "Unsupported acquisition action.", False)
        json.dump(result, sys.stdout, ensure_ascii=False)
        return 0
    except AcquisitionError as error:
        json.dump(
            {"stage": error.stage, "message": error.message, "retryable": error.retryable},
            sys.stderr,
            ensure_ascii=False,
        )
        return 2
    except Exception as error:
        json.dump(
            {
                "stage": "acquisition",
                "message": f"Unexpected local agent failure: {_safe_message(error)}",
                "retryable": True,
            },
            sys.stderr,
            ensure_ascii=False,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
