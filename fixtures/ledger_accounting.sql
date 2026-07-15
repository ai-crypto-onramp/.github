-- Fixtures for ledger_accounting database
\c ledger_accounting;

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
  ('acc-001', 'user_custodial', 'fiat', 'Alice USD custody', NULL, 'active', now() - interval '30 days'),
  ('acc-002', 'user_custodial', 'crypto', 'Bob BTC custody', NULL, 'active', now() - interval '25 days'),
  ('acc-003', 'user_payable', 'fiat', 'Alice payable USD', NULL, 'active', now() - interval '30 days'),
  ('acc-004', 'fee_revenue', 'fiat', 'Fee revenue USD', NULL, 'active', now() - interval '30 days'),
  ('acc-005', 'treasury_crypto', 'crypto', 'Treasury BTC', NULL, 'active', now() - interval '30 days'),
  ('acc-006', 'hot_wallet', 'crypto', 'Hot wallet ETH', NULL, 'active', now() - interval '20 days'),
  ('acc-007', 'fx_settlement', 'fiat', 'FX settlement EUR', NULL, 'active', now() - interval '15 days');

-- Postings (must come before entries)
INSERT INTO postings (posting_id, ref_tx_id, memo, status, hash_chain_head, created_at)
VALUES
  ('post-001', 'tx-001', 'Buy 0.5 BTC for Alice', 'posted', 'hash-001', now() - interval '2 hours'),
  ('post-002', 'tx-002', 'Fee collection on tx-001', 'posted', 'hash-002', now() - interval '2 hours'),
  ('post-003', 'tx-003', 'Hot wallet top-up ETH', 'posted', 'hash-003', now() - interval '1 hour');

-- Entries (append-only, balanced double-entry)
INSERT INTO entries (entry_id, posting_id, account_id, direction, amount, asset, sequence_number, prev_hash, this_hash, created_at)
VALUES
  ('ent-001', 'post-001', 'acc-002', 'debit', 50000000, 'BTC', 1, '0', 'hash-ent-001', now() - interval '2 hours'),
  ('ent-002', 'post-001', 'acc-003', 'credit', 50000000, 'USD', 2, 'hash-ent-001', 'hash-ent-002', now() - interval '2 hours'),
  ('ent-003', 'post-002', 'acc-003', 'debit', 125000, 'USD', 3, 'hash-ent-002', 'hash-ent-003', now() - interval '2 hours'),
  ('ent-004', 'post-002', 'acc-004', 'credit', 125000, 'USD', 4, 'hash-ent-003', 'hash-ent-004', now() - interval '2 hours'),
  ('ent-005', 'post-003', 'acc-006', 'debit', 1000000000000000000, 'ETH', 5, 'hash-ent-004', 'hash-ent-005', now() - interval '1 hour'),
  ('ent-006', 'post-003', 'acc-005', 'credit', 1000000000000000000, 'ETH', 6, 'hash-ent-005', 'hash-ent-006', now() - interval '1 hour');

-- Hash chain
INSERT INTO hash_chain (posting_id, head_hash, global_sequence_head, created_at)
VALUES
  ('post-001', 'hash-ent-002', 'hash-ent-002', now() - interval '2 hours'),
  ('post-002', 'hash-ent-004', 'hash-ent-004', now() - interval '2 hours'),
  ('post-003', 'hash-ent-006', 'hash-ent-006', now() - interval '1 hour');

-- Balance snapshots
INSERT INTO balance_snapshots (account_id, asset, balance, as_of_ts, last_entry_id)
VALUES
  ('acc-001', 'USD', 0, now() - interval '1 hour', 'ent-000'),
  ('acc-002', 'BTC', 50000000, now() - interval '1 hour', 'ent-001'),
  ('acc-003', 'USD', 49875000, now() - interval '1 hour', 'ent-003'),
  ('acc-004', 'USD', 125000, now() - interval '1 hour', 'ent-004'),
  ('acc-005', 'ETH', -1000000000000000000, now() - interval '1 hour', 'ent-006'),
  ('acc-006', 'ETH', 1000000000000000000, now() - interval '1 hour', 'ent-005');