#!/usr/bin/env python3
"""JSON-over-stdin CLI for transcript lesson analysis and answer evaluation."""

import json
import sys

from transcript_lesson import EvaluationRequest, analyze_transcript, evaluate_answer


def main() -> int:
    try:
        payload = json.load(sys.stdin)
        action = payload.get("action")
        if action == "analyze":
            result = analyze_transcript(payload.get("transcript", ""))
        elif action == "evaluate":
            result = evaluate_answer(EvaluationRequest.model_validate(payload.get("request", {})))
        else:
            raise ValueError("Unsupported transcript lesson action")

        print(result.model_dump_json())
        return 0
    except Exception as error:
        print(f"Transcript lesson agent failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
