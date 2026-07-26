-- Truncate all user tables in the *current* database, preserving schema and
-- migration state. Tables and constraints are preserved; only data is wiped.
-- schema_migrations (golang-migrate) and _sqlx_migrations (sqlx) are excluded
-- so MigrateUp returns ErrNoChange on the next service boot instead of
-- re-running migrations against already-existing objects.
--
-- Run per-DB via `make reset-db`. If a running service holds locks that block
-- the TRUNCATE, the 5s lock_timeout aborts atomically (DB left untouched).

SET lock_timeout = '5s';

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables
            WHERE schemaname NOT IN ('pg_catalog','information_schema')
              AND tablename NOT IN ('schema_migrations','_sqlx_migrations')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;