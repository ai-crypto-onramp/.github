-- Fixtures for ledger_accounting database.
-- Entries carry real SHA-256 hash-chain values computed offline with the
-- same algorithm as src/posting.rs (compute_hash = sha256(prev_hash || canonical)
-- where canonical = "{prev_hash}|{entry_id}|{account_id}|{dir}|{amount}|{asset}|{created_at_epoch_seconds}").
-- created_at is pinned to fixed epoch seconds so the chain is deterministic and
-- survives the service's startup verification (which re-derives hashes from
-- floor(extract(epoch from created_at))::bigint::text).
-- NOTE: enum literals (normal_balance, status, direction, asset_class) are
-- UPPER_SNAKE_CASE per the uniform DB conventions; hashes below were recomputed
-- with the capitalized direction values.
\c ledger_accounting;

-- Pinned reference timestamps (epoch seconds).
--   T0 = 1700000000  (post-001 / post-002 entries)
--   T1 = 1700003600  (post-003 entries)
--   T2 = 1700007200  (snapshots as-of)

-- Chart of accounts
INSERT INTO chart_of_accounts (version, type_name, normal_balance, allowed_directions, asset_class, created_at, updated_at)
VALUES
  ('v1', 'user_custodial', 'DEBIT',  ARRAY['DEBIT','CREDIT'], 'BOTH', now() - interval '30 days', now() - interval '30 days'),
  ('v1', 'user_payable',    'CREDIT', ARRAY['DEBIT','CREDIT'], 'FIAT', now() - interval '30 days', now() - interval '30 days'),
  ('v1', 'fee_revenue',     'CREDIT', ARRAY['CREDIT'],          'FIAT', now() - interval '30 days', now() - interval '30 days'),
  ('v1', 'treasury_crypto', 'DEBIT',  ARRAY['DEBIT','CREDIT'], 'CRYPTO', now() - interval '30 days', now() - interval '30 days'),
  ('v1', 'hot_wallet',      'DEBIT',  ARRAY['DEBIT','CREDIT'], 'CRYPTO', now() - interval '30 days', now() - interval '30 days'),
  ('v1', 'fx_settlement',   'DEBIT',  ARRAY['DEBIT','CREDIT'], 'FIAT', now() - interval '30 days', now() - interval '30 days');

-- Accounts
INSERT INTO accounts (account_id, type_name, asset_class, label, parent_id, status, created_at, updated_at)
VALUES
  ('acc-001', 'user_custodial', 'FIAT',   'Alice USD custody', NULL, 'ACTIVE', to_timestamp(1699971200), to_timestamp(1699971200)),
  ('acc-002', 'user_custodial', 'CRYPTO', 'Bob BTC custody',   NULL, 'ACTIVE', to_timestamp(1699971200), to_timestamp(1699971200)),
  ('acc-003', 'user_payable',    'FIAT',   'Alice payable USD', NULL, 'ACTIVE', to_timestamp(1699971200), to_timestamp(1699971200)),
  ('acc-004', 'fee_revenue',     'FIAT',   'Fee revenue USD',   NULL, 'ACTIVE', to_timestamp(1699971200), to_timestamp(1699971200)),
  ('acc-005', 'treasury_crypto', 'CRYPTO', 'Treasury BTC',      NULL, 'ACTIVE', to_timestamp(1699971200), to_timestamp(1699971200)),
  ('acc-006', 'hot_wallet',      'CRYPTO', 'Hot wallet ETH',    NULL, 'ACTIVE', to_timestamp(1699971200), to_timestamp(1699971200)),
  ('acc-007', 'fx_settlement',   'FIAT',   'FX settlement EUR', NULL, 'ACTIVE', to_timestamp(1699971200), to_timestamp(1699971200));

-- Postings (hash_chain_head = that posting's last entry this_hash)
INSERT INTO postings (posting_id, ref_tx_id, memo, status, hash_chain_head, created_at, updated_at)
VALUES
  ('post-001', 'tx-001', 'Buy 0.5 BTC for Alice', 'POSTED', '110278e7eaecc55a0b6ca89972f3a36176f86ae3b16beb4c3d2a76bef1eb754c', to_timestamp(1700000000), to_timestamp(1700000000)),
  ('post-002', 'tx-002', 'Fee collection on tx-001', 'POSTED', 'c57fcc71054c3b3dbc623fdf662d65042fe44751dc24d40219186031d6836f24', to_timestamp(1700000000), to_timestamp(1700000000)),
  ('post-003', 'tx-003', 'Hot wallet top-up ETH', 'POSTED', '2c7f2dd89731fe66c40ee4313d3b0e56164575f7296ef82c1e42ef42b43f781e', to_timestamp(1700003600), to_timestamp(1700003600));

-- Entries (append-only, balanced double-entry).
-- sequence_number is a GLOBAL counter across all entries; prev_hash chains
-- every entry to the previous one (genesis = 64 zeros for the first entry).
-- Hashes recomputed with UPPER_CASE direction literals.
INSERT INTO entries (entry_id, posting_id, account_id, direction, amount, asset, sequence_number, prev_hash, this_hash, created_at, updated_at)
VALUES
  ('ent-001', 'post-001', 'acc-002', 'DEBIT',  50000000,            'BTC', 1, '0000000000000000000000000000000000000000000000000000000000000000', 'c8690144839f20176c3c97587a95aca952333079da23cdb4e99eef291293febb', to_timestamp(1700000000), to_timestamp(1700000000)),
  ('ent-002', 'post-001', 'acc-003', 'CREDIT', 50000000,            'USD', 2, 'c8690144839f20176c3c97587a95aca952333079da23cdb4e99eef291293febb', '110278e7eaecc55a0b6ca89972f3a36176f86ae3b16beb4c3d2a76bef1eb754c', to_timestamp(1700000000), to_timestamp(1700000000)),
  ('ent-003', 'post-002', 'acc-003', 'DEBIT',  125000,              'USD', 3, '110278e7eaecc55a0b6ca89972f3a36176f86ae3b16beb4c3d2a76bef1eb754c', '1153b97d526778c55d4f70f843913924559ab2195e3e774b297d8d286de1f5c7', to_timestamp(1700000000), to_timestamp(1700000000)),
  ('ent-004', 'post-002', 'acc-004', 'CREDIT', 125000,              'USD', 4, '1153b97d526778c55d4f70f843913924559ab2195e3e774b297d8d286de1f5c7', 'c57fcc71054c3b3dbc623fdf662d65042fe44751dc24d40219186031d6836f24', to_timestamp(1700000000), to_timestamp(1700000000)),
  ('ent-005', 'post-003', 'acc-006', 'DEBIT',  1000000000000000000, 'ETH', 5, 'c57fcc71054c3b3dbc623fdf662d65042fe44751dc24d40219186031d6836f24', '7d2562585ab7bf3091a5a63b76118cbada57c7de9d7352d42a2cf2948dec8849', to_timestamp(1700003600), to_timestamp(1700003600)),
  ('ent-006', 'post-003', 'acc-005', 'CREDIT', 1000000000000000000, 'ETH', 6, '7d2562585ab7bf3091a5a63b76118cbada57c7de9d7352d42a2cf2948dec8849', '2c7f2dd89731fe66c40ee4313d3b0e56164575f7296ef82c1e42ef42b43f781e', to_timestamp(1700003600), to_timestamp(1700003600));

-- Hash chain anchors: head_hash = posting's last entry hash,
-- global_sequence_head = global chain head at the time of that posting.
INSERT INTO hash_chain (posting_id, head_hash, global_sequence_head, created_at, updated_at)
VALUES
  ('post-001', '110278e7eaecc55a0b6ca89972f3a36176f86ae3b16beb4c3d2a76bef1eb754c', '110278e7eaecc55a0b6ca89972f3a36176f86ae3b16beb4c3d2a76bef1eb754c', to_timestamp(1700000000), to_timestamp(1700000000)),
  ('post-002', 'c57fcc71054c3b3dbc623fdf662d65042fe44751dc24d40219186031d6836f24', 'c57fcc71054c3b3dbc623fdf662d65042fe44751dc24d40219186031d6836f24', to_timestamp(1700000000), to_timestamp(1700000000)),
  ('post-003', '2c7f2dd89731fe66c40ee4313d3b0e56164575f7296ef82c1e42ef42b43f781e', '2c7f2dd89731fe66c40ee4313d3b0e56164575f7296ef82c1e42ef42b43f781e', to_timestamp(1700003600), to_timestamp(1700003600));

-- Balance snapshots
INSERT INTO balance_snapshots (account_id, asset, balance, as_of_ts, last_entry_id, created_at, updated_at)
VALUES
  ('acc-001', 'USD', 0, to_timestamp(1700007200), 'ent-000', to_timestamp(1700007200), to_timestamp(1700007200)),
  ('acc-002', 'BTC', 50000000, to_timestamp(1700007200), 'ent-001', to_timestamp(1700007200), to_timestamp(1700007200)),
  ('acc-003', 'USD', 49875000, to_timestamp(1700007200), 'ent-003', to_timestamp(1700007200), to_timestamp(1700007200)),
  ('acc-004', 'USD', 125000, to_timestamp(1700007200), 'ent-004', to_timestamp(1700007200), to_timestamp(1700007200)),
  ('acc-005', 'ETH', -1000000000000000000, to_timestamp(1700007200), 'ent-006', to_timestamp(1700007200), to_timestamp(1700007200)),
  ('acc-006', 'ETH', 1000000000000000000, to_timestamp(1700007200), 'ent-005', to_timestamp(1700007200), to_timestamp(1700007200));