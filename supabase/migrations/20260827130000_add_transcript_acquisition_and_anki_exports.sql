ALTER TABLE transcript_lessons
    ADD COLUMN IF NOT EXISTS source_platform TEXT CHECK (source_platform IN ('youtube', 'tiktok')),
    ADD COLUMN IF NOT EXISTS source_title TEXT,
    ADD COLUMN IF NOT EXISTS source_duration_seconds DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS source_primary_language TEXT;

ALTER TABLE transcript_language_items
    ADD COLUMN IF NOT EXISTS anki_note_id BIGINT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_transcript_language_item_anki_note
    ON transcript_language_items(anki_note_id)
    WHERE anki_note_id IS NOT NULL;
