# Anki Importer

A native macOS application built with SwiftUI for importing data into Anki.

## Features

- **BoostVocab**: Create vocabulary lists with word-meaning pairs and write paragraphs with automatic highlighting

## Requirements

- macOS 13.0 or later
- Swift 6.0 or later

## Running the App

See [README-Swift.md](README-Swift.md) for detailed instructions.

Quick start:
```bash
cd /Users/justee_vo/personal/anki-importer
swift run AnkiImporter
```

## Project Structure

```
AnkiImporter/
├── AnkiImporterApp.swift       # Main app entry point
├── Models/
│   ├── AppTheme.swift          # Color and font theme
│   ├── WordPair.swift          # Word pair data model
│   └── Feature.swift           # Feature data model
├── Views/
│   ├── ContentView.swift       # Main content view
│   ├── HomeView.swift          # Home screen with feature cards
│   └── BoostVocabView.swift    # BoostVocab feature view
└── Info.plist                  # App configuration
```

## License

MIT License
