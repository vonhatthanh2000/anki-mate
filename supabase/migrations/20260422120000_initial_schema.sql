-- Migration: 20260422120000_initial_schema (CLI filename; app version 001)
-- Description: Initial database schema with batches, words, and paragraphs tables
-- Created: 2026-04-22

-- Migration tracking (run this first to track applied migrations)
CREATE TABLE IF NOT EXISTS schema_migrations (
    id SERIAL PRIMARY KEY,
    version VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    applied_at TIMESTAMPTZ DEFAULT NOW()
);

-- Check if this migration was already applied
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM schema_migrations WHERE version = '001') THEN
        RAISE NOTICE 'Migration 001_initial_schema already applied, skipping...';
        RETURN;
    END IF;
END $$;

-- ============================================
-- Batches table
-- ============================================
CREATE TABLE IF NOT EXISTS batches (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE batches IS 'Stores vocabulary batch groups';
COMMENT ON COLUMN batches.id IS 'Unique batch identifier';
COMMENT ON COLUMN batches.created_at IS 'When the batch was created';

-- ============================================
-- Words table
-- ============================================
CREATE TABLE IF NOT EXISTS words (
    id BIGSERIAL PRIMARY KEY,
    batch_id BIGINT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    word TEXT NOT NULL,
    meaning TEXT NOT NULL,
    word_type TEXT DEFAULT '',
    example_1 TEXT DEFAULT '',
    example_2 TEXT DEFAULT ''
);

COMMENT ON TABLE words IS 'Individual vocabulary words within a batch';
COMMENT ON COLUMN words.batch_id IS 'Reference to parent batch';
COMMENT ON COLUMN words.word IS 'The vocabulary word';
COMMENT ON COLUMN words.meaning IS 'Definition or translation';
COMMENT ON COLUMN words.word_type IS 'Part of speech (noun, verb, etc.)';
COMMENT ON COLUMN words.example_1 IS 'First example sentence';
COMMENT ON COLUMN words.example_2 IS 'Second example sentence';

-- ============================================
-- Paragraphs table
-- ============================================
CREATE TABLE IF NOT EXISTS paragraphs (
    id BIGSERIAL PRIMARY KEY,
    batch_id BIGINT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    paragraph TEXT NOT NULL
);

COMMENT ON TABLE paragraphs IS 'Context paragraph for vocabulary batches';
COMMENT ON COLUMN paragraphs.batch_id IS 'Reference to parent batch';
COMMENT ON COLUMN paragraphs.paragraph IS 'The context text containing vocabulary words';

-- ============================================
-- Row Level Security (RLS)
-- ============================================
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE words ENABLE ROW LEVEL SECURITY;
ALTER TABLE paragraphs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Allow all operations on batches" ON batches;
DROP POLICY IF EXISTS "Allow all operations on words" ON words;
DROP POLICY IF EXISTS "Allow all operations on paragraphs" ON paragraphs;

-- Create policies
CREATE POLICY "Allow all operations on batches" ON batches
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all operations on words" ON words
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all operations on paragraphs" ON paragraphs
    FOR ALL
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- ============================================
-- Indexes for performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_words_batch_id ON words(batch_id);
CREATE INDEX IF NOT EXISTS idx_paragraphs_batch_id ON paragraphs(batch_id);
CREATE INDEX IF NOT EXISTS idx_batches_created_at ON batches(created_at);

-- ============================================
-- Record migration
-- ============================================
INSERT INTO schema_migrations (version, name)
VALUES ('001', 'initial_schema')
ON CONFLICT (version) DO NOTHING;
