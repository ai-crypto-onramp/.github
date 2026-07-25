# Lock-Free Data-Access Migration Plan

This document captures a proposed (not yet implemented) plan to replace the
`SELECT ... FOR UPDATE` + multi-statement transaction patterns across the
codebase with single-statement, atomic-update patterns. It is a hardening
pass motivated by concurrency correctness and simplicity, **not** by the
`make reset-db` hang — see `fixtures/reset.sql` for the skip-and-continue
mitigation that ships today.

## Background: why this came up

`make reset-db seed-db` hangs when run against a live stack. `TRUNCATE TABLE
... CASCADE` acquires an `ACCESS EXCLUSIVE` table lock, which conflicts with
*any* open transaction that has touched the target table — even a plain
`SELECT` holds an `ACCESS SHARE` lock for the duration of its enclosing
transaction. As long as a service keeps a transaction open (e.g. the
`transaction-orchestrator` outbox relay ticks every 100 ms and opens a
serializable transaction each tick), `TRUNCATE` waits indefinitely.

The shipped fix (`fixtures/reset.sql`) wraps each database's truncate loop
in a `DO $$ ... EXCEPTION WHEN lock_timeout THEN ... END $$` block with
`SET lock_timeout = '5s'`, so a locked database is skipped atomically (the
block rolls back, leaving that database untouched) and `reset-db` continues
to the next database. This is a dev-tooling fix, not a service-logic fix.

The plan below addresses the broader pattern that made the hang possible:
services holding transactions open across network calls and multi-statement
reads. Flattening those patterns to single-statement atomic updates shrinks
the window to a single round-trip, which is the correct concurrency posture
regardless of the reset tooling.

## Why "lock-free" is the right instinct, with a caveat

`FOR UPDATE` row locks are *not* what blocks `TRUNCATE` — table-level
`ACCESS EXCLUSIVE` is. So "lock-free" alone does not eliminate the reset
window; a single autocommit `INSERT` still holds an `ACCESS SHARE` lock for
the round-trip. The real win is **single-statement transactions**: no
transaction is open long enough to stall a `TRUNCATE` except by sheer bad
luck, and the per-connection `idle_in_transaction_session_timeout` /
`lock_timeout` settings cap the worst case.

The rewrites are worth doing on their own merits:

- Atomic `UPDATE ... WHERE status='OLD' RETURNING ...` is simpler than
  `SELECT FOR UPDATE ... <think> ... UPDATE`.
- Drops the `pgx.Serializable` / `sql.LevelSerializable` overhead where the
  single statement is already correct under READ COMMITTED.
- Eliminates serializable-retry storms and deadlocks on concurrent state
  transitions.
- Smaller, faster hot paths (no second round-trip for the update).

## Three primitives cover every site

1. **Atomic counter / upsert** — `UPDATE t SET x = x + 1 RETURNING x`.
   Replaces `SELECT ... FOR UPDATE` + UPDATE for monotonic counters.
2. **CAS state transition** — `UPDATE t SET status='NEW' WHERE id=$1 AND
   status='OLD' RETURNING ...`. The `WHERE` clause *is* the lock; 0 rows
   affected = someone else moved it (no-op, 409, or bounded retry).
3. **Atomic claim** — `UPDATE t SET status='INFLIGHT', claimed_by=$1
   WHERE id IN (SELECT id FROM t WHERE status='PENDING' LIMIT N) RETURNING
   ...`. One statement, no `FOR UPDATE SKIP LOCKED`, no explicit tx.

Stale-row recovery (crashed workers leaving rows in `INFLIGHT`) moves to a
reaper that periodically flips rows past a heartbeat deadline back to
`PENDING`.

## Per-site rewrite plan

### 1. wallet-management — nonces (`internal/storage/postgres/postgres.go:400`)
The clearest win. Replace `SELECT pending_nonce ... FOR UPDATE` + `UPDATE`
with:

```sql
INSERT INTO nonces (wallet_id, chain, pending_nonce, version, updated_at)
VALUES ($1, $2, 1, 1, now())
ON CONFLICT (wallet_id, chain) DO UPDATE
  SET pending_nonce = nonces.pending_nonce + 1,
      version      = nonces.version + 1,
      updated_at   = now()
RETURNING pending_nonce;
```

Drop `sql.LevelSerializable` for this path. No behavior change visible to
callers.

### 2. identity-auth (`internal/dbstore.go:367,846,890,1077`)
Four near-identical state-machine rewrites:

- Revoke session: `UPDATE sessions SET revoked_at=now() WHERE id=$1 AND
  revoked_at IS NULL RETURNING user_id, expires_at`
- Revoke API key: same pattern with `revoked_at IS NULL` guard
- Consume password reset: `UPDATE password_resets SET used_at=now()
  WHERE token_hash=$1 AND used_at IS NULL AND expires_at > now() RETURNING
  user_id`
- Refresh-token rotation: CAS on `revoked_at IS NULL`

0 rows affected = already consumed/revoked/expired → return 409/410
instead of 500. Hurl tests that assert 500 on double-revoke need updating
to 409.

### 3. onboarding-kyc (`internal/db_stores.go:141,190`)
State-machine CAS on `kyc_applications.status`. Two transition sites,
both become `UPDATE kyc_applications SET status=$2, updated_at=now()
WHERE id=$1 AND status=$3 RETURNING ...`.

### 4. blockchain-gateway — tx_confirmations (`internal/store/postgres/postgres.go:218`)
Replace `SELECT ... FOR UPDATE` + conditional INSERT/UPDATE with one
upsert guarded by a monotonicity check:

```sql
INSERT INTO tx_confirmations (chain_id, tx_hash, confirmations, block_height, updated_at)
VALUES ($1,$2,$3,$4,now())
ON CONFLICT (chain_id, tx_hash) DO UPDATE
  SET confirmations = EXCLUDED.confirmations,
      block_height  = EXCLUDED.block_height,
      updated_at    = now()
  WHERE tx_confirmations.confirmations < EXCLUDED.confirmations
RETURNING ...;
```

### 5. payment-orchestration — intents / chargebacks (`internal/store/postgres/postgres.go:125,275`)
CAS on `intents.status` (and `intents.version` if present). Capture
transition becomes `UPDATE intents SET status='CAPTURED', version=version+1
WHERE id=$1 AND status='AUTHORIZED' RETURNING ...`. Chargeback claim same
pattern. 0 rows → 409 to caller, no internal retry.

### 6. treasury-orchestration — batches / float_positions (`internal/store/postgres/postgres.go:231,521`)
- Batches: state-machine CAS (`WHERE status='OPEN'`).
- Float settlement: `UPDATE float_positions SET settled=true WHERE
  fiat_currency=$1 AND settled=false RETURNING id` — atomic claim of all
  matching positions in one statement.

**Risk:** verify whether any batch operation requires two rows to change
atomically (e.g. debit one float, credit another). If so, keep that tx
but add `SET LOCAL lock_timeout = '2s'` and `SET LOCAL
idle_in_transaction_session_timeout = '5s'` so a stuck tx auto-aborts
instead of pinning `TRUNCATE`.

### 7. transaction-orchestrator — outbox relay (`internal/store/pg.go:323`, `internal/outbox/relay.go:100`)
The biggest win and the most work. Replace `ClaimOutboxPending` with:

```sql
UPDATE outbox_events
   SET status='INFLIGHT', claimed_at=now(), claimed_by=$1
 WHERE id IN (SELECT id FROM outbox_events
               WHERE status='PENDING' ORDER BY created_at LIMIT $2)
RETURNING id, event_id, tx_id, event_type, step, attempt, payload,
          created_at, dedup_key;
```

Autocommit, one round-trip, no row lock held across the publish call.
`MarkOutboxPublished` becomes one bulk `WHERE event_id = ANY($1)` update.

**Hard requirement:** a reaper that flips `INFLIGHT` rows older than ~60 s
back to `PENDING`. The relay code mentions a reaper but the implementation
was not found in the surveyed files — it must exist or be added before
this rewrite lands, otherwise crashed-relay rows sit in `INFLIGHT`
forever.

Drop `RunInTx` from `drainOnce`; drop `pgx.Serializable` for these ops.

### 8. transaction-orchestrator — CreateTx (`internal/store/pg.go:182`)
Legitimately multi-statement (inserts into 4 tables for atomicity). Keep
the tx, but add at the start:

```sql
SET LOCAL lock_timeout = '2s';
SET LOCAL idle_in_transaction_session_timeout = '5s';
```

Saga-state transitions (`UpdateSaga` at `pg.go:272`) are single UPDATEs —
drop the outer tx, run autocommit, use the `version` column as a CAS guard
(`WHERE version = $old`).

## Cross-cutting changes

- **`db.Connect` in each service** (e.g. `policy-risk-engine/internal/db/db.go:35`):
  set `SET idle_in_transaction_session_timeout = '5s'` and `SET
  lock_timeout = '5s'` on each pooled connection (via `?options=...` in the
  DSN or a connection hook). This caps the worst case at 5 s even if a
  future change reintroduces a long transaction.
- **Drop `Serializable`** wherever the rewrite makes the operation
  single-statement. READ COMMITTED + atomic `UPDATE ... RETURNING` is
  strictly stronger than a serializable multi-statement tx that does the
  same thing.
- **Retry policy for CAS**: 0 rows affected in a state-machine UPDATE is
  not an error — it is "someone else moved it." Each handler decides:
  no-op (idempotent), 409 (caller retries), or bounded retry with backoff
  (worker loops only).

## Risks to verify before implementation

- **Outbox reaper**: must exist or be added. Without `FOR UPDATE SKIP
  LOCKED`, the atomic-claim approach relies on `claimed_at` + reaper; if
  the reaper is missing, crashed-relay rows sit in `INFLIGHT` forever.
  Verify `internal/outbox/` for an existing reaper before rewriting the
  relay.
- **Multi-row invariants**: any place currently using `Serializable`
  because two rows must change *together* atomically (e.g. debit one
  account, credit another) cannot be flattened to single-statement CAS.
  Keep those in a tx with `SET LOCAL lock_timeout`. `treasury-
  orchestration` batches are the most likely candidate — read the schema
  before rewriting.
- **API contracts**: handlers that currently rely on `SELECT FOR UPDATE`
  returning the row even when the update would later fail will need to
  return 409/410 instead of 500. Update Hurl tests accordingly.
- **Connection-pool settings**: `policy-risk-engine/internal/db/db.go:40`
  sets `SetMaxOpenConns(25)` and `SetMaxIdleConns(5)` but no
  `SetConnMaxLifetime` / `SetConnMaxIdleTime`. Add these so the new
  per-connection `idle_in_transaction_session_timeout` actually takes
  effect on recycled connections.

## Suggested order

1. `wallet-management` nonces — smallest, clearest, no caller-visible
   behavior change. Validates the pattern.
2. `identity-auth` revokes — four near-identical rewrites, exercises the
   409 contract change.
3. `onboarding-kyc` + `blockchain-gateway` — straightforward CAS / upsert.
4. `payment-orchestration` + `treasury-orchestration` — CAS, but verify
   multi-row invariants in treasury first.
5. `transaction-orchestrator` outbox — biggest win, requires the reaper.
6. `transaction-orchestrator` `CreateTx` — keep the tx, add
   `SET LOCAL lock_timeout`.
7. Cross-cutting `idle_in_transaction_session_timeout` + `lock_timeout`
   in every service's `db.Connect`.

## Not a fix for the reset-db hang

To be explicit: this migration does **not** eliminate the `make reset-db`
window. A single autocommit statement still holds a lock for one
round-trip, and `TRUNCATE` can still collide with it. The shipped
`fixtures/reset.sql` (skip-and-continue with `lock_timeout = '5s'`) is
the correct dev-tooling fix; the lock-free migration is a separate
hardening pass with its own justification. Do not conflate the two when
reviewing PRs.