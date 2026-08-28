#!/usr/bin/env python3
"""JSON CLI used by the native app for transcript acquisition."""

import json
import sys

from transcript_backend import BackendError, CaptionAcquirer, SpeechToTextFallback


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in {"captions", "transcribe"}:
        print(json.dumps({"ok": False, "error": {"kind": "usage", "message": "Usage: transcript_cli.py <captions|transcribe> <url>"}}))
        return 2

    mode, exact_url = sys.argv[1:]
    try:
        result = CaptionAcquirer().acquire(exact_url) if mode == "captions" else SpeechToTextFallback().transcribe(exact_url)
        print(
            json.dumps(
                {
                    "ok": True,
                    "source": result.source,
                    "sentences": result.sentences,
                    "cleanup_warning": result.cleanup_warning,
                },
                ensure_ascii=False,
            )
        )
        return 0
    except BackendError as error:
        print(json.dumps({"ok": False, "error": {"kind": error.kind, "message": error.message}}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
