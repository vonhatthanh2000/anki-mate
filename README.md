# AnkiImporter (macOS)

SwiftUI macOS app: **BoostVocab** — vocabulary lists, paragraph preview with highlights, **Submit** to save a batch into local SQLite, and **Send to Anki** via AnkiConnect (`AnkiConnectClient.swift`).

## Requirements

- macOS 13.0 or later
- Swift 6.0 or later (SwiftPM or Xcode)

## Run

From the repository root (where `Package.swift` is):

```bash
swift run AnkiImporter
```

Or build and open the debug binary:

```bash
swift build
open "$(swift build --show-bin-path)/AnkiImporter"
```

Release `.app` bundle:

```bash
./package_macos_app.sh
```

Open in Xcode: `open Package.swift`

## Database file

SQLite is stored as **`anki_mate.db` in the same folder as the `AnkiImporter` executable** — for example next to `.build/arm64-apple-macosx/debug/AnkiImporter`, or inside `AnkiImporter.app/Contents/MacOS/` when you use `package_macos_app.sh`. That keeps the database easy to find next to the app you ran.

If `Bundle.main.executableURL` is unavailable (unusual), the app falls back to `~/Library/Application Support/AnkiImporter/anki_mate.db`.

## Project structure

```
AnkiImporter/
├── AnkiImporterApp.swift       # Entry point; initializes database
├── Persistence/                # SQLite only (connection, schema, batch SQL)
│   ├── DatabaseError.swift
│   ├── SQLiteDatabase.swift
│   ├── Schema.swift
│   └── BatchSQL.swift
├── Services/
│   ├── BatchStore.swift        # App-facing save API; delegates to Persistence
│   └── AnkiConnectClient.swift
├── Models/
│   ├── BatchWordInput.swift
│   ├── AppTheme.swift
│   ├── WordPair.swift
│   └── Feature.swift
├── Views/
│   ├── ContentView.swift
│   ├── HomeView.swift
│   └── BoostVocabView.swift
└── Info.plist
```

## License

MIT License
