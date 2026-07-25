-- Fixtures for identity_auth database
\c identity_auth;

-- Fixed UUIDv7-style literals for deterministic fixtures.
INSERT INTO users (id, email, password_hash, status, created_at, updated_at, closed_at)
VALUES
  ('01890000-0000-7000-8000-000000000001', 'alice@example.com', 'argon2id$hash-001', 'ACTIVE', now() - interval '30 days', now() - interval '1 day', NULL),
  ('01890000-0000-7000-8000-000000000002', 'bob@example.com',   'argon2id$hash-002', 'ACTIVE', now() - interval '20 days', now() - interval '2 days', NULL),
  ('01890000-0000-7000-8000-000000000003', 'charlie@example.com', 'argon2id$hash-003', 'LOCKED', now() - interval '10 days', now() - interval '5 days', NULL),
  ('01890000-0000-7000-8000-000000000004', 'diana@example.com', 'argon2id$hash-004', 'PENDING', now() - interval '1 hour', now() - interval '1 hour', NULL);

INSERT INTO sessions (id, user_id, refresh_token_hash, issuer, issued_at, last_seen_at, expires_at, revoked_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000010', '01890000-0000-7000-8000-000000000001', 'rthash-001', 'api-gateway', now() - interval '1 day', now() - interval '10 minutes', now() + interval '6 days', NULL, now() - interval '1 day', now() - interval '10 minutes'),
  ('01890000-0000-7000-8000-000000000011', '01890000-0000-7000-8000-000000000002', 'rthash-002', 'api-gateway', now() - interval '2 days', now() - interval '1 hour', now() + interval '5 days', NULL, now() - interval '2 days', now() - interval '1 hour'),
  ('01890000-0000-7000-8000-000000000012', '01890000-0000-7000-8000-000000000001', 'rthash-003', 'api-gateway', now() - interval '7 days', now() - interval '7 days', now() - interval '1 day', now() - interval '1 day', now() - interval '7 days', now() - interval '1 day');

INSERT INTO mfa_factors (id, user_id, type, secret_encrypted, confirmed, created_at, updated_at, disabled_at)
VALUES
  ('01890000-0000-7000-8000-000000000020', '01890000-0000-7000-8000-000000000001', 'TOTP', decode('7365637265745f656e637279707465645f303031', 'hex'), true, now() - interval '29 days', now() - interval '29 days', NULL),
  ('01890000-0000-7000-8000-000000000021', '01890000-0000-7000-8000-000000000002', 'TOTP', decode('7365637265745f656e637279707465645f303032', 'hex'), true, now() - interval '19 days', now() - interval '19 days', NULL);

INSERT INTO mfa_recovery_codes (id, user_id, code_hash, used_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000030', '01890000-0000-7000-8000-000000000001', 'rchash-001', NULL, now() - interval '29 days', now() - interval '29 days'),
  ('01890000-0000-7000-8000-000000000031', '01890000-0000-7000-8000-000000000001', 'rchash-002', NULL, now() - interval '29 days', now() - interval '29 days'),
  ('01890000-0000-7000-8000-000000000032', '01890000-0000-7000-8000-000000000001', 'rchash-003', now() - interval '5 days', now() - interval '29 days', now() - interval '5 days'),
  ('01890000-0000-7000-8000-000000000033', '01890000-0000-7000-8000-000000000002', 'rchash-004', NULL, now() - interval '19 days', now() - interval '19 days');

INSERT INTO api_keys (id, partner_id, prefix, key_hash, scopes, ip_allowlist, expires_at, created_at, updated_at, revoked_at, previous_key_hash, previous_prefix, rotated_at)
VALUES
  ('01890000-0000-7000-8000-000000000040', 'partner-acme', 'ak_live_', 'keyhash-001', '["payments:write","quotes:read"]'::jsonb, '["10.0.0.0/8"]'::jsonb, now() + interval '90 days', now() - interval '15 days', now() - interval '15 days', NULL, NULL, NULL, NULL),
  ('01890000-0000-7000-8000-000000000041', 'partner-globex', 'ak_live_', 'keyhash-002', '["payments:read"]'::jsonb, '[]'::jsonb, now() + interval '30 days', now() - interval '5 days', now() - interval '5 days', NULL, NULL, NULL, NULL);

-- Roles are seeded by the migration; add role bindings
-- INSERT INTO role_bindings (id, subject_type, subject_id, role, scope_type, scope_id, created_at, updated_at)
-- VALUES
--   ('01890000-0000-7000-8000-000000000050', 'USER', '01890000-0000-7000-8000-000000000001', 'USER', NULL, NULL, now() - interval '30 days', now() - interval '30 days'),
--   ('01890000-0000-7000-8000-000000000051', 'USER', '01890000-0000-7000-8000-000000000002', 'USER', NULL, NULL, now() - interval '20 days', now() - interval '20 days'),
--   ('01890000-0000-7000-8000-000000000052', 'API_KEY', '01890000-0000-7000-8000-000000000040', 'PARTNER_API', NULL, NULL, now() - interval '15 days', now() - interval '15 days'),
--   ('01890000-0000-7000-8000-000000000053', 'USER', '01890000-0000-7000-8000-000000000003', 'USER', NULL, NULL, now() - interval '10 days', now() - interval '10 days');

INSERT INTO password_resets (id, user_id, token_hash, expires_at, used_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000060', '01890000-0000-7000-8000-000000000003', 'prhash-001', now() - interval '4 days', now() - interval '4 days', now() - interval '4 days', now() - interval '4 days');

INSERT INTO lockouts (id, user_id, fail_count, locked_until, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000070', '01890000-0000-7000-8000-000000000003', 5, now() - interval '4 days', now() - interval '4 days', now() - interval '4 days');

INSERT INTO audit_events (id, type, subject_id, session_id, request_id, metadata, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000080', 'user.login', '01890000-0000-7000-8000-000000000001', '01890000-0000-7000-8000-000000000010', 'req-001', '{"ip":"10.0.0.1"}'::jsonb, now() - interval '1 day', now() - interval '1 day'),
  ('01890000-0000-7000-8000-000000000081', 'user.login_failed', '01890000-0000-7000-8000-000000000003', NULL, 'req-002', '{"ip":"10.0.0.2","reason":"bad_password"}'::jsonb, now() - interval '4 days', now() - interval '4 days'),
  ('01890000-0000-7000-8000-000000000082', 'api_key.created', '01890000-0000-7000-8000-000000000040', NULL, 'req-003', '{"partner_id":"partner-acme"}'::jsonb, now() - interval '15 days', now() - interval '15 days');

INSERT INTO verification_tokens (token_hash, user_id, created_at, updated_at)
VALUES
  ('vthash-001', '01890000-0000-7000-8000-000000000004', now() - interval '1 hour', now() - interval '1 hour');

INSERT INTO used_refresh_tokens (token_hash, session_id, created_at, updated_at)
VALUES
  ('urthash-001', '01890000-0000-7000-8000-000000000012', now() - interval '1 day', now() - interval '1 day');