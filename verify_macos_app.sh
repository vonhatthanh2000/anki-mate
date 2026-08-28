#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_DIR="${1:-build/AnkiImporter.app}"
APP_DIR="$(cd "$(dirname "$APP_DIR")" && pwd)/$(basename "$APP_DIR")"
CONTENTS_DIR="$APP_DIR/Contents"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
AGENT_DIR="$RESOURCES_DIR/agent"
PYTHON_BIN="$AGENT_DIR/.venv/bin/python3"

fail() {
    echo "Package verification failed: $1" >&2
    exit 1
}

require_file() {
    [ -f "$1" ] || fail "missing $1"
}

require_executable() {
    [ -x "$1" ] || fail "missing executable $1"
}

require_executable "$CONTENTS_DIR/MacOS/AnkiImporter"
require_file "$CONTENTS_DIR/Info.plist"
require_file "$AGENT_DIR/transcript_acquisition_cli.py"
require_file "$AGENT_DIR/transcript_lesson_cli.py"
require_file "$AGENT_DIR/requirements.txt"
require_executable "$PYTHON_BIN"

plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null

"$PYTHON_BIN" -c 'import dotenv, openai, pydantic, yt_dlp' \
    || fail "bundled Python dependencies cannot be imported"

if [ -f ".env" ]; then
    require_file "$RESOURCES_DIR/.env"
fi
if [ -f "agent/.env" ]; then
    require_file "$AGENT_DIR/.env"
fi

"$PYTHON_BIN" - "$RESOURCES_DIR/.env" <<'PY'
from pathlib import Path
import sys

from dotenv import dotenv_values

values = dotenv_values(Path(sys.argv[1]))
required = ("SUPABASE_URL", "SUPABASE_ANON_KEY")
missing = [key for key in required if not values.get(key)]
if missing:
    raise SystemExit("missing packaged credential names: " + ", ".join(missing))
PY

(
    cd "$AGENT_DIR"
    "$PYTHON_BIN" -c 'import os; from dotenv import load_dotenv; load_dotenv(); raise SystemExit(0 if os.getenv("OPENAI_API_KEY") else "missing packaged credential name: OPENAI_API_KEY")'
) || fail "bundled Python agent cannot resolve its OpenAI credential"

if find "$RESOURCES_DIR" \
    \( -name 'anki-mate-transcript-*' -o -name '*.mp3' -o -name '*.wav' \
       -o -name '*.m4a' -o -name '*.mp4' -o -name '*.mov' -o -name '*.webm' \
       -o -name '*.pyc' -o -name '__pycache__' \) \
    -print -quit | grep -q .; then
    fail "temporary media or Python cache files are present in the bundle"
fi

for dependency in ffmpeg ffprobe; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "Package verification warning: $dependency is not installed; the app will show setup guidance for transcription." >&2
    fi
done

echo "Package verification passed: structure, Python imports, credential names, and media hygiene"
