-- Fixtures for pricing_quote database
\c pricing_quote;

INSERT INTO quotes (quote_id, from_ccy, to_ccy, amount, rate, spread_bps, fee, fee_currency, total, crypto_amount, user_tier, side, status, created_at, updated_at, expires_at, claimed_at, claimed_by, source_venue)
VALUES
  ('01890000-0000-7000-8000-000000000c01', 'USD', 'BTC', 50000.00, 65000.00, 80, 250.00, 'USD', 50250.00, 0.76923076, 'TIER_1', 'BUY',  'CLAIMED',  now() - interval '2 hours',  now() - interval '1 hour',    now() - interval '1 hour', now() - interval '90 minutes', '01890000-0000-7000-8000-000000000001', 'binance'),
  ('01890000-0000-7000-8000-000000000c02', 'USD', 'ETH', 10000.00, 3500.00,  90, 45.00,  'USD', 10045.00, 2.87000000, 'TIER_2', 'BUY',  'EXPIRED',  now() - interval '3 hours',  now() - interval '2 hours',   now() - interval '2 hours', NULL, '', 'kraken'),
  ('01890000-0000-7000-8000-000000000c03', 'BTC', 'USD', 0.50,      64800.00, 70, 32.40,  'BTC', 0.50,     32400.00,   'TIER_2', 'SELL', 'PENDING',  now() - interval '10 minutes', now() - interval '10 minutes', now() + interval '5 minutes', NULL, '', 'binance'),
  ('01890000-0000-7000-8000-000000000c04', 'EUR', 'BTC', 30000.00, 66000.00, 80, 150.00, 'EUR', 30150.00, 0.45681818, 'TIER_1', 'BUY',  'CLAIMED',  now() - interval '5 hours',   now() - interval '4 hours',    now() - interval '4 hours', now() - interval '4 hours', '01890000-0000-7000-8000-000000000003', 'coinbase');

-- UUID PKs are app-generated; no sequence sync needed.

INSERT INTO fee_schedules (id, user_tier, asset, size_band_min, size_band_max, side, spread_bps, fee_type, fee_amount, fee_bps, enabled, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000c10', 'TIER_1', 'BTC', 0,    1000,  'BUY',  80, 'BPS', 0, 50, true, now() - interval '7 days', now() - interval '7 days'),
  ('01890000-0000-7000-8000-000000000c11', 'TIER_1', 'BTC', 1000, 10000, 'BUY',  60, 'BPS', 0, 30, true, now() - interval '7 days', now() - interval '7 days'),
  ('01890000-0000-7000-8000-000000000c12', 'TIER_1', 'ETH', 0,    100,   'BUY',  90, 'BPS', 0, 50, true, now() - interval '7 days', now() - interval '7 days'),
  ('01890000-0000-7000-8000-000000000c13', 'TIER_2', 'BTC', 0,    1000,  'BUY',  70, 'BPS', 0, 40, true, now() - interval '7 days', now() - interval '7 days'),
  ('01890000-0000-7000-8000-000000000c14', 'TIER_2', 'ETH', 0,    100,   'BUY',  75, 'BPS', 0, 40, true, now() - interval '7 days', now() - interval '7 days'),
  ('01890000-0000-7000-8000-000000000c15', 'TIER_2', 'BTC', 0,    1000,  'SELL', 70, 'BPS', 0, 40, true, now() - interval '7 days', now() - interval '7 days'),
  ('01890000-0000-7000-8000-000000000c16', 'TIER_1', 'BTC', 0,    1000,  'SELL', 80, 'BPS', 0, 50, true, now() - interval '7 days', now() - interval '7 days');

INSERT INTO rate_sources (id, name, priority, enabled, endpoint_ref, weight, created_at, updated_at)
VALUES
  ('01890000-0000-7000-8000-000000000c20', 'binance',  1, true, 'https://api.binance.com',  3, now() - interval '14 days', now() - interval '7 days'),
  ('01890000-0000-7000-8000-000000000c21', 'kraken',   2, true, 'https://api.kraken.com',   2, now() - interval '14 days', now() - interval '7 days'),
  ('01890000-0000-7000-8000-000000000c22', 'coinbase', 3, true, 'https://api.coinbase.com', 1, now() - interval '14 days', now() - interval '7 days');