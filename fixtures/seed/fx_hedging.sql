-- Fixtures for fx_hedging database
\c fx_hedging;

INSERT INTO fx_exposures (id, currency, net_amount, hedge_coverage, open_amount, source_flow, event_id, ts, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000801', 'EUR', 250000.0, 225000.0, 25000.0, 'PAYMENT_CAPTURE', 'evt-001', now() - interval '2 hours', now() - interval '2 hours', now() - interval '2 hours'),
  ('01890000-0000-7000-8000-000000000802', 'GBP', 120000.0, 100000.0, 20000.0, 'PAYMENT_CAPTURE', 'evt-002', now() - interval '1 hour', now() - interval '1 hour', now() - interval '1 hour'),
  ('01890000-0000-7000-8000-000000000803', 'JPY', 50000.0,  0.0,      50000.0, 'PAYMENT_CAPTURE', 'evt-003', now() - interval '45 minutes', now() - interval '45 minutes', now() - interval '45 minutes');

INSERT INTO hedges (id, currency, notional, tenor, type, status, quoted_rate, slippage_bps, pnl, client_request_id, policy_ratio, policy_cap_usd, cap_breached, value_date, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000810', 'EUR', 225000.0, 'SPOT',     'SPOT',    'EXECUTED', 1.0850, 1.2, 500.0, 'bo-ui-001', 0.9,  500000.0, false, '2026-07-17', now() - interval '90 minutes', now() - interval '80 minutes'),
  ('01890000-0000-7000-8000-000000000811', 'GBP', 100000.0, 'FORWARD_1M','FORWARD', 'EXECUTED', 1.2720, 0.5, 200.0, 'bo-ui-002', 0.83, 500000.0, false, '2026-08-15', now() - interval '50 minutes', now() - interval '45 minutes'),
  ('01890000-0000-7000-8000-000000000812', 'EUR', 50000.0,  'SPOT',     'SPOT',    'PENDING',  1.0860, 0.0, 0.0,   'bo-ui-003', 0.2,  500000.0, false, '2026-07-17', now() - interval '10 minutes', now() - interval '10 minutes');

INSERT INTO hedge_executions (id, hedge_id, venue, venue_trade_id, fill_price, quoted_price, slippage_bps, amount, ts, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000820', '01890000-0000-7000-8000-000000000810', 'dbfx', 'dbfx-1001', 1.0863, 1.0850, 1.2, 225000.0, now() - interval '85 minutes', now() - interval '85 minutes', now() - interval '85 minutes'),
  ('01890000-0000-7000-8000-000000000821', '01890000-0000-7000-8000-000000000811', 'dbfx', 'dbfx-1002', 1.2726, 1.2720, 0.5, 100000.0, now() - interval '48 minutes', now() - interval '48 minutes', now() - interval '48 minutes');

INSERT INTO fx_pnl (id, hedge_id, currency, component, realized, unrealized, rate, ts, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000830', '01890000-0000-7000-8000-000000000810', 'EUR', 'HEDGE_PNL', 500.0, 0.0,   1.0863, now() - interval '80 minutes', now() - interval '80 minutes', now() - interval '80 minutes'),
  ('01890000-0000-7000-8000-000000000831', '01890000-0000-7000-8000-000000000811', 'GBP', 'HEDGE_PNL', 200.0, 50.0,  1.2726, now() - interval '45 minutes', now() - interval '45 minutes', now() - interval '45 minutes'),
  ('01890000-0000-7000-8000-000000000832', NULL,                                           'EUR', 'SPOT_PNL',  0.0,   300.0, 1.0870, now() - interval '10 minutes', now() - interval '10 minutes', now() - interval '10 minutes'),
  ('01890000-0000-7000-8000-000000000833', NULL,                                           'EUR', 'SLIPPAGE_COST', -27.0, 0.0, 1.0850, now() - interval '80 minutes', now() - interval '80 minutes', now() - interval '80 minutes');

INSERT INTO slippage_samples (id, pair, hedge_id, execution_id, quoted_rate, executed_rate, slippage_bps, ts, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000840', 'EUR/USD', '01890000-0000-7000-8000-000000000810', 1, 1.0850, 1.0863, 1.2, now() - interval '85 minutes', now() - interval '85 minutes', now() - interval '85 minutes'),
  ('01890000-0000-7000-8000-000000000841', 'GBP/USD', '01890000-0000-7000-8000-000000000811', 2, 1.2720, 1.2726, 0.5, now() - interval '48 minutes', now() - interval '48 minutes', now() - interval '48 minutes'),
  ('01890000-0000-7000-8000-000000000842', 'EUR/USD', NULL, NULL, 1.0860, 1.0868, 0.7, now() - interval '20 minutes', now() - interval '20 minutes', now() - interval '20 minutes');