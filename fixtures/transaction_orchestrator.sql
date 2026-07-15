-- Fixtures for transaction_orchestrator database
\c transaction_orchestrator;

INSERT INTO transactions (tx_id, user_id, quote_id, amount, asset, rail, dest_address, status, created_at, updated_at, version)
VALUES
  ('tx-001', 'user-001', 'quote-001', '5000', 'BTC', 'card', '0xabc123def456789012345678901234567890abcd', 'completed', now() - interval '3 hours', now() - interval '2 hours', 5),
  ('tx-002', 'user-002', 'quote-002', '2500', 'ETH', 'ach', '0xdef456789012345678901234567890abcd123456', 'executing', now() - interval '1 hour', now() - interval '10 minutes', 3),
  ('tx-003', 'user-001', 'quote-003', '1000', 'USDC', 'sepa', '0x999888777666555544443333222211110000fffe', 'pending', now() - interval '5 minutes', now() - interval '5 minutes', 1),
  ('tx-004', 'user-003', 'quote-004', '500', 'BTC', 'card', 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', 'failed', now() - interval '4 hours', now() - interval '3 hours', 4);

INSERT INTO transaction_steps (tx_id, step_name, status, attempt, started_at, finished_at, error, idempotency_key)
VALUES
  ('tx-001', 'policy_check', 'completed', 1, now() - interval '3 hours', now() - interval '3 hours', NULL, 'idem-tx001-policy-1'),
  ('tx-001', 'payment_capture', 'completed', 1, now() - interval '3 hours', now() - interval '2 hours', NULL, 'idem-tx001-payment-1'),
  ('tx-001', 'kyt_screen', 'completed', 1, now() - interval '3 hours', now() - interval '3 hours', NULL, 'idem-tx001-kyt-1'),
  ('tx-001', 'mpc_sign', 'completed', 1, now() - interval '3 hours', now() - interval '2 hours', NULL, 'idem-tx001-mpc-1'),
  ('tx-001', 'chain_broadcast', 'completed', 1, now() - interval '2 hours', now() - interval '2 hours', NULL, 'idem-tx001-chain-1'),
  ('tx-001', 'ledger_post', 'completed', 1, now() - interval '2 hours', now() - interval '2 hours', NULL, 'idem-tx001-ledger-1'),
  ('tx-002', 'policy_check', 'completed', 1, now() - interval '1 hour', now() - interval '1 hour', NULL, 'idem-tx002-policy-1'),
  ('tx-002', 'payment_capture', 'completed', 1, now() - interval '1 hour', now() - interval '50 minutes', NULL, 'idem-tx002-payment-1'),
  ('tx-002', 'kyt_screen', 'completed', 1, now() - interval '50 minutes', now() - interval '45 minutes', NULL, 'idem-tx002-kyt-1'),
  ('tx-002', 'mpc_sign', 'executing', 1, now() - interval '45 minutes', NULL, NULL, 'idem-tx002-mpc-1'),
  ('tx-003', 'policy_check', 'pending', 1, NULL, NULL, NULL, 'idem-tx003-policy-1'),
  ('tx-004', 'policy_check', 'completed', 1, now() - interval '4 hours', now() - interval '4 hours', NULL, 'idem-tx004-policy-1'),
  ('tx-004', 'payment_capture', 'failed', 1, now() - interval '4 hours', now() - interval '3 hours', 'card declined: insufficient funds', 'idem-tx004-payment-1'),
  ('tx-004', 'payment_capture', 'failed', 2, now() - interval '3 hours', now() - interval '3 hours', 'card declined: insufficient funds', 'idem-tx004-payment-2');

INSERT INTO saga_state (tx_id, current_step, state, lease_owner, lease_expires_at, payload, version)
VALUES
  ('tx-001', 'ledger_post', 'completed', NULL, NULL, '{"result":"success"}'::jsonb, 5),
  ('tx-002', 'mpc_sign', 'running', 'mpc-worker-1', now() + interval '5 minutes', '{"participants":["node-0","node-1","node-2"]}'::jsonb, 3),
  ('tx-003', 'policy_check', 'pending', NULL, NULL, '{}'::jsonb, 1),
  ('tx-004', 'payment_capture', 'compensating', 'saga-worker-1', now() + interval '10 minutes', '{"error":"card declined"}'::jsonb, 4);

INSERT INTO outbox_events (event_id, tx_id, event_type, step, attempt, payload, created_at, published_at, status, dedup_key)
VALUES
  ('11111111-2222-3333-4444-555555555555', 'tx-001', 'tx.completed', 'ledger_post', 1, '{"status":"completed"}'::jsonb, now() - interval '2 hours', now() - interval '2 hours', 'published', 'dedup-tx001-completed'),
  ('22222222-3333-4444-5555-666666666666', 'tx-002', 'step.started', 'mpc_sign', 1, '{"step":"mpc_sign"}'::jsonb, now() - interval '45 minutes', now() - interval '44 minutes', 'published', 'dedup-tx002-mpc-start'),
  ('33333333-4444-5555-6666-777777777777', 'tx-004', 'tx.failed', 'payment_capture', 2, '{"reason":"card declined"}'::jsonb, now() - interval '3 hours', now() - interval '3 hours', 'published', 'dedup-tx004-failed'),
  ('44444444-5555-6666-7777-888888888888', 'tx-004', 'saga.compensating', 'payment_capture', 2, '{"reason":"card declined"}'::jsonb, now() - interval '3 hours', NULL, 'pending', 'dedup-tx004-compensate');