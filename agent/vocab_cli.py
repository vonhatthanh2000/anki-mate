#!/usr/bin/env python3
"""CLI wrapper for vocabulary agent. Input: word meaning (as arguments). Output: JSON."""

import sys
import json
import os

# Add the agent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

import anki_vocab_suggest


def main():
    if len(sys.argv) < 3:
        print("Usage: python vocab_cli.py <word> <meaning>", file=sys.stderr)
        sys.exit(1)

    word = sys.argv[1]
    meaning = sys.argv[2]

    message = f"Word: {word}\nMeaning: {meaning}"

    try:
        result = anki_vocab_suggest.anki_vocab_suggest_agent.run(message)
        # Extract content from the RunResponse
        if hasattr(result, 'content'):
            content = result.content
        elif hasattr(result, 'messages') and result.messages:
            content = result.messages[-1].content
        else:
            content = str(result)

        # Try to parse as JSON (handle markdown code blocks)
        data = None
        try:
            # Try direct JSON first
            data = json.loads(content)
        except json.JSONDecodeError:
            # Try to extract JSON from markdown code block
            if "```json" in content:
                start = content.find("```json") + 7
                end = content.find("```", start)
                if end > start:
                    json_str = content[start:end].strip()
                    try:
                        data = json.loads(json_str)
                    except:
                        pass
            elif "```" in content:
                start = content.find("```") + 3
                end = content.find("```", start)
                if end > start:
                    json_str = content[start:end].strip()
                    try:
                        data = json.loads(json_str)
                    except:
                        pass

        if data is None:
            # Return structured data even if parsing failed
            data = {
                "word": word,
                "meaning": meaning,
                "wordType": "",
                "example1": "",
                "example2": "",
                "raw_response": content
            }

        print(json.dumps(data))

    except Exception as e:
        # Return error as JSON
        error_output = {
            "word": word,
            "meaning": meaning,
            "wordType": "",
            "example1": "",
            "example2": "",
            "error": str(e)
        }
        print(json.dumps(error_output))
        sys.exit(1)


if __name__ == "__main__":
    main()
