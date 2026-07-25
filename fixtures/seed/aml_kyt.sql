-- Fixtures for aml_kyt database
\c aml_kyt;

INSERT INTO address_risk_cache (id, address, chain, risk_score, exposure, decision, vendor, cached_at, ttl_seconds, expires_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000a01', '0xabc123def456789012345678901234567890abcd', 'ethereum', 12, 'LOW',    'APPROVE', 'chainalysis', now() - interval '1 hour',  3600, now() + interval '50 minutes', now() - interval '1 hour', now() - interval '1 hour'),
  ('01890000-0000-7000-8000-000000000a02', '0xdef456789012345678901234567890abcd123456', 'ethereum', 85, 'HIGH',   'BLOCK',   'trm',         now() - interval '30 minutes', 3600, now() + interval '30 minutes', now() - interval '30 minutes', now() - interval '30 minutes'),
  ('01890000-0000-7000-8000-000000000a03', 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'bitcoin', 45, 'MEDIUM', 'REVIEW',  'chainalysis', now() - interval '2 hours',  3600, now() - interval '1 hour', now() - interval '2 hours', now() - interval '1 hour');

INSERT INTO kyt_screens (screen_id, tx_id, address, source_address, chain, amount, risk_score, exposure, decision, vendor, vendor_response_id, cache_hit, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000a10', 'tx-001', '0xabc123def456789012345678901234567890abcd', '0x999888777666555544443333222211110000fffe', 'ethereum', 1.5, 12, 'LOW',  'APPROVE', 'chainalysis', '01890000-0000-7000-8000-000000000a21', true,  now() - interval '55 minutes', now() - interval '55 minutes'),
  ('01890000-0000-7000-8000-000000000a11', 'tx-002', '0xdef456789012345678901234567890abcd123456', '0xaaa999888777666555544443333222211110000', 'ethereum', 0.05, 85, 'HIGH', 'BLOCK',   'trm',         '01890000-0000-7000-8000-000000000a22', false, now() - interval '25 minutes', now() - interval '25 minutes');

INSERT INTO kyt_alerts (id, screen_id, tx_id, address, chain, exposure, severity, status, assignee, created_at, updated_at, closed_at)
VALUES
  ('01890000-0000-7000-8000-000000000a30', '01890000-0000-7000-8000-000000000a11', 'tx-002', '0xdef456789012345678901234567890abcd123456', 'ethereum', 'HIGH', 'HIGH',     'IN_REVIEW', 'analyst-1', now() - interval '25 minutes', now() - interval '25 minutes', NULL),
  ('01890000-0000-7000-8000-000000000a31', NULL,                                          'tx-003', 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'bitcoin',  'MEDIUM', 'MEDIUM',   'OPEN',      NULL,        now() - interval '10 minutes', now() - interval '10 minutes', NULL);

INSERT INTO vendor_responses (id, vendor, request_payload, response_payload, idempotency_key, address, chain, tx_id, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000a21', 'chainalysis', '{"action":"score"}'::jsonb, '{"score":12,"exposure":"low"}'::jsonb,  'idem-chainalysis-001', '0xabc123def456789012345678901234567890abcd', 'ethereum', 'tx-001', now() - interval '55 minutes', now() - interval '55 minutes'),
  ('01890000-0000-7000-8000-000000000a22', 'trm',         '{"action":"score"}'::jsonb, '{"score":85,"exposure":"high"}'::jsonb, 'idem-trm-001',          '0xdef456789012345678901234567890abcd123456', 'ethereum', 'tx-002', now() - interval '25 minutes', now() - interval '25 minutes');

INSERT INTO audit_events (id, screen_id, tx_id, address, chain, amount, decision, exposure, risk_score, vendor, cache_hit, source, operator, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000a40', '01890000-0000-7000-8000-000000000a10', 'tx-001', '0xabc123def456789012345678901234567890abcd', 'ethereum', '1.5',  'APPROVE', 'LOW',    12, 'chainalysis', true,  'aml-kyt-screening', NULL, now() - interval '55 minutes', now() - interval '55 minutes'),
  ('01890000-0000-7000-8000-000000000a41', '01890000-0000-7000-8000-000000000a11', 'tx-002', '0xdef456789012345678901234567890abcd123456', 'ethereum', '0.05', 'BLOCK',   'HIGH',   85, 'trm',         false, 'aml-kyt-screening', NULL, now() - interval '25 minutes', now() - interval '25 minutes'),
  ('01890000-0000-7000-8000-000000000a42', NULL,                                          'tx-003', 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'bitcoin',  '0.25', 'REVIEW',  'MEDIUM', 45, 'chainalysis', true,  'aml-kyt-screening', NULL, now() - interval '10 minutes', now() - interval '10 minutes');