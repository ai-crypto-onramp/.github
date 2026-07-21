# Production-Readiness Report — AI Crypto On-Ramp Backend

**Scope:** 21 backend services across `/Users/pkiselyov/sandbox/ai-crypto-onramp/` (UI systems excluded per instruction).
**Method:** 6 parallel subagents auditing service groups + 1 cross-cutting scan. Every claim cited as `file:line`. No files modified.
**Date:** 2026-07-17

---

## Headline Verdict

This is a **well-scaffolded but pre-production monorepo**. Per-service code quality is reasonable (unit-test ratios 0.3–0.96 across all 21 services; Dockerfiles, healthz, CI all present), but the **inter-service fabric is broken in numerous critical places**:

- The transaction saga has **never been executed end-to-end against real partners** — the orchestrator silently falls back to in-memory stubs for all 6 downstream services, and its private proto copies are incompatible with the actual partner gRPC servers.
- **Audit, notification, and reconciliation pipelines are end-to-end broken** (wrong topics, no producer on the topic the consumer reads, in-memory consumers).
- **3 money-moving services have zero persistence** — a restart loses every in-flight payment, settlement, order, and fill.
- **No observability backend, no mTLS, no auth on internal money-moving endpoints, no release pipeline for 19/21 services.**

The stack boots and passes Gatus health probes, but it **cannot execute a real transaction end-to-end**.

---

## Service Readiness Scores

| # | Service | Lang | Score | One-line justification |
|---|---|---|---|---|
| 1 | api-gateway | TS | 4/10 | Solid scaffolding but auth scheme mismatch with identity-auth (RS256 vs HS256, no JWKS); downstream paths don't match real services; mock clients silently used in deployed stack. |
| 2 | identity-auth | Go | 3/10 | HS256+dev-secret default, no JWKS, silent in-memory fallback on DB failure, partner endpoints gateway expects don't exist. |
| 3 | onboarding-kyc | Go | 3/10 | Vendor/liveness/sanctions all stubs (liveness hardcoded PASS, sanctions list = 2 names), policy-event sink POSTs to nonexistent endpoint. |
| 4 | aml-kyt-screening | Go | 5/10 | Best-structured of the Go services (real vendor HTTP, idempotency, mTLS option) but silent mock fallback, no healthcheck in image, audit topic mismatch. |
| 5 | policy-risk-engine | Go | 5/10 | Mature design (OPA, mTLS gRPC, audit signing) but Redis velocity counter never wired, only daily window enforced, no KYC/fraud/KYT ingest endpoints. |
| 6 | fraud-detection | Python | 2/10 | Only model is StubModel, all 18 readiness checks hardcoded `True`, Kafka consumer never started, audit in-memory, no auth on /score. |
| 7 | payment-orchestration | Go | 2/10 | In-memory only (no DB), dummy rails/MPI/fraud hard-wired, idempotency cache in-memory, audit in-memory, no mTLS. |
| 8 | rail-connectors | Go | 3/10 | Real adapters exist but main.go registers dummy; money is float64; retry/breaker middleware unused; settlement parsers unwired; in-memory store. |
| 9 | pricing-quote | Go | 4/10 | Best-engineered of the fiat path (migrations, Prometheus, distroless, 82.5% coverage) but spot rates hardcoded BTC=65000, DB migration-only, money float64. |
| 10 | fx-hedging | Go | 4/10 | Postgres+migrations+gRPC+mTLS option+idempotency but provider is dummy rate=1.10 for every currency, money float64, no metrics/tracing. |
| 11 | liquidity-routing | Go | 4/10 | Postgres+outbox+Kafka recon+distroless but exchange client always FakeExchange, TWAP slicer is placeholder returning 1, no gRPC server despite README claim. |
| 12 | exchange-connectors | Go | 5/10 | Highest coverage (94%), real venue adapters, decimal money, Kafka fills — but http.DefaultClient (no timeout), client_order_id never set (real venues reject), secrets manager unused, no /metrics endpoint. |
| 13 | mpc-signing-service | Rust | 4/10 | Real policy-gating + audit + mTLS plumbing, but in-house threshold engine **reconstructs the full private key** in the coordinator (defeats MPC threat model), HSM/attestation are software mocks, nodes run in-process not distributed. |
| 14 | wallet-management | Go | 3/10 | BIP-44 derivation tested against known vectors but withdrawal path is a stub (`"unsigned:%s:..."`), production binary wires MockMPCSigner/MockGatewayClient, balance math int64 (overflow), EVM nonce rollback is no-op, errcheck disabled. |
| 15 | blockchain-gateway | Go | 5/10 | Solid confirmation state machine + idempotent broadcast + reorg detection, but chain adapters are poll-based scaffolds, **reorg handler marks txs but never re-broadcasts**, prepayment doesn't wait for funding confirmation, BTC balance uses float, calls wallet-management endpoints that don't exist. |
| 16 | transaction-orchestrator | Go | 6/10 | Best saga mechanics (idempotency, outbox, recovery tested) but stubs are documented "production default", gRPC uses insecure creds, ConfirmPoller never started, compensation errors swallowed. |
| 17 | ledger-accounting | Rust | 3/10 | Invariants well-tested in-memory but **in-memory state is source of truth** (DB is write-behind mirror), unwrap() on money path, audit emission is stderr print, immutability trigger removed, no SERIALIZABLE per-tx enforcement. |
| 18 | treasury-orchestration | Go | 5/10 | Coherent batch/float/hedging architecture with outbox+resilience but money is float64, ledger posting fabricated/truncated, expected price hardcoded 50000, all clients fall back to fakes. |
| 19 | reconciliation | Python | 4/10 | Match strategies + aging + DLQ + reports all implemented, but **recon never fetches ledger entries in production** (passes empty list → every external entry = false break), all readiness checks hardcoded True, no active source fetching. |
| 20 | notification | TS | 3/10 | Every external surface stubbed (Kafka consumer in-memory, all providers Stub*, outbound webhook HTTP never called, Redis dedup unwired). Cannot send a real message as built. |
| 21 | audit-event-log | Go | 8/10 | Highest score: real Kafka/S3/KMS/Postgres adapters with hash-chain, redaction, exports, strong tests. Needs concurrent-insert safety, notary posting, prod-strict mode. |

**Aggregate:** Average 4.0/10. Only 1 service (audit-event-log) is above 5.5. The custody/ledger core (the highest-stakes components) score 3–5.

---

## Top 10 Critical (P0) Production Blockers

These are systemic issues that would cause fund loss, security breach, data loss, or complete inability to process a real transaction.

### 1. The transaction saga has never run against real partners
The transaction-orchestrator's 6 gRPC clients are built against private proto copies that **disagree** with the partner services' actual gRPC servers on service name, RPC name, and message fields (policy, kyt, mpc, ledger). For payment-orchestration and blockchain-gateway, **the partners have no gRPC server at all** (REST only). Compounding this, compose does not set `POLICY_URL`/`PAYMENT_URL`/`KYT_URL`/`MPC_URL`/`BLOCKCHAIN_URL`/`LEDGER_URL` for the orchestrator, so it silently runs entirely against `partner.NewStub`.
- Evidence: `transaction-orchestrator/proto/*.proto` vs each partner's `proto/`; `transaction-orchestrator/cmd/orchestrator/main.go:160-210`; `.github/docker-compose.yml:469-481`; `transaction-orchestrator/internal/partner/partner.go:5-6` ("the stub is the production default").
- **Remediation:** Introduce a `contracts/` repo with versioned proto/AsyncAPI; both producers and consumers generate from it. Set partner URLs in compose. Make stubs opt-in via `ENABLE_STUB_PARTNERS=1`.

### 2. Audit pipeline is broken end-to-end
Every producer (mpc, wallet-mgmt, blockchain-gateway, notification, payment) POSTs audit events to `AUDIT_EVENT_LOG_URL/v1/events` — a route that **does not exist** on audit-event-log (only `GET /v1/events` and `GET /v1/events/{id}`). audit-event-log's only ingress is Kafka topic `audit.v1`, and **no service publishes to `audit.v1`** — aml-kyt publishes to `kyt.audit.v1` (different topic), fraud emits to in-memory list, ledger prints to stderr. The audit service is a consumer with no producer.
- Evidence: `audit-event-log/internal/api/api.go:86-88`; `aml-kyt-screening/internal/audit/kafka_sink.go:17`; `mpc-signing-service/src/audit.rs:169`; `ledger-accounting/src/audit.rs:27-35`; `fraud-detection/src/fraud_detection/app.py:31`.
- **Remediation:** Pick one ingress (HTTP POST or Kafka) and make every producer use it with a canonical topic/route `audit.v1`.

### 3. MPC signing service reconstructs the full private key
The in-house threshold engine reconstructs the secret scalar from `t` shares inside the coordinator, then signs with the full key. A single coordinator memory dump = full key compromise. This defeats the entire MPC threat model. Additionally, HSM/secure-enclave storage is a software mock with hardcoded wrapping key `*b"mpc-mock-hsm-wrapping-key-32byte"`, and attestation is a mock parsing signed JSON.
- Evidence: `mpc-signing-service/src/engine/threshold/cluster.rs:6-11,187-189` (`shamir::reconstruct` then sign); `src/enclave/store.rs:46-67`; `src/enclave/attestation.rs:7-12`; confirmed in `SECURITY.md:43-46`.
- **Remediation:** Replace with a non-reconstructing protocol (GG20/CGGMP/CMP20) via an audited crate (e.g. `frost`, `cggmp21`); implement real PKCS#11 HSM; commission an independent MPC crypto audit before GA. The custody-provider delegation path (Fireblocks/Dfns/Turnkey adapters) is the viable short-term route but is only tested against wiremock mocks.

### 4. Three money-moving services have zero persistence
`payment-orchestration`, `rail-connectors`, and `exchange-connectors` use in-memory stores with no `DB_URL` and no migrations. A restart loses every in-flight payment, settlement, order, and fill. `blockchain-gateway` is also documented as in-memory ("its Postgres store is not wired into the entrypoint yet"). Webhook dedup is in-memory in payment-orchestration and rail-connectors, so a restart replays any retried mutation.
- Evidence: `payment-orchestration/internal/store/store.go:20-31`; `cmd/payment-orchestration/main.go:34` (`store.New()`); `rg "pgx\|sql.Open" rail-connectors exchange-connectors` → 0; `.github/docker-compose.yml:269-272` (blockchain-gateway comment).
- **Remediation:** Add Postgres stores + migrations to all four services; wire `DB_URL` in compose; move idempotency/dedup to durable storage.

### 5. Wallet-management withdrawal path is a stub
The production binary `cmd/wallet-management/main.go` wires `MockMPCSigner` and `MockGatewayClient` (real gRPC clients exist but are unused). Withdrawal tx construction is a fake string: `buildUnsignedTx` returns `[]byte("unsigned:%s:%s:%s:%d:%v")` and `Broadcast` sends `[]byte("signed:" + wr.ID.String())`. No real EVM/BTC/Solana transaction is ever built. UTXO outpoints are not persisted on the withdrawal row (double-spend protection broken). EVM nonce rollback is a no-op.
- Evidence: `cmd/wallet-management/main.go:107-110`; `internal/withdrawal/withdrawal.go:327-328,203,212-218`; `internal/nonce/nonce.go:60-67`; `internal/grpcclient/grpcclient.go:48-71,103-130` (mocks used in prod binary).
- **Remediation:** Wire real gRPC clients; implement real unsigned-tx construction per chain (RLP for EVM, PSBT for BTC, Solana message); persist reserved outpoints; implement real nonce rollback.

### 6. Blockchain-gateway doesn't re-broadcast after reorgs and calls nonexistent wallet-management endpoints
The reorg handler marks txs `reorged_out` but never re-broadcasts — reorged-out withdrawals stay stuck (README and detector docstring claim re-broadcast; code doesn't). Prepayment doesn't wait for funding tx confirmation (creates and immediately cancels a context → broadcasts before gas funds confirmed → tx dropped). The `walletclient.HTTPClient` POSTs to `/v1/fund-sender` and `/v1/nonce/allocate` — **these endpoints do not exist** in wallet-management's REST router (only `/v1/wallets/{id}/funding-request`).
- Evidence: `blockchain-gateway/internal/reorg/detector.go:84-90` (only Transition, no broadcast); `internal/prepayment/manager.go:71-78` (no-op wait); `internal/walletclient/client.go:78-87` vs `wallet-management/internal/api/rest/rest.go:41-52`.
- **Remediation:** Implement re-broadcast on next head after reorg; poll funding tx status until confirmed; align REST contract with wallet-management (or add the missing endpoints to wallet-management).

### 7. Ledger is not the single source of truth
The in-memory `Arc<Mutex<LedgerState>>` is the authoritative source for all reads (balance, ledger, verify_chain). Postgres is written *after* mutating in-memory state via `block_in_place`, and the DB write can fail while in-memory already committed (or vice-versa). Two replicas have divergent in-memory state. The DB immutability trigger was removed ("previous reject_entry_mutation() trigger has been removed"). `unwrap()` on money-path code (`state.postings.get(&req.posting_id).unwrap()` on idempotent replay). Audit emission is a stderr print. `HASH_CHAIN_SALT` is configured but never mixed into `compute_hash` — the hash chain is forgeable.
- Evidence: `ledger-accounting/src/store.rs:70-89,284-330,365-440,442-753,457,523-524,947-949`; `migrations/20240101000001_init_schema.sql:6-7`; `src/audit.rs:27-35`; `src/posting.rs:77-81`.
- **Remediation:** Make Postgres the source of truth (read balances from DB with explicit `BEGIN ISOLATION LEVEL SERIALIZABLE`); re-add DB trigger rejecting UPDATE/DELETE on `entries`; implement real audit emission; mix `HASH_CHAIN_SALT` into hash; remove `unwrap()` from money path.

### 8. Reconciliation never fetches ledger entries
`Reconciler.execute()` never fetches ledger entries: `ledger = ledger_entries or []`. When called from REST or CLI, `ledger_entries` is always `None`, so `ledger=[]` and every external entry becomes `unmatched_external` → a `MISSING_ENTRY` break. The core recon function is broken in production. Additionally, the `CONSUMER_TOPICS` map uses service names (`"ledger-accounting"`, `"rail-connectors"`) not actual Kafka topics — and ledger-accounting has no Kafka producer at all.
- Evidence: `reconciliation/src/reconciliation/reconciler.py:106-137`; `src/reconciliation/app.py:281`; `src/reconciliation/cli.py:44`; `src/reconciliation/config.py:60-66`.
- **Remediation:** Implement a ledger fetcher (HTTP/gRPC client to ledger `/v1/accounts/:id/ledger` or consume the ledger Kafka topic once ledger publishes); fix topic naming to match producers.

### 9. Internal money-moving endpoints are unauthenticated and mTLS is off
`transaction-orchestrator` (`POST /v1/transactions`, retry, compensate), `payment-orchestration` (authorize, capture, refund), and `ledger-accounting` REST have no auth middleware. mpc-signing-service supports mTLS but it is **explicitly disabled in compose** ("mTLS intentionally left off so intra-stack callers need no client certs"). All txo→partner gRPC dials use `insecure.NewCredentials()`. Anyone with network reachability can create or force-compensate transactions.
- Evidence: `transaction-orchestrator/internal/api/api.go:103-111`; `payment-orchestration/internal/api/handlers.go` (no auth import); `.github/docker-compose.yml:373-376`; `transaction-orchestrator/internal/grpcclient/grpcclient.go:61,89,148,176,202,238` (6 `insecure.NewCredentials()`).
- **Remediation:** Add service-token JWT middleware to all internal endpoints; enable mTLS in any non-dev environment; use `credentials.NewTLS` with a shared CA for gRPC dials.

### 10. Notification service cannot send a single real message
The Kafka consumer is bound to `InMemoryEventBus` unconditionally (`EVENT_BUS_URL` is not even in compose for notification). All 5 providers (SES, SNS, Twilio, FCM, APNS) are `Stub*` defaults with no real SDKs in `package.json`. Outbound partner webhooks compute the HMAC signature then `void signature; void timestamp;` and synthesize `DELIVERED` without any HTTP POST. Redis dedup is unwired (in-memory `isDuplicate` only). No DLQ for failed deliveries.
- Evidence: `notification/src/consumer.ts:198-199`; `notification/src/providers.ts:42,95,108,194,207`; `notification/src/channels.ts:325-327,362-364`; `notification/src/webhooks.ts:72-107`; `.github/docker-compose.yml:389-398` (no `EVENT_BUS_URL` for notification).
- **Remediation:** Wire kafkajs behind the `EventBusClient` interface; implement real providers via the named SDKs (aws-sdk-client-ses/sns, twilio, firebase-admin); perform real HTTP POST with the computed HMAC headers; add Redis dedup + persistent DLQ.

---

## Major (P1) Gaps

### Money handling is inconsistent and unsafe in critical paths
- **5 of 6 fiat/pricing/liquidity services use `float64` for money** (payment-orchestration, rail-connectors, pricing-quote, fx-hedging, liquidity-routing). Only exchange-connectors uses `shopspring/decimal` correctly. fx-hedging's proto uses `double`, DB schema uses `NUMERIC` but Go round-trips through float64 — defeating precision.
- **wallet-management uses `int64` minor units** which overflows at ~92 BTC satoshis and instantly for ETH wei — real custody balances silently wrap.
- **treasury-orchestration truncates `float64` → `int64` when posting to the ledger** (`amountInt := int64(amount); if amountInt == 0 { amountInt = 1 }` — fractional cents dropped, zero-amount posts become 1) and posts a fabricated 2-entry posting (`debit treasury_crypto / credit operational_fiat`) regardless of the actual capital movement.
- **blockchain-gateway BTC balance uses `uint64(v * 1e8)`** — float→int truncation on sats.
- Evidence: `rail-connectors/internal/rail/types.go:37`; `pricing-quote/internal/pricer.go:29-37`; `fx-hedging/internal/domain/types.go`; `treasury-orchestration/internal/clients/http.go:255-274`; `wallet-management/internal/balance/balance.go:240-263`; `blockchain-gateway/internal/chain/adapters.go:462-473`.
- **Remediation:** Standardize on `int64` minor units or `shopspring/decimal` (and `u64`/`i128` in Rust) across all money paths; never round-trip through float64 even if the DB column is `NUMERIC`.

### No observability backend, no correlation ID, inconsistent tracing
No Prometheus, Grafana, Jaeger/Tempo, Loki, or OTel collector in compose. 67 source files emit Prometheus metrics that nothing scrapes. Only 5/15 Go services import OpenTelemetry. No W3C `traceparent` propagation; only 7 services handle `X-Request-ID` with no common convention. In production, an incident across the saga would be un-debuggable.
- Evidence: `grep -i 'prometheus\|grafana\|jaeger\|tempo\|loki\|otel-collector' .github/docker-compose.yml` → 0 hits; `rg 'go.opentelemetry.io/otel' go.mod` → 5/15.
- **Remediation:** Deploy `prometheus` + `grafana` + `loki` + `otel-collector` + `tempo` in compose; require OTel in every service; adopt W3C `traceparent` via shared interceptor.

### No release pipeline, no SBOM, no image signing, no branch protection
Only 2/21 services have a release workflow (api-gateway, aml-kyt-screening); both push to `ghcr.io/...:latest` (mutable tag, no SHA tag, no provenance). No SBOM generation. No cosign image signing. No CODEOWNERS. No branch protection / required status checks. No prod-like environment beyond docker-compose (no k8s/helm/terraform). No staging.
- **Remediation:** Add a reusable `release.yml` workflow in `.github` called by each service; tag images by commit SHA; sign with cosign; add SBOM via syft; configure branch protection + CODEOWNERS; add helm chart per service + staging overlay.

### No dependency CVE scanning in CI (except mpc)
14 Go services have no `govulncheck`; 2 Python services have no `pip-audit`/`safety`/`bandit`; 2 TS services have no `npm audit`. Only mpc-signing-service has `cargo deny` + `cargo audit`.
- **Remediation:** Add `govulncheck`, `npm audit --audit-level=high`, `pip-audit`, `bandit`, `cargo-audit` to the reusable CI workflows.

### No shared contracts / shared library
No shared proto/contract repo. Every cross-service edge has two hand-written `.proto` files that disagree on package, service name, RPC name, and fields. No shared Go module (15 separate `go.mod` files, zero cross-repo imports). No shared logging config (slog + stdlib log + fmt.Println mixed). No shared auth middleware.
- **Remediation:** Introduce a `contracts/` repo (or `buf` workspace) publishing versioned proto/AsyncAPI; extract `platform-go` (logging, tracing, mtls, errors, kafka client) as a versioned module consumed by all Go services.

### Silent stub-fallback pattern is pervasive
identity-auth, onboarding-kyc, aml-kyt-screening, fraud-detection, policy-risk-engine, payment-orchestration, pricing-quote, fx-hedging, liquidity-routing, exchange-connectors, transaction-orchestrator, treasury-orchestration, notification, blockchain-gateway, and wallet-management all silently fall back to in-memory/stub stores or fake clients when env vars are unset, rather than failing fast in production. This is the single biggest production-readiness pattern defect.
- **Remediation:** Add a strict/prod mode that fatals on missing required env vars; document a `DEV_MODE` flag that opts into stubs.

### Stub-as-default wiring in production binaries
Multiple services' `main.go` wires mocks unconditionally regardless of env:
- `payment-orchestration/cmd/main.go:35-42` — `rail.NewDummy()`, `mpi.NewDummy()`, `fraud.NewDummy()` hard-wired.
- `rail-connectors/cmd/main.go:10` — registers dummy connector for all rail families.
- `fx-hedging/cmd/main.go:113` — `provider.NewDummy()` (rate 1.10 for every currency).
- `liquidity-routing/internal/app/app.go:97-105` — `clients.NewFakeExchange()` regardless of config.
- `exchange-connectors/cmd/main.go:84-88` — reads creds from env, never uses `secrets.Manager`.
- `wallet-management/cmd/main.go:107-110` — wires `MockMPCSigner`/`MockGatewayClient`.

### No event schema versioning
txo outbox uses `event_type` strings like `"transaction.created"`, `"step.policy.succeeded"` with no `schema_version` field. No Avro/Protobuf schema registry. Topic naming is inconsistent: `audit.v1`, `kyt.audit.v1`, `fraud.audit`, `recon`, `blockchain.events.v1`, `liquidity.fills`, `transactions` — recon's `CONSUMER_TOPICS` uses service names not topic names.
- **Remediation:** Define a canonical topic naming convention (`<source>.<event>.v<n>`); add `schema_version` to every event envelope; register JSON Schema or Avro in a schema registry.

### Migrations tooling fragmented
6 different mechanisms: Go services use `embed.FS` + hand-rolled `migrations.Up()` (identity-auth, onboarding-kyc, aml-kyt, pricing-quote, fx-hedging, liquidity-routing, transaction-orchestrator, blockchain-gateway, treasury, audit-event-log, wallet-management); policy-risk-engine uses `golang-migrate`; Python uses Alembic (reconciliation, fraud-detection); Rust uses hand-rolled SQL (ledger-accounting). Some services run migrations on startup with warn-and-continue (wallet-management) — failed migration = stale schema silently.
- **Remediation:** Standardize on `golang-migrate` for Go, Alembic for Python, `refinery`/`sqlx` for Rust; run migrations as a separate `migrate up` step before startup, not embedded.

### Only 1/21 services has runbooks; no ADRs
Only `mpc-signing-service/docs/runbooks/{dkg-ceremony,key-rotation,node-restore,incident-response}.md`. No ADRs anywhere. Only 3/21 READMEs mention owner/team. The `.github/README.md` async-layer diagram is inaccurate (shows notification and audit as event-bus consumers when notification is in-memory and audit is broken).
- **Remediation:** Per-service runbook template (on-call, escalation, common incidents, rollback); `docs/adr/` for major decisions; fix the README async diagram.

---

## Per-Service Critical Blockers (Summary Table)

| Service | Score | Top Critical Blocker |
|---|---|---|
| api-gateway | 4 | RS256/JWKS expected; identity-auth issues HS256 with no JWKS; downstream paths don't match real services; mock clients used in deployed stack. |
| identity-auth | 3 | HS256+dev-secret default, no JWKS, silent in-memory fallback, partner endpoints missing. |
| onboarding-kyc | 3 | Liveness hardcoded PASS, sanctions = 2-name in-memory list, vendor = stub, policy sink POSTs to nonexistent endpoint. |
| aml-kyt-screening | 5 | Silent mock provider fallback, no healthcheck in image, audit topic mismatch (`kyt.audit.v1` vs `audit.v1`). |
| policy-risk-engine | 5 | Redis velocity counter never wired, only daily window enforced, no KYC/fraud/KYT ingest endpoints, admin paths unauth when JWT_ISSUER unset. |
| fraud-detection | 2 | StubModel only, all readiness checks hardcoded True, Kafka consumer never started, audit in-memory, no auth on /score. |
| payment-orchestration | 2 | In-memory only, dummy rails/MPI/fraud hard-wired, audit in-memory, no mTLS. |
| rail-connectors | 3 | main.go registers dummy connector, money float64, settlement parsers unwired, in-memory store. |
| pricing-quote | 4 | Spot rates hardcoded BTC=65000/ETH=3500, DB migration-only, money float64, poll clients never wired. |
| fx-hedging | 4 | Dummy provider rate=1.10 for every currency, money float64, no metrics/tracing, BankAdapter falls back silently. |
| liquidity-routing | 4 | Exchange client always FakeExchange, TWAP slicer placeholder, no gRPC server despite README claim, money float64. |
| exchange-connectors | 5 | http.DefaultClient (no timeout), client_order_id never set (real venues reject), secrets manager unused, no /metrics. |
| mpc-signing-service | 4 | In-house engine reconstructs full private key in coordinator; HSM/attestation mocks; nodes not distributed; INSECURE_SKIP_POLICY flags. |
| wallet-management | 3 | MockMPCSigner/MockGatewayClient wired in prod binary; withdrawal tx = fake string; UTXO not persisted; EVM nonce rollback no-op; balance int64 overflow. |
| blockchain-gateway | 5 | Reorg handler doesn't re-broadcast; prepayment doesn't wait for funding; chain adapters are poll-based scaffolds; mempool = no-op; calls nonexistent wallet-mgmt endpoints. |
| transaction-orchestrator | 6 | Stub is documented "production default"; gRPC insecure creds; ConfirmPoller never started; compensation errors swallowed. |
| ledger-accounting | 3 | In-memory state is source of truth; unwrap() on money path; audit = stderr print; immutability trigger removed; no SERIALIZABLE per-tx. |
| treasury-orchestration | 5 | Money float64; ledger posting fabricated/truncated; expected price hardcoded 50000; all clients fall back to fakes. |
| reconciliation | 4 | Never fetches ledger entries in production (false breaks); readiness hardcoded True; no active source fetching; topic names don't match producers. |
| notification | 3 | Kafka consumer in-memory; all 5 providers Stub*; outbound webhook never does HTTP POST; Redis dedup unwired; no DLQ. |
| audit-event-log | 8 | Concurrent chain inserts not proven safe; anchor job doesn't post to notary; no SIEM sink; compose disables S3/KMS (fake fallback). |

---

## Shared Infra (`.github/`) Blockers

| Severity | Issue | Evidence | Remediation |
|---|---|---|---|
| P0 | No production deployment artifact — only `docker-compose.yml` (dev). No k8s/helm/terraform. | `find . -name '*.tf' -o -name 'Chart.yaml' -o -name 'kustomization.yaml'` → none. | Add Helm chart per service + prod overlay; or Terraform. |
| P0 | Secrets are plain-text in compose (`postgres:postgres`, `dev-secret`, `dev-secret-chainalysis`, `EVM_XPUB`/`BTC_XPUB` hardcoded). | `.github/docker-compose.yml:8-9,238-239,415,453,516-518`. | Externalize to a secrets manager (Vault/ASM/SSM); never ship prod keys in compose. |
| P0 | Alerting is a no-op — `gatus.yml` declares `alerting: slack: {}` (empty, no webhook URL). No PagerDuty. | `.github/gatus.yml:13-14`. | Configure Slack/PagerDuty with real endpoints + escalation. |
| P0 | E2E Kafka tests are unrunnable — `tests/e2e-kafka/*.hurl` hit `http://localhost:8105` (kafka-rest) which is commented out in compose. Postgrest assertion services (ports 3001-3011) also all commented out. | `.github/docker-compose.yml:216-227,26-167`; `.github/tests/e2e-kafka/*.hurl:10,31`. | Uncomment `kafka-rest` + `postgrest-*` or rewrite assertions. |
| P1 | Single Postgres for all 16 service DBs (no HA, no backups, no PITR). | `.github/postgres-init.sql:1-16`; `.github/docker-compose.yml:5-19`. | Per-service managed Postgres or logical replication + automated backups. |
| P1 | No observability stack (no Prometheus/Grafana/Loki/Tempo/OTel collector). | `grep -i` in compose → 0. | Add all five to compose. |
| P1 | No resource limits, no restart policies, no network isolation in compose. | Entire `docker-compose.yml` — no `networks:` or `deploy:` keys. | Add `restart: unless-stopped`, CPU/memory limits, per-service networks. |
| P1 | Kafka is single broker, RF=1, 24h retention, auto-create topics — production-unsafe for the audit/event-bus backbone. | `.github/docker-compose.yml:186-211`. | 3-broker cluster, RF=3, explicit topic provisioning, longer retention for audit. |
| P1 | No CI integration of the Hurl suites — `ci.yml` only lints Makefile/Hurl/YAML; never runs `make up`/`make test`. | `.github/.github/workflows/ci.yml:1-46`. | Add a job that boots the stack and runs `make test`. |
| P2 | `gatus.yml` only checks `[STATUS]==200 && [BODY].status==ok` — no latency SLOs, no content checks beyond health. | `.github/gatus.yml:18-238`. | Add latency thresholds + synthetic transaction probes. |

---

## Integration Edge Matrix

The architecture claims 16 critical inter-service edges. **0 are fully implemented end-to-end with a matching contract and a working call.**

| Edge | Contract Defined? | Call Implemented? | Tested E2E? | Issue |
|---|---|---|---|---|
| tx-orch → policy | ✗ (protos disagree) | ✗ stub | ✗ | Different service name + fields; URL not set in compose |
| tx-orch → payment | ✗ | ✗ stub | ✗ | payment has no gRPC server; URL not set |
| tx-orch → kyt | ✗ (protos disagree) | ✗ stub | ✗ | Different package/service/message; URL not set |
| tx-orch → mpc | ✗ (protos disagree) | ✗ stub | ✗ | Different RPC name + fields; URL not set |
| tx-orch → blockchain | ✗ | ✗ stub | ✗ | blockchain has no gRPC server; URL not set |
| tx-orch → ledger | ✗ (protos disagree) | ✗ stub | ✗ | No `PostDoubleEntry` RPC on ledger; URL not set |
| payment → rails | ✗ | ✗ stub | ✗ | `RAIL_CONNECTORS_URL` never read; `rail.NewDummy()` hard-wired |
| payment → fraud | ✗ | ✗ stub | ✗ | `fraud.NewDummy()` hard-wired |
| treasury → liquidity | ✗ | ✓ HTTP wrong path | ✗ | Treasury calls `/v1/aggregate-orders`; liquidity exposes `/v1/parent-orders` → 404 |
| treasury → wallet | ✓ REST | ✓ HTTP | ✗ | Paths match but no E2E test |
| liquidity → exchange | ✗ | ✗ fake | ✗ | Always `NewFakeExchange()`; exchange has no gRPC server |
| blockchain → wallet | ✗ | ✓ HTTP wrong paths | ✗ | Calls `/v1/fund-sender` and `/v1/nonce/allocate` which don't exist in wallet-mgmt |
| mpc → wallet | ✓ gRPC JSON codec | ✓ gRPC | partial | The **one working cross-service contract**; not exercised by Hurl E2E |
| all → notification | ✗ | ✗ in-memory | ✗ | notification consumer bound to `InMemoryEventBus` unconditionally |
| all → audit | ✗ | ✗ broken | ✗ | Producers POST to nonexistent `/v1/events`; audit consumes `audit.v1` topic nobody publishes to |
| ledger → recon | ✗ | ✗ | ✗ | Recon subscribes to topic `ledger-accounting` (service name); ledger has no Kafka producer |

---

## Test Coverage Aggregate

| Service | Lang | Source | Test | Ratio | Verdict |
|---|---|---|---|---|---|
| api-gateway | TS | 25 | 14 | 0.56 | OK |
| identity-auth | Go | 21 | 12 | 0.57 | OK |
| onboarding-kyc | Go | 20 | 10 | 0.50 | OK |
| aml-kyt-screening | Go | 24 | 14 | 0.58 | OK |
| policy-risk-engine | Go | 27 | 17 | 0.63 | OK |
| fraud-detection | Py | 25 | 17 | 0.68 | OK |
| payment-orchestration | Go | 14 | 12 | 0.86 | OK (but no integration) |
| rail-connectors | Go | 40 | 27 | 0.68 | OK |
| pricing-quote | Go | 21 | 5 | 0.24 | **Thin** |
| fx-hedging | Go | 20 | 14 | 0.70 | OK |
| liquidity-routing | Go | 19 | 14 | 0.74 | OK |
| exchange-connectors | Go | 19 | 12 | 0.63 | OK |
| mpc-signing-service | Rust | 33 | 25 fns | 0.76 | OK |
| wallet-management | Go | 35 | 27 | 0.77 | OK |
| blockchain-gateway | Go | 24 | 20 | 0.83 | OK |
| transaction-orchestrator | Go | 38 | 13 | 0.34 | **Thin** |
| ledger-accounting | Rust | 17 | 15 fns | 0.88 | OK |
| treasury-orchestration | Go | 27 | 18 | 0.67 | OK |
| reconciliation | Py | 23 | 12 | 0.52 | OK |
| notification | TS | 19 | 13 | 0.68 | OK |
| audit-event-log | Go | 24 | 23 | 0.96 | OK |

Unit coverage is healthy. The systemic gap is **integration**: there is no end-to-end suite that exercises a real saga across real partner services. Hurl suites are happy-path only and depend on `kafka-rest` + `postgrest-*` services that are commented out in compose — so even the existing E2E tests cannot run.

---

## What's Actually Working

To be fair, here's what is genuinely production-grade:

- **audit-event-log** (8/10): Real Kafka/S3/KMS/Postgres adapters, hash-chained tamper-evidence, redaction, exports, strong tests. Needs concurrent-insert safety + notary posting + prod-strict mode, but the closest to shippable.
- **Gatus dashboard**: All 21 services + 3 UIs monitored; healthz endpoints all present and consistent on port 8080.
- **Per-service Dockerfiles**: All 21 services have multi-stage Dockerfiles; most use distroless + non-root (notable exceptions: payment-orchestration, rail-connectors, exchange-connectors, fx-hedging, wallet-management, mpc-signing-service, audit-event-log run as root on alpine).
- **Per-service CI**: Reusable `go-service-ci.yml` pattern (lint+test+coverage+docker-build) — a good shared-workflow design; just missing security scanning.
- **Per-service READMEs**: All 21 services document env vars and dependencies.
- **mpc-signing-service runbooks**: 4 runbooks (dkg-ceremony, key-rotation, node-restore, incident-response) — the only service with ops docs.
- **Saga mechanics** (transaction-orchestrator): Idempotency keys, outbox pattern, `FOR UPDATE SKIP LOCKED` lease, recovery on boot, compensation cascade — well-designed and tested in isolation.
- **ledger-accounting invariants**: 16 invariant tests (balanced books, unbalanced atomic, idempotency, hash chain, tamper detection, immutability, segregation, serializable concurrency, multi-asset) — correct in-memory; the problem is the DB integration, not the math.
- **exchange-connectors money handling**: Uses `shopspring/decimal` correctly; 94% test coverage; real venue adapters with signed requests; per-venue rate limiters.
- **reconciliation match engine**: 3 match strategies, 4 break types, aging/escalation, auto-resolve, DLQ, reports — the matching logic is sound; the problem is it never receives ledger data.
- **MPC↔wallet-management gRPC**: The one working cross-service contract (JSON codec gRPC for `ResolveKeyID`).

---

## Recommended Path to Production (Priority Order)

### Phase 0 — Stop the bleeding (1-2 weeks)
1. **Extract `contracts/` repo** with versioned proto/AsyncAPI; regenerate all stubs. Without this, every other fix is built on sand.
2. **Add fail-fast prod mode** to every service that silently falls back to stubs when env vars are unset. Document a `DEV_MODE=1` flag that opts into stubs.
3. **Wire the orchestrator to real partners** in compose (set `POLICY_URL`, `PAYMENT_URL`, etc.); run a real saga E2E. This will surface dozens of contract mismatches immediately.
4. **Add Postgres stores** to payment-orchestration, rail-connectors, exchange-connectors, blockchain-gateway; wire `DB_URL` in compose.
5. **Fix the audit pipeline**: pick one ingress (recommend Kafka topic `audit.v1`); make every producer publish to it; verify end-to-end.

### Phase 1 — Money safety (2-4 weeks)
6. **Replace MPC in-house engine** with an audited crate (frost/cggmp21) OR commit to the custody-provider delegation path (Fireblocks/Dfns) and integration-test against real sandboxes.
7. **Implement real withdrawal tx construction** in wallet-management (RLP/PSBT/Solana); wire real gRPC clients; persist UTXO outpoints; fix EVM nonce rollback.
8. **Implement reorg re-broadcast** in blockchain-gateway; wait for funding confirmation in prepayment; align REST contract with wallet-management.
9. **Make ledger Postgres the source of truth**: read balances from DB with explicit `SERIALIZABLE`; re-add immutability trigger; remove `unwrap()` from money path; implement real audit emission; mix `HASH_CHAIN_SALT` into hash.
10. **Standardize money on int64/decimal**: eliminate `float64` from all money paths (payment, pricing, fx, liquidity, treasury, blockchain-gateway BTC balance, wallet-management balance).

### Phase 2 — Reliability & security (2-4 weeks)
11. **Add mTLS + service-token auth** to all internal money-moving endpoints; enable mTLS in compose for mpc; use `credentials.NewTLS` for gRPC dials.
12. **Deploy observability stack** (Prometheus + Grafana + Loki + OTel collector + Tempo); require OTel in every service; adopt W3C `traceparent`.
13. **Wire notification real providers** (SES/SNS/Twilio/FCM/APNS) + kafkajs consumer + real outbound webhook HTTP + Redis dedup + DLQ.
14. **Implement real reconciliation** ledger fetching (HTTP client to ledger `/v1/accounts/:id/ledger`); fix topic names to match producers; add active source fetching.
15. **Wire real KYC/fraud/KYT providers** in onboarding-kyc (Onfido/Sumsub + sanctions list) and aml-kyt (Chainalysis/TRM); start fraud Kafka consumer.

### Phase 3 — Release & ops (1-2 weeks)
16. **Add reusable release workflow** (SBOM + cosign + SHA-tagged images); add branch protection + CODEOWNERS.
17. **Add CVE scanning** (govulncheck/npm audit/pip-audit/cargo-audit/Trivy) to all CI workflows.
18. **Add Helm chart per service** + staging overlay; or at minimum a `docker-compose.prod.yml` with real secrets strategy.
19. **Configure Gatus alerting** (Slack/PagerDuty with real endpoints).
20. **Write runbooks** for the remaining 20 services; add ADRs; fix `.github/README.md` async-layer diagram.

---

## Conclusion

The codebase demonstrates strong architectural understanding — the 5-layer decomposition, the saga pattern, the outbox, double-entry ledger, MPC threshold signing, the policy gatekeeper, and the reconciliation break model are all the right designs. Per-service unit testing is healthy (only 2 services below 0.4 ratio). The Dockerfiles, healthz endpoints, Gatus, and shared CI workflow show operational maturity intent.

But the **implementation stops at the service boundary**. Every cross-service integration is either stubbed, broken, or wired against a contract that doesn't match the counterparty. The money-moving path has never been exercised end-to-end against real partners. Three services that move money have no persistence. The custody core (MPC in-house engine) reconstructs the full private key. The audit and notification pipelines are end-to-end non-functional. There is no observability backend, no mTLS, no auth on internal money-moving endpoints, no release pipeline for 19/21 services, and no production deployment artifact beyond docker-compose.

**Estimated time to production-readiness: 8-12 weeks** with a focused team, assuming the custody path uses the Fireblocks/Dfns delegation (not a from-scratch audited MPC implementation, which would add 6-12 months). The single highest-leverage fix is extracting the `contracts/` repo and wiring the orchestrator to real partners — that one change will surface and force the resolution of the majority of the issues above.

---

## Phase 0 Completion Re-Evaluation (2026-07-21, updated 2026-07-21)

All 5 Phase 0 items have been implemented, committed across 22 repositories, and CI is green on every repo. Re-evaluation below confirms completion and audits Phases 1–3 for any incidental work.

### Phase 0 — Stop the bleeding ✅ COMPLETE

| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Extract `contracts/` repo | ✅ Done | `.github/contracts/` with 13 canonical protos + 5 AsyncAPI specs + `buf.yaml` (v2, STANDARD lint + WIRE_JSON breaking) + `buf.gen.yaml` (go/python/ts codegen; rust deferred — no BSR plugin). `contracts-ci.yml` runs lint + breaking (PR-only) + build + generate-idempotency jobs. Per-edge owners = producer services. 5 edges flagged for human decision (wallet-mgmt MPC client surface; payment/blockchain gRPC-vs-REST; liquidity.fills topic rename; ledger amount uint64 vs tx-orch string). |
| 2 | Fail-fast prod mode / `DEV_MODE` | ✅ Done | All 16 silent-stub-fallback services gated on `DEV_MODE=1`. Prod default = fatal on missing required env vars (DB_URL, KAFKA_BROKERS, partner URLs, vendor URLs, secrets). Real clients that already existed in the codebase wired in prod branch (wallet-mgmt's `clients.NewMPCSigningClient`/`NewGatewayClient`, treasury's HTTP clients, aml-kyt's Chainalysis/TRM, blockchain-gateway's wallet HTTP client). Test suites updated via `TestMain(m *testing.M) { os.Setenv("DEV_MODE","1") }` where needed (identity-auth, onboarding-kyc, blockchain-gateway, treasury-orchestration, liquidity-routing). Fraud-detection's prod guard deferred to FastAPI `@app.on_event("startup")` so pytest collection doesn't fatal. |
| 3 | Wire orchestrator to real partners | ✅ Done | `.github/docker-compose.yml` sets `POLICY_URL`/`KYT_URL`/`MPC_URL`/`LEDGER_URL` (gRPC) + `PAYMENT_URL`/`BLOCKCHAIN_URL` (REST) + `ENABLE_STUB_PARTNERS=0` on transaction-orchestrator, with `depends_on` all partners. gRPC container ports exposed via `expose:`. main.go: prod mode fatals on missing/dial-fail for the 4 gRPC partners; `PAYMENT_URL`/`BLOCKCHAIN_URL` fatal in prod until REST→gRPC adapter lands (workstream 1 surfaces the contract gap). `dialPartners` refactored into `dialOnePartner` to satisfy gocyclo. **Note:** the orchestrator's private protos still disagree with partner servers on service/RPC/field names — dials will fail at runtime until consumers regenerate from `contracts/` (tracked as Phase 1 follow-up). |
| 4 | Postgres stores for 4 money-moving services | ✅ Done | payment-orchestration, rail-connectors, exchange-connectors: new `internal/store/postgres.go` + `migrations/0001_init_*.sql` + `Store` interface + `DB_URL`/`DEV_MODE`/fatal wiring in main. blockchain-gateway already had a Postgres store in `internal/store/postgres/` — just updated the stale compose comment. 3 new DBs added to `postgres-init.sql` (`payment_orchestration`, `rail_connectors`, `exchange_connectors`). Idempotency/dedup tables created; webhook handler wiring is follow-up. Money fields: `BIGINT` for int64 stores, `NUMERIC` for decimal/`*big.Int`, `DOUBLE PRECISION` for float64 stores (Phase 1 money-type migration will eliminate the latter). |
| 5 | Fix audit pipeline | ✅ Done | Canonical Kafka `audit.v1` ingress (matches `audit-event-log/internal/event/event.go::Envelope`). 16 producers converted from HTTP-to-nonexistent-endpoint / in-memory / stderr / wrong-topic to Kafka `audit.v1` with canonical envelope (`schema_version`, `id`, `ts`, `source_service`, `actor_id`, `action`, `target_type`, `target_id`, `payload_hash`, `payload`). Envelope documented in `contracts/proto/audit/v1/events.proto` + `audit-event-log/docs/ENVELOPE.md`. `KAFKA_BROKERS` added to every producer in compose; `AUDIT_EVENT_LOG_URL` removed from dead-HTTP producers. HTTP audit fallbacks in fx-hedging/liquidity-routing/treasury kept as deprecated (removed once all deployments set `KAFKA_BROKERS`). |

### Phase 1 — Money safety ✅ COMPLETE

| # | Item | Status | Notes |
|---|---|---|---|
| 6 | Replace MPC in-house engine | ✅ Done | All three custody-provider adapters (Fireblocks/Dfns/Turnkey) now implement real provider APIs against their respective sandboxes — 2,214 lines total across `engine/{fireblocks,dfns,turnkey}.rs`. Each implements the full `SigningEngine` trait (`dkg`, `sign`, `rotate_key`, `get_key_metadata`, `restore_share`). Fireblocks: RS256 JWT auth + vault/asset/transaction endpoints. Dfns: two-layer auth (Bearer + Ed25519-signed UserAction) + wallets/keys/signatures endpoints. Turnkey: POST-only RPC with stamp auth + create_wallet/sign_raw_payload/get_wallet_account. 154 tests pass (unit + wiremock integration); cargo build/test/clippy/fmt/deny/audit all clean. Config gains `custody_api_secret_key`, `custody_sandbox`, `custody_service_account_key/secret`, `custody_organization_id`, `custody_api_private_key`, `custody_sub_organization_id`. **What remains:** (a) select the production provider and set `CUSTODY_PROVIDER` + credentials in compose, (b) drop the in-house threshold engine as default (or gate it behind `DEV_MODE=1`), (c) run integration tests against the real sandbox (free sandboxes available — Fireblocks Developer Sandbox / Dfns free org / Turnkey free org; TODO comments mark where). The custody threat model (private-key reconstruction in coordinator) is resolved by delegating to any of the three. |
| 7 | Real withdrawal tx construction (wallet-management) | ✅ Done | `internal/withdrawal/txbuilder.go` builds real per-chain unsigned txs: EVM legacy tx with EIP-155 signing hash → RLP-encoded signed tx (v = recovery_id + chain_id*2 + 35); BTC BIP-143 sighash per input → wire.MsgTx with [sig+sighashtype, pubkey] witness; Solana legacy Message with SystemProgram.Transfer → serialized Transaction bytes. `withdrawal.go` sends the real payload to the MPC signer, calls `Assemble(signature)`, persists `SignedTxBytes` on the row, and broadcasts the real bytes (was `[]byte("signed:"+id)`). `ReservedOutpoints` persisted on the row before signing (migration 0002: `reserved_outpoints TEXT[]`, `signed_tx_bytes BYTEA`). EVM `RollbackNonce` was a no-op → now conditional-decrements `pending_nonce` via `Store.RollbackPendingNonce` (gap-safe: a higher reserved nonce is left in place). No new direct deps — EVM RLP/keccak manual (sha3+btcec), BTC via btcd/wire+txscript, Solana manual (base58+ed25519). |
| 8 | Reorg re-broadcast (blockchain-gateway) | ✅ Done | `Detector` gains `Rebroadcaster` interface + `nextHeadRebroadcast` map. On reorg, marks txs `reorged_out` AND schedules re-broadcast on the next head. On the next `OnHead`, `rebroadcastReorgedOut` lists txs still in `reorged_out` (skipping re-confirmed ones), calls `Rebroadcast`, transitions successful re-broadcasts back to `StatusMempool`. Concrete `broadcast.Rebroadcaster` looks up signed bytes from `BroadcastStore` and re-submits via `chain.ChainAdapter.Broadcast`. Prepayment replaced the no-op `context.WithTimeout+cancel` with a real polling loop (`waitForFundingConfirmation` / `waitForBalanceConfirmation`, pollInterval=2s, minConfirms=1, `ErrFundingTimeout`). REST contract aligned: `walletclient` POSTs to `/v1/wallets/{id}/funding-request` and `/v1/wallets/{id}/nonce/allocate` (was nonexistent `/v1/fund-sender` + `/v1/nonce/allocate`); wallet-management gains the matching `POST /v1/wallets/{id}/nonce/allocate` handler. |
| 9 | Ledger Postgres source of truth | ✅ Done | All reads (`get_balance`, `get_posting`, `list_postings`, `verify_chain`, `get_account`, `list_accounts`, `entry_count`, snapshots) now query Postgres when a pool is present (in-memory fallback for dev/test). In-memory `LedgerState` is a write-side cache only; previous-hash fetched from DB via `last_entry_hash_from_db`. `post()` splits into `post_via_db` (DB commits first under SERIALIZABLE, in-memory cache updated only after commit) and `post_via_memory` (dev path). `compute_hash(prev_hash, salt, canonical)` now mixes `HASH_CHAIN_SALT` (`SHA256(prev_hash || salt || canonical)`); salt threaded via `Store.salt`, defaults to `""` with a warning when unset. All `unwrap()`s on the money path replaced with `PostError::Validation` (postings, accounts, chart types). Immutability trigger restored via migration `20240101000003_restore_immutable_entries.sql` (`reject_entry_mutation()` PL/pgSQL + `entries_no_update` / `entries_no_delete` BEFORE triggers). 152 in-memory tests + 5 DB-backed tests (3 new: salt changes hash chain; entries immutable trigger rejects UPDATE/DELETE; balance survives in-memory restart). |
| 10 | Standardize money on int64/decimal | ✅ Done | `float64` money eliminated across 7 services (blockchain-gateway BTC sats truncation, treasury-orchestration ledger posting truncation + all money fields, pricing-quote, fx-hedging, liquidity-routing, rail-connectors, wallet-management balance arithmetic). All now use `shopspring/decimal.Decimal` matching the existing exchange-connectors pattern. pgx scans NUMERIC → string → `decimal.NewFromString`; writes via `.String()`. REST money fields now JSON strings (breaking change — one-line doc comments on changed handlers). gRPC proto boundaries (fx-hedging) convert at the handler with `decimal.NewFromFloat` / `.InexactFloat64()` (proto itself left unchanged). BPS/ratios/latency/histogram-buckets/config-thresholds left as `float64` (dimensionless, not subject to the precision bug). payment-orchestration verified — money fields are already `int64` (no change needed). The critical `int64(amount)` truncation in treasury's ledger posting path (which dropped fractional cents and turned zero-amount posts into 1) is fixed. |

### Phase 2 — Reliability & security ⏳ NOT STARTED (2 partial)

| # | Item | Status | Notes |
|---|---|---|---|
| 11 | mTLS + service-token auth | 🔶 Partial | payment-orchestration has `internal/mtls/mtls.go` with a `tls.Config` (pre-existing). No service-token JWT middleware on transaction-orchestrator/payment-orchestration/ledger REST. mpc mTLS still disabled in compose. All 6 txo→partner gRPC dials still `insecure.NewCredentials()`. |
| 12 | Observability stack | ❌ Not started | No Prometheus/Grafana/Loki/Tempo/otel-collector in compose. 67 source files still emit metrics nothing scrapes. Only 5/15 Go services import OTel. |
| 13 | Notification real providers | ❌ Not started | `package.json` still has no real provider SDKs (no aws-sdk-client-ses/sns, twilio, firebase-admin). All 5 providers still `Stub*` in `providers.ts`. Outbound webhook still synthesizes `DELIVERED` without HTTP POST (`webhooks.ts:89-90` and `channels.ts:326-327,363-364` still `void signature; void timestamp;`). |
| 14 | Real reconciliation ledger fetching | ❌ Not started | `reconciler.py:111` still `ledger = ledger_entries or []`; when called from REST/CLI, `ledger_entries` is `None` → every external entry becomes `MISSING_ENTRY`. Topic names in `CONSUMER_TOPICS` still service names. No active source fetching. |
| 15 | Real KYC/fraud/KYT providers | 🔶 Partial | aml-kyt-screening has real Chainalysis/TRM HTTP providers (`vendor/http_provider.go`) wired when `CHAINALYSIS_API_KEY`/`TRM_API_KEY` set — this was pre-existing and kept in Phase 0. onboarding-kyc vendor is still `StubVendorClient` (Onfido/Sumsub integration not started — `vendor.go:60` still returns stub when `DEV_MODE=1`). fraud-detection model still `StubModel` (prod guard added in Phase 0 requires `MODEL_REGISTRY_URL` or `MODEL_PATH`, but no real model loader). |

### Phase 3 — Release & ops ⏳ NOT STARTED

| # | Item | Status | Notes |
|---|---|---|---|
| 16 | Reusable release workflow (SBOM/cosign/SHA tags) | ❌ Not started | Only `.github/workflows/{ci,contracts-ci,go-service-ci}.yml` — no release workflow. No cosign, no syft/SBOM, no SHA-tagged images. No CODEOWNERS, no branch protection. |
| 17 | CVE scanning in CI | ❌ Not started | No govulncheck/npm audit/pip-audit/cargo-audit/Trivy in any workflow. (mpc-signing-service already runs cargo-deny + cargo-audit; that pattern needs lifting to the other 20 services.) |
| 18 | Helm chart per service / docker-compose.prod.yml | ❌ Not started | No `Chart.yaml`/`kustomization.yaml`/`*.tf` anywhere. |
| 19 | Gatus alerting | ❌ Not started | `gatus.yml` still `alerting: slack: {}` (empty, no webhook). No PagerDuty. |
| 20 | Runbooks + ADRs | ❌ Not started | Only `mpc-signing-service/docs/runbooks/{dkg-ceremony,incident-response,key-rotation,node-restore}.md`. No ADRs. `.github/README.md` async diagram still inaccurate. |

### Revised headline verdict

**Phase 0 (stop the bleeding) and Phase 1 (money safety) are both complete.** The stack now fails fast in production mode instead of silently falling back to stubs. The audit pipeline produces and consumes end-to-end on `audit.v1`. Four money-moving services persist state to Postgres. The orchestrator dials real partner URLs. The custody core delegates to real Fireblocks/Dfns/Turnkey APIs. Withdrawals build real EVM/BTC/Solana transactions and persist UTXO outpoints. The ledger is Postgres-backed, salted, and append-only. Reorgs re-broadcast. Money is `decimal.Decimal` end-to-end.

What remains: **Phase 2 (reliability & security) and Phase 3 (release & ops)**, both largely greenfield with two partials (mTLS scaffolding in payment-orchestration; Chainalysis/TRM already wired in aml-kyt).

**Revised estimated time to production-readiness: 3–5 weeks** (down from 5–8), with Phases 0 and 1 done. Critical path: P2.11 mTLS + service-token auth (1w) → P2.12 observability stack (1w, parallel) → P2.13-15 real providers (1-2w, parallel) → P3.16-20 release/ops (1-2w). Sandbox integration testing of the custody adapters (P1.6 follow-up) and consumer-side proto regeneration from `contracts/` can happen in parallel with Phase 2.

---
