-- Check migration status
-- Run this in Supabase SQL Editor to see which migrations have been applied

SELECT
    version,
    name,
    applied_at,
    CASE
        WHEN applied_at IS NOT NULL THEN '✅ Applied'
        ELSE '⏳ Pending'
    END as status
FROM schema_migrations
ORDER BY version;

-- Or if the table doesn't exist yet (first run):
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'schema_migrations') THEN
        RAISE NOTICE 'Migration tracking table not created yet. Run 20260422120000_initial_schema.sql (or supabase db push) first.';
    ELSE
        RAISE NOTICE 'Migration tracking is active.';
    END IF;
END $$;
