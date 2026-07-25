# E2E API Coverage Plan

## Summary

This document compares the total HTTP API endpoints exposed by each
service (excluding healthz/readyz/metrics and UI services) against the
endpoints exercised by the existing Hurl integration test suites in
`tests/`. gRPC endpoints are listed but not counted toward coverage
(Hurl is HTTP-only).

## Methodology

- **Total endpoints**: every unique `METHOD path` registered by the
  service's router/mux (Go), axum (Rust), Fastify (TS), or FastAPI
  (Python). Healthz, readyz, and /metrics are excluded.
- **Covered endpoints**: every unique `METHOD path` that appears as a
  request line in a Hurl test file under `tests/`. Query-string variants
  of the same path count as one endpoint (e.g. `GET /v1/events` and
  `GET /v1/events?service=ledger` are the same endpoint).
- **Error-branch coverage**: requests to non-existent IDs (e.g.
  `GET /v1/transactions/tx_doesnotexist`) count as covered since they
  exercise the 404 path.

## Coverage by service

### accounting-ledger (10 HTTP + 5 gRPC)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | GET | /v1/chart-of-accounts | ✅ |
| 2 | GET | /v1/accounts | ❌ |
| 3 | POST | /v1/accounts | ✅ |
| 4 | GET | /v1/accounts/:id/balance | ✅ |
| 5 | GET | /v1/accounts/:id/ledger | ✅ |
| 6 | GET | /v1/postings | ❌ |
| 7 | POST | /v1/postings | ✅ |
| 8 | GET | /v1/postings/:id | ✅ |
| 9 | GET | /v1/reconciliation/user-custodial-sum | ✅ |
| 10 | GET | /v1/chain/verify | ✅ |

**HTTP coverage: 8/10 (80%)**

gRPC (not testable via Hurl): CreateAccount, PostPosting, GetPosting,
GetBalance, VerifyChain.

---

### audit-logger (8 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | GET | /v1/events | ✅ |
| 2 | GET | /v1/events/:id | ✅ |
| 3 | GET | /v1/events/:id/verify-chain | ✅ |
| 4 | POST | /v1/exports | ✅ |
| 5 | GET | /v1/exports/:id | ✅ |
| 6 | POST | /v1/admin/verify-chain | ✅ |
| 7 | POST | /v1/admin/legal-hold/:id | ✅ |
| 8 | POST | /v1/admin/redaction/reload | ❌ |

**HTTP coverage: 7/8 (88%)**

---

### auth-identity (23 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/users | ✅ |
| 2 | POST | /v1/users/verify | ✅ |
| 3 | GET | /v1/users/me | ✅ |
| 4 | PATCH | /v1/users/me | ❌ |
| 5 | DELETE | /v1/users/me | ✅ |
| 6 | POST | /v1/sessions | ✅ |
| 7 | GET | /v1/sessions | ✅ |
| 8 | DELETE | /v1/sessions | ✅ |
| 9 | DELETE | /v1/sessions/:id | ❌ |
| 10 | POST | /v1/sessions/refresh | ✅ |
| 11 | POST | /v1/mfa/enroll | ❌ |
| 12 | POST | /v1/mfa/verify | ❌ |
| 13 | POST | /v1/mfa/recovery | ❌ |
| 14 | DELETE | /v1/mfa/factors/:id | ❌ |
| 15 | POST | /v1/password/reset/init | ❌ |
| 16 | POST | /v1/password/reset/confirm | ❌ |
| 17 | POST | /v1/api-keys | ❌ |
| 18 | GET | /v1/api-keys | ❌ |
| 19 | POST | /v1/api-keys/:id/rotate | ❌ |
| 20 | DELETE | /v1/api-keys/:id | ❌ |
| 21 | GET | /v1/roles | ❌ |
| 22 | POST | /v1/role-bindings | ❌ |
| 23 | GET | /v1/role-bindings | ❌ |
| 24 | DELETE | /v1/role-bindings/:id | ❌ |
| 25 | POST | /v1/authz | ❌ |
| 26 | GET | /v1/audit-events | ❌ |
| 27 | POST | /v1/admin/unlock | ❌ |

**HTTP coverage: 8/27 (30%)**

---

### fraud-engine (3 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/fraud/score | ❌ |
| 2 | GET | /v1/fraud/models | ❌ |
| 3 | POST | /v1/fraud/feedback | ❌ |

**HTTP coverage: 0/3 (0%)**

---

### fx-hedger (9 HTTP + 4 gRPC)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | GET | /v1/exposures | ❌ |
| 2 | GET | /v1/exposure/:currency | ✅ |
| 3 | POST | /v1/exposure/:currency | ✅ |
| 4 | GET | /v1/hedges | ❌ |
| 5 | POST | /v1/hedges | ✅ |
| 6 | GET | /v1/hedges/:id | ✅ |
| 7 | GET | /v1/pnl | ✅ |
| 8 | GET | /v1/slippage | ✅ |
| 9 | GET | /v1/settlement | ✅ |

**HTTP coverage: 7/9 (78%)**

gRPC (not testable via Hurl): GetLiveRate, GetNetExposure,
StreamExposure, SubmitHedgePlan.

---

### gateway-api (9 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/auth/session | ❌ |
| 2 | GET | /v1/me | ❌ |
| 3 | POST | /v1/quotes | ❌ |
| 4 | POST | /v1/transactions | ❌ |
| 5 | GET | /v1/transactions/:id | ❌ |
| 6 | GET | /v1/transactions | ❌ |
| 7 | POST | /v1/kyc/start | ❌ |
| 8 | GET | /v1/kyc/status | ❌ |
| 9 | POST | /v1/partner/webhooks | ❌ |

**HTTP coverage: 0/9 (0%)**

---

### gateway-blockchain (7 HTTP + 1 WS)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/chains/:chain/broadcast | ❌ |
| 2 | POST | /v1/chains/:chain/estimate-fee | ❌ |
| 3 | GET | /v1/chains/:chain/height | ❌ |
| 4 | GET | /v1/chains/:chain/address/:addr/balance | ❌ |
| 5 | GET | /v1/chains/:chain/tx/:hash | ❌ |
| 6 | GET | /v1/chains/:chain/tx/:hash/status | ❌ |
| 7 | WS | /v1/chains/:chain/heads | ❌ |

**HTTP coverage: 0/7 (0%)**

---

### gateway-exchange (8 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | GET | /admin/status | ✅ |
| 2 | POST | /admin/rotate-credentials | ✅ |
| 3 | POST | /v1/orders | ✅ |
| 4 | GET | /v1/orders/:id | ✅ |
| 5 | POST | /v1/orders/:id/cancel | ✅ |
| 6 | GET | /v1/orders/:id/fills | ✅ |
| 7 | GET | /v1/balances | ✅ |
| 8 | GET | /v1/book/:pair | ✅ |

**HTTP coverage: 8/8 (100%)**

---

### gateway-fiat (5 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/authorize | ✅ |
| 2 | POST | /v1/capture/:payment_id | ✅ |
| 3 | POST | /v1/refund/:payment_id | ✅ |
| 4 | GET | /v1/status/:payment_id | ✅ |
| 5 | POST | /webhooks/:rail | ✅ |

**HTTP coverage: 5/5 (100%)**

---

### kyc-onboarding (11 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/kyc/applications | ✅ |
| 2 | GET | /v1/kyc/applications/:id | ✅ |
| 3 | GET | /v1/kyc/status/:user_id | ✅ |
| 4 | POST | /v1/kyc/applications/:id/documents | ✅ |
| 5 | GET | /v1/kyc/applications/:id/documents | ✅ |
| 6 | POST | /v1/kyc/applications/:id/liveness | ✅ |
| 7 | GET | /v1/kyc/applications/:id/liveness | ✅ |
| 8 | POST | /v1/kyc/applications/:id/screening | ✅ |
| 9 | POST | /v1/kyc/applications/:id/screening/disposition | ❌ |
| 10 | POST | /v1/webhooks/:vendor | ✅ |
| 11 | POST | /internal/v1/rekyc/trigger | ❌ |
| 12 | GET | /v1/audit-events | ❌ |

**HTTP coverage: 9/12 (75%)**

---

### kyt-aml-screening (6 HTTP + 2 gRPC)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/kyt/screen | ✅ |
| 2 | GET | /v1/kyt/alerts/:id | ✅ |
| 3 | GET | /v1/kyt/alerts | ✅ |
| 4 | POST | /v1/kyt/alerts/:id/assign | ✅ |
| 5 | POST | /v1/kyt/alerts/:id/close | ✅ |
| 6 | POST | /v1/webhooks/:vendor | ✅ |

**HTTP coverage: 6/6 (100%)**

gRPC (not testable via Hurl): Screen, GetAlert.

---

### liquidity-router (6 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | GET | /v1/parent-orders | ❌ |
| 2 | POST | /v1/parent-orders | ✅ |
| 3 | GET | /v1/parent-orders/:id | ✅ |
| 4 | POST | /v1/parent-orders/:id/cancel | ✅ |
| 5 | GET | /v1/parent-orders/:id/fills | ✅ |
| 6 | GET | /v1/venue-states | ❌ |

**HTTP coverage: 4/6 (67%)**

---

### mpc-signer (1 HTTP + 5 gRPC)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/custody/webhook | ✅ |

**HTTP coverage: 1/1 (100%)**

gRPC (not testable via Hurl): SignTx, Dkg, RotateKey, GetKeyMetadata,
RestoreShare.

---

### notifier (14 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | GET | /v1/preferences | ✅ |
| 2 | POST | /v1/preferences/:user_id | ✅ |
| 3 | GET | /v1/preferences/:user_id | ✅ |
| 4 | POST | /v1/events | ✅ |
| 5 | GET | /v1/notifications | ❌ |
| 6 | POST | /v1/notifications/send | ✅ |
| 7 | GET | /v1/notifications/:id | ✅ |
| 8 | GET | /v1/notifications/:id/status | ✅ |
| 9 | POST | /v1/webhooks/partners | ✅ |
| 10 | GET | /v1/webhooks/partners | ✅ |
| 11 | POST | /v1/webhooks/partners/:id/confirm | ✅ |
| 12 | POST | /v1/webhooks/partners/:id/deliver | ❌ |
| 13 | GET | /v1/audit-events | ✅ |
| 14 | POST | /v1/webhooks/verify | ❌ |

**HTTP coverage: 11/14 (79%)**

---

### payment-orchestrator (8 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/payments/intents | ✅ |
| 2 | GET | /v1/payments | ❌ |
| 3 | GET | /v1/payments/:id | ✅ |
| 4 | POST | /v1/payments/:id/capture | ✅ |
| 5 | POST | /v1/payments/:id/void | ✅ |
| 6 | POST | /v1/payments/:id/refund | ✅ |
| 7 | POST | /v1/payments/:id/3ds-challenge | ✅ |
| 8 | POST | /v1/webhooks/:rail | ✅ |

**HTTP coverage: 7/8 (88%)**

---

### policy-risk-engine (9 HTTP + 1 gRPC)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/policy/evaluate | ✅ |
| 2 | POST | /v1/policy/whitelist | ✅ |
| 3 | GET | /v1/policy/whitelist/:user_id | ✅ |
| 4 | POST | /v1/policy/whitelist/:user_id/verify | ✅ |
| 5 | POST | /v1/policy/review/:decision_id/resolve | ✅ |
| 6 | GET | /v1/policy/review | ✅ |
| 7 | GET | /v1/policy/rules | ✅ |
| 8 | GET | /v1/policy/rules/:version | ✅ |
| 9 | POST | /v1/policy/rules | ✅ |

**HTTP coverage: 9/9 (100%)**

gRPC (not testable via Hurl): Evaluate.

---

### pricing-quote (10 HTTP + 1 WS)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | GET | /v1/quotes | ❌ |
| 2 | POST | /v1/quotes | ✅ |
| 3 | GET | /v1/quotes/:id | ✅ |
| 4 | POST | /v1/quotes/:id/refresh | ✅ |
| 5 | POST | /internal/v1/quotes/:id/claim | ✅ |
| 6 | POST | /internal/v1/fee-schedules/reload | ✅ |
| 7 | GET | /v1/fee-schedules | ❌ |
| 8 | GET | /v1/rate-sources | ❌ |
| 9 | GET | /v1/audit-events | ✅ |
| 10 | WS | /v1/rates/subscribe | ❌ |

**HTTP coverage: 6/10 (60%)**

---

### reconciliation (12 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | GET | /v1/breaks | ✅ |
| 2 | GET | /v1/breaks/:break_id | ✅ |
| 3 | POST | /v1/breaks/:break_id/resolve | ✅ |
| 4 | POST | /v1/breaks/:break_id/escalate | ✅ |
| 5 | GET | /v1/recon-runs | ❌ |
| 6 | GET | /v1/recon-runs/:run_id | ✅ |
| 7 | POST | /v1/recon-runs | ✅ |
| 8 | GET | /v1/recon-runs/:run_id/report | ✅ |
| 9 | POST | /v1/recon-runs/:run_id/report/archive | ❌ |
| 10 | GET | /v1/recon-rules | ❌ |
| 11 | POST | /v1/recon-rules | ❌ |
| 12 | GET | /v1/breaks-export | ✅ |

**HTTP coverage: 8/12 (67%)**

---

### treasury-orchestrator (11 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | GET | /v1/batches | ✅ |
| 2 | GET | /v1/batches/:id | ✅ |
| 3 | POST | /v1/batches/:id/close | ✅ |
| 4 | GET | /v1/batches/:id/memberships | ❌ |
| 5 | GET | /v1/float | ❌ |
| 6 | GET | /v1/float/:fiat_currency | ✅ |
| 7 | GET | /v1/funding-requests | ✅ |
| 8 | POST | /v1/funding-requests | ✅ |
| 9 | GET | /v1/rebalancing-jobs | ✅ |
| 10 | GET | /v1/aggregate-orders | ❌ |
| 11 | POST | /v1/events/ | ❌ |

**HTTP coverage: 7/11 (64%)**

---

### tx-orchestrator (5 HTTP)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/transactions | ✅ |
| 2 | GET | /v1/transactions/:id | ✅ |
| 3 | GET | /v1/transactions/:id/steps | ✅ |
| 4 | POST | /v1/transactions/:id/retry | ✅ |
| 5 | POST | /v1/transactions/:id/compensate | ✅ |

**HTTP coverage: 5/5 (100%)**

---

### wallet-manager (12 HTTP + 3 gRPC)

| # | Method | Path | Covered? |
|---|---|---|---|
| 1 | POST | /v1/wallets | ✅ |
| 2 | GET | /v1/wallets/:id | ✅ |
| 3 | GET | /v1/wallets | ❌ |
| 4 | GET | /v1/wallets/:id/addresses | ✅ |
| 5 | POST | /v1/wallets/:id/addresses/derive | ✅ |
| 6 | GET | /v1/wallets/:id/balances | ✅ |
| 7 | POST | /v1/wallets/:id/funding-request | ❌ |
| 8 | GET | /v1/wallets/:id/funding-requests | ❌ |
| 9 | POST | /v1/wallets/:id/nonce/allocate | ❌ |
| 10 | POST | /v1/withdrawals | ❌ |
| 11 | GET | /v1/withdrawals | ❌ |
| 12 | GET | /v1/withdrawals/:id | ❌ |

**HTTP coverage: 5/12 (42%)**

gRPC (not testable via Hurl): ResolveKeyID, OnConfirmation, OnReorg.

---

## Summary table

| Service | Total HTTP | Covered | % |
|---|---|---|---|
| accounting-ledger | 10 | 8 | 80% |
| audit-logger | 8 | 7 | 88% |
| auth-identity | 27 | 8 | 30% |
| fraud-engine | 3 | 0 | 0% |
| fx-hedger | 9 | 7 | 78% |
| gateway-api | 9 | 0 | 0% |
| gateway-blockchain | 7 | 0 | 0% |
| gateway-exchange | 8 | 8 | 100% |
| gateway-fiat | 5 | 5 | 100% |
| kyc-onboarding | 12 | 9 | 75% |
| kyt-aml-screening | 6 | 6 | 100% |
| liquidity-router | 6 | 4 | 67% |
| mpc-signer | 1 | 1 | 100% |
| notifier | 14 | 11 | 79% |
| payment-orchestrator | 8 | 7 | 88% |
| policy-risk-engine | 9 | 9 | 100% |
| pricing-quote | 10 | 6 | 60% |
| reconciliation | 12 | 8 | 67% |
| treasury-orchestrator | 11 | 7 | 64% |
| tx-orchestrator | 5 | 5 | 100% |
| wallet-manager | 12 | 5 | 42% |
| **Total** | **167** | **111** | **66%** |

## gRPC endpoints (not testable via Hurl)

| Service | gRPC methods |
|---|---|
| accounting-ledger | CreateAccount, PostPosting, GetPosting, GetBalance, VerifyChain |
| fx-hedger | GetLiveRate, GetNetExposure, StreamExposure, SubmitHedgePlan |
| kyt-aml-screening | Screen, GetAlert |
| mpc-signer | SignTx, Dkg, RotateKey, GetKeyMetadata, RestoreShare |
| policy-risk-engine | Evaluate |
| wallet-manager | ResolveKeyID, OnConfirmation, OnReorg |

**22 gRPC methods total — 0% covered by Hurl (HTTP-only tool).**

## Uncovered services (0% HTTP coverage)

Three services have zero Hurl coverage beyond healthz:

1. **fraud-engine** (3 endpoints) — `POST /v1/fraud/score`, `GET
   /v1/fraud/models`, `POST /v1/fraud/feedback`. The test file only hits
   healthz.
2. **gateway-api** (9 endpoints) — the BFF layer; all routes require JWT
   auth and proxy to backend services. No Hurl test exercises any route.
3. **gateway-blockchain** (7 endpoints) — chain broadcast/fee/status
   endpoints. Stub chain mode in dev means most return 404 for unknown
   chains; no Hurl test exercises any route.

## Largest coverage gaps (by uncovered endpoint count)

| Service | Uncovered | Key missing endpoints |
|---|---|---|
| auth-identity | 19 | MFA (4), API keys (4), RBAC (4), password reset (2), PATCH /me, DELETE session/:id, authz, audit-events, admin/unlock |
| wallet-manager | 7 | withdrawals (3), funding-request (2), nonce/allocate, list wallets |
| gateway-api | 9 | all (auth/session, me, quotes, transactions, KYC, webhooks) |
| gateway-blockchain | 7 | all (broadcast, fee, height, balance, tx, status, WS heads) |
| fraud-engine | 3 | all (score, models, feedback) |
| pricing-quote | 4 | list quotes, fee-schedules, rate-sources, WS subscribe |
| treasury-orchestrator | 4 | memberships, float list, aggregate-orders, events push |
| reconciliation | 4 | list runs, report archive, rules (2) |
| auth-identity | — | (see above) |
| accounting-ledger | 2 | list accounts, list postings |
| notifier | 3 | list notifications, webhook deliver, webhook verify |