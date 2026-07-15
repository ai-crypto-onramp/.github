-- Fixtures for identity_auth database
\c identity_auth;

INSERT INTO users (id, email, password_hash, status, created_at, updated_at, closed_at)
VALUES
  ('user-001', 'alice@example.com', 'argon2id$hash-001', 'active', now() - interval '30 days', now() - interval '1 day', NULL),
  ('user-002', 'bob@example.com', 'argon2id$hash-002', 'active', now() - interval '20 days', now() - interval '2 days', NULL),
  ('user-003', 'charlie@example.com', 'argon2id$hash-003', 'locked', now() - interval '10 days', now() - interval '5 days', NULL),
  ('user-004', 'diana@example.com', 'argon2id$hash-004', 'pending', now() - interval '1 hour', now() - interval '1 hour', NULL);

INSERT INTO sessions (id, user_id, refresh_token_hash, issuer, issued_at, last_seen_at, expires_at, revoked_at)
VALUES
  ('sess-001', 'user-001', 'rthash-001', 'api-gateway', now() - interval '1 day', now() - interval '10 minutes', now() + interval '6 days', NULL),
  ('sess-002', 'user-002', 'rthash-002', 'api-gateway', now() - interval '2 days', now() - interval '1 hour', now() + interval '5 days', NULL),
  ('sess-003', 'user-001', 'rthash-003', 'api-gateway', now() - interval '7 days', now() - interval '7 days', now() - interval '1 day', now() - interval '1 day');

INSERT INTO mfa_factors (id, user_id, type, secret_encrypted, confirmed, created_at, disabled_at)
VALUES
  ('mfa-001', 'user-001', 'totp', decode('7365637265745f656e637279707465645f303031', 'hex'), true, now() - interval '29 days', NULL),
  ('mfa-002', 'user-002', 'totp', decode('7365637265745f656e637279707465645f303032', 'hex'), true, now() - interval '19 days', NULL);

INSERT INTO mfa_recovery_codes (id, user_id, code_hash, used_at)
VALUES
  ('rc-001', 'user-001', 'rchash-001', NULL),
  ('rc-002', 'user-001', 'rchash-002', NULL),
  ('rc-003', 'user-001', 'rchash-003', now() - interval '5 days'),
  ('rc-004', 'user-002', 'rchash-004', NULL);

INSERT INTO api_keys (id, partner_id, prefix, key_hash, scopes, ip_allowlist, expires_at, created_at, revoked_at, previous_key_hash, previous_prefix, rotated_at)
VALUES
  ('key-001', 'partner-acme', 'ak_live_', 'keyhash-001', '["payments:write","quotes:read"]'::jsonb, '["10.0.0.0/8"]'::jsonb, now() + interval '90 days', now() - interval '15 days', NULL, NULL, NULL, NULL),
  ('key-002', 'partner-globex', 'ak_live_', 'keyhash-002', '["payments:read"]'::jsonb, '[]'::jsonb, now() + interval '30 days', now() - interval '5 days', NULL, NULL, NULL, NULL);

-- Roles are seeded by the migration; add role bindings
-- INSERT INTO role_bindings (id, subject_type, subject_id, role, scope_type, scope_id, created_at)
-- VALUES
--   ('rb-001', 'user', 'user-001', 'user', NULL, NULL, now() - interval '30 days'),
--   ('rb-002', 'user', 'user-002', 'user', NULL, NULL, now() - interval '20 days'),
--   ('rb-003', 'api_key', 'key-001', 'partner_api', NULL, NULL, now() - interval '15 days'),
--   ('rb-004', 'user', 'user-003', 'user', NULL, NULL, now() - interval '10 days');

INSERT INTO password_resets (id, user_id, token_hash, expires_at, used_at)
VALUES
  ('pr-001', 'user-003', 'prhash-001', now() - interval '4 days', now() - interval '4 days');

INSERT INTO lockouts (user_id, fail_count, locked_until, updated_at)
VALUES
  ('user-003', 5, now() - interval '4 days', now() - interval '4 days');

INSERT INTO audit_events (id, type, subject_id, session_id, request_id, metadata, created_at)
VALUES
  ('ae-001', 'user.login', 'user-001', 'sess-001', 'req-001', '{"ip":"10.0.0.1"}'::jsonb, now() - interval '1 day'),
  ('ae-002', 'user.login_failed', 'user-003', NULL, 'req-002', '{"ip":"10.0.0.2","reason":"bad_password"}'::jsonb, now() - interval '4 days'),
  ('ae-003', 'api_key.created', 'key-001', NULL, 'req-003', '{"partner_id":"partner-acme"}'::jsonb, now() - interval '15 days');

INSERT INTO verification_tokens (token_hash, user_id, created_at)
VALUES
  ('vthash-001', 'user-004', now() - interval '1 hour');

INSERT INTO used_refresh_tokens (token_hash, session_id, created_at)
VALUES
  ('urthash-001', 'sess-003', now() - interval '1 day');