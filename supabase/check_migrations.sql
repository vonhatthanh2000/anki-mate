-- Check migration status (Supabase ledger)
--
-- History is stored in supabase_migrations.schema_migrations when you apply
-- migrations via Supabase CLI (`supabase db push`, `supabase migration up`)
-- or the Dashboard migration workflow. If this query errors with "relation
-- does not exist", no migration has been applied through that path yet.

SELECT version, name
FROM supabase_migrations.schema_migrations
ORDER BY version;
