-- Fixtures for policy_engine database
\c policy_engine;

-- Policies (active_version is nullable initially, set via ALTER)
INSERT INTO policies (id, scope, active_version, created_at)
VALUES
  (1, 'global', NULL, now() - interval '30 days'),
  (2, 'partner:acme', NULL, now() - interval '15 days');

-- Policy versions
INSERT INTO policy_versions (id, policy_id, version, rego_hash, rego_source, created_at, created_by)
VALUES
  (1, 1, 1, 'rego-hash-001', 'package default.allow; default allow := false; allow if { input.amount <= 100000 }', now() - interval '30 days', 'admin'),
  (2, 1, 2, 'rego-hash-002', 'package default.allow; default allow := false; allow if { input.amount <= 500000 }', now() - interval '10 days', 'admin'),
  (3, 2, 3, 'rego-hash-003', 'package default.allow; default allow := false; allow if { input.partner_id == "acme" }', now() - interval '15 days', 'admin');

-- Link active versions
UPDATE policies SET active_version = 2 WHERE id = 1;
UPDATE policies SET active_version = 3 WHERE id = 2;

-- Policy decisions
INSERT INTO policy_decisions (decision_id, policy_version, request_hash, decision, reasons, applied_rules, score, signature, created_at)
VALUES
  ('dec-001', 2, 'req-hash-001', 'allow', ARRAY['amount_within_limit'], ARRAY['default.allow'], 0.95, NULL, now() - interval '2 hours'),
  ('dec-002', 2, 'req-hash-002', 'deny', ARRAY['amount_exceeds_limit'], ARRAY['default.allow'], 0.12, NULL, now() - interval '1 hour'),
  ('dec-003', 2, 'req-hash-003', 'review', ARRAY['velocity_check_triggered'], ARRAY['velocity.check'], 0.55, NULL, now() - interval '30 minutes'),
  ('dec-004', 3, 'req-hash-004', 'allow', ARRAY['partner_whitelisted'], ARRAY['default.allow'], 0.98, NULL, now() - interval '15 minutes');

-- Whitelist addresses
INSERT INTO whitelist_addresses (id, user_id, chain, address, label, verified_at, status, created_at)
VALUES
  (1, 'user-001', 'ethereum', '0xabc123def456789012345678901234567890abcd', 'Alice main wallet', now() - interval '20 days', 'verified', now() - interval '25 days'),
  (2, 'user-002', 'bitcoin', 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'Bob cold storage', now() - interval '15 days', 'verified', now() - interval '18 days'),
  (3, 'user-001', 'ethereum', '0xdef456789012345678901234567890abcd123456', 'Alice backup', NULL, 'pending', now() - interval '2 hours');

-- Review queue
INSERT INTO review_queue (id, decision_id, tx_id, status, assigned_to, created_at, resolved_at, resolution)
VALUES
  (1, 'dec-003', 'tx-005', 'pending', NULL, now() - interval '30 minutes', NULL, NULL),
  (2, 'dec-002', 'tx-004', 'resolved', 'analyst-1', now() - interval '1 hour', now() - interval '40 minutes', 'confirmed_deny');

-- Sync BIGSERIAL sequences to max(id) so service-boot inserts (which rely on
-- nextval) don't collide with the explicit ids seeded above.
SELECT setval(pg_get_serial_sequence('policies',          'id'), COALESCE((SELECT max(id) FROM policies),          1), true);
SELECT setval(pg_get_serial_sequence('policy_versions',   'id'), COALESCE((SELECT max(id) FROM policy_versions),   1), true);
SELECT setval(pg_get_serial_sequence('whitelist_addresses','id'), COALESCE((SELECT max(id) FROM whitelist_addresses),1), true);
SELECT setval(pg_get_serial_sequence('review_queue',      'id'), COALESCE((SELECT max(id) FROM review_queue),      1), true);