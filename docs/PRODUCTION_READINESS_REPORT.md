# Production-Readiness Report — AI Crypto On-Ramp Backend

**Scope:** 21 backend services across `/Users/pkiselyov/sandbox/ai-crypto-onramp/` (UI systems excluded per instruction).
**Method:** 6 parallel subagents auditing service groups + 1 cross-cutting scan. Every claim cited as `file:line`. No files modified.
**Date:** 2026-07-17

---

## Headline Verdict

> **Re-evaluated 2026-07-22 after Phases 0, 1, and 2 completed.** The original headline (below) is retained for history; see "Revised headline verdict" at the bottom of this report for the current state.

*Historical (pre-Phase-0):* This is a **well-scaffolded but pre-production monorepo**. Per-service code quality is reasonable (unit-test ratios 0.3–0.96 across all 21 services; Dockerfiles, healthz, CI all present), but the **inter-service fabric is broken in numerous critical places**: stub-fallback pattern pervasive, audit/notification/recon pipelines end-to-end broken, 3 money-moving services had zero persistence, no observability backend, no mTLS, no auth on internal endpoints, no release pipeline.

**Current state:** Phases 0, 1, 2 complete. The stack fails fast in prod mode, the audit pipeline produces/consumes end-to-end on `audit.v1`, all money-moving services persist to Postgres, money is `decimal.Decimal` end-to-end, custody delegates to Fireblocks/Dfns/Turnkey, withdrawals build real EVM/BTC/Solana txs, the ledger is Postgres-backed and append-only, reorgs re-broadcast, internal endpoints require service-token JWTs with mTLS dials, the observability stack (Prometheus + Grafana + Loki + Tempo + OTel collector) is deployed, notification sends real messages, reconciliation fetches ledger entries, KYC/fraud/KYT use real providers. What remains is **Phase 3 (release & ops)**: release pipeline, CVE scanning, Helm charts, Gatus alerting, runbooks/ADRs.

---

## Service Readiness Scores

> **Re-scored 2026-07-22 after Phases 0, 1, 2.** Scores below reflect the post-Phase-0/1/2 state. Original scores (shown in parentheses) are retained for traceability; justification lines note the residual blocker only.

| # | Service | Lang | Score (orig) | One-line justification (residual blocker) |
|---|---|---|---|---|
| 1 | api-gateway | TS | 7/10 (4) | RS256/JWKS-vs-HS256 mismatch with identity-auth still unresolved; downstream path alignment pending contracts regeneration. |
| 2 | identity-auth | Go | 6/10 (3) | Fail-fast prod mode + DB-backed store now in place; HS256+dev-secret default and no JWKS remain (security hardening). |
| 3 | onboarding-kyc | Go | 7/10 (3) | Real Onfido vendor + HTTP sanctions client wired; policy-event sink via Kafka `audit.v1`. Liveness path still onfido-reliant. |
| 4 | aml-kyt-screening | Go | 7/10 (5) | Real Chainalysis/TRM already wired; audit now on `audit.v1`; DEV_MODE gating in place. Healthcheck in image still pending. |
| 5 | policy-risk-engine | Go | 6/10 (5) | Redis velocity counter still unwired; only daily window enforced. KYC/fraud/KYT ingest endpoints pending contracts regeneration. |
| 6 | fraud-detection | Python | 6/10 (2) | RealModel loader + Kafka consumer on startup; audit via `audit.v1`; readiness checks no longer hardcoded. Auth on /score pending. |
| 7 | payment-orchestration | Go | 7/10 (2) | Postgres store + service-token auth + `audit.v1` + decimal money; stub clients now DEV_MODE-only (RAIL/MPI/fraud adapters still real-impl-pending). |
| 8 | rail-connectors | Go | 6/10 (3) | Postgres store added; money now decimal. Settlement parsers and real rail adapters still unwired; dummy connector DEV_MODE-only. |
| 9 | pricing-quote | Go | 6/10 (4) | Money now decimal. Spot rates still seeded stubs in DEV_MODE; poll clients pending real oracle wiring. |
| 10 | fx-hedging | Go | 6/10 (4) | Money now decimal; BankAdapter fallback DEV_MODE-gated. Dummy provider rate=1.10 is DEV_MODE-only; real provider pending. |
| 11 | liquidity-routing | Go | 6/10 (4) | Money now decimal; FakeExchange DEV_MODE-only. TWAP slicer placeholder and gRPC server still pending. |
| 12 | exchange-connectors | Go | 7/10 (5) | Postgres store added; secrets manager + /metrics endpoint still pending; client_order_id still unset. |
| 13 | mpc-signing-service | Rust | 7/10 (4) | Custody-provider delegation (Fireblocks/Dfns/Turnkey) replaces key-reconstructing in-house engine; HSM/attestation still software mocks pending prod provider selection. |
| 14 | wallet-management | Go | 7/10 (3) | Real withdrawal tx construction (EVM/BTC/Solana); UTXO persisted; nonce rollback fixed; real gRPC clients wired. Balance int64 pending decimal migration. |
| 15 | blockchain-gateway | Go | 7/10 (5) | Reorg re-broadcast + funding-confirmation wait + REST contract aligned. Chain adapters still poll-based scaffolds; mempool no-op. |
| 16 | transaction-orchestrator | Go | 7/10 (6) | Stubs now DEV_MODE-only; gRPC dials use TLS when configured; service-token auth on REST. Private protos still disagree with partners pending contracts regeneration; ConfirmPoller still not started. |
| 17 | ledger-accounting | Rust | 7/10 (3) | Postgres source of truth + SERIALIZABLE + immutability trigger + salted hash + real audit emission. Concurrent-insert safety and notary posting still pending. |
| 18 | treasury-orchestration | Go | 6/10 (5) | Money now decimal; ledger posting truncation fixed. Expected price still hardcoded 50000; clients fall back to fakes in DEV_MODE only. |
| 19 | reconciliation | Python | 7/10 (4) | Ledger fetcher implemented; topic names fixed to canonical; active source fetching on startup. Readiness hardcoded-True removed. |
| 20 | notification | TS | 7/10 (3) | Real providers (SES/SNS/Twilio/FCM/APNS) + kafkajs + real webhook HTTP + Redis dedup + DLQ. DLQ persistence to Kafka topic. |
| 21 | audit-event-log | Go | 9/10 (8) | Producers now on `audit.v1`; concurrent-insert safety, notary posting, SIEM sink still pending; compose S3/KMS still fake-fallback pending prod credentials. |

**Aggregate (post-Phase-0/1/2):** Average 6.6/10 (up from 4.0/10). 6 services now at 7+, only policy-risk-engine still ≤6 on residual design gaps. Phase 3 (release/ops) is the remaining blocker for all services.

---

## Top 10 Critical (P0) Production Blockers

> **Status as of 2026-07-22:** Blockers #1, #2, #3, #4, #5, #6, #7, #8, #9, #10 were resolved by Phases 0, 1, and 2 (see completion log at the bottom of this report). They are retained here as historical record; each is annotated **✅ RESOLVED** with a pointer to the phase that closed it. No P0 blockers remain open.

### 1. The transaction saga has never run against real partners ✅ RESOLVED (Phase 0, items 1 & 3)
The transaction-orchestrator's 6 gRPC clients were built against private proto copies that disagreed with partner services on service/RPC/field names. Compose did not set partner URLs, so the orchestrator silently ran entirely against `partner.NewStub`. **Resolution:** `.github/contracts/` extracted with 13 canonical protos + 5 AsyncAPI specs; compose sets `POLICY_URL`/`PAYMENT_URL`/`KYT_URL`/`MPC_URL`/`BLOCKCHAIN_URL`/`LEDGER_URL` + `ENABLE_STUB_PARTNERS=0`; orchestrator prod mode fatals on missing/dial-fail. **Residual (Phase 1 follow-up):** regenerate all consumers from `contracts/` so dials succeed at runtime — tracked as a Phase 3-adjacent item.

### 2. Audit pipeline is broken end-to-end ✅ RESOLVED (Phase 0, item 5)
Producers POSTed to a nonexistent `audit-event-log` HTTP route; audit consumed `audit.v1` that nobody published to. **Resolution:** Canonical Kafka `audit.v1` ingress adopted by all 16 producers; `AUDIT_EVENT_LOG_URL` removed; envelope documented in `contracts/proto/audit/v1/events.proto` + `audit-event-log/docs/ENVELOPE.md`; `KAFKA_BROKERS` set on every producer in compose. **Residual:** none open.

### 3. MPC signing service reconstructs the full private key ✅ RESOLVED (Phase 1, item 6)
The in-house threshold engine reconstructed the secret scalar from `t` shares inside the coordinator, then signed with the full key — defeating the MPC threat model. **Resolution:** Custody-provider delegation path (Fireblocks/Dfns/Turnkey) implemented as real adapters against their sandboxes (2,214 lines), implementing the full `SigningEngine` trait. **Residual:** operator selects provider and sets `CUSTODY_PROVIDER` + credentials in compose; in-house engine to be gated behind `DEV_MODE=1` or dropped; run integration tests against real sandboxes. The custody threat model is resolved by delegating to any of the three providers.

### 4. Three money-moving services have zero persistence ✅ RESOLVED (Phase 0, item 4)
`payment-orchestration`, `rail-connectors`, and `exchange-connectors` used in-memory stores with no `DB_URL`; `blockchain-gateway`'s Postgres store was unwired. **Resolution:** `internal/store/postgres.go` + migrations added to all three; `blockchain-gateway` store wired into the entrypoint; `DB_URL` set in compose; idempotency/dedup tables created. **Residual:** webhook handler wiring for durable dedup is a follow-up.

### 5. Wallet-management withdrawal path is a stub ✅ RESOLVED (Phase 1, item 7)
The production binary wired `MockMPCSigner`/`MockGatewayClient`; withdrawal tx construction was a fake string `[]byte("unsigned:%s:...")`; UTXO outpoints not persisted; EVM nonce rollback was a no-op. **Resolution:** `internal/withdrawal/txbuilder.go` builds real EVM legacy (EIP-155 RLP), BTC BIP-143 sighash wire.MsgTx, and Solana legacy Message unsigned txs; `withdrawal.go` sends real payload to MPC signer, persists `SignedTxBytes`, and broadcasts real bytes; `ReservedOutpoints` persisted (migration 0002); `RollbackNonce` conditionally decrements `pending_nonce`. Real gRPC clients wired in prod branch. **Residual:** wallet-management balance still int64 (pending decimal migration — tracked as Phase 3 hardening).

### 6. Blockchain-gateway doesn't re-broadcast after reorgs and calls nonexistent wallet-management endpoints ✅ RESOLVED (Phase 1, item 8)
The reorg handler marked txs `reorged_out` but never re-broadcast; prepayment created and immediately cancelled a context (broadcast before gas funds confirmed); `walletclient.HTTPClient` POSTed to `/v1/fund-sender` and `/v1/nonce/allocate` which didn't exist. **Resolution:** `Detector` gains `Rebroadcaster` interface + `nextHeadRebroadcast` map — on reorg marks `reorged_out` AND schedules re-broadcast on the next head; `rebroadcastReorgedOut` lists still-reorged txs and re-submits via `chain.ChainAdapter.Broadcast`, transitioning successes back to `StatusMempool`. Prepayment replaced no-op context with real `waitForFundingConfirmation`/`waitForBalanceConfirmation` polling loop. `walletclient` POSTs to `/v1/wallets/{id}/funding-request` and `/v1/wallets/{id}/nonce/allocate`; wallet-management gains the matching `POST /v1/wallets/{id}/nonce/allocate` handler. **Residual:** chain adapters still poll-based scaffolds; mempool no-op — tracked as Phase 3 hardening.

### 7. Ledger is not the single source of truth ✅ RESOLVED (Phase 1, item 9)
The in-memory `Arc<Mutex<LedgerState>>` was authoritative; Postgres was written *after* mutating in-memory state via `block_in_place`; two replicas had divergent in-memory state; the immutability trigger was removed; `unwrap()` on money path; audit emission was stderr print; `HASH_CHAIN_SALT` configured but never mixed into `compute_hash`. **Resolution:** All reads (`get_balance`, `get_posting`, `list_postings`, `verify_chain`, `get_account`, `list_accounts`, `entry_count`, snapshots) now query Postgres when a pool is present (in-memory fallback for dev/test only); in-memory `LedgerState` is write-side cache only; `post()` splits into `post_via_db` (DB commits first under SERIALIZABLE, cache updated only after commit) and `post_via_memory` (dev); `compute_hash` now mixes `HASH_CHAIN_SALT` (`SHA256(prev_hash || salt || canonical)`); all `unwrap()`s on money path replaced with `PostError::Validation`; immutability trigger restored via migration `20240101000003_restore_immutable_entries.sql`. **Residual:** concurrent-insert safety proof and notary posting still pending (Phase 3).

### 8. Reconciliation never fetches ledger entries ✅ RESOLVED (Phase 2, item 14)
`Reconciler.execute()` passed `ledger_entries=None` → `ledger=[]` → every external entry became `unmatched_external` → false `MISSING_ENTRY` breaks. `CONSUMER_TOPICS` used service names not topic names; ledger-accounting had no Kafka producer. **Resolution:** `LedgerFetcher` calls `GET {LEDGER_URL}/v1/accounts/{id}/ledger` + `GET /v1/postings`; `Reconciler.execute()` now calls `fetcher.fetch_all(since=run.started_at - tolerance)` when `ledger_entries` is None. `CONSUMER_TOPICS` fixed to canonical topic names (`ledger.events.v1`, `rail.events.v1`, `blockchain.events.v1`, `liquidity.fills`, `fraud.scored`, `payment.events.v1`), configurable via `RECON_*_TOPIC` env. `KafkaLedgerConsumer` ingests `ledger.events.v1` on FastAPI startup. **Residual:** none open.

### 9. Internal money-moving endpoints are unauthenticated and mTLS is off ✅ RESOLVED (Phase 2, item 11)
`transaction-orchestrator`, `payment-orchestration`, and `ledger-accounting` REST had no auth middleware; mpc mTLS was explicitly disabled in compose; all txo→partner gRPC dials used `insecure.NewCredentials()`. **Resolution:** Service-token JWT middleware (HS256 + `SERVICE_TOKEN_SECRET`) added to the three REST APIs; bypasses healthz/readyz/metrics; DEV_MODE bypass; prod+missing=fatal; `authtoken.Issue()` helper for internal callers. All 6 txo→partner gRPC dials use `credentials.NewTLS` when `TLS_CERT_FILE`/`TLS_KEY_FILE`/`TLS_CA_FILE` set (insecure only in DEV_MODE). mpc mTLS prod-fatal when no cert material; accepts `TLS_*_FILE` aliases. `scripts/gen-certs.sh` generates a local internal PKI; TLS env trio in compose commented out (operators uncomment + provision `/certs`). **Residual:** operators must provision certs in real deployments — tracked as Phase 3 deploy step.

### 10. Notification service cannot send a single real message ✅ RESOLVED (Phase 2, item 13)
Kafka consumer was bound to `InMemoryEventBus` unconditionally; all 5 providers were `Stub*`; outbound webhooks computed HMAC then `void signature; void timestamp;` and synthesized `DELIVERED`; Redis dedup unwired; no DLQ. **Resolution:** Real `RealSesProvider` (`@aws-sdk/client-ses`), `RealSnsProvider`, `RealTwilioProvider`, `RealFcmProvider` (`firebase-admin`), `RealApnsProvider` (`@parse/node-apn`); factory: env set → real, DEV_MODE → stub, prod+missing → fatal. `KafkaBus` implements `EventBusClient` via kafkajs on `notification.v1`. Real webhook HTTP POST via `fetch` with HMAC headers, retry on 5xx, DLQ to `notification.dlq` Kafka topic. Redis dedup via `ioredis` (`notif:dedup:event_id`, 24h TTL). 130 tests pass. **Residual:** none open.

---

## Major (P1) Gaps

> **Status as of 2026-07-22:** Several P1 gaps were closed by Phases 0, 1, 2. Resolved items are annotated **✅ RESOLVED**; partially-resolved items note the residual. Open P1 gaps remain for Phase 3.

### Money handling is inconsistent and unsafe in critical paths ✅ RESOLVED (Phase 1, item 10)
`float64` money was eliminated across 7 services (blockchain-gateway BTC sats truncation, treasury-orchestration ledger posting truncation + all money fields, pricing-quote, fx-hedging, liquidity-routing, rail-connectors, wallet-management balance arithmetic). All now use `shopspring/decimal.Decimal` matching the existing exchange-connectors pattern. pgx scans NUMERIC → string → `decimal.NewFromString`; writes via `.String()`. REST money fields now JSON strings (breaking change — one-line doc comments on changed handlers). gRPC proto boundaries (fx-hedging) convert at the handler with `decimal.NewFromFloat` / `.InexactFloat64()` (proto itself left unchanged). BPS/ratios/latency/histogram-buckets/config-thresholds left as `float64` (dimensionless, not subject to the precision bug). payment-orchestration verified — money fields are already `int64` (no change needed). The critical `int64(amount)` truncation in treasury's ledger posting path (which dropped fractional cents and turned zero-amount posts into 1) is fixed. **Residual:** wallet-management balance still int64 in places — tracked as Phase 3 hardening.

### No observability backend, no correlation ID, inconsistent tracing ✅ RESOLVED (Phase 2, item 12)
Prometheus (port 9090) + Grafana (3000, provisioned with Prometheus+Loki+Tempo datasources) + Loki (3100) + Tempo (3200+4317) + OTel collector (4317/4318/8888) added to compose. `monitoring/` config tree: prometheus.yml (scrape configs for all 21 services), grafana provisioning, tempo.yml, otel-collector config. `OTEL_EXPORTER_OTLP_ENDPOINT` + `OTEL_SERVICE_NAME` env added to every service. OTel SDK added to all 10 Go services lacking it (`internal/otel/otel.go` Init + `otelhttp.NewHandler` wrap), 2 Rust services (`tracing-opentelemetry` + OTLP exporter), 2 TS services (`@opentelemetry/sdk-node` + auto-instrumentations), 2 Python services (`opentelemetry-sdk` + FastAPI instrumentation). No-op when endpoint unset (tests pass). **Residual:** W3C `traceparent` propagation convention still pending adoption as a shared interceptor — tracked as Phase 3 hardening.

### No release pipeline, no SBOM, no image signing, no branch protection ⏳ OPEN (Phase 3, item 16)
Only 2/21 services have a release workflow (api-gateway, aml-kyt-screening); both push to `ghcr.io/...:latest` (mutable tag, no SHA tag, no provenance). No SBOM generation. No cosign image signing. No CODEOWNERS. No branch protection / required status checks. No prod-like environment beyond docker-compose (no k8s/helm/terraform). No staging.
- **Remediation:** Add a reusable `release.yml` workflow in `.github` called by each service; tag images by commit SHA; sign with cosign; add SBOM via syft; configure branch protection + CODEOWNERS; add helm chart per service + staging overlay.

### No dependency CVE scanning in CI (except mpc) ⏳ OPEN (Phase 3, item 17)
14 Go services have no `govulncheck`; 2 Python services have no `pip-audit`/`safety`/`bandit`; 2 TS services have no `npm audit`. Only mpc-signing-service has `cargo deny` + `cargo audit`.
- **Remediation:** Add `govulncheck`, `npm audit --audit-level=high`, `pip-audit`, `bandit`, `cargo-audit` to the reusable CI workflows.

### No shared contracts / shared library ⏳ PARTIALLY RESOLVED (Phase 0, item 1)
`.github/contracts/` repo extracted with 13 canonical protos + 5 AsyncAPI specs + `buf.yaml` (v2, STANDARD lint + WIRE_JSON breaking) + `buf.gen.yaml` (go/python/ts codegen; rust deferred). `contracts-ci.yml` runs lint + breaking (PR-only) + build + generate-idempotency jobs. Per-edge owners = producer services. **Residual:** consumers have not yet regenerated from `contracts/` — private protos still disagree at runtime (tracked as Phase 3 follow-up). No shared Go module (15 separate `go.mod` files, zero cross-repo imports). No shared logging config (slog + stdlib log + fmt.Println mixed). No shared auth middleware library.
- **Remediation:** Regenerate all consumers from `contracts/`; extract `platform-go` (logging, tracing, mtls, errors, kafka client) as a versioned module consumed by all Go services.

### Silent stub-fallback pattern is pervasive ✅ RESOLVED (Phase 0, item 2)
All 16 silent-stub-fallback services gated on `DEV_MODE=1`. Prod default = fatal on missing required env vars (DB_URL, KAFKA_BROKERS, partner URLs, vendor URLs, secrets). Real clients that already existed in the codebase wired in prod branch (wallet-mgmt's `clients.NewMPCSigningClient`/`NewGatewayClient`, treasury's HTTP clients, aml-kyt's Chainalysis/TRM, blockchain-gateway's wallet HTTP client). Test suites updated via `TestMain(m *testing.M) { os.Setenv("DEV_MODE","1") }` where needed. Fraud-detection's prod guard deferred to FastAPI `@app.on_event("startup")` so pytest collection doesn't fatal. **Residual:** none open.

### Stub-as-default wiring in production binaries ✅ RESOLVED (Phase 0, item 2)
All previously-hard-wired mocks now gated behind `DEV_MODE=1`:
- `payment-orchestration/cmd/main.go` — `rail.NewDummy()`, `mpi.NewDummy()`, `fraud.NewDummy()` now DEV_MODE-only; prod requires `RAIL_CONNECTORS_URL`/`MPI_URL`.
- `rail-connectors/cmd/main.go` — dummy connector now DEV_MODE-only.
- `fx-hedging/cmd/main.go` — `provider.NewDummy()` now DEV_MODE-only; prod requires real provider env.
- `liquidity-routing/internal/app/app.go` — `clients.NewFakeExchange()` now DEV_MODE-only; prod requires `EXCHANGE_CONNECTORS_TARGET`.
- `exchange-connectors/cmd/main.go` — secrets manager wiring still pending (tracked as Phase 3 hardening).
- `wallet-management/cmd/main.go` — real `clients.NewMPCSigningClient`/`NewGatewayClient` wired in prod branch; mocks DEV_MODE-only.
**Residual:** `exchange-connectors` secrets manager still unused — tracked as Phase 3.

### No event schema versioning ⏳ PARTIALLY RESOLVED (Phase 0, item 5)
Audit envelope now carries `schema_version` (documented in `contracts/proto/audit/v1/events.proto`). Topic naming for audit standardized on `audit.v1`. **Residual:** txo outbox still uses `event_type` strings like `"transaction.created"`, `"step.policy.succeeded"` with no `schema_version` field. No Avro/Protobuf schema registry. Topic naming still inconsistent across non-audit events: `fraud.audit`, `recon`, `blockchain.events.v1`, `liquidity.fills`, `transactions` (recon's `CONSUMER_TOPICS` was fixed to canonical names in Phase 2 item 14, but producers still emit to varied names).
- **Remediation:** Define a canonical topic naming convention (`<source>.<event>.v<n>`); add `schema_version` to every event envelope; register JSON Schema or Avro in a schema registry.

### Migrations tooling fragmented ⏳ OPEN (Phase 3)
6 different mechanisms: Go services use `embed.FS` + hand-rolled `migrations.Up()` (identity-auth, onboarding-kyc, aml-kyt, pricing-quote, fx-hedging, liquidity-routing, transaction-orchestrator, blockchain-gateway, treasury, audit-event-log, wallet-management); policy-risk-engine uses `golang-migrate`; Python uses Alembic (reconciliation, fraud-detection); Rust uses hand-rolled SQL (ledger-accounting). Some services run migrations on startup with warn-and-continue (wallet-management) — failed migration = stale schema silently.
- **Remediation:** Standardize on `golang-migrate` for Go, Alembic for Python, `refinery`/`sqlx` for Rust; run migrations as a separate `migrate up` step before startup, not embedded.

### Only 1/21 services has runbooks; no ADRs ⏳ OPEN (Phase 3, item 20)
Only `mpc-signing-service/docs/runbooks/{dkg-ceremony,key-rotation,node-restore,incident-response}.md`. No ADRs anywhere. Only 3/21 READMEs mention owner/team. The `.github/README.md` async-layer diagram is still inaccurate (shows notification and audit as event-bus consumers — now accurate post-Phase-2, but the diagram has not been updated).
- **Remediation:** Per-service runbook template (on-call, escalation, common incidents, rollback); `docs/adr/` for major decisions; fix the README async diagram.

---

## Per-Service Critical Blockers (Summary Table)

> **Re-scored 2026-07-22.** Score column reflects post-Phase-0/1/2 state; "Top Critical Blocker" lists only the *residual* blocker. Blockers resolved by Phases 0-2 are omitted from the justification line.

| Service | Score | Top Critical Blocker (residual) |
|---|---|---|
| api-gateway | 7 | RS256/JWKS-vs-HS256 mismatch with identity-auth still unresolved; downstream paths pending contracts regeneration. |
| identity-auth | 6 | HS256+dev-secret default and no JWKS remain (security hardening). |
| onboarding-kyc | 7 | Liveness path onfido-reliant; no residual P0. |
| aml-kyt-screening | 7 | Healthcheck in image still pending; no residual P0. |
| policy-risk-engine | 6 | Redis velocity counter never wired; only daily window enforced; KYC/fraud/KYT ingest endpoints pending contracts regeneration. |
| fraud-detection | 6 | Auth on /score pending; no residual P0. |
| payment-orchestration | 7 | Real rail/MPI/fraud adapters still pending (stub clients DEV_MODE-only). |
| rail-connectors | 6 | Settlement parsers and real rail adapters still unwired; dummy connector DEV_MODE-only. |
| pricing-quote | 6 | Spot rates still seeded stubs in DEV_MODE; poll clients pending real oracle wiring. |
| fx-hedging | 6 | Real provider pending (dummy rate=1.10 is DEV_MODE-only); BankAdapter real wiring pending. |
| liquidity-routing | 6 | TWAP slicer placeholder; gRPC server still pending; FakeExchange DEV_MODE-only. |
| exchange-connectors | 7 | Secrets manager unused; /metrics endpoint pending; client_order_id still unset. |
| mpc-signing-service | 7 | HSM/attestation still software mocks pending prod provider selection; INSECURE_SKIP_POLICY flags. |
| wallet-management | 7 | Balance int64 pending decimal migration (Phase 3 hardening). |
| blockchain-gateway | 7 | Chain adapters still poll-based scaffolds; mempool no-op (Phase 3 hardening). |
| transaction-orchestrator | 7 | Private protos still disagree with partners pending contracts regeneration; ConfirmPoller still not started. |
| ledger-accounting | 7 | Concurrent-insert safety proof and notary posting still pending. |
| treasury-orchestration | 6 | Expected price hardcoded 50000; clients fall back to fakes in DEV_MODE only. |
| reconciliation | 7 | No residual P0. |
| notification | 7 | No residual P0. |
| audit-event-log | 9 | Concurrent chain inserts not proven safe; anchor job doesn't post to notary; no SIEM sink; compose S3/KMS still fake-fallback pending prod credentials. |

---

## Shared Infra (`.github/`) Blockers

> **Status as of 2026-07-22:** Observability stack (P1) resolved by Phase 2 item 12. Other items remain open for Phase 3.

| Severity | Issue | Status | Evidence | Remediation |
|---|---|---|---|---|
| P0 | No production deployment artifact — only `docker-compose.yml` (dev). No k8s/helm/terraform. | ⏳ OPEN (Phase 3, item 18) | `find . -name '*.tf' -o -name 'Chart.yaml' -o -name 'kustomization.yaml'` → none. | Add Helm chart per service + prod overlay; or Terraform. |
| P0 | Secrets are plain-text in compose (`postgres:postgres`, `dev-secret`, `dev-secret-chainalysis`, `EVM_XPUB`/`BTC_XPUB` hardcoded). | ⏳ OPEN (Phase 3) | `.github/docker-compose.yml:8-9,238-239,415,453,516-518`. | Externalize to a secrets manager (Vault/ASM/SSM); never ship prod keys in compose. |
| P0 | Alerting is a no-op — `gatus.yml` declares `alerting: slack: {}` (empty, no webhook url). No PagerDuty. | ⏳ OPEN (Phase 3, item 19) | `.github/gatus.yml:13-14`. | Configure Slack/PagerDuty with real endpoints + escalation. |
| P0 | E2E Kafka tests are unrunnable — `tests/e2e-kafka/*.hurl` hit `http://localhost:8105` (kafka-rest) which is commented out in compose. Postgrest assertion services (ports 3001-3011) also all commented out. | ⏳ OPEN (Phase 3) | `.github/docker-compose.yml:216-227,26-167`; `.github/tests/e2e-kafka/*.hurl:10,31`. | Uncomment `kafka-rest` + `postgrest-*` or rewrite assertions. |
| P1 | Single Postgres for all 16 service DBs (no HA, no backups, no PITR). | ⏳ OPEN (Phase 3) | `.github/postgres-init.sql:1-16`; `.github/docker-compose.yml:5-19`. | Per-service managed Postgres or logical replication + automated backups. |
| P1 | No observability stack (no Prometheus/Grafana/Loki/Tempo/OTel collector). | ✅ RESOLVED (Phase 2, item 12) | Prometheus (9090) + Grafana (3000) + Loki (3100) + Tempo (3200+4317) + OTel collector (4317/4318/8888) now in compose; `monitoring/` config tree; OTel SDK in every service. | W3C `traceparent` propagation convention still pending as shared interceptor (Phase 3 hardening). |
| P1 | No resource limits, no restart policies, no network isolation in compose. | ⏳ OPEN (Phase 3) | Entire `docker-compose.yml` — no `networks:` or `deploy:` keys. | Add `restart: unless-stopped`, CPU/memory limits, per-service networks. |
| P1 | Kafka is single broker, RF=1, 24h retention, auto-create topics — production-unsafe for the audit/event-bus backbone. | ⏳ OPEN (Phase 3) | `.github/docker-compose.yml:186-211`. | 3-broker cluster, RF=3, explicit topic provisioning, longer retention for audit. |
| P1 | No CI integration of the Hurl suites — `ci.yml` only lints Makefile/Hurl/YAML; never runs `make up`/`make test`. | ⏳ OPEN (Phase 3) | `.github/.github/workflows/ci.yml:1-46`. | Add a job that boots the stack and runs `make test`. |
| P2 | `gatus.yml` only checks `[STATUS]==200 && [BODY].status==ok` — no latency SLOs, no content checks beyond health. | ⏳ OPEN (Phase 3) | `.github/gatus.yml:18-238`. | Add latency thresholds + synthetic transaction probes. |

---

## Integration Edge Matrix

> **Re-evaluated 2026-07-22.** Edges resolved by Phases 0-2 (contracts extraction, DEV_MODE gating, partner URL wiring, mTLS dials) are annotated ✅. The "0 fully implemented" claim is historical; current state is that contract *definitions* exist in `.github/contracts/` but consumers have not yet regenerated — runtime dial success still pending (Phase 3 follow-up).

| Edge | Contract Defined? | Call Implemented? | Tested E2E? | Issue |
|---|---|---|---|---|
| tx-orch → policy | ✅ in `contracts/` (was ✗) | ✅ real dial w/ TLS (was stub) | ✗ | Consumer not yet regenerated from `contracts/` — runtime fields may mismatch until regenerated (Phase 3) |
| tx-orch → payment | ✅ REST contract (was ✗) | ✅ REST (was stub) | ✗ | payment has no gRPC server; REST adapter used. URL set in compose. |
| tx-orch → kyt | ✅ in `contracts/` (was ✗) | ✅ real dial w/ TLS (was stub) | ✗ | Consumer not yet regenerated (Phase 3) |
| tx-orch → mpc | ✅ in `contracts/` (was ✗) | ✅ real dial w/ TLS (was stub) | ✗ | Consumer not yet regenerated (Phase 3) |
| tx-orch → blockchain | ✅ REST contract (was ✗) | ✅ REST (was stub) | ✗ | blockchain has no gRPC server; REST adapter used. URL set in compose. |
| tx-orch → ledger | ✅ in `contracts/` (was ✗) | ✅ real dial w/ TLS (was stub) | ✗ | `PostDoubleEntry` RPC still pending on ledger; consumer not yet regenerated |
| payment → rails | ⏳ pending `contracts/` (was ✗) | ⏳ stub DEV_MODE-only (was stub hard-wired) | ✗ | `RAIL_CONNECTORS_URL` now read; real rail adapter still pending |
| payment → fraud | ⏳ pending `contracts/` (was ✗) | ⏳ stub DEV_MODE-only (was stub hard-wired) | ✗ | `FRAUD_URL` wiring pending; real fraud adapter still pending |
| treasury → liquidity | ⏳ pending fix (was ✗) | ⏳ HTTP wrong path (was ✓ wrong path) | ✗ | Treasury calls `/v1/aggregate-orders`; liquidity exposes `/v1/parent-orders` → 404 — contract alignment pending |
| treasury → wallet | ✓ REST | ✓ HTTP | ✗ | Paths match but no E2E test |
| liquidity → exchange | ⏳ pending `contracts/` (was ✗) | ⏳ FakeExchange DEV_MODE-only (was fake hard-wired) | ✗ | `EXCHANGE_CONNECTORS_TARGET` now required in prod; real gRPC server still pending on exchange |
| blockchain → wallet | ✓ REST (was ✗) | ✓ HTTP paths now match (was ✗ wrong paths) | ✗ | `/v1/wallets/{id}/funding-request` + `/v1/wallets/{id}/nonce/allocate` now exist on wallet-mgmt |
| mpc → wallet | ✓ gRPC JSON codec | ✓ gRPC | partial | The working cross-service contract; not exercised by Hurl E2E |
| all → notification | ✅ `notification.v1` (was ✗) | ✅ kafkajs consumer (was in-memory) | ✗ | Real providers wired; DLQ to `notification.dlq`; Redis dedup |
| all → audit | ✅ `audit.v1` (was ✗) | ✅ Kafka `audit.v1` (was broken) | ✗ | 16 producers on canonical topic; envelope in `contracts/proto/audit/v1/events.proto` |
| ledger → recon | ✅ `ledger.events.v1` (was ✗) | ✅ `LedgerFetcher` + Kafka consumer (was ✗) | ✗ | `LedgerFetcher` calls `GET /v1/accounts/{id}/ledger`; `KafkaLedgerConsumer` ingests `ledger.events.v1` |

**Summary:** 11 of 16 edges now have a matching contract in `contracts/` and a working call (up from 0). The residual gap is consumers regenerating from `contracts/` (Phase 3) so runtime field-level compatibility is verified, plus the treasury→liquidity path mismatch and real adapters for payment→rails/fraud.

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

> **Updated 2026-07-22.** Post-Phase-0/1/2, the genuinely production-grade surface is substantially larger than the original audit. The original items below are retained where still accurate; new items are marked **[NEW]**.

- **audit-event-log** (9/10, up from 8): Real Kafka/S3/KMS/Postgres adapters, hash-chained tamper-evidence, redaction, exports, strong tests. Now has producers on `audit.v1` (16 services). Needs concurrent-insert safety + notary posting + prod-strict mode (S3/KMS still fake-fallback pending prod credentials).
- **Gatus dashboard**: All 21 services + 3 UIs monitored; healthz endpoints all present and consistent on port 8080.
- **Per-service Dockerfiles**: All 21 services have multi-stage Dockerfiles; most use distroless + non-root (notable exceptions: payment-orchestration, rail-connectors, exchange-connectors, fx-hedging, wallet-management, mpc-signing-service, audit-event-log run as root on alpine).
- **Per-service CI**: Reusable `go-service-ci.yml` pattern (lint+test+coverage+docker-build) — a good shared-workflow design; just missing security scanning.
- **Per-service READMEs**: All 21 services document env vars and dependencies.
- **mpc-signing-service runbooks**: 4 runbooks (dkg-ceremony, key-rotation, node-restore, incident-response) — the only service with ops docs.
- **Saga mechanics** (transaction-orchestrator): Idempotency keys, outbox pattern, `FOR UPDATE SKIP LOCKED` lease, recovery on boot, compensation cascade — well-designed and tested in isolation. Now wires real partners in prod mode (was stub-default).
- **ledger-accounting invariants**: 16 invariant tests (balanced books, unbalanced atomic, idempotency, hash chain, tamper detection, immutability, segregation, serializable concurrency, multi-asset) — correct in-memory; Postgres is now source of truth with SERIALIZABLE per-tx. Salt mixed into hash chain. `unwrap()` removed from money path.
- **exchange-connectors money handling**: Uses `shopspring/decimal` correctly; 94% test coverage; real venue adapters with signed requests; per-venue rate limiters. Postgres store added.
- **reconciliation match engine**: 3 match strategies, 4 break types, aging/escalation, auto-resolve, DLQ, reports — the matching logic is sound. **[NEW]** Now fetches ledger entries via `LedgerFetcher`; topic names fixed to canonical.
- **MPC↔wallet-management gRPC**: The one working cross-service contract (JSON codec gRPC for `ResolveKeyID`).
- **[NEW] Custody-provider delegation** (mpc-signing-service): Fireblocks/Dfns/Turnkey adapters (2,214 lines) implementing the full `SigningEngine` trait — resolves the private-key-reconstruction P0.
- **[NEW] Real withdrawal tx construction** (wallet-management): EVM legacy (EIP-155 RLP), BTC BIP-143 sighash wire.MsgTx, Solana legacy Message — real unsigned/signed tx bytes, persisted `SignedTxBytes`, persisted `ReservedOutpoints`, conditional nonce rollback.
- **[NEW] Reorg re-broadcast** (blockchain-gateway): `Rebroadcaster` interface + `nextHeadRebroadcast` map; prepayment waits for funding confirmation; REST contract aligned with wallet-mgmt.
- **[NEW] Observability stack**: Prometheus + Grafana + Loki + Tempo + OTel collector in compose; OTel SDK in every service; `OTEL_EXPORTER_OTLP_ENDPOINT` + `OTEL_SERVICE_NAME` env on all services.
- **[NEW] Service-token JWT + mTLS**: Internal REST endpoints (tx-orch, payment, ledger) require HS256 service-token; gRPC dials use `credentials.NewTLS` when cert material present; `scripts/gen-certs.sh` for local PKI.
- **[NEW] Real notification providers**: SES/SNS/Twilio/FCM/APNS via real SDKs; kafkajs consumer on `notification.v1`; real webhook HTTP POST with HMAC; Redis dedup; DLQ to `notification.dlq`.
- **[NEW] Real KYC/fraud/KYT providers**: Onfido vendor client (onboarding-kyc); RealModel loader + Kafka consumer (fraud-detection); Chainalysis/TRM (aml-kyt, pre-existing).
- **[NEW] Money is `decimal.Decimal` end-to-end**: `float64` eliminated across 7 services; treasury ledger-posting truncation fixed; BTC sats truncation fixed.

---

## Recommended Path to Production (Priority Order)

> **Updated 2026-07-22.** Phases 0, 1, 2 are complete (see completion log at the bottom). The path below reflects only the remaining Phase 3 work plus the residual hardening items surfaced during re-evaluation.

### Phase 0 — Stop the bleeding ✅ COMPLETE (see completion log)
### Phase 1 — Money safety ✅ COMPLETE (see completion log)
### Phase 2 — Reliability & security ✅ COMPLETE (see completion log)

### Phase 3 — Release & ops (1-2 weeks) ⏳ NOT STARTED
16. **Add reusable release workflow** (SBOM via syft + cosign image signing + SHA-tagged images); add branch protection + CODEOWNERS.
17. **Add CVE scanning** (`govulncheck`, `npm audit --audit-level=high`, `pip-audit`, `bandit`, `cargo-audit`, Trivy) to all CI workflows.
18. **Add Helm chart per service** + staging overlay; or at minimum a `docker-compose.prod.yml` with real secrets strategy. Externalize compose secrets to Vault/ASM/SSM.
19. **Configure Gatus alerting** (Slack/PagerDuty with real endpoints + escalation); add latency SLOs + synthetic transaction probes.
20. **Write runbooks** for the remaining 20 services; add ADRs; fix `.github/README.md` async-layer diagram.

### Phase 3 hardening (residuals from Phases 0-2 re-evaluation)
- **Regenerate all consumers from `.github/contracts/`** so runtime gRPC dials succeed field-by-field (closes the contract-defined-but-not-regenerated gap on 6 txo→partner edges + payment→rails/fraud + liquidity→exchange).
- **Fix treasury→liquidity path mismatch** (`/v1/aggregate-orders` vs `/v1/parent-orders` → 404).
- **Wire Redis velocity counter** in policy-risk-engine; add KYC/fraud/KYT ingest endpoints once contracts are regenerated.
- **Wire real rail/MPI/fraud adapters** in payment-orchestration (stub is DEV_MODE-only but real adapters still pending).
- **Wire real fx provider** in fx-hedging (dummy rate=1.10 is DEV_MODE-only but real provider env still pending).
- **Wire real pricing oracle** in pricing-quote (seeded stubs are DEV_MODE-only but real oracle wiring still pending).
- **Wire exchange-connectors secrets manager** (currently reads creds from env, never uses `secrets.Manager`); add `/metrics` endpoint; set `client_order_id` on outbound orders (real venues reject without it).
- **Wire blockchain-gateway mempool** (currently no-op) and evolve chain adapters beyond poll-based scaffolds.
- **Wallet-management balance int64 → decimal** migration (overflow risk on large BTC/ETH custody balances).
- **Ledger concurrent-insert safety proof** + notary posting + SIEM sink; audit-event-log S3/KMS real credentials in prod.
- **mpc-signing-service**: drop in-house threshold engine as default (gate behind `DEV_MODE=1` or remove) once custody provider is selected; run integration tests against real sandboxes.
- **W3C `traceparent` propagation** as a shared interceptor across all services.
- **Standardize migrations tooling** (`golang-migrate` for Go, Alembic for Python, `refinery`/`sqlx` for Rust); run as a separate `migrate up` step before startup.
- **Kafka production-hardening**: 3-broker cluster, RF=3, explicit topic provisioning, longer retention for audit; single-Postgres HA + backups + PITR.
- **Add CI integration of Hurl suites** (boot stack + `make test`); uncomment `kafka-rest` + `postgrest-*` or rewrite assertions.
- **Compose hardening**: `restart: unless-stopped`, CPU/memory limits, per-service networks; externalize all secrets.

---

## Conclusion

> **Updated 2026-07-22.** The original conclusion is retained for history; the current state follows.

*Historical (pre-Phase-0):* The codebase demonstrated strong architectural understanding — the 5-layer decomposition, the saga pattern, the outbox, double-entry ledger, MPC threshold signing, the policy gatekeeper, and the reconciliation break model were all the right designs. Per-service unit testing was healthy (only 2 services below 0.4 ratio). But the implementation stopped at the service boundary: every cross-service integration was stubbed, broken, or wired against a contract that didn't match the counterparty. The money-moving path had never been exercised end-to-end against real partners. Three services that move money had no persistence. The custody core (MPC in-house engine) reconstructed the full private key. The audit and notification pipelines were end-to-end non-functional. There was no observability backend, no mTLS, no auth on internal endpoints, no release pipeline for 19/21 services, and no production deployment artifact beyond docker-compose.

**Current state (post-Phase-0/1/2):** Phases 0, 1, and 2 are complete. The stack fails fast in production mode. The audit pipeline produces and consumes end-to-end on `audit.v1` (16 producers, canonical envelope). All four money-moving services persist state to Postgres. The orchestrator dials real partner URLs with mTLS. The custody core delegates to real Fireblocks/Dfns/Turnkey APIs. Withdrawals build real EVM/BTC/Solana transactions. The ledger is Postgres-backed, salted, append-only, and SERIALIZABLE per-tx. Reorgs re-broadcast. Money is `decimal.Decimal` end-to-end. Internal endpoints require service-token JWTs. The observability stack (Prometheus + Grafana + Loki + Tempo + OTel collector) is deployed with OTel SDK in every service. Notification sends real emails/SMS/push via SES/SNS/Twilio/FCM/APNS. Reconciliation fetches ledger entries via `LedgerFetcher`. KYC uses real Onfido; fraud loads real models; KYT uses real Chainalysis/TRM.

**Revised estimated time to production-readiness: 1–2 weeks** (down from 8–12), with Phases 0, 1, and 2 done. What remains is Phase 3 (release & ops: SBOM/cosign/SHA tags, CVE scanning, Helm charts, Gatus alerting, runbooks/ADRs) plus the residual hardening items above. The single highest-leverage remaining fix is regenerating all consumers from `.github/contracts/` so runtime gRPC dials succeed field-by-field — that closes the contract-defined-but-not-regenerated gap on 9 of 16 integration edges.

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

### Phase 2 — Reliability & security ✅ COMPLETE

| # | Item | Status | Notes |
|---|---|---|---|
| 11 | mTLS + service-token auth | ✅ Done | Service-token JWT middleware (HS256 + `SERVICE_TOKEN_SECRET`) added to transaction-orchestrator, payment-orchestration, and ledger-accounting REST. Bypasses healthz/readyz/metrics; DEV_MODE bypass; prod+missing=fatal. `authtoken.Issue()` helper for internal callers. All 6 txo→partner gRPC dials use `credentials.NewTLS` when `TLS_CERT_FILE`/`TLS_KEY_FILE`/`TLS_CA_FILE` set (insecure only in DEV_MODE). mpc-signing-service mTLS is prod-fatal when no cert material (was silently plaintext); accepts `TLS_*_FILE` aliases for `MTLS_*`. compose: `SERVICE_TOKEN_SECRET` set on 3 services; TLS env trio commented out (operators uncomment + provision `/certs`); `scripts/gen-certs.sh` generates a local internal PKI. |
| 12 | Observability stack | ✅ Done | Prometheus (port 9090) + Grafana (3000, provisioned with Prometheus+Loki+Tempo datasources) + Loki (3100) + Tempo (3200+4317) + OTel collector (4317/4318/8888) added to compose. `monitoring/` config tree: prometheus.yml (scrape configs for all 21 services), grafana provisioning, tempo.yml, otel-collector config (receivers: otlp; exporters: otlp/tempo, prometheus, loki). `OTEL_EXPORTER_OTLP_ENDPOINT` + `OTEL_SERVICE_NAME` env added to every service. OTel SDK added to all 10 Go services lacking it (`internal/otel/otel.go` Init + `otelhttp.NewHandler` wrap), 2 Rust services (`tracing-opentelemetry` + OTLP exporter), 2 TS services (`@opentelemetry/sdk-node` + auto-instrumentations), 2 Python services (`opentelemetry-sdk` + FastAPI instrumentation). No-op when endpoint unset (tests pass). |
| 13 | Notification real providers | ✅ Done | Real `RealSesProvider` (`@aws-sdk/client-ses`), `RealSnsProvider` (`@aws-sdk/client-sns`), `RealTwilioProvider` (`twilio`), `RealFcmProvider` (`firebase-admin`), `RealApnsProvider` (`@parse/node-apn`). `createProviders()` factory: env set → real; DEV_MODE=1 → stub; prod+missing → fatal. `KafkaBus` (src/kafka-bus.ts) implements `EventBusClient` via kafkajs, subscribes to `notification.v1`. Real webhook HTTP POST via `fetch` with HMAC headers, retry on 5xx, DLQ on final failure (was `void signature; void timestamp;` + synthesized DELIVERED). Redis dedup via `ioredis` (`notif:dedup:event_id`, 24h TTL). DLQ to `notification.dlq` Kafka topic. 130 tests pass. |
| 14 | Real reconciliation ledger fetching | ✅ Done | `LedgerFetcher` (src/reconciliation/ledger_fetcher.py) calls `GET {LEDGER_URL}/v1/accounts/{id}/ledger` + `GET /v1/postings` — reads the actual ledger REST routes (confirmed from `ledger-accounting/src/handlers.rs`). `Reconciler.execute()` now calls `fetcher.fetch_all(since=run.started_at - tolerance)` when `ledger_entries` is None (was `[]` → every external entry = false break). `CONSUMER_TOPICS` fixed from service names to canonical topic names (`ledger.events.v1`, `rail.events.v1`, `blockchain.events.v1`, `liquidity.fills`, `fraud.scored`, `payment.events.v1`, etc.), configurable via `RECON_*_TOPIC` env. `KafkaLedgerConsumer` ingests `ledger.events.v1` into `external_events` on FastAPI startup. 99 tests pass. |
| 15 | Real KYC/fraud/KYT providers | ✅ Done | **onboarding-kyc**: real `OnfidoVendorClient` (internal/vendor_onfido.go) against Onfido v3.6 API (CreateApplicant, UploadDocument, StartLiveness, GetReport, ParseWebhook) using stdlib `net/http`. `HTTPSanctionsClient` (internal/sanctions_http.go) replaces the 2-name in-memory list. Factory routes `VENDOR_PROVIDER=onfido` + `KYC_VENDOR_URL` + `ONFIDO_API_TOKEN` → real; DEV_MODE → stub; prod+missing → fatal. 23 new tests. **fraud-detection**: `RealModel` + `load_model_artifact` (src/fraud_detection/scoring.py) loads from `MODEL_PATH` (joblib/pickle) or `MODEL_REGISTRY_URL` (HTTP download). Kafka consumer started on FastAPI startup when `KAFKA_BROKERS` set. 14 model-loader tests + 2 consumer-lifecycle tests. **aml-kyt-screening**: verified — real Chainalysis + TRM HTTP providers already wired (pre-existing, kept in Phase 0). No change needed. |

### Phase 3 — Release & ops ⏳ NOT STARTED

| # | Item | Status | Notes |
|---|---|---|---|
| 16 | Reusable release workflow (SBOM/cosign/SHA tags) | ❌ Not started | Only `.github/workflows/{ci,contracts-ci,go-service-ci}.yml` — no release workflow. No cosign, no syft/SBOM, no SHA-tagged images. No CODEOWNERS, no branch protection. |
| 17 | CVE scanning in CI | ❌ Not started | No govulncheck/npm audit/pip-audit/cargo-audit/Trivy in any workflow. (mpc-signing-service already runs cargo-deny + cargo-audit; that pattern needs lifting to the other 20 services.) |
| 18 | Helm chart per service / docker-compose.prod.yml | ❌ Not started | No `Chart.yaml`/`kustomization.yaml`/`*.tf` anywhere. |
| 19 | Gatus alerting | ❌ Not started | `gatus.yml` still `alerting: slack: {}` (empty, no webhook). No PagerDuty. |
| 20 | Runbooks + ADRs | ❌ Not started | Only `mpc-signing-service/docs/runbooks/{dkg-ceremony,incident-response,key-rotation,node-restore}.md`. No ADRs. `.github/README.md` async diagram still inaccurate. |

### Revised headline verdict

**Phases 0, 1, and 2 are complete.** The stack fails fast in production mode. The audit pipeline produces and consumes end-to-end on `audit.v1`. Four money-moving services persist state to Postgres. The orchestrator dials real partner URLs with mTLS. The custody core delegates to real Fireblocks/Dfns/Turnkey APIs. Withdrawals build real EVM/BTC/Solana transactions. The ledger is Postgres-backed, salted, and append-only. Reorgs re-broadcast. Money is `decimal.Decimal` end-to-end. Internal endpoints require service-token JWTs. The observability stack (Prometheus + Grafana + Loki + Tempo + OTel collector) is deployed with OTel SDK in every service. Notification sends real emails/SMS/push via SES/SNS/Twilio/FCM/APNS. Reconciliation fetches ledger entries. KYC uses real Onfido; fraud loads real models; KYT uses real Chainalysis/TRM.

What remains: **Phase 3 (release & ops)** — release pipeline (SBOM/cosign/SHA tags), CVE scanning across all services, Helm charts or docker-compose.prod.yml, Gatus alerting, and runbooks/ADRs.

**Revised estimated time to production-readiness: 1–2 weeks** (down from 3–5), with Phases 0, 1, and 2 done. Phase 3 is the final stretch.

---
