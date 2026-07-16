-- Fixtures for ledger_accounting database.
-- Entries carry real SHA-256 hash-chain values computed offline with the
-- same algorithm as src/posting.rs (compute_hash = sha256(prev_hash || canonical)
-- where canonical = "{prev_hash}|{entry_id}|{account_id}|{dir}|{amount}|{asset}|{created_at_epoch_seconds}").
-- created_at is pinned to fixed epoch seconds so the chain is deterministic and
-- survives the service's startup verification (which re-derives hashes from
-- floor(extract(epoch from created_at))::bigint::text).
\c ledger_accounting;

-- Pinned reference timestamps (epoch seconds).
--   T0 = 1700000000  (post-001 / post-002 entries)
--   T1 = 1700003600  (post-003 entries)
--   T2 = 1700007200  (snapshots as-of)

-- Chart of accounts
INSERT INTO chart_of_accounts (version, type_name, normal_balance, allowed_directions, asset_class)
VALUES
  ('v1', 'user_custodial', 'debit', ARRAY['debit','credit'], 'both'),
  ('v1', 'user_payable', 'credit', ARRAY['debit','credit'], 'fiat'),
  ('v1', 'fee_revenue', 'credit', ARRAY['credit'], 'fiat'),
  ('v1', 'treasury_crypto', 'debit', ARRAY['debit','credit'], 'crypto'),
  ('v1', 'hot_wallet', 'debit', ARRAY['debit','credit'], 'crypto'),
  ('v1', 'fx_settlement', 'debit', ARRAY['debit','credit'], 'fiat');

-- Accounts
INSERT INTO accounts (account_id, type_name, asset_class, label, parent_id, status, created_at)
VALUES
  ('acc-001', 'user_custodial', 'fiat', 'Alice USD custody', NULL, 'active', to_timestamp(1699971200)),
  ('acc-002', 'user_custodial', 'crypto', 'Bob BTC custody', NULL, 'active', to_timestamp(1699971200)),
  ('acc-003', 'user_payable', 'fiat', 'Alice payable USD', NULL, 'active', to_timestamp(1699971200)),
  ('acc-004', 'fee_revenue', 'fiat', 'Fee revenue USD', NULL, 'active', to_timestamp(1699971200)),
  ('acc-005', 'treasury_crypto', 'crypto', 'Treasury BTC', NULL, 'active', to_timestamp(1699971200)),
  ('acc-006', 'hot_wallet', 'crypto', 'Hot wallet ETH', NULL, 'active', to_timestamp(1699971200)),
  ('acc-007', 'fx_settlement', 'fiat', 'FX settlement EUR', NULL, 'active', to_timestamp(1699971200));

-- Postings (hash_chain_head = that posting's last entry this_hash)
INSERT INTO postings (posting_id, ref_tx_id, memo, status, hash_chain_head, created_at)
VALUES
  ('post-001', 'tx-001', 'Buy 0.5 BTC for Alice', 'posted', 'a83dc63dbac305f14c15634f8d842cd0bda6a683e218adfac6cec5f4b3ce541a', to_timestamp(1700000000)),
  ('post-002', 'tx-002', 'Fee collection on tx-001', 'posted', '391fe471eea7a6ef8837be27095c5ccdea502a2b3b3e8f515ac411c1310e0c77', to_timestamp(1700000000)),
  ('post-003', 'tx-003', 'Hot wallet top-up ETH', 'posted', '5b9a982d431dddbc87966366bfc632827480e44d57d3bb64b31438b7f5412dc3', to_timestamp(1700003600));

-- Entries (append-only, balanced double-entry).
-- sequence_number is a GLOBAL counter across all entries; prev_hash chains
-- every entry to the previous one (genesis = 64 zeros for the first entry).
INSERT INTO entries (entry_id, posting_id, account_id, direction, amount, asset, sequence_number, prev_hash, this_hash, created_at)
VALUES
  ('ent-001', 'post-001', 'acc-002', 'debit',  50000000,              'BTC', 1, '0000000000000000000000000000000000000000000000000000000000000000', 'ac12352f8d67b9789402ea61b878cdcd9db36661cb47671c71337054c743d03a', to_timestamp(1700000000)),
  ('ent-002', 'post-001', 'acc-003', 'credit', 50000000,              'USD', 2, 'ac12352f8d67b9789402ea61b878cdcd9db36661cb47671c71337054c743d03a', 'a83dc63dbac305f14c15634f8d842cd0bda6a683e218adfac6cec5f4b3ce541a', to_timestamp(1700000000)),
  ('ent-003', 'post-002', 'acc-003', 'debit',  125000,                'USD', 3, 'a83dc63dbac305f14c15634f8d842cd0bda6a683e218adfac6cec5f4b3ce541a', 'd20f283c9e4695b4c8c11f1c36ab2cabedede21f859173b6306617e5029e24a2', to_timestamp(1700000000)),
  ('ent-004', 'post-002', 'acc-004', 'credit', 125000,                'USD', 4, 'd20f283c9e4695b4c8c11f1c36ab2cabedede21f859173b6306617e5029e24a2', '391fe471eea7a6ef8837be27095c5ccdea502a2b3b3e8f515ac411c1310e0c77', to_timestamp(1700000000)),
  ('ent-005', 'post-003', 'acc-006', 'debit',  1000000000000000000,   'ETH', 5, '391fe471eea7a6ef8837be27095c5ccdea502a2b3b3e8f515ac411c1310e0c77', '9c7bf08a3bb04513d89668bf89c30ecc288cb4a77bb09d2f36b7a87f83797c16', to_timestamp(1700003600)),
  ('ent-006', 'post-003', 'acc-005', 'credit', 1000000000000000000,   'ETH', 6, '9c7bf08a3bb04513d89668bf89c30ecc288cb4a77bb09d2f36b7a87f83797c16', '5b9a982d431dddbc87966366bfc632827480e44d57d3bb64b31438b7f5412dc3', to_timestamp(1700003600));

-- Hash chain anchors: head_hash = posting's last entry hash,
-- global_sequence_head = global chain head at the time of that posting.
INSERT INTO hash_chain (posting_id, head_hash, global_sequence_head, created_at)
VALUES
  ('post-001', 'a83dc63dbac305f14c15634f8d842cd0bda6a683e218adfac6cec5f4b3ce541a', 'a83dc63dbac305f14c15634f8d842cd0bda6a683e218adfac6cec5f4b3ce541a', to_timestamp(1700000000)),
  ('post-002', '391fe471eea7a6ef8837be27095c5ccdea502a2b3b3e8f515ac411c1310e0c77', '391fe471eea7a6ef8837be27095c5ccdea502a2b3b3e8f515ac411c1310e0c77', to_timestamp(1700000000)),
  ('post-003', '5b9a982d431dddbc87966366bfc632827480e44d57d3bb64b31438b7f5412dc3', '5b9a982d431dddbc87966366bfc632827480e44d57d3bb64b31438b7f5412dc3', to_timestamp(1700003600));

-- Balance snapshots
INSERT INTO balance_snapshots (account_id, asset, balance, as_of_ts, last_entry_id)
VALUES
  ('acc-001', 'USD', 0, to_timestamp(1700007200), 'ent-000'),
  ('acc-002', 'BTC', 50000000, to_timestamp(1700007200), 'ent-001'),
  ('acc-003', 'USD', 49875000, to_timestamp(1700007200), 'ent-003'),
  ('acc-004', 'USD', 125000, to_timestamp(1700007200), 'ent-004'),
  ('acc-005', 'ETH', -1000000000000000000, to_timestamp(1700007200), 'ent-006'),
  ('acc-006', 'ETH', 1000000000000000000, to_timestamp(1700007200), 'ent-005');