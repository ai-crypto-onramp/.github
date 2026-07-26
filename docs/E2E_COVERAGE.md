# E2E Coverage

Unified summary of Hurl integration test coverage across all three
transport planes: HTTP REST, async Kafka events, and gRPC.

## API (HTTP)

**184 / 191 endpoints covered — 96%**

| Service | Total | Covered | % | Test file |
|---|---|---|---|---|
| accounting-ledger | 10 | 10 | 100% | `tests/accounting-ledger/ledger.hurl` |
| audit-logger | 8 | 7 | 88% | `tests/audit-logger/audit.hurl` |
| gateway-auth | 27 | 27 | 100% | `tests/gateway-auth/auth-flow.hurl` |
| engine-fraud | 3 | 3 | 100% | `tests/engine-fraud/fraud.hurl` |
| fx-hedger | 9 | 7 | 78% | `tests/fx-hedger/hedging.hurl` |
| gateway-api | 9 | 9 | 100% | `tests/gateway-api/gateway-api.hurl` |
| gateway-blockchain | 6 | 6 | 100% | `tests/gateway-blockchain/blockchain.hurl` |
| gateway-exchange | 8 | 8 | 100% | `tests/gateway-exchange/exchange.hurl` |
| gateway-fiat | 5 | 5 | 100% | `tests/gateway-fiat/rails.hurl` |
| kyc-onboarding | 12 | 12 | 100% | `tests/kyc-onboarding/kyc-flow.hurl` |
| kyt-aml-screening | 6 | 6 | 100% | `tests/kyt-aml-screening/screening.hurl` |
| engine-liquidity | 6 | 4 | 67% | `tests/engine-liquidity/liquidity.hurl` |
| mpc-signer | 1 | 1 | 100% | `tests/mpc-signer/health.hurl` |
| notifier | 14 | 14 | 100% | `tests/notifier/notifications.hurl` |
| orchestrator-fiat | 8 | 7 | 88% | `tests/orchestrator-fiat/payments.hurl` |
| engine-policy-risk | 9 | 9 | 100% | `tests/engine-policy-risk/policy-flow.hurl` |
| engine-pricing | 10 | 9 | 90% | `tests/engine-pricing/quotes.hurl` |
| engine-recon | 12 | 12 | 100% | `tests/engine-recon/engine-recon.hurl` |
| orchestrator-treasury | 11 | 11 | 100% | `tests/orchestrator-treasury/treasury.hurl` |
| orchestrator-tx | 5 | 5 | 100% | `tests/orchestrator-tx/orchestrator.hurl` |
| wallet-manager | 12 | 12 | 100% | `tests/wallet-manager/wallet.hurl` |
| **Total** | **191** | **184** | **96%** | |

### Remaining HTTP gaps (7 endpoints)

| Service | Uncovered | Reason |
|---|---|---|
| fx-hedger | 2 | `GET /v1/exposures`, `GET /v1/hedges` |
| engine-liquidity | 2 | `GET /v1/parent-orders`, `GET /v1/venue-states` |
| audit-logger | 1 | `POST /v1/admin/redaction/reload` |
| orchestrator-fiat | 1 | `GET /v1/payments` |
| engine-pricing | 1 | `WS /v1/rates/subscribe` — Hurl is HTTP-only |
| gateway-blockchain | 1 | `WS /v1/chains/:chain/heads` — Hurl is HTTP-only |

## Async (Kafka event topics)

**9 / 11 topics covered — 82%**

| Topic | Covered? | Test | Trigger → Verify |
|---|---|---|---|
| `audit.v1` | ✅ | `e2e-async/kyt-audit.hurl` | KYT screen → audit-logger `GET /v1/events` |
| `transactions` | ✅ | `e2e-async/orchestrator-tx.hurl` | Create tx → saga state + steps persisted |
| `exchange.events.v1` | ✅ | `e2e-async/exchange-fills.hurl` | Market order → `GET /v1/orders/{id}/fills` |
| `ledger.events.v1` | ✅ | `e2e-async/ledger-events.hurl` | `POST /v1/postings` → recon run on engine-recon |
| `fraud.scored` | ✅ | `e2e-async/fraud-scored.hurl` | `POST /v1/fraud/score` → policy review queue |
| `payment.events.v1` | ✅ | `e2e-async/payment-events.hurl` | Payment intent + capture → `GET /v1/payments/{id}` |
| `rail.events.v1` | ✅ | `e2e-async/rail-events.hurl` | Payment capture → recon run (source=RAILS) |
| `liquidity.fills` | ✅ | `e2e-async/liquidity-fills.hurl` | `POST /v1/parent-orders` → `GET /v1/parent-orders/{id}/fills` |
| `notification.v1` | ✅ | `e2e-async/notification-events.hurl` | `POST /v1/notifications/send` → `GET /v1/notifications/{id}` |
| `blockchain.events.v1` | ❌ | — | Requires a real chain adapter; stub mode doesn't broadcast. No service-native endpoint to verify without a node. |
| `custody.events.v1` | ❌ | — | Requires the saga to reach the MPC sign step; in dev mode the saga stalls at POLICY. No direct REST trigger for MPC signing (gRPC only). |

### Dev-mode wiring notes

Several async tests exercise the trigger + verify path even when the
Kafka producer isn't wired in dev mode. The synchronous state-machine
transition is verified regardless; full Kafka pipeline coverage awaits
dev-mode producer wiring:

- **`fraud.scored`** — engine-fraud's `AuditEmitter` is constructed
  without a Kafka producer in dev mode. The fraud score is fed into
  engine-policy-risk synchronously via the `fraud_score` field on
  `POST /v1/policy/evaluate`.
- **`payment.events.v1`** / **`rail.events.v1`** — orchestrator-fiat
  and gateway-fiat don't emit Kafka events in dev mode. Payment state
  transitions are verified via `GET /v1/payments/{id}`; rail recon runs
  complete with zero matched events (shape check, not count).
- **`liquidity.fills`** — the TWAP/VWAP slicer isn't auto-started for
  new parent orders in dev mode (only `ResumeActive` on restart). The
  test verifies the parent order is created and the fills endpoint
  returns a valid array (empty until a slicer driver is wired).

## gRPC

**0 / 22 methods covered — 0%**

Hurl is HTTP-only; gRPC endpoints are not testable via the current
Hurl integration suite.

| Service | gRPC methods |
|---|---|
| accounting-ledger | CreateAccount, PostPosting, GetPosting, GetBalance, VerifyChain |
| fx-hedger | GetLiveRate, GetNetExposure, StreamExposure, SubmitHedgePlan |
| kyt-aml-screening | Screen, GetAlert |
| mpc-signer | SignTx, Dkg, RotateKey, GetKeyMetadata, RestoreShare |
| engine-policy-risk | Evaluate |
| wallet-manager | ResolveKeyID, OnConfirmation, OnReorg |

gRPC coverage would require a dedicated gRPC test harness (e.g. grpcurl,
ghz, or language-specific clients). The `custody.events.v1` async gap is
partly caused by `mpc-signer`'s `SignTx` being gRPC-only with no REST
trigger.