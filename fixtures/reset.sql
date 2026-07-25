-- Truncate all user tables in the *current* database, preserving schema and
-- migration state. Tables and constraints are preserved; only data is wiped.
-- schema_migrations (golang-migrate) and _sqlx_migrations (sqlx) are excluded
-- so MigrateUp returns ErrNoChange on the next service boot instead of
-- re-running migrations against already-existing objects.
--
-- This file is meant to be run once per service database; the Makefile
-- `reset-db` target enumerates the databases from pg_database and pipes
-- this file into psql once per DB. That keeps this file a pure SQL unit
-- (no \c meta-commands, no dblink, no psql \gexec tricks) and makes adding
-- a new service database automatic.
--
-- Skip-and-continue behaviour: the truncate loop runs inside a single DO
-- block guarded by a short lock_timeout. If any TRUNCATE cannot acquire
-- an ACCESS EXCLUSIVE lock (because a running service holds an open
-- transaction touching the table), the whole block is rolled back
-- atomically -- the database is left untouched rather than half-truncated
-- -- and an ERROR is raised so the Makefile reset-db loop aborts (psql
-- -v ON_ERROR_STOP=1 turns ERROR into a non-zero exit). The operator
-- stops the offending service and re-runs. This prevents `make reset-db
-- seed-db` from seeding against a half-reset state.
--
-- For a guaranteed-complete reset, stop the app services first:
--   make down && make up postgres && make reset-db seed-db && make up

SET lock_timeout = '5s';

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables
            WHERE schemaname NOT IN ('pg_catalog','information_schema')
              AND tablename NOT IN ('schema_migrations','_sqlx_migrations')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
EXCEPTION
  WHEN lock_not_available THEN
    RAISE EXCEPTION 'database % has tables locked by a running service; reset aborted for this db (it was left untouched). Stop the app services and re-run: make reset-db', current_database();
END $$;