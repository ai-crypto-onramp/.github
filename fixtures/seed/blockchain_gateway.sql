-- Fixtures for blockchain_gateway database
\c blockchain_gateway;

INSERT INTO broadcasts (id, chain_id, tx_hash, signed_tx, from_addr, to_addr, value, nonce, submitted_at, submitted_by, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000601', 'ethereum', '0xaaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1', decode('0f86c0185e8d4a5100082520894bbb222bbb222bbb222bbb222bbb222bbb222bbb22880de0b6b3a7640000801ca0ccc333ccc333ccc333ccc333ccc333ccc333ccc333ccc333ccc333ccc333ccc3a0ddd444ddd444ddd444ddd444ddd444ddd444ddd444ddd444ddd444ddd444ddd4', 'hex'), '0xeee001eee001eee001eee001eee001eee001eee001', '0xbbb222bbb222bbb222bbb222bbb222bbb222bbb22', 1.0, 5, now() - interval '1 hour', 'transaction-orchestrator', now() - interval '1 hour', now() - interval '1 hour'),
  ('01890000-0000-7000-8000-000000000602', 'bitcoin', 'bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222', decode('0100000001abcdef1234567890', 'hex'), 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq', 0.15, 0, now() - interval '30 minutes', 'transaction-orchestrator', now() - interval '30 minutes', now() - interval '30 minutes');

INSERT INTO tx_confirmations (id, chain_id, tx_hash, status, block_height, block_hash, confirmations, first_seen_at, confirmed_at, finalized_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000610', 'ethereum', '0xaaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1', 'CONFIRMED', 19000000, '0xfff000fff000fff000fff000fff000fff000fff000fff000fff000fff000fff000', 12, now() - interval '55 minutes', now() - interval '45 minutes', now() - interval '20 minutes', now() - interval '55 minutes', now() - interval '20 minutes'),
  ('01890000-0000-7000-8000-000000000611', 'bitcoin', 'bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222', 'PENDING', 840000, '', 0, now() - interval '30 minutes', NULL, NULL, now() - interval '30 minutes', now() - interval '30 minutes');

INSERT INTO chain_tips (chain_id, tip_height, tip_hash, finalized_height, created_at, updated_at)
VALUES
  ('ethereum', 19000012, '0xfff000fff000fff000fff000fff000fff000fff000fff000fff000fff000fff000', 19000000, now() - interval '1 hour', now() - interval '5 minutes'),
  ('bitcoin', 840000, '0000000000000000000abc123def4567890123456789012345678901234567890', 839995, now() - interval '1 hour', now() - interval '8 minutes');

INSERT INTO fee_estimates (id, chain_id, priority, gas_limit, max_fee_per_gas, max_priority_fee_per_gas, gas_price, total_fee, sample_count, strategy, computed_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000620', 'ethereum', 'LOW',    21000, 12.5, 1.0, 0, 0.0002625, 10, 'percentile_50', now() - interval '3 minutes', now() - interval '3 minutes', now() - interval '3 minutes'),
  ('01890000-0000-7000-8000-000000000621', 'ethereum', 'MEDIUM', 21000, 25.0, 2.0, 0, 0.000525,  10, 'percentile_75', now() - interval '3 minutes', now() - interval '3 minutes', now() - interval '3 minutes'),
  ('01890000-0000-7000-8000-000000000622', 'ethereum', 'HIGH',   21000, 50.0, 5.0, 0, 0.00105,   10, 'percentile_95', now() - interval '3 minutes', now() - interval '3 minutes', now() - interval '3 minutes');

INSERT INTO reorg_events (id, chain_id, detected_at, old_tip_hash, new_tip_hash, common_ancestor_height, affected_tx_hashes, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000630', 'ethereum', now() - interval '2 hours', '0xold00000000000000000000000000000000000000000000000000000000000000', '0xnew00000000000000000000000000000000000000000000000000000000000000', 18999990, ARRAY['0xaaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1'], now() - interval '2 hours', now() - interval '2 hours');

INSERT INTO outbox (id, chain_id, tx_hash, status, block_height, event_type, payload, created_at, updated_at, emitted_at)
VALUES
  ('01890000-0000-7000-8000-000000000640', 'ethereum', '0xaaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1', 'CONFIRMED', 19000000, 'tx.confirmed', decode('7b2274785f68617368223a223078616161317d', 'hex'), now() - interval '45 minutes', now() - interval '45 minutes', now() - interval '40 minutes'),
  ('01890000-0000-7000-8000-000000000641', 'bitcoin', 'bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222', 'BROADCAST', 0, 'tx.broadcast', decode('7b2274785f68617368223a22626262327d', 'hex'), now() - interval '30 minutes', now() - interval '30 minutes', now() - interval '28 minutes');