-- Fixtures for pricing_quote database
\c pricing_quote;

INSERT INTO quotes (quote_id, from_ccy, to_ccy, amount, rate, spread_bps, fee, fee_currency, total, crypto_amount, user_tier, side, status, created_at, expires_at, claimed_at, claimed_by, source_venue)
VALUES
  ('q-001', 'USD', 'BTC', 50000.00, 65000.00, 80, 250.00, 'USD', 50250.00, 0.76923076, 'tier_1', 'buy',  'claimed', now() - interval '2 hours', now() - interval '1 hour',   now() - interval '90 minutes', 'user-001', 'binance'),
  ('q-002', 'USD', 'ETH', 10000.00, 3500.00,  90, 45.00,  'USD', 10045.00, 2.87000000, 'tier_2', 'buy',  'expired', now() - interval '3 hours', now() - interval '2 hours',   NULL, '', 'kraken'),
  ('q-003', 'BTC', 'USD', 0.50,     64800.00, 70, 32.40,  'BTC', 0.50,     32400.00,   'tier_2', 'sell', 'pending', now() - interval '10 minutes', now() + interval '5 minutes', NULL, '', 'binance'),
  ('q-004', 'EUR', 'BTC', 30000.00, 66000.00, 80, 150.00, 'EUR', 30150.00, 0.45681818, 'tier_1', 'buy',  'claimed', now() - interval '5 hours',  now() - interval '4 hours',  now() - interval '4 hours', 'user-003', 'coinbase');

-- Sync BIGSERIAL sequence so later inserts via the service don't collide.
SELECT setval(pg_get_serial_sequence('fee_schedules', 'id'), COALESCE((SELECT max(id) FROM fee_schedules), 1), true);

INSERT INTO fee_schedules (user_tier, asset, size_band_min, size_band_max, side, spread_bps, fee_type, fee_amount, fee_bps, enabled, updated_at)
VALUES
  ('tier_1', 'BTC', 0,    1000,  'buy',  80, 'bps', 0, 50, true, now() - interval '7 days'),
  ('tier_1', 'BTC', 1000, 10000, 'buy',  60, 'bps', 0, 30, true, now() - interval '7 days'),
  ('tier_1', 'ETH', 0,    100,   'buy',  90, 'bps', 0, 50, true, now() - interval '7 days'),
  ('tier_2', 'BTC', 0,    1000,  'buy',  70, 'bps', 0, 40, true, now() - interval '7 days'),
  ('tier_2', 'ETH', 0,    100,   'buy',  75, 'bps', 0, 40, true, now() - interval '7 days'),
  ('tier_2', 'BTC', 0,    1000,  'sell', 70, 'bps', 0, 40, true, now() - interval '7 days'),
  ('tier_1', 'BTC', 0,    1000,  'sell', 80, 'bps', 0, 50, true, now() - interval '7 days');

-- Sync BIGSERIAL sequence for rate_sources (seeds below).
SELECT setval(pg_get_serial_sequence('rate_sources', 'id'), COALESCE((SELECT max(id) FROM rate_sources), 1), true);

INSERT INTO rate_sources (name, priority, enabled, endpoint_ref, weight, created_at, updated_at)
VALUES
  ('binance',  1, true, 'https://api.binance.com',  3, now() - interval '14 days', now() - interval '7 days'),
  ('kraken',   2, true, 'https://api.kraken.com',   2, now() - interval '14 days', now() - interval '7 days'),
  ('coinbase', 3, true, 'https://api.coinbase.com', 1, now() - interval '14 days', now() - interval '7 days');