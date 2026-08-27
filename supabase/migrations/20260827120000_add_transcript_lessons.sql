-- Transcript Lessons: approved transcripts, analysis, exercises, and attempts.

CREATE TABLE IF NOT EXISTS transcript_lessons (
    id BIGSERIAL PRIMARY KEY,
    source_url TEXT,
    approved_transcript TEXT NOT NULL CHECK (length(trim(approved_transcript)) > 0),
    summary JSONB NOT NULL DEFAULT '[]'::jsonb,
    main_point TEXT NOT NULL,
    supporting_ideas JSONB NOT NULL DEFAULT '[]'::jsonb,
    tone_and_register TEXT NOT NULL,
    context_notes JSONB NOT NULL DEFAULT '[]'::jsonb,
    item_count INTEGER NOT NULL CHECK (item_count BETWEEN 6 AND 10),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transcript_language_items (
    id BIGSERIAL PRIMARY KEY,
    lesson_id BIGINT NOT NULL REFERENCES transcript_lessons(id) ON DELETE CASCADE,
    item_key TEXT NOT NULL,
    expression TEXT NOT NULL,
    span_start INTEGER NOT NULL CHECK (span_start >= 0),
    span_end INTEGER NOT NULL CHECK (span_end > span_start),
    source_excerpt TEXT NOT NULL,
    primary_category TEXT NOT NULL CHECK (
        primary_category IN ('Vocabulary', 'Idiom', 'Phrasal verb', 'Collocation', 'Slang', 'Grammar pattern')
    ),
    secondary_categories JSONB NOT NULL DEFAULT '[]'::jsonb,
    meaning_and_usage TEXT NOT NULL,
    cefr_estimate TEXT NOT NULL,
    selection_rationale TEXT NOT NULL,
    natural_example TEXT NOT NULL,
    vietnamese_gloss TEXT,
    practice_priority INTEGER CHECK (practice_priority BETWEEN 1 AND 5),
    UNIQUE (lesson_id, item_key),
    UNIQUE (lesson_id, span_start, span_end)
);

COMMENT ON COLUMN transcript_language_items.span_start IS 'Inclusive UTF-16 code-unit offset in approved_transcript';
COMMENT ON COLUMN transcript_language_items.span_end IS 'Exclusive UTF-16 code-unit offset in approved_transcript';

CREATE TABLE IF NOT EXISTS transcript_exercises (
    id BIGSERIAL PRIMARY KEY,
    lesson_id BIGINT NOT NULL REFERENCES transcript_lessons(id) ON DELETE CASCADE,
    exercise_key TEXT NOT NULL,
    item_key TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('recognition', 'production')),
    prompt TEXT NOT NULL,
    expected_answer TEXT,
    explanation TEXT,
    UNIQUE (lesson_id, exercise_key),
    UNIQUE (lesson_id, item_key, kind),
    FOREIGN KEY (lesson_id, item_key)
        REFERENCES transcript_language_items(lesson_id, item_key)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS transcript_exercise_attempts (
    id BIGSERIAL PRIMARY KEY,
    lesson_id BIGINT NOT NULL REFERENCES transcript_lessons(id) ON DELETE CASCADE,
    exercise_key TEXT NOT NULL,
    answer TEXT NOT NULL CHECK (length(trim(answer)) > 0),
    is_correct BOOLEAN NOT NULL,
    meaning_feedback TEXT NOT NULL,
    correctness_feedback TEXT NOT NULL,
    appropriateness_feedback TEXT NOT NULL,
    naturalness_feedback TEXT NOT NULL,
    explanation TEXT NOT NULL,
    natural_revision TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (lesson_id, exercise_key)
        REFERENCES transcript_exercises(lesson_id, exercise_key)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_transcript_lessons_created_at
    ON transcript_lessons(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transcript_language_items_lesson_id
    ON transcript_language_items(lesson_id);
CREATE INDEX IF NOT EXISTS idx_transcript_exercises_lesson_id
    ON transcript_exercises(lesson_id);
CREATE INDEX IF NOT EXISTS idx_transcript_exercise_attempts_lesson_id
    ON transcript_exercise_attempts(lesson_id);

ALTER TABLE transcript_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcript_language_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcript_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcript_exercise_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all operations on transcript lessons" ON transcript_lessons;
DROP POLICY IF EXISTS "Allow all operations on transcript language items" ON transcript_language_items;
DROP POLICY IF EXISTS "Allow all operations on transcript exercises" ON transcript_exercises;
DROP POLICY IF EXISTS "Allow all operations on transcript exercise attempts" ON transcript_exercise_attempts;

CREATE POLICY "Allow all operations on transcript lessons"
    ON transcript_lessons FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations on transcript language items"
    ON transcript_language_items FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations on transcript exercises"
    ON transcript_exercises FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations on transcript exercise attempts"
    ON transcript_exercise_attempts FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
