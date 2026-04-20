#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="build/AnkiImporter.app"
EXE="$BIN_DIR/AnkiImporter"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$EXE" "$APP_DIR/Contents/MacOS/"
cp macos/Info-bundle.plist "$APP_DIR/Contents/Info.plist"

echo "Built $APP_DIR — run: open \"$APP_DIR\""
