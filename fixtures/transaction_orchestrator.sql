-- Fixtures for transaction_orchestrator database
\c transaction_orchestrator;

-- NOTE: tx_id is a business identifier (UNIQUE); the surrogate id UUID is the PK.
INSERT INTO transactions (id, tx_id, user_id, quote_id, amount, asset, rail, dest_address, status, created_at, updated_at, version)
VALUES
  ('01890000-0000-7000-8000-000000000e01', 'tx-001', '01890000-0000-7000-8000-000000000001', 'q-001', '5000', 'BTC',  'CARD', '0xabc123def456789012345678901234567890abcd', 'COMPLETED', now() - interval '3 hours', now() - interval '2 hours', 5),
  ('01890000-0000-7000-8000-000000000e02', 'tx-002', '01890000-0000-7000-8000-000000000002', 'q-002', '2500', 'ETH',  'ACH',  '0xdef456789012345678901234567890abcd123456', 'EXECUTING', now() - interval '1 hour',  now() - interval '10 minutes', 3),
  ('01890000-0000-7000-8000-000000000e03', 'tx-003', '01890000-0000-7000-8000-000000000001', 'q-003', '1000', 'USDC', 'SEPA', '0x999888777666555544443333222211110000fffe', 'PENDING',   now() - interval '5 minutes', now() - interval '5 minutes', 1),
  ('01890000-0000-7000-8000-000000000e04', 'tx-004', '01890000-0000-7000-8000-000000000003', 'q-004', '500',  'BTC',  'CARD', 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',  'FAILED',    now() - interval '4 hours', now() - interval '3 hours', 4);

INSERT INTO transaction_steps (id, tx_id, step_name, status, attempt, started_at, finished_at, error, idempotency_key)
VALUES
  ('01890000-0000-7000-8000-000000000e10', '01890000-0000-7000-8000-000000000e01', 'policy_check',     'COMPLETED', 1, now() - interval '3 hours', now() - interval '3 hours', NULL, 'idem-tx001-policy-1'),
  ('01890000-0000-7000-8000-000000000e11', '01890000-0000-7000-8000-000000000e01', 'payment_capture',  'COMPLETED', 1, now() - interval '3 hours', now() - interval '2 hours', NULL, 'idem-tx001-payment-1'),
  ('01890000-0000-7000-8000-000000000e12', '01890000-0000-7000-8000-000000000e01', 'kyt_screen',      'COMPLETED', 1, now() - interval '3 hours', now() - interval '3 hours', NULL, 'idem-tx001-kyt-1'),
  ('01890000-0000-7000-8000-000000000e13', '01890000-0000-7000-8000-000000000e01', 'mpc_sign',         'COMPLETED', 1, now() - interval '3 hours', now() - interval '2 hours', NULL, 'idem-tx001-mpc-1'),
  ('01890000-0000-7000-8000-000000000e14', '01890000-0000-7000-8000-000000000e01', 'chain_broadcast',  'COMPLETED', 1, now() - interval '2 hours', now() - interval '2 hours', NULL, 'idem-tx001-chain-1'),
  ('01890000-0000-7000-8000-000000000e15', '01890000-0000-7000-8000-000000000e01', 'ledger_post',      'COMPLETED', 1, now() - interval '2 hours', now() - interval '2 hours', NULL, 'idem-tx001-ledger-1'),
  ('01890000-0000-7000-8000-000000000e16', '01890000-0000-7000-8000-000000000e02', 'policy_check',     'COMPLETED', 1, now() - interval '1 hour',  now() - interval '1 hour',  NULL, 'idem-tx002-policy-1'),
  ('01890000-0000-7000-8000-000000000e17', '01890000-0000-7000-8000-000000000e02', 'payment_capture',  'COMPLETED', 1, now() - interval '1 hour',  now() - interval '50 minutes', NULL, 'idem-tx002-payment-1'),
  ('01890000-0000-7000-8000-000000000e18', '01890000-0000-7000-8000-000000000e02', 'kyt_screen',       'COMPLETED', 1, now() - interval '50 minutes', now() - interval '45 minutes', NULL, 'idem-tx002-kyt-1'),
  ('01890000-0000-7000-8000-000000000e19', '01890000-0000-7000-8000-000000000e02', 'mpc_sign',         'EXECUTING', 1, now() - interval '45 minutes', NULL, NULL, 'idem-tx002-mpc-1'),
  ('01890000-0000-7000-8000-000000000e1a', '01890000-0000-7000-8000-000000000e03', 'policy_check',     'PENDING',   1, NULL, NULL, NULL, 'idem-tx003-policy-1'),
  ('01890000-0000-7000-8000-000000000e1b', '01890000-0000-7000-8000-000000000e04', 'policy_check',     'COMPLETED', 1, now() - interval '4 hours', now() - interval '4 hours', NULL, 'idem-tx004-policy-1'),
  ('01890000-0000-7000-8000-000000000e1c', '01890000-0000-7000-8000-000000000e04', 'payment_capture',  'FAILED',    1, now() - interval '4 hours', now() - interval '3 hours', 'card declined: insufficient funds', 'idem-tx004-payment-1'),
  ('01890000-0000-7000-8000-000000000e1d', '01890000-0000-7000-8000-000000000e04', 'payment_capture',  'FAILED',    2, now() - interval '3 hours', now() - interval '3 hours', 'card declined: insufficient funds', 'idem-tx004-payment-2');

-- Backfill created_at/updated_at from the step's started/finished timestamps.
UPDATE transaction_steps SET created_at = COALESCE(started_at, now()), updated_at = COALESCE(finished_at, started_at, now());

INSERT INTO saga_state (id, tx_id, current_step, state, lease_owner, lease_expires_at, payload, version, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000e20', '01890000-0000-7000-8000-000000000e01', 'ledger_post',     'COMPLETED',    NULL,          NULL,                       '{"result":"success"}'::jsonb,                    5, now() - interval '3 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000e21', '01890000-0000-7000-8000-000000000e02', 'mpc_sign',        'RUNNING',       'mpc-worker-1', now() + interval '5 minutes',  '{"participants":["node-0","node-1","node-2"]}'::jsonb, 3, now() - interval '1 hour',  now() - interval '10 minutes'),
  ('01890000-0000-7000-8000-000000000e22', '01890000-0000-7000-8000-000000000e03', 'policy_check',    'PENDING',       NULL,          NULL,                       '{}'::jsonb,                                    1, now() - interval '5 minutes', now() - interval '5 minutes'),
  ('01890000-0000-7000-8000-000000000e23', '01890000-0000-7000-8000-000000000e04', 'payment_capture', 'COMPENSATING', 'saga-worker-1', now() + interval '10 minutes', '{"error":"card declined"}'::jsonb,             4, now() - interval '4 hours', now() - interval '3 hours');

INSERT INTO outbox_events (id, event_id, tx_id, event_type, step, attempt, payload, created_at, updated_at, published_at, status, dedup_key)
VALUES
  ('01890000-0000-7000-8000-000000000e30', '11111111-2222-3333-4444-555555555555', '01890000-0000-7000-8000-000000000e01', 'tx.completed',       'ledger_post',    1, '{"status":"COMPLETED"}'::jsonb, now() - interval '2 hours',    now() - interval '2 hours',    now() - interval '2 hours',    'PUBLISHED', 'dedup-tx001-completed'),
  ('01890000-0000-7000-8000-000000000e31', '22222222-3333-4444-5555-666666666666', '01890000-0000-7000-8000-000000000e02', 'step.started',       'mpc_sign',        1, '{"step":"mpc_sign"}'::jsonb,    now() - interval '45 minutes', now() - interval '45 minutes', now() - interval '44 minutes', 'PUBLISHED', 'dedup-tx002-mpc-start'),
  ('01890000-0000-7000-8000-000000000e32', '33333333-4444-5555-6666-777777777777', '01890000-0000-7000-8000-000000000e04', 'tx.failed',          'payment_capture', 2, '{"reason":"card declined"}'::jsonb, now() - interval '3 hours', now() - interval '3 hours', now() - interval '3 hours', 'PUBLISHED', 'dedup-tx004-failed'),
  ('01890000-0000-7000-8000-000000000e33', '44444444-5555-6666-7777-888888888888', '01890000-0000-7000-8000-000000000e04', 'saga.compensating', 'payment_capture', 2, '{"reason":"card declined"}'::jsonb, now() - interval '3 hours', now() - interval '3 hours', NULL,                        'PENDING',   'dedup-tx004-compensate');