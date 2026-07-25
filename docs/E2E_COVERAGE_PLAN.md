# E2E Async Event Coverage Plan

## Summary

The `tests/e2e-async/` directory contains Hurl integration tests that
verify async event flows end-to-end. Each test triggers a service via
its HTTP API and verifies the observable outcome through service-native
GET endpoints (no kafka-rest or postgrest dependencies).

## Async event topics (11 total)

| Topic | Covered? | Test | How |
|---|---|---|---|
| `audit.v1` | ✅ | `e2e-async/kyt-audit.hurl` | Triggers a KYT screen, verifies audit-logger has ingested events via `GET /v1/events`. |
| `transactions` | ✅ | `e2e-async/tx-orchestrator.hurl` | Creates a transaction, verifies saga state + steps persisted via `GET /v1/transactions/{id}` and `GET /v1/transactions/{id}/steps`. The outbox relay publishes `transaction.created` to this topic. |
| `exchange.events.v1` | ✅ | `e2e-async/exchange-fills.hurl` | Places a market order, verifies fill persisted via `GET /v1/orders/{id}/fills` and order status via `GET /v1/orders/{id}`. |
| `blockchain.events.v1` | ❌ | — | Requires a real chain adapter; stub mode doesn't broadcast. No service-native endpoint to verify broadcast events without a node. |
| `custody.events.v1` | ❌ | — | Requires the saga to reach the MPC sign step; in dev mode the saga stalls at POLICY. No direct REST trigger for MPC signing. |
| `fraud.scored` | ❌ | — | The fraud-engine publishes to this topic asynchronously; the policy-risk-engine consumes it. The fraud Kafka producer may not be wired in dev mode (StubModel returns fixed scores). |
| `ledger.events.v1` | ❌ | — | Requires a ledger posting to trigger the event emitter. The accounting-ledger has `POST /v1/postings` which could trigger this, but the event emission path needs verification. |
| `liquidity.fills` | ❌ | — | Requires a parent order to be sliced and filled; only treasury drives slicing, and treasury only acts on `tx.completed` (never fires in dev mode). |
| `notification.v1` | ❌ | — | Requires a saga step to emit a notification event; the saga stalls at POLICY in dev mode. The notifier's `POST /v1/notifications/send` can trigger delivery directly, but that bypasses the Kafka consumer path. |
| `payment.events.v1` | ❌ | — | Requires a payment intent to reach a terminal state (captured/refunded/chargeback). Dummy rails return success but may not emit Kafka events. |
| `rail.events.v1` | ❌ | — | Requires a payment to be captured and settled through a rail. The dummy rail adapter doesn't emit settlement events. |

## Coverage: 3/11 (27%)

## Why 8 topics are uncovered

The root cause is that the saga never progresses past the POLICY step in
dev mode. Partner stubs return success responses but don't drive the
saga forward, so `tx.completed` is never published. Every downstream
async event that depends on saga progression never fires:

```
tx-orchestrator (stuck at POLICY)
    ↓ tx.completed (never published)
    ↓
treasury-orchestrator (never receives)
    ↓ aggregate fill (never triggers)
    ↓
liquidity-router (never slices)
    ↓ fills (never produced)
    ↓
gateway-blockchain (never broadcasts)
    ↓ blockchain.events.v1 (never emitted)
    ↓
mpc-signer (never signs)
    ↓ custody.events.v1 (never emitted)
    ↓
notifier (never gets tx lifecycle events)
    ↓ notification.v1 (never emitted by orchestrator)
```

The 8 uncovered topics break into two groups:

### Group A: Triggered by the saga (6 topics)

`blockchain.events.v1`, `custody.events.v1`, `liquidity.fills`,
`notification.v1`, `rail.events.v1`, `payment.events.v1` — all depend
on the saga advancing past the POLICY step. Covering these requires
either:

1. A dev-mode saga driver that auto-advances steps (stub partners that
   return success AND trigger the next saga step), or
2. Direct per-service triggers that bypass the saga (e.g. POST a
   payment capture to trigger `payment.events.v1`, POST a ledger
   posting to trigger `ledger.events.v1`).

### Group B: Independent of the saga (2 topics)

`fraud.scored` and `ledger.events.v1` — these can be triggered
independently of the saga:

- **`fraud.scored`**: the fraud-engine can be triggered via its Kafka
  consumer (payment events) or directly via its scoring endpoint. The
  fraud Kafka producer wiring needs verification — the StubModel may
  not publish to Kafka.
- **`ledger.events.v1`**: the accounting-ledger emits events on
  postings. A `POST /v1/postings` with balanced entries should trigger
  the emitter, but the Kafka producer may not be wired in dev mode.

## Recommended path to full coverage

### Option 1: Per-service direct triggers (practical, incremental)

Add one Hurl test per topic that triggers the producing service
directly via its REST API, then verifies the outcome via a consuming
service's GET endpoint:

| Topic | Trigger | Verify via |
|---|---|---|
| `ledger.events.v1` | `POST /v1/postings` on accounting-ledger | `GET /v1/recon-runs/{id}` on reconciliation (run after posting) |
| `fraud.scored` | `POST /v1/fraud/score` on fraud-engine (if endpoint exists) or send a payment event via Kafka | `GET /v1/policy/review` on policy-risk-engine (score feeds into review) |
| `payment.events.v1` | `POST /v1/payments/intents` + `POST /v1/payments/{id}/capture` on payment-orchestrator | `GET /v1/payments/{id}` (status = captured) |
| `rail.events.v1` | `POST /v1/payments/{id}/capture` triggers rail settlement | `GET /v1/recon-runs/{id}` on reconciliation |
| `blockchain.events.v1` | Configure a stub chain adapter that emits on broadcast | `GET /v1/recon-runs/{id}` on reconciliation |
| `custody.events.v1` | Direct gRPC `SignTx` call to mpc-signer (requires a key + policy token) | `GET /v1/recon-runs/{id}` on reconciliation |
| `liquidity.fills` | `POST /v1/parent-orders` on liquidity-router (slicing produces fills) | `GET /v1/parent-orders/{id}/fills` on liquidity-router |
| `notification.v1` | `POST /v1/notifications/send` on notifier | `GET /v1/notifications/{id}` on notifier (status = delivered/pending) |

### Option 2: Dev-mode saga auto-advance (higher effort, higher payoff)

Make the partner stubs in dev mode actually drive the saga forward —
each stub returns success AND the orchestrator advances to the next
step automatically. This would fire the full async chain end-to-end
and cover all 11 topics with a single test. Requires modifying the
orchestrator's dev-mode saga executor to auto-advance steps when
partner stubs return success.

### Recommended: Option 1 first, then Option 2

Option 1 is incremental and each test is independent. Option 2 is the
ideal end state but requires orchestrator changes. Start with Option 1
to get to 11/11 coverage, then pursue Option 2 as a hardening pass.