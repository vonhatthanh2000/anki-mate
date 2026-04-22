#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "Building AnkiImporter app bundle..."

# Build Swift release binary
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

# App bundle paths
APP_DIR="build/AnkiImporter.app"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
AGENT_DIR="$RESOURCES_DIR/agent"

# Clean and create structure
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$AGENT_DIR"

# Copy executable
cp "$BIN_DIR/AnkiImporter" "$APP_DIR/Contents/MacOS/"

# Copy Info.plist
cp macos/Info-bundle.plist "$APP_DIR/Contents/Info.plist"

# Copy app logo
if [ -f "Logo.png" ]; then
    cp "Logo.png" "$RESOURCES_DIR/AppIcon.png"
    echo "Logo added to bundle"
fi

# Copy Python agent files (preserve .env and .venv)
cp -R agent/* "$AGENT_DIR/"

# Copy root .env file for Supabase credentials
if [ -f ".env" ]; then
    cp ".env" "$RESOURCES_DIR/"
    echo "Root .env (Supabase credentials) added to bundle"
fi

# Copy agent .env file if exists
if [ -f "agent/.env" ]; then
    cp "agent/.env" "$AGENT_DIR/"
fi

# Copy .venv folder if exists
if [ -d "agent/.venv" ]; then
    cp -R "agent/.venv" "$AGENT_DIR/"
    echo "Python venv included in bundle"
fi

echo "Python agent added to bundle"

# Remove .pyc files and __pycache__ from agent
find "$AGENT_DIR" -name "*.pyc" -delete 2>/dev/null || true
find "$AGENT_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

echo ""
echo "✅ Built: $APP_DIR"
echo ""
echo "To run:"
echo "  open \"$APP_DIR\""
echo ""
echo "To install to Applications folder:"
echo "  cp -R \"$APP_DIR\" /Applications/"
