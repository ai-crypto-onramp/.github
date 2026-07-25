-- Fixtures for liquidity database
\c liquidity;

INSERT INTO parent_orders (id, asset, side, notional, strategy, status, quoted_mid, realized_slippage_bps, vwap_benchmark, client_request_id, filled_qty, avg_fill_price, total_fee, slice_count, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000901', 'BTC',  'BUY',  50000.0,  'TWAP', 'EXECUTING', 65000.0, 2.5, 65162.5, 'bo-ui-1001', 30.0, 65162.5, 15.0, 4, now() - interval '1 hour', now() - interval '15 minutes'),
  ('01890000-0000-7000-8000-000000000902', 'ETH',  'BUY',  25000.0,  'VWAP', 'COMPLETE',  3200.0,  1.0, 3203.2,  'bo-ui-1002', 25000.0, 3203.2, 8.0, 3, now() - interval '3 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000903', 'USDC', 'SELL', 100000.0, 'POV',  'PENDING',   1.0,    0.0, 0.0,     'bo-ui-1003', 0.0, 0.0, 0.0, 0, now() - interval '5 minutes', now() - interval '5 minutes');

INSERT INTO child_orders (id, parent_order_id, venue_id, side, size, price_limit, status, idempotency_key, slice_index, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000910', '01890000-0000-7000-8000-000000000901', 'kraken',  'BUY', 12.5, 65100.0, 'FILLED', 'idem-co-001', 0, now() - interval '55 minutes', now() - interval '50 minutes'),
  ('01890000-0000-7000-8000-000000000911', '01890000-0000-7000-8000-000000000901', 'binance', 'BUY', 12.5, 65200.0, 'FILLED', 'idem-co-002', 1, now() - interval '40 minutes', now() - interval '35 minutes'),
  ('01890000-0000-7000-8000-000000000912', '01890000-0000-7000-8000-000000000901', 'kraken',  'BUY', 12.5, 65150.0, 'WORKING', 'idem-co-003', 2, now() - interval '25 minutes', now() - interval '20 minutes'),
  ('01890000-0000-7000-8000-000000000913', '01890000-0000-7000-8000-000000000901', 'binance', 'BUY', 12.5, 65250.0, 'OPEN',   'idem-co-004', 3, now() - interval '10 minutes', now() - interval '10 minutes'),
  ('01890000-0000-7000-8000-000000000914', '01890000-0000-7000-8000-000000000902', 'kraken',  'BUY', 10000.0, 3200.0, 'FILLED', 'idem-co-005', 0, now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000915', '01890000-0000-7000-8000-000000000902', 'binance', 'BUY', 10000.0, 3205.0, 'FILLED', 'idem-co-006', 1, now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000916', '01890000-0000-7000-8000-000000000902', 'kraken',  'BUY', 5000.0,  3203.0, 'FILLED', 'idem-co-007', 2, now() - interval '2 hours', now() - interval '2 hours');

INSERT INTO fills (id, child_order_id, parent_order_id, venue_id, price, quantity, fee, venue_order_id, idempotency_key, executed_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000920', '01890000-0000-7000-8000-000000000910', '01890000-0000-7000-8000-000000000901', 'kraken',  65098.0, 12.5,   3.75, 'kraken-1001', 'idem-fill-001', now() - interval '50 minutes', now() - interval '50 minutes', now() - interval '50 minutes'),
  ('01890000-0000-7000-8000-000000000921', '01890000-0000-7000-8000-000000000911', '01890000-0000-7000-8000-000000000901', 'binance', 65205.0, 12.5,   3.75, 'binance-2001','idem-fill-002', now() - interval '35 minutes', now() - interval '35 minutes', now() - interval '35 minutes'),
  ('01890000-0000-7000-8000-000000000922', '01890000-0000-7000-8000-000000000914', '01890000-0000-7000-8000-000000000902', 'kraken',  3200.5,  10000.0, 2.0,  'kraken-1002', 'idem-fill-003', now() - interval '2 hours', now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000923', '01890000-0000-7000-8000-000000000915', '01890000-0000-7000-8000-000000000902', 'binance', 3205.0,  10000.0, 3.0,  'binance-2002','idem-fill-004', now() - interval '2 hours', now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000924', '01890000-0000-7000-8000-000000000916', '01890000-0000-7000-8000-000000000902', 'kraken',  3203.2,  5000.0,  1.0,  'kraken-1003', 'idem-fill-005', now() - interval '2 hours', now() - interval '2 hours', now() - interval '2 hours');

INSERT INTO venue_states (id, venue_id, asset, available_balance, top_bid, top_ask, latency_ms, error_rate, healthy, last_heartbeat_at, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000930', 'kraken',  'BTC',  150.0,    64990.0, 65010.0, 45, 0.01,  true, now() - interval '1 minute', now() - interval '1 hour', now() - interval '1 minute'),
  ('01890000-0000-7000-8000-000000000931', 'kraken',  'ETH',  2000.0,   3198.0,  3201.0,  45, 0.01,  true, now() - interval '1 minute', now() - interval '1 hour', now() - interval '1 minute'),
  ('01890000-0000-7000-8000-000000000932', 'binance', 'BTC',  500.0,    64995.0, 65005.0, 20, 0.005, true, now() - interval '30 seconds', now() - interval '1 hour', now() - interval '30 seconds'),
  ('01890000-0000-7000-8000-000000000933', 'binance', 'ETH',  5000.0,   3199.0,  3200.5,  20, 0.005, true, now() - interval '30 seconds', now() - interval '1 hour', now() - interval '30 seconds'),
  ('01890000-0000-7000-8000-000000000934', 'binance', 'USDC', 2000000.0, 0.9998, 1.0001,  20, 0.005, true, now() - interval '30 seconds', now() - interval '1 hour', now() - interval '30 seconds'),
  ('01890000-0000-7000-8000-000000000935', 'kraken',  'USDC', 1000000.0, 0.9999, 1.0002, 45, 0.01,  true, now() - interval '1 minute', now() - interval '1 hour', now() - interval '1 minute');