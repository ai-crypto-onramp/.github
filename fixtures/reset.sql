-- Truncate all user tables in every service database.
-- Tables and migrations are preserved; only data is wiped.
-- Run via:  docker compose exec -T postgres psql -U postgres -v ON_ERROR_STOP=1 < fixtures/reset.sql

\c aml_kyt
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c audit
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c blockchain_gateway
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c fx_hedging
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c identity_auth
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c ledger_accounting
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c liquidity
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c onboarding_kyc
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c policy_engine
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c reconciliation
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c transaction_orchestrator
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c treasury
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

\c wallet_management
DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')) LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;