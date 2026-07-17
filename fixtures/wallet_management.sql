-- Fixtures for wallet_management database
\c wallet_management;

-- Deterministic UUIDv7-style literals (0189... prefix = fixed timestamp).
INSERT INTO wallets (id, chain, type, label, state, key_id, custodian_ref, rotation_days, rotation_after_receives, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000101', 'ethereum', 'HOT', 'ETH Hot Wallet',  'ACTIVE', 'key-eth-hot-001', '', 30, 1000, now() - interval '30 days', now() - interval '1 day'),
  ('01890000-0000-7000-8000-000000000102', 'bitcoin',  'HOT', 'BTC Hot Wallet',  'ACTIVE', 'key-btc-hot-001', '', 30, 500,  now() - interval '30 days', now() - interval '2 days'),
  ('01890000-0000-7000-8000-000000000103', 'ethereum', 'WARM', 'ETH Warm Wallet', 'ACTIVE', 'key-eth-warm-001', 'fireblocks-custody-001', 90, NULL, now() - interval '30 days', now() - interval '5 days'),
  ('01890000-0000-7000-8000-000000000104', 'bitcoin',  'COLD', 'BTC Cold Vault',  'ACTIVE', 'key-btc-cold-001', 'fireblocks-custody-002', 365, NULL, now() - interval '60 days', now() - interval '10 days'),
  ('01890000-0000-7000-8000-000000000105', 'polygon', 'HOT', 'MATIC Hot Wallet', 'PAUSED', 'key-matic-hot-001', '', 30, 1000, now() - interval '15 days', now() - interval '3 days');

INSERT INTO addresses (id, wallet_id, chain, address, derivation_path, index, change, state, receive_count, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000110', '01890000-0000-7000-8000-000000000101', 'ethereum', '0xabc123def456789012345678901234567890abcd', 'm/44''/60''/0''/0/0', 0, 0, 'ACTIVE', 42, now() - interval '30 days', now() - interval '1 day'),
  ('01890000-0000-7000-8000-000000000111', '01890000-0000-7000-8000-000000000102', 'bitcoin', 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'm/84''/0''/0''/0/0', 0, 0, 'ACTIVE', 15, now() - interval '30 days', now() - interval '2 days'),
  ('01890000-0000-7000-8000-000000000112', '01890000-0000-7000-8000-000000000102', 'bitcoin', 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq', 'm/84''/0''/0''/0/1', 1, 0, 'DEPRECATED', 8, now() - interval '25 days', now() - interval '5 days'),
  ('01890000-0000-7000-8000-000000000113', '01890000-0000-7000-8000-000000000103', 'ethereum', '0xdef456789012345678901234567890abcd123456', 'm/44''/60''/1''/0/0', 0, 0, 'ACTIVE', 5, now() - interval '30 days', now() - interval '5 days'),
  ('01890000-0000-7000-8000-000000000114', '01890000-0000-7000-8000-000000000104', 'bitcoin', 'bc1qxyz...coldstorage...', 'm/84''/0''/0''/0/0', 0, 0, 'ACTIVE', 0, now() - interval '60 days', now() - interval '10 days');

INSERT INTO balances (wallet_id, asset, confirmed, pending, locked, last_block_seen, created_at, updated_at)
VALUES
  -- ('01890000-0000-7000-8000-000000000101', 'ETH', 1500000000000000, 500000000000000, 200000000000000, 19000012, now() - interval '30 days', now() - interval '5 minutes'),
  ('01890000-0000-7000-8000-000000000102', 'BTC', 1250000000, 0, 250000000, 840000, now() - interval '30 days', now() - interval '8 minutes'),
  --('01890000-0000-7000-8000-000000000103', 'ETH', 50000000000000000, 0, 0, 19000012, now() - interval '30 days', now() - interval '1 hour'),
  ('01890000-0000-7000-8000-000000000104', 'BTC', 10000000000, 0, 0, 840000, now() - interval '60 days', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000105', 'MATIC', 0, 0, 0, 0, now() - interval '15 days', now() - interval '3 days');

INSERT INTO utxos (outpoint, wallet_id, value, script_type, confirmations, lock_state, locked_at, spent_at, tx_hash, created_at, updated_at)
VALUES
  ('btc:tx001:0', '01890000-0000-7000-8000-000000000102', 500000000, 'P2WPKH', 120, 'FREE', NULL, NULL, 'tx-hash-001', now() - interval '30 days', now() - interval '1 day'),
  ('btc:tx002:1', '01890000-0000-7000-8000-000000000102', 750000000, 'P2WPKH', 85, 'LOCKED', now() - interval '2 hours', NULL, 'tx-hash-002', now() - interval '30 days', now() - interval '2 hours'),
  ('btc:tx003:0', '01890000-0000-7000-8000-000000000104', 5000000000, 'P2WPKH', 500, 'FREE', NULL, NULL, 'tx-hash-003', now() - interval '60 days', now() - interval '5 days'),
  ('btc:tx004:0', '01890000-0000-7000-8000-000000000102', 250000000, 'P2WPKH', 30, 'SPENT', NULL, now() - interval '3 hours', 'tx-hash-004', now() - interval '30 days', now() - interval '3 hours');

INSERT INTO nonces (wallet_id, chain, pending_nonce, broadcast_nonce, version, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000101', 'ethereum', 5, 4, 1, now() - interval '30 days', now() - interval '10 minutes'),
  ('01890000-0000-7000-8000-000000000105', 'polygon', 0, 0, 0, now() - interval '15 days', now() - interval '3 days');

INSERT INTO withdrawal_requests (id, wallet_id, to_address, asset, amount, state, policy_decision_id, failure_reason, tx_hash, nonce_value, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000120', '01890000-0000-7000-8000-000000000101', '0xeee001eee001eee001eee001eee001eee001eee001', 'ETH', 100000000000000000, 'CONFIRMED', 'dec-001', '', '0xwd001', 4, now() - interval '1 hour', now() - interval '30 minutes'),
  ('01890000-0000-7000-8000-000000000121', '01890000-0000-7000-8000-000000000102', 'bc1qrecipient...', 'BTC', 50000000, 'SIGNED', 'dec-002', '', '', NULL, now() - interval '2 hours', now() - interval '1 hour'),
  ('01890000-0000-7000-8000-000000000122', '01890000-0000-7000-8000-000000000101', '0xfff000fff000fff000fff000fff000fff000fff000', 'ETH', 250000000000000000, 'PENDING', '', '', '', NULL, now() - interval '15 minutes', now() - interval '15 minutes');
  --('01890000-0000-7000-8000-000000000123', '01890000-0000-7000-8000-000000000105', '0xaaa999...', 'MATIC', 1000000000000000000, 'FAILED', '', 'policy denied: wallet paused', '', NULL, now() - interval '3 days', now() - interval '3 days');

INSERT INTO key_mappings (wallet_id, key_id, active_from, active_to, rotation_state, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000101', 'key-eth-hot-001', now() - interval '30 days', NULL, 'CURRENT', now() - interval '30 days', now() - interval '30 days'),
  ('01890000-0000-7000-8000-000000000102', 'key-btc-hot-001', now() - interval '30 days', NULL, 'CURRENT', now() - interval '30 days', now() - interval '30 days'),
  ('01890000-0000-7000-8000-000000000102', 'key-btc-hot-000', now() - interval '60 days', now() - interval '30 days', 'RETIRED', now() - interval '60 days', now() - interval '30 days'),
  ('01890000-0000-7000-8000-000000000103', 'key-eth-warm-001', now() - interval '30 days', NULL, 'CURRENT', now() - interval '30 days', now() - interval '30 days'),
  ('01890000-0000-7000-8000-000000000104', 'key-btc-cold-001', now() - interval '60 days', NULL, 'CURRENT', now() - interval '60 days', now() - interval '60 days');

INSERT INTO funding_requests (id, wallet_id, asset, amount, state, treasury_batch_id, reason, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000130', '01890000-0000-7000-8000-000000000102', 'BTC', 200000000, 'SETTLED', 'batch-1', 'hot wallet below threshold', now() - interval '2 hours', now() - interval '1 hour');
  -- ('01890000-0000-7000-8000-000000000131', '01890000-0000-7000-8000-000000000101', 'ETH', 500000000000000, 'REQUESTED', '', 'increased withdrawal volume', now() - interval '30 minutes', now() - interval '30 minutes');

INSERT INTO audit_outbox (id, event_id, wallet_id, event_type, payload, seq, delivered, attempts, created_at, updated_at, delivered_at)
VALUES
  ('01890000-0000-7000-8000-000000000140', '11111111-2222-3333-4444-555555555555', '01890000-0000-7000-8000-000000000101', 'balance.updated', '{"asset":"ETH","confirmed":"1.5"}'::jsonb, 1, true, 1, now() - interval '5 minutes', now() - interval '5 minutes', now() - interval '4 minutes'),
  ('01890000-0000-7000-8000-000000000141', '22222222-3333-4444-5555-666666666666', '01890000-0000-7000-8000-000000000102', 'withdrawal.confirmed', '{"wd_id":"wd-001"}'::jsonb, 2, true, 1, now() - interval '30 minutes', now() - interval '30 minutes', now() - interval '28 minutes'),
  ('01890000-0000-7000-8000-000000000142', '33333333-4444-5555-6666-777777777777', '01890000-0000-7000-8000-000000000102', 'key.rotated', '{"old":"key-btc-hot-000","new":"key-btc-hot-001"}'::jsonb, 3, true, 1, now() - interval '30 days', now() - interval '30 days', now() - interval '30 days');

INSERT INTO audit_seq (wallet_id, seq, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000101', 1, now() - interval '30 days', now() - interval '5 minutes'),
  ('01890000-0000-7000-8000-000000000102', 3, now() - interval '30 days', now() - interval '28 minutes'),
  ('01890000-0000-7000-8000-000000000103', 0, now() - interval '30 days', now() - interval '30 days'),
  ('01890000-0000-7000-8000-000000000104', 0, now() - interval '60 days', now() - interval '60 days');

INSERT INTO balance_events (id, wallet_id, asset, block_height, event_id, applied_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000150', '01890000-0000-7000-8000-000000000101', 'ETH', 19000012, 'evt-balance-001', now() - interval '5 minutes', now() - interval '5 minutes', now() - interval '5 minutes'),
  ('01890000-0000-7000-8000-000000000151', '01890000-0000-7000-8000-000000000102', 'BTC', 840000, 'evt-balance-002', now() - interval '8 minutes', now() - interval '8 minutes', now() - interval '8 minutes');