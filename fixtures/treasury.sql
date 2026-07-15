-- Fixtures for treasury database
\c treasury;

INSERT INTO batches (id, asset_pair, status, notional_usd, opened_at, closed_at)
VALUES
  (1, 'BTC/USD', 'open', 50000.0, now() - interval '2 hours', NULL),
  (2, 'ETH/USD', 'closed', 25000.0, now() - interval '4 hours', now() - interval '3 hours'),
  (3, 'BTC/USD', 'open', 15000.0, now() - interval '30 minutes', NULL);

INSERT INTO batch_memberships (id, batch_id, tx_id, amount, asset, fiat_currency, notional_usd, user_id, created_at)
VALUES
  (1, 1, 'tx-001', 0.5, 'BTC', 'USD', 32500.0, 'user-001', now() - interval '2 hours'),
  (2, 1, 'tx-005', 0.15, 'BTC', 'USD', 9750.0, 'user-002', now() - interval '90 minutes'),
  (3, 1, 'tx-006', 0.12, 'BTC', 'USD', 7800.0, 'user-004', now() - interval '80 minutes'),
  (4, 2, 'tx-007', 7.5, 'ETH', 'USD', 24000.0, 'user-001', now() - interval '4 hours'),
  (5, 2, 'tx-008', 0.3, 'ETH', 'USD', 960.0, 'user-002', now() - interval '4 hours'),
  (6, 3, 'tx-009', 0.08, 'BTC', 'USD', 5200.0, 'user-005', now() - interval '25 minutes'),
  (7, 3, 'tx-010', 0.15, 'BTC', 'USD', 9750.0, 'user-001', now() - interval '20 minutes');

INSERT INTO aggregate_orders (id, batch_id, asset_pair, side, notional_usd, venue_routes, fill_price, total_filled, hedged_notional, status, created_at, settled_at)
VALUES
  (1, 2, 'ETH/USD', 'buy', 25000.0, '[{"venue":"kraken","share":0.6},{"venue":"binance","share":0.4}]'::jsonb, 3203.2, 7.8, 20000.0, 'settled', now() - interval '4 hours', now() - interval '3 hours'),
  (2, 1, 'BTC/USD', 'buy', 50000.0, '[{"venue":"kraken","share":0.5},{"venue":"binance","share":0.5}]'::jsonb, 0, 0, 0, 'executing', now() - interval '2 hours', NULL);

INSERT INTO funding_requests (id, wallet_id, asset, amount, status, source_venue, created_at, completed_at)
VALUES
  (1, 'hot-wallet-btc-001', 'BTC', 2.0, 'pending', 'kraken', now() - interval '1 hour', NULL),
  (2, 'hot-wallet-eth-001', 'ETH', 50.0, 'completed', 'binance', now() - interval '3 hours', now() - interval '2 hours'),
  (3, 'warm-wallet-btc-001', 'BTC', 5.0, 'pending', 'kraken', now() - interval '30 minutes', NULL);

INSERT INTO float_positions (id, fiat_currency, short_fiat_amount, long_crypto_amount, long_crypto_asset, settlement_due_at, settled, batch_id, created_at, updated_at)
VALUES
  (1, 'USD', 50000.0, 0.77, 'BTC', now() + interval '2 days', false, 1, now() - interval '2 hours', now() - interval '10 minutes'),
  (2, 'USD', 25000.0, 7.8, 'ETH', now() - interval '1 day', true, 2, now() - interval '4 hours', now() - interval '3 hours'),
  (3, 'USD', 15000.0, 0.23, 'BTC', now() + interval '3 days', false, 3, now() - interval '30 minutes', now() - interval '20 minutes'),
  (4, 'EUR', 250000.0, 0, '', now() + interval '1 day', false, NULL, now() - interval '90 minutes', now() - interval '90 minutes');

INSERT INTO rebalancing_jobs (id, from_ref, to_ref, asset, amount, status, reason, created_at, completed_at)
VALUES
  (1, 'warm-wallet-btc-001', 'hot-wallet-btc-001', 'BTC', 1.5, 'pending', 'hot wallet below threshold', now() - interval '45 minutes', NULL),
  (2, 'cold-wallet-eth-001', 'warm-wallet-eth-001', 'ETH', 100.0, 'completed', 'scheduled rebalance', now() - interval '3 hours', now() - interval '2 hours'),
  (3, 'warm-wallet-btc-001', 'hot-wallet-btc-001', 'BTC', 0.5, 'pending', 'increased withdrawal volume', now() - interval '15 minutes', NULL);

INSERT INTO outbox (id, aggregate, event_type, dedup_key, payload, created_at, emitted_at)
VALUES
  (1, 'batch', 'batch.opened', 'dedup-batch-1-open', '{"batch_id":1}'::jsonb, now() - interval '2 hours', now() - interval '2 hours'),
  (2, 'batch', 'batch.closed', 'dedup-batch-2-close', '{"batch_id":2}'::jsonb, now() - interval '3 hours', now() - interval '3 hours'),
  (3, 'funding', 'funding.requested', 'dedup-fr-1', '{"funding_request_id":1}'::jsonb, now() - interval '1 hour', NULL),
  (4, 'rebalancing', 'rebalancing.requested', 'dedup-rb-1', '{"rebalancing_job_id":1}'::jsonb, now() - interval '45 minutes', NULL);