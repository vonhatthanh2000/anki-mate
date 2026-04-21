# Vocab to Anki (macOS)

![App Logo](AnkiImport-logo.png)

**Vocab to Anki** — A native macOS app for creating vocabulary entries and importing them directly to Anki with AI-generated examples.

## Features

- ✨ **AI-Powered**: Uses OpenAI to generate word types and example sentences
- 📝 **Batch Management**: Save multiple words with paragraphs
- 🔍 **Smart Preview**: Highlight vocabulary words in context
- 📤 **Direct Anki Import**: Send cards directly to Anki with one click
- 🗄️ **Local SQLite**: All data stored locally

## Requirements

- macOS 13.0 or later
- Anki desktop app with [AnkiConnect](https://foosoft.net/projects/anki-connect/) add-on
- OpenAI API key (for AI generation)

## Quick Start

### Option 1: Build & Run App Bundle

```bash
./package_macos_app.sh
open "build/AnkiImporter.app"
```

### Option 2: Run from Source

```bash
swift run AnkiImporter
```

### Option 3: Install to Applications

```bash
./package_macos_app.sh
cp -R "build/AnkiImporter.app" /Applications/
```

## Setup

1. **Configure OpenAI API Key**: Add your key to `agent/.env`:
   ```
   OPENAI_API_KEY=sk-your-key-here
   ```

2. **Install Anki & AnkiConnect**:
   - Download [Anki](https://apps.ankiweb.net/)
   - Install [AnkiConnect](https://foosoft.net/projects/anki-connect/) add-on (code: `2055492159`)

3. **Create Vocab Deck**: In Anki, create a deck named "Vocab" with note type containing fields:
   - Word
   - Meaning
   - Word type
   - Example 1
   - Example 2

## Project Structure

```
AnkiImporter/
├── AnkiImporterApp.swift          # App entry point
├── Persistence/                   # SQLite layer
│   ├── DatabaseError.swift
│   ├── SQLiteDatabase.swift
│   ├── Schema.swift
│   ├── BatchSQL.swift
│   └── BatchRead.swift
├── Services/                      # Business logic
│   ├── BatchStore.swift
│   ├── AnkiConnectClient.swift   # AnkiConnect integration
│   └── VocabAgentClient.swift      # OpenAI agent integration
├── Models/
│   ├── SavedBatch.swift
│   ├── BatchWordInput.swift
│   ├── AppTheme.swift
│   ├── WordPair.swift
│   └── Feature.swift
├── Views/
│   ├── ContentView.swift
│   ├── HomeView.swift
│   ├── SavedBatchesWindow.swift
│   ├── HighlightedParagraph.swift
│   └── BoostVocabView.swift
└── Info.plist

agent/                             # Python AI agent (bundled)
├── anki_vocab_suggest.py
├── vocab_cli.py                    # CLI wrapper for Swift
├── requirements.txt
├── .venv/                          # Python dependencies
└── .env                            # API key (not in repo)
```

## Database Location

SQLite is stored as **`anki_mate.db`** next to the app executable:
- Dev builds: `.build/arm64-apple-macosx/debug/anki_mate.db`
- Packaged app: `AnkiImporter.app/Contents/MacOS/anki_mate.db`

## License

MIT License
