-- Fixtures for treasury database
\c treasury;

INSERT INTO batches (id, asset_pair, status, notional_usd, opened_at, closed_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000301', 'BTC/USD', 'OPEN',   50000.0, now() - interval '2 hours', NULL, now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000302', 'ETH/USD', 'CLOSED', 25000.0, now() - interval '4 hours', now() - interval '3 hours', now() - interval '4 hours', now() - interval '3 hours'),
  ('01890000-0000-7000-8000-000000000303', 'BTC/USD', 'OPEN',   15000.0, now() - interval '30 minutes', NULL, now() - interval '30 minutes', now() - interval '30 minutes');

INSERT INTO batch_memberships (id, batch_id, tx_id, amount, asset, fiat_currency, notional_usd, user_id, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000310', '01890000-0000-7000-8000-000000000301', 'tx-001', 0.5,  'BTC', 'USD', 32500.0, '01890000-0000-7000-8000-000000000001', now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000311', '01890000-0000-7000-8000-000000000301', 'tx-005', 0.15, 'BTC', 'USD', 9750.0,  '01890000-0000-7000-8000-000000000002', now() - interval '90 minutes', now() - interval '90 minutes'),
  ('01890000-0000-7000-8000-000000000312', '01890000-0000-7000-8000-000000000301', 'tx-006', 0.12, 'BTC', 'USD', 7800.0,  '01890000-0000-7000-8000-000000000004', now() - interval '80 minutes', now() - interval '80 minutes'),
  ('01890000-0000-7000-8000-000000000313', '01890000-0000-7000-8000-000000000302', 'tx-007', 7.5,  'ETH', 'USD', 24000.0, '01890000-0000-7000-8000-000000000001', now() - interval '4 hours', now() - interval '4 hours'),
  ('01890000-0000-7000-8000-000000000314', '01890000-0000-7000-8000-000000000302', 'tx-008', 0.3,  'ETH', 'USD', 960.0,   '01890000-0000-7000-8000-000000000002', now() - interval '4 hours', now() - interval '4 hours'),
  ('01890000-0000-7000-8000-000000000315', '01890000-0000-7000-8000-000000000303', 'tx-009', 0.08, 'BTC', 'USD', 5200.0,  '01890000-0000-7000-8000-000000000005', now() - interval '25 minutes', now() - interval '25 minutes'),
  ('01890000-0000-7000-8000-000000000316', '01890000-0000-7000-8000-000000000303', 'tx-010', 0.15, 'BTC', 'USD', 9750.0,  '01890000-0000-7000-8000-000000000001', now() - interval '20 minutes', now() - interval '20 minutes');

INSERT INTO aggregate_orders (id, batch_id, asset_pair, side, notional_usd, venue_routes, fill_price, total_filled, hedged_notional, status, created_at, updated_at, settled_at)
VALUES
  ('01890000-0000-7000-8000-000000000320', '01890000-0000-7000-8000-000000000302', 'ETH/USD', 'BUY', 25000.0, '[{"venue":"kraken","share":0.6},{"venue":"binance","share":0.4}]'::jsonb, 3203.2, 7.8, 20000.0, 'SETTLED',   now() - interval '4 hours', now() - interval '3 hours', now() - interval '3 hours'),
  ('01890000-0000-7000-8000-000000000321', '01890000-0000-7000-8000-000000000301', 'BTC/USD', 'BUY', 50000.0, '[{"venue":"kraken","share":0.5},{"venue":"binance","share":0.5}]'::jsonb, 0, 0, 0, 'EXECUTING', now() - interval '2 hours', now() - interval '2 hours', NULL);

INSERT INTO funding_requests (id, wallet_id, asset, amount, status, source_venue, created_at, updated_at, completed_at)
VALUES
  ('01890000-0000-7000-8000-000000000330', 'hot-wallet-btc-001',  'BTC', 2.0,  'PENDING',  'kraken',  now() - interval '1 hour',   now() - interval '1 hour',   NULL),
  ('01890000-0000-7000-8000-000000000331', 'hot-wallet-eth-001',  'ETH', 50.0, 'COMPLETED','binance', now() - interval '3 hours', now() - interval '3 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000332', 'warm-wallet-btc-001','BTC', 5.0,  'PENDING',  'kraken',  now() - interval '30 minutes', now() - interval '30 minutes', NULL);

INSERT INTO float_positions (id, fiat_currency, short_fiat_amount, long_crypto_amount, long_crypto_asset, settlement_due_at, settled, batch_id, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000340', 'USD', 50000.0, 0.77, 'BTC', now() + interval '2 days',  false, '01890000-0000-7000-8000-000000000301', now() - interval '2 hours', now() - interval '10 minutes'),
  ('01890000-0000-7000-8000-000000000341', 'USD', 25000.0, 7.8, 'ETH', now() - interval '1 day',   true,  '01890000-0000-7000-8000-000000000302', now() - interval '4 hours', now() - interval '3 hours'),
  ('01890000-0000-7000-8000-000000000342', 'USD', 15000.0, 0.23, 'BTC', now() + interval '3 days', false, '01890000-0000-7000-8000-000000000303', now() - interval '30 minutes', now() - interval '20 minutes'),
  ('01890000-0000-7000-8000-000000000343', 'EUR', 250000.0, 0,   '',    now() + interval '1 day',  false, NULL,                                    now() - interval '90 minutes', now() - interval '90 minutes');

INSERT INTO rebalancing_jobs (id, from_ref, to_ref, asset, amount, status, reason, created_at, updated_at, completed_at)
VALUES
  ('01890000-0000-7000-8000-000000000350', 'warm-wallet-btc-001', 'hot-wallet-btc-001', 'BTC', 1.5,  'PENDING',  'hot wallet below threshold', now() - interval '45 minutes', now() - interval '45 minutes', NULL),
  ('01890000-0000-7000-8000-000000000351', 'cold-wallet-eth-001', 'warm-wallet-eth-001','ETH', 100.0, 'COMPLETED','scheduled rebalance',        now() - interval '3 hours',   now() - interval '2 hours',   now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000352', 'warm-wallet-btc-001', 'hot-wallet-btc-001', 'BTC', 0.5,  'PENDING',  'increased withdrawal volume', now() - interval '15 minutes', now() - interval '15 minutes', NULL);

INSERT INTO outbox (id, aggregate, event_type, dedup_key, payload, created_at, updated_at, emitted_at)
VALUES
  ('01890000-0000-7000-8000-000000000360', 'batch',      'batch.opened',          'dedup-batch-1-open',  '{"batch_id":"01890000-0000-7000-8000-000000000301"}'::jsonb, now() - interval '2 hours',   now() - interval '2 hours',   now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000361', 'batch',      'batch.closed',          'dedup-batch-2-close', '{"batch_id":"01890000-0000-7000-8000-000000000302"}'::jsonb, now() - interval '3 hours',   now() - interval '3 hours',   now() - interval '3 hours'),
  ('01890000-0000-7000-8000-000000000362', 'funding',    'funding.requested',     'dedup-fr-1',         '{"funding_request_id":"01890000-0000-7000-8000-000000000330"}'::jsonb, now() - interval '1 hour', now() - interval '1 hour', NULL),
  ('01890000-0000-7000-8000-000000000363', 'rebalancing','rebalancing.requested','dedup-rb-1',         '{"rebalancing_job_id":"01890000-0000-7000-8000-000000000350"}'::jsonb, now() - interval '45 minutes', now() - interval '45 minutes', NULL);