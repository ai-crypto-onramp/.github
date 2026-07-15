-- Fixtures for aml_kyt database
\c aml_kyt;

INSERT INTO address_risk_cache (address, chain, risk_score, exposure, decision, vendor, cached_at, ttl_seconds, expires_at)
VALUES
  ('0xabc123def456789012345678901234567890abcd', 'ethereum', 12, 'low', 'approve', 'chainalysis', now() - interval '1 hour', 3600, now() + interval '50 minutes'),
  ('0xdef456789012345678901234567890abcd123456', 'ethereum', 85, 'high', 'block', 'trm', now() - interval '30 minutes', 3600, now() + interval '30 minutes'),
  ('bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'bitcoin', 45, 'medium', 'review', 'chainalysis', now() - interval '2 hours', 3600, now() - interval '1 hour');

INSERT INTO kyt_screens (screen_id, tx_id, address, source_address, chain, amount, risk_score, exposure, decision, vendor, vendor_response_id, cache_hit, created_at)
VALUES
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'tx-001', '0xabc123def456789012345678901234567890abcd', '0x999888777666555544443333222211110000fffe', 'ethereum', 1.5, 12, 'low', 'approve', 'chainalysis', 'f7e6d5c4-b3a2-1980-fedc-ba9876543210', true, now() - interval '55 minutes'),
  ('b2c3d4e5-f6a7-8901-bcde-f12345678901', 'tx-002', '0xdef456789012345678901234567890abcd123456', '0xaaa999888777666555544443333222211110000', 'ethereum', 0.05, 85, 'high', 'block', 'trm', 'e5d4c3b2-a1f0-9876-5432-109876543210', false, now() - interval '25 minutes');

INSERT INTO kyt_alerts (id, screen_id, tx_id, address, chain, exposure, severity, status, assignee, created_at, closed_at)
VALUES
  ('c3d4e5f6-a7b8-9012-cdef-123456789012', 'b2c3d4e5-f6a7-8901-bcde-f12345678901', 'tx-002', '0xdef456789012345678901234567890abcd123456', 'ethereum', 'high', 'high', 'in_review', 'analyst-1', now() - interval '25 minutes', NULL),
  ('d4e5f6a7-b8c9-0123-def2-345678901234', NULL, 'tx-003', 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'bitcoin', 'medium', 'medium', 'open', NULL, now() - interval '10 minutes', NULL);

INSERT INTO vendor_responses (id, vendor, request_payload, response_payload, idempotency_key, address, chain, tx_id, created_at)
VALUES
  ('e5f6a7b8-c9d0-1234-ef23-456789012345', 'chainalysis', '{"action":"score"}'::jsonb, '{"score":12,"exposure":"low"}'::jsonb, 'idem-chainalysis-001', '0xabc123def456789012345678901234567890abcd', 'ethereum', 'tx-001', now() - interval '55 minutes'),
  ('f6a7b8c9-d0e1-2345-f234-567890123456', 'trm', '{"action":"score"}'::jsonb, '{"score":85,"exposure":"high"}'::jsonb, 'idem-trm-001', '0xdef456789012345678901234567890abcd123456', 'ethereum', 'tx-002', now() - interval '25 minutes');

INSERT INTO audit_events (screen_id, tx_id, address, chain, amount, decision, exposure, risk_score, vendor, cache_hit, source, operator, created_at)
VALUES
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'tx-001', '0xabc123def456789012345678901234567890abcd', 'ethereum', '1.5', 'approve', 'low', 12, 'chainalysis', true, 'aml-kyt-screening', NULL, now() - interval '55 minutes'),
  ('b2c3d4e5-f6a7-8901-bcde-f12345678901', 'tx-002', '0xdef456789012345678901234567890abcd123456', 'ethereum', '0.05', 'block', 'high', 85, 'trm', false, 'aml-kyt-screening', NULL, now() - interval '25 minutes'),
  (NULL, 'tx-003', 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'bitcoin', '0.25', 'review', 'medium', 45, 'chainalysis', true, 'aml-kyt-screening', NULL, now() - interval '10 minutes');