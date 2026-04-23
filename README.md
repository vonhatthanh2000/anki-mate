# Vocab to Anki (macOS)

![App Logo](AnkiImport-logo.png)

**Vocab to Anki** — A native macOS app for creating vocabulary entries and importing them directly to Anki with AI-generated examples.

## Features

- ✨ **AI-Powered**: Uses OpenAI to generate word types and example sentences
- 📝 **Batch Management**: Save multiple words with paragraphs
- 🔍 **Smart Preview**: Highlight vocabulary words in context
- 📤 **Direct Anki Import**: Send cards directly to Anki with one click
- ☁️ **Cloud Database**: All data stored in Supabase for easy management and syncing

## Requirements

- macOS 13.0 or later
- Anki desktop app with [AnkiConnect](https://foosoft.net/projects/anki-connect/) add-on
- OpenAI API key (for AI generation)
- Supabase account (for cloud database)

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

### 1. Configure Supabase

1. Create a free account at [supabase.com](https://supabase.com)
2. Create a new project
3. Go to **SQL Editor** → **New query** and run the migrations in order:
   - First run: `supabase/migrations/20260422120000_initial_schema.sql` (or `supabase db push` after linking; see [supabase/README.md](supabase/README.md))
   - See [supabase/README.md](supabase/README.md) for migration details
4. Get your project credentials:
   - Go to **Settings** → **API** → **Project URL** and **anon key**
5. Add credentials to the `.env` file in project root:
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

### 2. Configure OpenAI API Key

Add your key to `agent/.env`:
```
OPENAI_API_KEY=sk-your-key-here
```

**Note**: You can also put all credentials in the root `.env` file:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
OPENAI_API_KEY=sk-your-key-here
```

### 3. Install Anki & AnkiConnect

- Download [Anki](https://apps.ankiweb.net/)
- Install [AnkiConnect](https://foosoft.net/projects/anki-connect/) add-on (code: `2055492159`)

### 4. Create Vocab Deck

In Anki, create a deck named "Vocab" with note type containing fields:
- Word
- Meaning
- Word type
- Example 1
- Example 2

## Project Structure

```
AnkiImporter/
├── AnkiImporterApp.swift          # App entry point
├── Persistence/                   # (Empty - now using Supabase)
├── Services/                      # Business logic
│   ├── SupabaseStore.swift        # Supabase cloud database
│   ├── AnkiConnectClient.swift    # AnkiConnect integration
│   └── VocabAgentClient.swift     # OpenAI agent integration
├── Models/
│   ├── SavedBatch.swift
│   ├── BatchWordInput.swift
│   ├── AppTheme.swift
│   ├── WordPair.swift
│   ├── TopicRecord.swift
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
├── vocab_cli.py                   # CLI wrapper for Swift
├── requirements.txt
├── .venv/                         # Python dependencies
└── .env                           # API key (not in repo)

supabase/                          # Database migrations
├── check_migrations.sql           # Query supabase_migrations.schema_migrations
└── migrations/
    ├── 20260422120000_initial_schema.sql
    ├── 20260423120000_add_topic_to_words.sql
    └── 20260423130000_drop_legacy_public_schema_migrations.sql

supabase_schema.sql                # Database schema for Supabase (legacy)
```

## Database

Data is now stored in **Supabase** (PostgreSQL cloud database) instead of local SQLite:

- **Tables**: `batches`, `words`, `paragraphs`, `topics` (words reference `topics.id` via `topic_id`)
- **Relationships**: Words and paragraphs reference batches via foreign keys
- **Date Filtering**: Server-side filtering for "This Week" and "This Month" views
- **Migrations**: SQL files in `supabase/migrations/`; applied history lives in `supabase_migrations.schema_migrations` when you use the Supabase CLI or Dashboard migrations

### Schema Setup

Prefer the Supabase CLI so history stays in sync:

```bash
supabase link   # once, to your project
supabase db push
```

To inspect what the platform has recorded:

```bash
# Run in SQL Editor (see file for details)
supabase/check_migrations.sql
```

You can still paste files from `supabase/migrations/` into the SQL Editor, but only CLI/Dashboard migrations reliably maintain `supabase_migrations.schema_migrations`.

### Manual Setup (without migrations)

If you prefer to set up Supabase tables manually:

```sql
CREATE TABLE batches (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE topics (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE words (
    id BIGSERIAL PRIMARY KEY,
    batch_id BIGINT REFERENCES batches(id) ON DELETE CASCADE,
    topic_id BIGINT NOT NULL REFERENCES topics(id) ON DELETE RESTRICT,
    word TEXT NOT NULL,
    meaning TEXT NOT NULL,
    word_type TEXT DEFAULT '',
    example_1 TEXT DEFAULT '',
    example_2 TEXT DEFAULT ''
);

CREATE TABLE paragraphs (
    id BIGSERIAL PRIMARY KEY,
    batch_id BIGINT REFERENCES batches(id) ON DELETE CASCADE,
    paragraph TEXT NOT NULL
);

-- Enable RLS and create policies
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE words ENABLE ROW LEVEL SECURITY;
ALTER TABLE paragraphs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations on batches" ON batches FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations on topics" ON topics FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations on words" ON words FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations on paragraphs" ON paragraphs FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
```

### Future Schema Changes

When upgrading the schema:

1. Check current migration status: `supabase/check_migrations.sql` (queries `supabase_migrations.schema_migrations`)
2. Add a new timestamped file under `supabase/migrations/` and run `supabase db push` (or your linked deploy flow)

## License

MIT License
