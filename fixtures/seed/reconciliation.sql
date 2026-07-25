-- Fixtures for reconciliation database
\c reconciliation;

-- External events
INSERT INTO external_events (id, source, external_event_id, payload, ingested_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000d01', 'LEDGER',    'ledger-evt-001',   '{"amount":5000,"asset":"USD","account":"acc-001"}'::jsonb,    now() - interval '3 hours', now() - interval '3 hours', now() - interval '3 hours'),
  ('01890000-0000-7000-8000-000000000d02', 'RAILS',     'rail-evt-001',     '{"amount":5000,"asset":"USD","payment_id":"pm-001"}'::jsonb,   now() - interval '3 hours', now() - interval '3 hours', now() - interval '3 hours'),
  ('01890000-0000-7000-8000-000000000d03', 'LEDGER',    'ledger-evt-002',   '{"amount":125,"asset":"USD","account":"acc-004"}'::jsonb,     now() - interval '2 hours', now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000d04', 'EXCHANGES', 'exchange-evt-001', '{"amount":0.5,"asset":"BTC","venue":"kraken"}'::jsonb,        now() - interval '2 hours', now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000d05', 'ONCHAIN',   'onchain-evt-001',  '{"tx_hash":"0xaaa111","amount":0.5,"asset":"BTC"}'::jsonb,    now() - interval '1 hour',  now() - interval '1 hour',  now() - interval '1 hour'),
  ('01890000-0000-7000-8000-000000000d06', 'CUSTODY',   'custody-evt-001',  '{"amount":1000,"asset":"ETH","wallet":"hot-001"}'::jsonb,     now() - interval '45 minutes', now() - interval '45 minutes', now() - interval '45 minutes');

-- Recon runs
INSERT INTO recon_runs (id, source, scope, status, matched_count, unmatched_count, breaks_count, started_at, completed_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000d10', 'LEDGER',    'DAILY',    'COMPLETED', 4, 1, 1, now() - interval '3 hours', now() - interval '2 hours', now() - interval '3 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000d11', 'RAILS',     'DAILY',    'COMPLETED', 5, 0, 0, now() - interval '3 hours', now() - interval '2 hours', now() - interval '3 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000d12', 'EXCHANGES', 'INTRADAY', 'RUNNING',   2, 1, 0, now() - interval '30 minutes', NULL, now() - interval '30 minutes', now() - interval '30 minutes'),
  ('01890000-0000-7000-8000-000000000d13', 'ONCHAIN',   'DAILY',    'FAILED',    0, 2, 2, now() - interval '1 hour',  now() - interval '55 minutes', now() - interval '1 hour', now() - interval '55 minutes');

-- Breaks
INSERT INTO breaks (id, run_id, type, classification, source, asset, reference, internal_amount, external_amount, status, detected_at, resolved_at, age_seconds, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000d20', '01890000-0000-7000-8000-000000000d10', 'AMOUNT_MISMATCH', 'TIMING', 'LEDGER',    'USD', 'pm-001', 5000.0, 4995.0, 'OPEN',       now() - interval '2 hours',   NULL,                       7200, now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000d21', '01890000-0000-7000-8000-000000000d13', 'MISSING_ENTRY',   'REAL',   'ONCHAIN',   'BTC', '0xaaa111', NULL,  0.5,    'OPEN',       now() - interval '55 minutes', NULL,                       3300, now() - interval '55 minutes', now() - interval '55 minutes'),
  ('01890000-0000-7000-8000-000000000d22', '01890000-0000-7000-8000-000000000d13', 'DUPLICATE',       'REAL',   'ONCHAIN',   'ETH', '0xbbb222', 1.0,   1.0,    'RESOLVED',   now() - interval '55 minutes', now() - interval '40 minutes', 3300, now() - interval '55 minutes', now() - interval '40 minutes'),
  ('01890000-0000-7000-8000-000000000d23', NULL,                                         'TIMING_GAP',      'TIMING', 'CUSTODY',   'ETH', 'custody-001', 1000.0, 1000.0, 'ESCALATED', now() - interval '45 minutes', NULL,                       2700, now() - interval '45 minutes', now() - interval '45 minutes');

-- Break resolutions
INSERT INTO break_resolutions (id, break_id, type, actor, note, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000d30', '01890000-0000-7000-8000-000000000d22', 'AUTO', 'system', 'Auto-resolved: duplicate confirmed and deduplicated', now() - interval '40 minutes', now() - interval '40 minutes');

-- Recon rules
INSERT INTO recon_rules (id, source, asset, match_strategy, tolerance_seconds, escalation_age_minutes, auto_resolve_timing, config, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000d40', 'LEDGER',    'USD', 'EXACT',                300,  60,  true,  '{"threshold":0.01}'::jsonb, now() - interval '30 days', now() - interval '10 days'),
  ('01890000-0000-7000-8000-000000000d41', 'LEDGER',    'EUR', 'EXACT',                300,  60,  true,  '{"threshold":0.01}'::jsonb, now() - interval '30 days', now() - interval '10 days'),
  ('01890000-0000-7000-8000-000000000d42', 'RAILS',     NULL,  'FUZZY',                600,  120, false, '{"max_delta":0.50}'::jsonb, now() - interval '30 days', now() - interval '10 days'),
  ('01890000-0000-7000-8000-000000000d43', 'ONCHAIN',   'BTC', 'EXACT',                3600, 240, false, '{}'::jsonb,                 now() - interval '30 days', now() - interval '10 days'),
  ('01890000-0000-7000-8000-000000000d44', 'EXCHANGES', NULL,  'BALANCE_ROLLFORWARD',  300,  60,  true,  '{}'::jsonb,                 now() - interval '30 days', now() - interval '10 days'),
  ('01890000-0000-7000-8000-000000000d45', 'CUSTODY',   NULL,  'EXACT',                300,  90,  false, '{}'::jsonb,                 now() - interval '30 days', now() - interval '10 days');