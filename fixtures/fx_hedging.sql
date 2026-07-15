-- Fixtures for fx_hedging database
\c fx_hedging;

INSERT INTO fx_exposures (currency, net_amount, hedge_coverage, open_amount, source_flow, event_id, ts)
VALUES
  ('EUR', 250000.0, 225000.0, 25000.0, 'payment_capture', 'evt-001', now() - interval '2 hours'),
  ('GBP', 120000.0, 100000.0, 20000.0, 'payment_capture', 'evt-002', now() - interval '1 hour'),
  ('JPY', 50000.0, 0.0, 50000.0, 'payment_capture', 'evt-003', now() - interval '45 minutes');

INSERT INTO hedges (id, currency, notional, tenor, type, status, quoted_rate, slippage_bps, pnl, client_request_id, policy_ratio, policy_cap_usd, cap_breached, value_date, created_at, updated_at)
VALUES
  ('b4e4e5f1-0fc0-543c-a0ea-b98cfbb9daa9'::uuid, 'EUR', 225000.0, 'spot', 'spot', 'executed', 1.0850, 1.2, 500.0, 'bo-ui-001', 0.9, 500000.0, false, '2026-07-17', now() - interval '90 minutes', now() - interval '80 minutes'),
  ('91b4c96d-a4b8-5948-a83e-fcf19eabb46a'::uuid, 'GBP', 100000.0, 'forward_1m', 'forward', 'executed', 1.2720, 0.5, 200.0, 'bo-ui-002', 0.83, 500000.0, false, '2026-08-15', now() - interval '50 minutes', now() - interval '45 minutes'),
  ('12ca74f9-9dc9-51c5-9ae7-0674d901dc2e'::uuid, 'EUR', 50000.0, 'spot', 'spot', 'pending', 1.0860, 0.0, 0.0, 'bo-ui-003', 0.2, 500000.0, false, '2026-07-17', now() - interval '10 minutes', now() - interval '10 minutes');

INSERT INTO hedge_executions (hedge_id, venue, venue_trade_id, fill_price, quoted_price, slippage_bps, amount, ts)
VALUES
  ('b4e4e5f1-0fc0-543c-a0ea-b98cfbb9daa9'::uuid, 'dbfx', 'dbfx-1001', 1.0863, 1.0850, 1.2, 225000.0, now() - interval '85 minutes'),
  ('91b4c96d-a4b8-5948-a83e-fcf19eabb46a'::uuid, 'dbfx', 'dbfx-1002', 1.2726, 1.2720, 0.5, 100000.0, now() - interval '48 minutes');

INSERT INTO fx_pnl (hedge_id, currency, component, realized, unrealized, rate, ts)
VALUES
  ('b4e4e5f1-0fc0-543c-a0ea-b98cfbb9daa9'::uuid, 'EUR', 'hedge_pnl', 500.0, 0.0, 1.0863, now() - interval '80 minutes'),
  ('91b4c96d-a4b8-5948-a83e-fcf19eabb46a'::uuid, 'GBP', 'hedge_pnl', 200.0, 50.0, 1.2726, now() - interval '45 minutes'),
  (NULL, 'EUR', 'spot_pnl', 0.0, 300.0, 1.0870, now() - interval '10 minutes'),
  (NULL, 'EUR', 'slippage_cost', -27.0, 0.0, 1.0850, now() - interval '80 minutes');

INSERT INTO slippage_samples (pair, hedge_id, execution_id, quoted_rate, executed_rate, slippage_bps, ts)
VALUES
  ('EUR/USD', 'b4e4e5f1-0fc0-543c-a0ea-b98cfbb9daa9'::uuid, 1, 1.0850, 1.0863, 1.2, now() - interval '85 minutes'),
  ('GBP/USD', '91b4c96d-a4b8-5948-a83e-fcf19eabb46a'::uuid, 2, 1.2720, 1.2726, 0.5, now() - interval '48 minutes'),
  ('EUR/USD', NULL, NULL, 1.0860, 1.0868, 0.7, now() - interval '20 minutes');