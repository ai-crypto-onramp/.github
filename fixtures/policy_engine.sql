-- Fixtures for policy_engine database
\c policy_engine;

-- Deterministic UUIDv7-style literals for the previously BIGSERIAL ids.
-- policies (active_version is nullable initially, set via ALTER)
INSERT INTO policies (id, scope, active_version, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000201', 'global', NULL, now() - interval '30 days', now() - interval '30 days'),
  ('01890000-0000-7000-8000-000000000202', 'partner:acme', NULL, now() - interval '15 days', now() - interval '15 days');

-- Policy versions
INSERT INTO policy_versions (id, policy_id, version, rego_hash, rego_source, created_at, updated_at, created_by)
VALUES
  ('01890000-0000-7000-8000-000000000210', '01890000-0000-7000-8000-000000000201', 1, 'rego-hash-001', 'package default.allow; default allow := false; allow if { input.amount <= 100000 }', now() - interval '30 days', now() - interval '30 days', 'admin'),
  ('01890000-0000-7000-8000-000000000211', '01890000-0000-7000-8000-000000000201', 2, 'rego-hash-002', 'package default.allow; default allow := false; allow if { input.amount <= 500000 }', now() - interval '10 days', now() - interval '10 days', 'admin'),
  ('01890000-0000-7000-8000-000000000212', '01890000-0000-7000-8000-000000000202', 3, 'rego-hash-003', 'package default.allow; default allow := false; allow if { input.partner_id == "acme" }', now() - interval '15 days', now() - interval '15 days', 'admin');

-- Link active versions
UPDATE policies SET active_version = '01890000-0000-7000-8000-000000000211', updated_at = now() WHERE id = '01890000-0000-7000-8000-000000000201';
UPDATE policies SET active_version = '01890000-0000-7000-8000-000000000212', updated_at = now() WHERE id = '01890000-0000-7000-8000-000000000202';

-- Policy decisions
INSERT INTO policy_decisions (decision_id, policy_version, request_hash, decision, reasons, applied_rules, score, signature, created_at, updated_at)
VALUES
  ('dec-001', '01890000-0000-7000-8000-000000000211', 'req-hash-001', 'ALLOW', ARRAY['amount_within_limit'], ARRAY['default.allow'], 0.95, NULL, now() - interval '2 hours', now() - interval '2 hours'),
  ('dec-002', '01890000-0000-7000-8000-000000000211', 'req-hash-002', 'DENY',  ARRAY['amount_exceeds_limit'], ARRAY['default.allow'], 0.12, NULL, now() - interval '1 hour', now() - interval '1 hour'),
  ('dec-003', '01890000-0000-7000-8000-000000000211', 'req-hash-003', 'REVIEW', ARRAY['velocity_check_triggered'], ARRAY['velocity.check'], 0.55, NULL, now() - interval '30 minutes', now() - interval '30 minutes'),
  ('dec-004', '01890000-0000-7000-8000-000000000212', 'req-hash-004', 'ALLOW', ARRAY['partner_whitelisted'], ARRAY['default.allow'], 0.98, NULL, now() - interval '15 minutes', now() - interval '15 minutes');

-- Whitelist addresses
INSERT INTO whitelist_addresses (id, user_id, chain, address, label, verified_at, status, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000220', '01890000-0000-7000-8000-000000000001', 'ethereum', '0xabc123def456789012345678901234567890abcd', 'Alice main wallet', now() - interval '20 days', 'VERIFIED', now() - interval '25 days', now() - interval '20 days'),
  ('01890000-0000-7000-8000-000000000221', '01890000-0000-7000-8000-000000000002', 'bitcoin', 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'Bob cold storage', now() - interval '15 days', 'VERIFIED', now() - interval '18 days', now() - interval '15 days'),
  ('01890000-0000-7000-8000-000000000222', '01890000-0000-7000-8000-000000000001', 'ethereum', '0xdef456789012345678901234567890abcd123456', 'Alice backup', NULL, 'PENDING', now() - interval '2 hours', now() - interval '2 hours');

-- Review queue
INSERT INTO review_queue (id, decision_id, tx_id, status, assigned_to, created_at, updated_at, resolved_at, resolution)
VALUES
  ('01890000-0000-7000-8000-000000000230', 'dec-003', 'tx-005', 'PENDING', NULL, now() - interval '30 minutes', now() - interval '30 minutes', NULL, NULL),
  ('01890000-0000-7000-8000-000000000231', 'dec-002', 'tx-004', 'RESOLVED', 'analyst-1', now() - interval '1 hour', now() - interval '40 minutes', now() - interval '40 minutes', 'CONFIRMED_DENY');

-- UUID PKs are app-generated; no sequence sync needed.