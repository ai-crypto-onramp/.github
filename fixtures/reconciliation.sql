-- Fixtures for reconciliation database
\c reconciliation;

-- External events
INSERT INTO external_events (id, source, external_event_id, payload, ingested_at)
VALUES
  (1, 'ledger', 'ledger-evt-001', '{"amount":5000,"asset":"USD","account":"acc-001"}'::jsonb, now() - interval '3 hours'),
  (2, 'rails', 'rail-evt-001', '{"amount":5000,"asset":"USD","payment_id":"pm-001"}'::jsonb, now() - interval '3 hours'),
  (3, 'ledger', 'ledger-evt-002', '{"amount":125,"asset":"USD","account":"acc-004"}'::jsonb, now() - interval '2 hours'),
  (4, 'exchanges', 'exchange-evt-001', '{"amount":0.5,"asset":"BTC","venue":"kraken"}'::jsonb, now() - interval '2 hours'),
  (5, 'onchain', 'onchain-evt-001', '{"tx_hash":"0xaaa111","amount":0.5,"asset":"BTC"}'::jsonb, now() - interval '1 hour'),
  (6, 'custody', 'custody-evt-001', '{"amount":1000,"asset":"ETH","wallet":"hot-001"}'::jsonb, now() - interval '45 minutes');

-- Recon runs
INSERT INTO recon_runs (id, source, scope, status, matched_count, unmatched_count, breaks_count, started_at, completed_at)
VALUES
  (1, 'ledger', 'daily', 'completed', 4, 1, 1, now() - interval '3 hours', now() - interval '2 hours'),
  (2, 'rails', 'daily', 'completed', 5, 0, 0, now() - interval '3 hours', now() - interval '2 hours'),
  (3, 'exchanges', 'intraday', 'running', 2, 1, 0, now() - interval '30 minutes', NULL),
  (4, 'onchain', 'daily', 'failed', 0, 2, 2, now() - interval '1 hour', now() - interval '55 minutes');

-- Breaks
INSERT INTO breaks (id, run_id, type, classification, source, asset, reference, internal_amount, external_amount, status, detected_at, resolved_at, age_seconds)
VALUES
  (1, 1, 'amount_mismatch', 'timing', 'ledger', 'USD', 'pm-001', 5000.0, 4995.0, 'open', now() - interval '2 hours', NULL, 7200),
  (2, 4, 'missing_entry', 'real', 'onchain', 'BTC', '0xaaa111', NULL, 0.5, 'open', now() - interval '55 minutes', NULL, 3300),
  (3, 4, 'duplicate', 'real', 'onchain', 'ETH', '0xbbb222', 1.0, 1.0, 'resolved', now() - interval '55 minutes', now() - interval '40 minutes', 3300),
  (4, NULL, 'timing_gap', 'timing', 'custody', 'ETH', 'custody-001', 1000.0, 1000.0, 'escalated', now() - interval '45 minutes', NULL, 2700);

-- Break resolutions
INSERT INTO break_resolutions (id, break_id, type, actor, note, created_at)
VALUES
  (1, 3, 'auto', 'system', 'Auto-resolved: duplicate confirmed and deduplicated', now() - interval '40 minutes');

-- Recon rules
INSERT INTO recon_rules (id, source, asset, match_strategy, tolerance_seconds, escalation_age_minutes, auto_resolve_timing, config, created_at, updated_at)
VALUES
  (1, 'ledger', 'USD', 'exact', 300, 60, true, '{"threshold":0.01}'::jsonb, now() - interval '30 days', now() - interval '10 days'),
  (2, 'ledger', 'EUR', 'exact', 300, 60, true, '{"threshold":0.01}'::jsonb, now() - interval '30 days', now() - interval '10 days'),
  (3, 'rails', NULL, 'fuzzy', 600, 120, false, '{"max_delta":0.50}'::jsonb, now() - interval '30 days', now() - interval '10 days'),
  (4, 'onchain', 'BTC', 'exact', 3600, 240, false, '{}'::jsonb, now() - interval '30 days', now() - interval '10 days'),
  (5, 'exchanges', NULL, 'balance_rollforward', 300, 60, true, '{}'::jsonb, now() - interval '30 days', now() - interval '10 days'),
  (6, 'custody', NULL, 'exact', 300, 90, false, '{}'::jsonb, now() - interval '30 days', now() - interval '10 days');