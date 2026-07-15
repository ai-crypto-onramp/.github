-- Fixtures for liquidity database
\c liquidity;

INSERT INTO parent_orders (id, asset, side, notional, strategy, status, quoted_mid, realized_slippage_bps, vwap_benchmark, client_request_id, filled_qty, avg_fill_price, total_fee, slice_count, created_at, updated_at)
VALUES
  ('po-001', 'BTC', 'buy', 50000.0, 'twap', 'executing', 65000.0, 2.5, 65162.5, 'bo-ui-1001', 30.0, 65162.5, 15.0, 4, now() - interval '1 hour', now() - interval '15 minutes'),
  ('po-002', 'ETH', 'buy', 25000.0, 'vwap', 'complete', 3200.0, 1.0, 3203.2, 'bo-ui-1002', 25000.0, 3203.2, 8.0, 3, now() - interval '3 hours', now() - interval '2 hours'),
  ('po-003', 'USDC', 'sell', 100000.0, 'pov', 'pending', 1.0, 0.0, 0.0, 'bo-ui-1003', 0.0, 0.0, 0.0, 0, now() - interval '5 minutes', now() - interval '5 minutes');

INSERT INTO child_orders (id, parent_order_id, venue_id, side, size, price_limit, status, idempotency_key, slice_index, created_at, updated_at)
VALUES
  ('co-001', 'po-001', 'kraken', 'buy', 12.5, 65100.0, 'filled', 'idem-co-001', 0, now() - interval '55 minutes', now() - interval '50 minutes'),
  ('co-002', 'po-001', 'binance', 'buy', 12.5, 65200.0, 'filled', 'idem-co-002', 1, now() - interval '40 minutes', now() - interval '35 minutes'),
  ('co-003', 'po-001', 'kraken', 'buy', 12.5, 65150.0, 'working', 'idem-co-003', 2, now() - interval '25 minutes', now() - interval '20 minutes'),
  ('co-004', 'po-001', 'binance', 'buy', 12.5, 65250.0, 'open', 'idem-co-004', 3, now() - interval '10 minutes', now() - interval '10 minutes'),
  ('co-005', 'po-002', 'kraken', 'buy', 10000.0, 3200.0, 'filled', 'idem-co-005', 0, now() - interval '2 hours', now() - interval '2 hours'),
  ('co-006', 'po-002', 'binance', 'buy', 10000.0, 3205.0, 'filled', 'idem-co-006', 1, now() - interval '2 hours', now() - interval '2 hours'),
  ('co-007', 'po-002', 'kraken', 'buy', 5000.0, 3203.0, 'filled', 'idem-co-007', 2, now() - interval '2 hours', now() - interval '2 hours');

INSERT INTO fills (id, child_order_id, parent_order_id, venue_id, price, quantity, fee, venue_order_id, idempotency_key, executed_at)
VALUES
  ('fill-001', 'co-001', 'po-001', 'kraken', 65098.0, 12.5, 3.75, 'kraken-1001', 'idem-fill-001', now() - interval '50 minutes'),
  ('fill-002', 'co-002', 'po-001', 'binance', 65205.0, 12.5, 3.75, 'binance-2001', 'idem-fill-002', now() - interval '35 minutes'),
  ('fill-003', 'co-005', 'po-002', 'kraken', 3200.5, 10000.0, 2.0, 'kraken-1002', 'idem-fill-003', now() - interval '2 hours'),
  ('fill-004', 'co-006', 'po-002', 'binance', 3205.0, 10000.0, 3.0, 'binance-2002', 'idem-fill-004', now() - interval '2 hours'),
  ('fill-005', 'co-007', 'po-002', 'kraken', 3203.2, 5000.0, 1.0, 'kraken-1003', 'idem-fill-005', now() - interval '2 hours');

INSERT INTO venue_states (venue_id, asset, available_balance, top_bid, top_ask, latency_ms, error_rate, healthy, last_heartbeat_at)
VALUES
  ('kraken', 'BTC', 150.0, 64990.0, 65010.0, 45, 0.01, true, now() - interval '1 minute'),
  ('kraken', 'ETH', 2000.0, 3198.0, 3201.0, 45, 0.01, true, now() - interval '1 minute'),
  ('binance', 'BTC', 500.0, 64995.0, 65005.0, 20, 0.005, true, now() - interval '30 seconds'),
  ('binance', 'ETH', 5000.0, 3199.0, 3200.5, 20, 0.005, true, now() - interval '30 seconds'),
  ('binance', 'USDC', 2000000.0, 0.9998, 1.0001, 20, 0.005, true, now() - interval '30 seconds'),
  ('kraken', 'USDC', 1000000.0, 0.9999, 1.0002, 45, 0.01, true, now() - interval '1 minute');