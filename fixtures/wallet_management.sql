-- Fixtures for wallet_management database
\c wallet_management;

INSERT INTO wallets (id, chain, type, label, state, key_id, custodian_ref, rotation_days, rotation_after_receives, created_at, updated_at)
VALUES
  ('11111111-aaaa-1111-aaaa-111111111111'::uuid, 'ethereum', 'hot', 'ETH Hot Wallet', 'active', 'key-eth-hot-001', '', 30, 1000, now() - interval '30 days', now() - interval '1 day'),
  ('22222222-bbbb-2222-bbbb-222222222222'::uuid, 'bitcoin', 'hot', 'BTC Hot Wallet', 'active', 'key-btc-hot-001', '', 30, 500, now() - interval '30 days', now() - interval '2 days'),
  ('33333333-cccc-3333-cccc-333333333333'::uuid, 'ethereum', 'warm', 'ETH Warm Wallet', 'active', 'key-eth-warm-001', 'fireblocks-custody-001', 90, NULL, now() - interval '30 days', now() - interval '5 days'),
  ('44444444-dddd-4444-dddd-444444444444'::uuid, 'bitcoin', 'cold', 'BTC Cold Vault', 'active', 'key-btc-cold-001', 'fireblocks-custody-002', 365, NULL, now() - interval '60 days', now() - interval '10 days'),
  ('55555555-eeee-5555-eeee-555555555555'::uuid, 'polygon', 'hot', 'MATIC Hot Wallet', 'paused', 'key-matic-hot-001', '', 30, 1000, now() - interval '15 days', now() - interval '3 days');

INSERT INTO addresses (id, wallet_id, chain, address, derivation_path, index, change, state, receive_count, created_at)
VALUES
  ('e0a68022-27ed-5afa-800b-89ea86c06b1d'::uuid, '11111111-aaaa-1111-aaaa-111111111111'::uuid, 'ethereum', '0xabc123def456789012345678901234567890abcd', 'm/44''/60''/0''/0/0', 0, 0, 'active', 42, now() - interval '30 days'),
  ('08a78a09-7b68-5671-bb88-d000601d2a26'::uuid, '22222222-bbbb-2222-bbbb-222222222222'::uuid, 'bitcoin', 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'm/84''/0''/0''/0/0', 0, 0, 'active', 15, now() - interval '30 days'),
  ('3dbc7314-0cb4-53b2-b0cc-9ebcf9affb05'::uuid, '22222222-bbbb-2222-bbbb-222222222222'::uuid, 'bitcoin', 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq', 'm/84''/0''/0''/0/1', 1, 0, 'deprecated', 8, now() - interval '25 days'),
  ('9f7a77a3-e44d-5397-a429-a905e47f59ac'::uuid, '33333333-cccc-3333-cccc-333333333333'::uuid, 'ethereum', '0xdef456789012345678901234567890abcd123456', 'm/44''/60''/1''/0/0', 0, 0, 'active', 5, now() - interval '30 days'),
  ('db5116bc-19c5-5e15-8214-b780aed749c4'::uuid, '44444444-dddd-4444-dddd-444444444444'::uuid, 'bitcoin', 'bc1qxyz...coldstorage...', 'm/84''/0''/0''/0/0', 0, 0, 'active', 0, now() - interval '60 days');

INSERT INTO balances (wallet_id, asset, confirmed, pending, locked, last_block_seen, updated_at)
VALUES
  -- ('11111111-aaaa-1111-aaaa-111111111111'::uuid, 'ETH', 1500000000000000, 500000000000000, 200000000000000, 19000012, now() - interval '5 minutes'),
  ('22222222-bbbb-2222-bbbb-222222222222'::uuid, 'BTC', 1250000000, 0, 250000000, 840000, now() - interval '8 minutes'),
  --('33333333-cccc-3333-cccc-333333333333'::uuid, 'ETH', 50000000000000000, 0, 0, 19000012, now() - interval '1 hour'),
  ('44444444-dddd-4444-dddd-444444444444'::uuid, 'BTC', 10000000000, 0, 0, 840000, now() - interval '2 hours'),
  ('55555555-eeee-5555-eeee-555555555555'::uuid, 'MATIC', 0, 0, 0, 0, now() - interval '3 days');

INSERT INTO utxos (outpoint, wallet_id, value, script_type, confirmations, lock_state, locked_at, spent_at, tx_hash, updated_at)
VALUES
  ('btc:tx001:0', '22222222-bbbb-2222-bbbb-222222222222'::uuid, 500000000, 'p2wpkh', 120, 'free', NULL, NULL, 'tx-hash-001', now() - interval '1 day'),
  ('btc:tx002:1', '22222222-bbbb-2222-bbbb-222222222222'::uuid, 750000000, 'p2wpkh', 85, 'locked', now() - interval '2 hours', NULL, 'tx-hash-002', now() - interval '2 hours'),
  ('btc:tx003:0', '44444444-dddd-4444-dddd-444444444444'::uuid, 5000000000, 'p2wpkh', 500, 'free', NULL, NULL, 'tx-hash-003', now() - interval '5 days'),
  ('btc:tx004:0', '22222222-bbbb-2222-bbbb-222222222222'::uuid, 250000000, 'p2wpkh', 30, 'spent', NULL, now() - interval '3 hours', 'tx-hash-004', now() - interval '3 hours');

INSERT INTO nonces (wallet_id, chain, pending_nonce, broadcast_nonce, version, updated_at)
VALUES
  ('11111111-aaaa-1111-aaaa-111111111111'::uuid, 'ethereum', 5, 4, 1, now() - interval '10 minutes'),
  ('55555555-eeee-5555-eeee-555555555555'::uuid, 'polygon', 0, 0, 0, now() - interval '3 days');

INSERT INTO withdrawal_requests (id, wallet_id, to_address, asset, amount, state, policy_decision_id, failure_reason, tx_hash, nonce_value, created_at, updated_at)
VALUES
  ('65aa73ca-64a0-56ca-8178-fe6e955c5346'::uuid, '11111111-aaaa-1111-aaaa-111111111111'::uuid, '0xeee001eee001eee001eee001eee001eee001eee001', 'ETH', 100000000000000000, 'confirmed', 'dec-001', '', '0xwd001', 4, now() - interval '1 hour', now() - interval '30 minutes'),
  ('8abd5d23-33a7-5ca0-9f90-d3988daab337'::uuid, '22222222-bbbb-2222-bbbb-222222222222'::uuid, 'bc1qrecipient...', 'BTC', 50000000, 'signed', 'dec-002', '', '', NULL, now() - interval '2 hours', now() - interval '1 hour'),
  ('6e8600e9-0844-5379-8e35-17a43ee6ac38'::uuid, '11111111-aaaa-1111-aaaa-111111111111'::uuid, '0xfff000fff000fff000fff000fff000fff000fff000', 'ETH', 250000000000000000, 'pending', '', '', '', NULL, now() - interval '15 minutes', now() - interval '15 minutes');
  --('8b39f1c3-62a9-588e-93b7-28100fa2e5fb'::uuid, '55555555-eeee-5555-eeee-555555555555'::uuid, '0xaaa999...', 'MATIC', 1000000000000000000, 'failed', '', 'policy denied: wallet paused', '', NULL, now() - interval '3 days', now() - interval '3 days');

INSERT INTO key_mappings (wallet_id, key_id, active_from, active_to, rotation_state, created_at)
VALUES
  ('11111111-aaaa-1111-aaaa-111111111111'::uuid, 'key-eth-hot-001', now() - interval '30 days', NULL, 'current', now() - interval '30 days'),
  ('22222222-bbbb-2222-bbbb-222222222222'::uuid, 'key-btc-hot-001', now() - interval '30 days', NULL, 'current', now() - interval '30 days'),
  ('22222222-bbbb-2222-bbbb-222222222222'::uuid, 'key-btc-hot-000', now() - interval '60 days', now() - interval '30 days', 'retired', now() - interval '60 days'),
  ('33333333-cccc-3333-cccc-333333333333'::uuid, 'key-eth-warm-001', now() - interval '30 days', NULL, 'current', now() - interval '30 days'),
  ('44444444-dddd-4444-dddd-444444444444'::uuid, 'key-btc-cold-001', now() - interval '60 days', NULL, 'current', now() - interval '60 days');

INSERT INTO funding_requests (id, wallet_id, asset, amount, state, treasury_batch_id, reason, created_at, updated_at)
VALUES
  ('4ed11454-a41b-5e3e-9151-d21919e49654'::uuid, '22222222-bbbb-2222-bbbb-222222222222'::uuid, 'BTC', 200000000, 'settled', 'batch-1', 'hot wallet below threshold', now() - interval '2 hours', now() - interval '1 hour');
  -- ('3131810f-3c15-5778-b154-404e04162c3b'::uuid, '11111111-aaaa-1111-aaaa-111111111111'::uuid, 'ETH', 500000000000000, 'requested', '', 'increased withdrawal volume', now() - interval '30 minutes', now() - interval '30 minutes');

INSERT INTO audit_outbox (id, event_id, wallet_id, event_type, payload, seq, delivered, attempts, created_at, delivered_at)
VALUES
  ('2a170bb4-3229-5c77-bdf8-78b785cd54d1'::uuid, '11111111-2222-3333-4444-555555555555'::uuid, '11111111-aaaa-1111-aaaa-111111111111'::uuid, 'balance.updated', '{"asset":"ETH","confirmed":"1.5"}'::jsonb, 1, true, 1, now() - interval '5 minutes', now() - interval '4 minutes'),
  ('b0f4cf84-74e1-5078-af9e-6ae752df0b60'::uuid, '22222222-3333-4444-5555-666666666666'::uuid, '22222222-bbbb-2222-bbbb-222222222222'::uuid, 'withdrawal.confirmed', '{"wd_id":"wd-001"}'::jsonb, 2, true, 1, now() - interval '30 minutes', now() - interval '28 minutes'),
  ('b308930c-0400-5ecd-94d9-6cdbf4894c48'::uuid, '33333333-4444-5555-6666-777777777777'::uuid, '22222222-bbbb-2222-bbbb-222222222222'::uuid, 'key.rotated', '{"old":"key-btc-hot-000","new":"key-btc-hot-001"}'::jsonb, 3, true, 1, now() - interval '30 days', now() - interval '30 days');

INSERT INTO audit_seq (wallet_id, seq)
VALUES
  ('11111111-aaaa-1111-aaaa-111111111111'::uuid, 1),
  ('22222222-bbbb-2222-bbbb-222222222222'::uuid, 3),
  ('33333333-cccc-3333-cccc-333333333333'::uuid, 0),
  ('44444444-dddd-4444-dddd-444444444444'::uuid, 0);

INSERT INTO balance_events (id, wallet_id, asset, block_height, event_id, applied_at)
VALUES
  ('faa7d2f9-72b1-5694-9282-7abdcf4f0f99'::uuid, '11111111-aaaa-1111-aaaa-111111111111'::uuid, 'ETH', 19000012, 'evt-balance-001', now() - interval '5 minutes'),
  ('3938dfb0-773e-5c29-9760-89ef901cec8f'::uuid, '22222222-bbbb-2222-bbbb-222222222222'::uuid, 'BTC', 840000, 'evt-balance-002', now() - interval '8 minutes');