-- Add topic lookup, point every word at the default topic, remove legacy words.topic text if present.

CREATE TABLE IF NOT EXISTS topics (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all operations on topics" ON topics;
CREATE POLICY "Allow all operations on topics" ON topics FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

INSERT INTO topics (name) VALUES ('Topic 1 - Cultural Identity') ON CONFLICT (name) DO NOTHING;

ALTER TABLE words ADD COLUMN IF NOT EXISTS topic_id BIGINT REFERENCES topics(id) ON DELETE RESTRICT;

UPDATE words SET topic_id = (SELECT id FROM topics WHERE name = 'Topic 1 - Cultural Identity' LIMIT 1);

ALTER TABLE words DROP COLUMN IF EXISTS topic;

ALTER TABLE words ALTER COLUMN topic_id SET NOT NULL;


CREATE INDEX IF NOT EXISTS idx_words_topic_id ON words(topic_id);