# Production-Readiness Report v2 — AI Crypto On-Ramp Backend

> **Re-audited from scratch 2026-07-25.** Every service was re-examined independently; prior report's "completed" claims were not assumed. Findings supersede the 2026-07-22 report. Prior completed items are carried forward only where the fresh audit confirms them.

**Scope:** 21 backend services + 3 UIs + `.github/` local-testing harness.
**Method:** 6 parallel agents, every claim cited `file:line`. `.github/` docker-compose/gatus scored as local-testing harness (tolerant — not prod deployment).

---

## Headline Verdict

**Not production-ready.** Fresh audit finds the prior report overstated completion. While real provider adapters and Postgres stores exist, many are **unwired in the prod path** (silent stub fallback, in-memory default, "not yet implemented" fatals). 15/21 services expose unauthenticated REST/gRPC. 7 services still have `float64` on money paths. The custody core still defaults to in-house threshold signing (private-key reconstruction). The observability stack claimed in Phase 2 is **absent from the compose harness**. Estimated time to production-readiness: **4–6 weeks**.

---

## Service Readiness Scores

| # | Service | Lang | Score | Top residual blocker |
|---|---|---|---|---|
| 1 | gateway-api | TS | 7 | Mock downstream + hardcoded `dev-internal-secret` when env unset (src/index.ts:59,66-67) |
| 2 | gateway-auth | Go | 4 | SHA-256 password hash (not Argon2id); HS256+`dev-secret` default; no Kafka audit (internal/crypto.go:46, config.go:22) |
| 3 | kyc-onboarding | Go | 5 | Hardcoded `dev-webhook-secret`; in-memory sanctions/webhook stores; no endpoint auth (internal/webhooks.go:57, server.go:356) |
| 4 | kyt-aml-screening | Go | 6 | Empty webhook HMAC key when env unset; plaintext gRPC; in-memory dedup (cmd/kyt/main.go:166, grpcserver/server.go:40) |
| 5 | engine-policy-risk | Go | 7 | Redis velocity never wired; `/evaluate` auth bypassable; float64 USD caps (main.go:168, api.go:185, evaluate.go:127) |
| 6 | engine-pricing | Go | 4 | In-memory store in prod; seeded static spot rates; poll client never wired (store.go:79, spot.go:117) |
| 7 | engine-liquidity | Go | 4 | `FakeExchange` wired unconditionally; fake treasury/audit/recon; float64 book levels (app.go:107-152, clients.go:33) |
| 8 | engine-fraud | Python | 4 | `StubModel` is default; all 18 readiness checks hardcoded True; in-memory feature store (scoring.py:221, app.py:77) |
| 9 | engine-recon | Python | 5 | 18 readiness checks hardcoded True; Kafka defaults off (`enable_kafka=False`); sqlite default DB (app.py:41, config.py:24,36) |
| 10 | orchestrator-fiat | Go | 4 | `rail.NewDummy()`+`mpi.NewDummy()` in prod; in-memory idempotency; writes outside tx (main.go:60-65, handlers.go:42) |
| 11 | orchestrator-treasury | Go | 6 | REST unauthenticated; static readyz; outbox appended after commit (api.go:32-60, app.go:162) |
| 12 | orchestrator-tx | Go | 5 | Payment/blockchain stubs fatal-or-stub; audit never dialed; static readyz; no OTel (main.go:87-88, api.go:124) |
| 13 | fx-hedger | Go | 4 | Stub provider in prod path; `DOUBLE PRECISION` money cols; no auth (main.go:137, migrations:8-50) |
| 14 | notifier | TS | 6 | No endpoint auth; stub-secret webhook fallback; Redis silent in-memory fallback (app.ts:44-190, redis-runtime.ts:37) |
| 15 | mpc-signer | Rust | 3 | In-house engine reconstructs full key; no HSM wired; control-plane RPCs unauthenticated (cluster.rs:171, service.rs:179) |
| 16 | wallet-manager | Go | 4 | BTC/Solana sighash uses placeholder pubkey/blockhash; no REST/gRPC auth; insecure gRPC dials (txbuilder.go:148,209, rest.go:35) |
| 17 | gateway-blockchain | Go | 6 | REST unauthenticated; RPC no TLS; OTLP `WithInsecure()`; no readyz (router.go:40, adapters.go:80, otel.go:58) |
| 18 | gateway-fiat | Go | 3 | Prod fatals "not implemented"; dummy rail always registered; `dev-secret` webhook; float64 ACH amount (main.go:53, dummy/register.go:9, ach/adapter.go:327) |
| 19 | gateway-exchange | Go | 5 | Prod fatals on secrets manager; unauth REST; root Dockerfile; OTLP insecure (main.go:126, server.go:57) |
| 20 | accounting-ledger | Rust | 6 | Non-atomic chain extension (concurrent fork risk); plaintext gRPC; DB-empty silently in-memory (store.rs:761, main.rs:73) |
| 21 | audit-logger | Go | 4 | Silent fallback to fake S3/KMS/Kafka no DEV_MODE gate; non-atomic chain; `X-Audit-Roles` header spoofable (app.go:61-137, auth.go:28) |

**Aggregate:** Average **4.9/10** (was claimed 6.6/10). Only 2 services ≥7. 13 services ≤5. The prior report's Phase 0-2 "completion" did not survive a from-scratch audit — stubs are gated by env but the real adapters are often unimplemented or unwired.

### Local-testing harness

| Area | Score | Note |
|---|---|---|
| `.github/` (compose, gatus, scripts) | 8/10 | Solid local harness; tolerant of dev secrets, single-broker Kafka. Missing: app healthchecks, observability stack absent, no release/CVE workflow. |
| `ui-front-office` | 3/10 | 1/52 tasks done; no auth, no pages, no API integration. |
| `ui-middle-office` | 3/10 | 1/53 tasks done; no auth/RBAC, no router, no API integration. |
| `ui-back-office` | 5/10 | 53/53 tasks done but dashboards thin; no auth; clients carry no service token; MPC dashboard placeholder. |

---

## Completed Items Carried Forward (verified by fresh audit)

These items from the prior report's Phases 0-2 are confirmed done in the codebase:

**Phase 0 — Stop the bleeding (confirmed):**
- ✅ `.github/contracts/` extracted: 13 protos + 5 AsyncAPI + `buf.yaml`/`buf.gen.yaml` + `contracts-ci.yml`. Consumers NOT yet regenerated.
- ✅ `DEV_MODE` gating exists in most services (gateway-blockchain, orchestrator-tx, orchestrator-fiat, wallet-manager, mpc-signer, notifier, kyc-onboarding, kyt-aml-screening all have DEV_MODE branches). However several services lack a hard fatal in prod when real client is unimplemented (gateway-fiat, gateway-exchange, engine-liquidity, orchestrator-fiat rail/MPI, engine-pricing, fx-hedger).
- ✅ Partner URLs set in compose for orchestrator-tx (`POLICY_URL`/`KYT_URL`/`MPC_URL`/`LEDGER_URL`/`PAYMENT_URL`/`BLOCKCHAIN_URL`).
- ✅ Postgres stores added to orchestrator-fiat, gateway-fiat, gateway-exchange with `DB_URL` in compose.
- ✅ `audit.v1` Kafka topic adopted by producers; envelope in `contracts/proto/audit/v1/events.proto`. (Note: some producers still use in-memory sinks — see service rows.)

**Phase 1 — Money safety (partially confirmed):**
- ✅ `decimal.Decimal` used in gateway-blockchain, orchestrator-treasury, engine-pricing, engine-liquidity, rail-connector/gateway-fiat, exchange-connector/gateway-exchange, wallet-manager EVM path.
- ✅ Custody-provider adapters (Fireblocks/Dfns/Turnkey) implemented in mpc-signer — but **not the default**; in-house engine still default.
- ✅ Real withdrawal tx construction for EVM in wallet-manager. **BTC/Solana use placeholder pubkeys/blockhash** (regressed/not actually complete).
- ✅ Reorg re-broadcast in gateway-blockchain.
- ✅ Ledger Postgres source of truth when `DB_URL` set; SERIALIZABLE; salt mixed into hash. **Chain extension is non-atomic** (regressed).
- ⚠️ `float64` still on money paths in: fx-hedger (Postgres cols), engine-liquidity (book levels, slicer participation), engine-policy-risk (USD caps), gateway-fiat (ACH amount), orchestrator-treasury (config thresholds).

**Phase 2 — Reliability & security (partially confirmed):**
- ✅ Service-token JWT middleware exists on orchestrator-tx, orchestrator-fiat, accounting-ledger REST. **NOT on 12 other services** with mutating endpoints.
- ✅ gRPC dials use `credentials.NewTLS` when TLS env set (orchestrator-tx confirmed). Many other services still default to `insecure.NewCredentials()` (wallet-manager, mpc-signer wallet client, gateway-blockchain OTLP).
- ✅ Real notifier providers (SES/SNS/Twilio/FCM/APNS) implemented; kafkajs consumer; HMAC webhooks; Redis dedup; DLQ. Redis silently falls back to in-memory when unset.
- ✅ `LedgerFetcher` in engine-recon; canonical topic names configurable.
- ✅ Real Onfido/Chainalysis/TRM providers exist. Fraud `RealModel` loader exists but `StubModel` is still default.
- ❌ **Observability stack NOT in compose.** Prior report claimed Prometheus+Grafana+Loki+Tempo+OTel collector deployed — fresh audit of `docker-compose.yml` finds **no such services and no `OTEL_*` env vars**. OTel SDK code may exist in some services but the harness doesn't wire it. This is a significant overstatement in the prior report.

---

## Top 10 Critical (P0) Production Blockers (current)

1. **mpc-signer default reconstructs the full private key.** In-house threshold engine still the default; `CUSTODY_PROVIDER=in_house`. Real adapters exist but aren't selected. Control-plane RPCs (DKG/Rotate/Restore) unauthenticated. (src/engine/threshold/cluster.rs:171, src/grpc/service.rs:179)
2. **wallet-manager BTC/Solana withdrawals sign placeholder sighashes.** BTC P2WPKH uses 20-byte zero placeholder pubkey hash; Solana uses `sha256(walletID)` as `from` and `solana-recent-blockhash-placeholder`. MPC signs an invalid sighash → signature won't validate onchain. (internal/withdrawal/txbuilder.go:148,156,194,209)
3. **15/21 services expose unauthenticated REST/gRPC.** gateway-blockchain, gateway-exchange, gateway-fiat, orchestrator-treasury, engine-pricing, engine-liquidity, engine-fraud, engine-recon, fx-hedger, notifier, wallet-manager, mpc-signer control-plane, kyc-onboarding, accounting-ledger gRPC, audit-logger (spoofable header). Money-moving endpoints in this set = direct loss vector.
4. **Silent stub-fallback in prod for 6 services.** gateway-fiat and gateway-exchange fatal with "not implemented"; orchestrator-fiat wires `Dummy` rail/MPI; engine-liquidity wires `FakeExchange` unconditionally; engine-pricing uses in-memory store + seeded static rates; fx-hedger falls through to `provider.NewDummy()`. (cited per service above)
5. **accounting-ledger + audit-logger hash chains non-atomic.** `prev_hash`/`sequence_number` read outside the insert transaction → concurrent ingests fork the chain. audit-logger same pattern. (store.rs:761, ingest.go:152-208)
6. **engine-fraud ships `StubModel` as default.** Any artifact load failure falls back to weighted-sum stub. All 18 readiness checks hardcoded `True`. (scoring.py:221, app.py:77)
7. **gateway-auth uses SHA-256 password hashing** (not Argon2id/bcrypt) and HS256+`dev-secret` JWT default with no fatal. README falsely claims Argon2id. (internal/crypto.go:46, config.go:22)
8. **engine-recon Kafka defaults off.** `enable_kafka=False` default; `DB_URL` defaults to sqlite `:memory:`. Prod with only `KAFKA_BROKERS` set still uses in-memory producer. (config.py:24,36)
9. **wallet-manager + mpc-signer gRPC dials plaintext.** `insecure.NewCredentials()` default; mpc-signer `GrpcWalletClient` dials `http://`. Signing/broadcast traffic exposed. (clients.go:38, wallet.rs:72)
10. **No observability stack in compose.** Prior Phase-2 claim unverified — no Prometheus/Grafana/Loki/Tempo/OTel services, no `OTEL_*` env. The system is unobservable in the actual harness.

---

## Major (P1) Gaps

- **Money float64 in 5 services** (fx-hedger Postgres cols, engine-liquidity book levels + slicer, engine-policy-risk USD caps, gateway-fiat ACH amount, orchestrator-treasury config thresholds).
- **Static `/readyz` in 6 services** (orchestrator-treasury, orchestrator-tx, engine-fraud, engine-recon, gateway-auth, gateway-blockchain has no readyz). Load balancers route to broken pods.
- **In-memory idempotency/dedup in orchestrator-fiat, kyt-aml-screening, notifier (when Redis unset)** — money-loss on retry across replicas.
- **Outbox appended after DB commit** in orchestrator-treasury — crash loses audit/ledger event while state change persists.
- **Dockerfiles run as root** in gateway-fiat, gateway-exchange, fx-hedger, engine-recon, audit-logger.
- **No release pipeline / SBOM / cosign / SHA tags / CODEOWNERS / branch protection.**
- **No CVE scanning** except mpc-signer (cargo-deny/audit).
- **No runbooks** for 20/21 services (only mpc-signer).
- **Consumers not regenerated from `contracts/`** — gRPC dials may fail at runtime field-by-field.
- **Treasury→liquidity path mismatch** (`/v1/aggregate-orders` vs `/v1/parent-orders`).
- **No shared Go module** — 15 separate `go.mod`, no shared logging/auth/otel library.
- **UI services unfinished** — front-office 1/52, middle-office 1/53 tasks; back-office no auth and clients carry no service token.
- **Hurl E2E suites not in CI.**

---

## Integration Edge Matrix

| Edge | Contract | Call | Tested | Issue |
|---|---|---|---|---|
| txo → policy | ✅ contracts/ | ✅ TLS dial | ✗ | Consumer not regenerated |
| txo → kyt | ✅ contracts/ | ✅ TLS dial | ✗ | Consumer not regenerated |
| txo → mpc | ✅ contracts/ | ✅ TLS dial | ✗ | Consumer not regenerated |
| txo → ledger | ✅ contracts/ | ✅ TLS dial | ✗ | `PostDoubleEntry` RPC pending |
| txo → payment | ✅ REST | ⚠️ stub-or-fatal | ✗ | Real adapter not implemented |
| txo → blockchain | ✅ REST | ⚠️ stub-or-fatal | ✗ | Real adapter not implemented |
| txo → audit | ✗ | ❌ stub never dialed | ✗ | In-memory audit in prod |
| payment → rails | ✗ | ❌ dummy always | ✗ | Real rail adapters unimplemented |
| payment → fraud | ✗ | ❌ dummy always | ✗ | Real fraud adapter unimplemented |
| treasury → liquidity | ✗ | ❌ 404 path | ✗ | `/v1/aggregate-orders` vs `/v1/parent-orders` |
| treasury → wallet | ✓ REST | ✓ HTTP | ✗ | No E2E |
| liquidity → exchange | ✗ | ❌ FakeExchange | ✗ | gRPC server pending on exchange |
| blockchain → wallet | ✓ REST | ✓ HTTP | ✗ | Paths match |
| mpc → wallet | ✓ gRPC | ⚠️ plaintext http | partial | No TLS |
| all → notifier | ✅ notifier.v1 | ✅ kafkajs | ✗ | Real providers wired |
| all → audit | ✅ audit.v1 | ⚠️ mixed | ✗ | Some producers still in-memory |
| ledger → recon | ✅ ledger.events.v1 | ✅ LedgerFetcher | ✗ | Kafka default off in recon |

**Summary:** 6/16 edges fully working; 5 edges stub-or-fatal; 4 edges in-memory/plaintext. The prior report's "11/16 working" claim is not supported.

---

## Recommended Path to Production (Priority Order)

Phases 0-2 items below are the **verified-completed** subset of the prior report's plan. Phases 3+ are new/residual.

### Phase 0 — Stop the bleeding ✅ COMPLETE (verified)
1. ✅ Extract `contracts/` repo
2. ✅ `DEV_MODE` fail-fast gating (partial — see Phase 4 for gaps)
3. ✅ Wire orchestrator-tx partner URLs in compose
4. ✅ Postgres stores for money-moving services
5. ✅ `audit.v1` canonical Kafka ingress

### Phase 1 — Money safety ⚠️ PARTIALLY COMPLETE (re-opened)
6. ✅ Custody-provider adapters implemented (Fireblocks/Dfns/Turnkey) — **but not default; in-house still reconstructs key** → see Phase 4
7. ⚠️ Real withdrawal tx construction — EVM confirmed; **BTC/Solana use placeholder pubkeys/blockhash** → see Phase 4
8. ✅ Reorg re-broadcast (gateway-blockchain)
9. ✅ Ledger Postgres source of truth + salt + SERIALIZABLE — **non-atomic chain extension** → see Phase 4
10. ⚠️ `decimal.Decimal` migration — **5 services still have float64 on money paths** → see Phase 4

### Phase 2 — Reliability & security ⚠️ PARTIALLY COMPLETE (re-opened)
11. ✅ Service-token JWT on orchestrator-tx, orchestrator-fiat, accounting-ledger REST — **12 other services unauthenticated** → see Phase 4
12. ❌ **Observability stack NOT in compose** (prior claim false) → see Phase 4
13. ✅ Real notifier providers + kafkajs + HMAC webhooks + Redis dedup + DLQ — **Redis silent in-memory fallback** → see Phase 4
14. ✅ `LedgerFetcher` + canonical topic names in engine-recon — **Kafka defaults off, sqlite default DB** → see Phase 4
15. ✅ Real Onfido/Chainalysis/TRM providers — **`StubModel` default in fraud** → see Phase 4

### Phase 3 — Release & ops ⏳ NOT STARTED (unchanged from prior report)
16. **Reusable release workflow** (SBOM via syft + cosign image signing + SHA-tagged images); branch protection + CODEOWNERS.
17. **CVE scanning** (`govulncheck`, `npm audit --audit-level=high`, `pip-audit`, `bandit`, `cargo-audit`, Trivy) in all CI workflows.
18. **Finish UI services**:
    - ui-front-office: 51/52 tasks — signup, KYC wizard, quoting/checkout, dashboard, wallets, notifications, auth/session, error boundaries.
    - ui-middle-office: 52/53 tasks — KYC review queue, AML desk, policy dashboard, user mgmt, audit explorer, TanStack Query/Router, BFF proxy.
    - ui-back-office: dashboards thin, MPC monitor placeholder, no auth, clients carry no service token.
19. **Wire real third-party vendor API keys and drop `DEV_MODE=1`.** Per-service credential inventory (unchanged from prior report): kyt (`CHAINALYSIS/TRM_API_KEY`), kyc (`ONFIDO_API_TOKEN`), fraud (`MODEL_PATH`), notifier (SES/SNS/Twilio/FCM/APNS creds), orchestrator-fiat (rail/MPI provider keys), fx-hedger (FX provider key), engine-pricing (oracle key), gateway-exchange (venue API keys/secrets), gateway-blockchain (RPC URLs), mpc-signer (`CUSTODY_PROVIDER` + custody creds), wallet-manager (real xpubs), all gRPC services (`TLS_*_FILE` for mTLS).
20. **Runbooks** for 20 services.

### Phase 4 — Reopened Phase 1-2 residuals (NEW — from fresh audit)
> These are items the prior report marked complete but the fresh audit found incomplete or regressed.

21. **Make custody-provider the default in mpc-signer.** Set `CUSTODY_PROVIDER=fireblocks|dfns|turnkey` in compose; gate in-house threshold engine behind `DEV_MODE=1` or remove it. Authenticate control-plane RPCs (DKG/Rotate/Restore/GetKeyMetadata) with policy token. Wire HSM/attestation (not `MockHsmStore`). Run integration tests against real sandboxes. (src/engine/threshold/cluster.rs:171, src/grpc/service.rs:179, src/enclave/store.rs)
22. **Fix wallet-manager BTC/Solana withdrawal sighashes.** BTC: derive real P2WPKH pubkey hash from the wallet's xpub + derivation path (not 20-byte zero placeholder). Solana: fetch real recent blockhash from RPC; use real `from` pubkey (not `sha256(walletID)`). Without this, every BTC/Solana withdrawal is invalid. (internal/withdrawal/txbuilder.go:148,156,194,209)
23. **Add auth to 12 unauthenticated services.** Service-token JWT middleware (reuse the orchestrator-tx pattern) on: gateway-blockchain, gateway-exchange, gateway-fiat, orchestrator-treasury, engine-pricing, engine-liquidity, engine-fraud, engine-recon, fx-hedger, notifier, wallet-manager, kyc-onboarding. mpc-signer control-plane RPCs. accounting-ledger gRPC. audit-logger: replace `X-Audit-Roles` header with signed token. (cited per service above)
24. **Wire real adapters (not stubs) in prod path for 6 services:**
    - gateway-fiat: implement real rail connectors (ACH/SEPA/Card/Pix/UPI); remove `dummy/register.go` init; remove "not yet implemented" fatal.
    - gateway-exchange: wire `secrets.Manager` for venue credentials; remove "not yet implemented" fatal.
    - orchestrator-fiat: implement real rail + MPI clients (not `NewDummy()`).
    - engine-liquidity: wire real exchange gRPC client when `EXCHANGE_CONNECTORS_TARGET` set (not `FakeExchange`); wire real treasury/audit/recon clients.
    - engine-pricing: wire `SetFXClient`/`startFeedConsumer`/`SetPollHook`; use Postgres store in prod (not in-memory); fetch real spot rates from oracle.
    - fx-hedger: wire real FX provider in prod (not `provider.NewDummy()`); wire real `BankAdapter`/`VenueAdapter` when URLs set.
25. **Eliminate float64 on money paths in 5 services:** fx-hedger Postgres cols → NUMERIC + decimal; engine-liquidity `BookLevel.Price/Size` + slicer participation → decimal; engine-policy-risk USD caps → decimal; gateway-fiat ACH amount → decimal (remove `Float64()`+`int64(f+0.5)`); orchestrator-treasury config thresholds → decimal.
26. **Make ledger + audit-logger chain extension atomic.** Read `prev_hash`/`sequence_number` inside the insert transaction under `SERIALIZABLE` + advisory lock, or use `INSERT ... RETURNING` with a single `WITH` CTE. (accounting-ledger src/store.rs:761, audit-logger internal/ingest/ingest.go:152-208)
27. **Wire observability stack in compose.** Add Prometheus + Grafana + Loki + Tempo + OTel collector services; set `OTEL_EXPORTER_OTLP_ENDPOINT` + `OTEL_SERVICE_NAME` on every service. Prior report claimed this was done — it is not. (`.github/docker-compose.yml` — no such services present)
28. **Fix engine-recon defaults.** `enable_kafka` should default to `True` when `KAFKA_BROKERS` set (not `False`); `DB_URL` should fatal in prod when unset (not sqlite `:memory:`). (config.py:24,36)
29. **Fix engine-fraud defaults.** Remove `StubModel` as fallback; fatal in prod when `MODEL_PATH`/`MODEL_REGISTRY_URL` unset. Wire Kafka producer for audit (currently in-memory). Wire real `FeatureStoreClient` (not `InMemoryFeatureStore` default). (scoring.py:221, app.py:65,68)
30. **Fix gateway-auth password hashing.** Replace SHA-256 with Argon2id (or bcrypt). Make `JWT_SECRET` unset = fatal in prod. Add JWKS endpoint or migrate to RS256. Wire Kafka audit (currently in-memory only). (internal/crypto.go:46, config.go:22)
31. **Fix notifier Redis fallback.** Fatal in prod when `REDIS_URL` unset (not silent in-memory). Wire `EVENT_BUS_URL`/Kafka bus when `KAFKA_BROKERS` set (currently logs "not yet wired" and continues). (src/redis-runtime.ts:37, src/index.ts:47)
32. **Fix static `/readyz` in 6 services.** Add real dependency checks (DB/Redis/Kafka/vendor): orchestrator-treasury, orchestrator-tx, engine-fraud, engine-recon, gateway-auth, gateway-blockchain. (cited per service above)
33. **Fix orchestrator-treasury outbox.** Append outbox events inside the same DB transaction as the state change (not after commit). (app.go:162-163)
34. **Fix orchestrator-tx audit + payment + blockchain.** Dial audit partner (currently stub never replaced); implement real payment/blockchain adapters (currently stub-or-fatal). Wire OTel + `/metrics`. (main.go:87-88,125)
35. **Fix mpc-signer + wallet-manager gRPC TLS.** mpc `GrpcWalletClient` must use HTTPS + TLS (not `http://`); wallet-manager gRPC clients must use `credentials.NewTLS` (not `insecure.NewCredentials()` default). (src/wallet.rs:72, internal/clients/clients.go:38)
36. **Fix dockerfiles running as root.** gateway-fiat, gateway-exchange, fx-hedger, engine-recon, audit-logger → distroless nonroot or add `USER`.

### Phase 5 — Hardening (residuals carried from prior report)
37. **Regenerate all consumers from `.github/contracts/`** so runtime gRPC dials succeed field-by-field.
38. **Fix treasury→liquidity path mismatch** (`/v1/aggregate-orders` vs `/v1/parent-orders`).
39. **Wire Redis velocity counter** in engine-policy-risk; add KYC/fraud/KYT ingest endpoints once contracts regenerated.
40. **Wire gateway-blockchain mempool + real chain adapters** (not poll-based scaffolds).
41. **Wallet-manager balance int64 → decimal** migration.
42. **Ledger notary posting + SIEM sink** in audit-logger; real S3/KMS creds in prod.
43. **W3C `traceparent` propagation** as shared interceptor.
44. **Standardize migrations tooling** (`golang-migrate` for Go, Alembic for Python, `refinery`/`sqlx` for Rust); run as separate `migrate up` step.
45. **Kafka prod hardening** (3-broker, RF=3, explicit topic provisioning, longer audit retention); Postgres HA + PITR.
46. **Add Hurl E2E suites to CI.**
47. **Extract `platform-go` shared module** (logging, tracing, mtls, errors, kafka client) consumed by all Go services.
48. **Compose app healthchecks** (only postgres/redis/kafka have them today); `restart: unless-stopped`; resource limits; per-service networks.
49. **Schema versioning** on all non-audit event topics; schema registry.
50. **KYC document encryption at rest** (currently base64 in `object_key` column).

---

## What Actually Works (verified)

- **.github/contracts/** canonical proto + AsyncAPI definitions with buf lint + breaking CI.
- **.github/ docker-compose** local harness: 23 services boot, gatus monitors 25 endpoints, Makefile + Hurl + gen-token scripts.
- **accounting-ledger** invariants (balanced books, idempotency, hash chain with salt, immutability trigger, SERIALIZABLE) — correct when DB set; needs atomic chain extension.
- **orchestrator-tx saga mechanics**: outbox, `FOR UPDATE SKIP LOCKED` lease, recovery on boot, compensation cascade, tx+steps in one Postgres tx.
- **engine-liquidity** decimal on REST surface + slicer notional; real Kafka audit/recon producers with `RequireAll` acks.
- **gateway-blockchain** reorg re-broadcast + funding-confirmation wait + decimal money.
- **notifier** real provider SDKs + kafkajs + HMAC webhooks + Redis dedup + DLQ (when Redis/Kafka set).
- **engine-recon** `LedgerFetcher` + 3 match strategies + 4 break types + aging + DLQ.
- **kyc-onboarding** real Onfido adapter with HMAC webhooks + retries.
- **kyt-aml-screening** real Chainalysis/TRM with circuit breaker + idempotency + audit emitter.
- **mpc-signer** SignTx pipeline is fail-closed (policy token + wallet binding + replay protection + signed audit); custody adapters (Fireblocks/Dfns/Turnkey) implemented — just not default.
- **gateway-exchange** real Binance/Kraken connectors with HMAC signing + rate limits + decimal money.
- **audit-logger** real S3/KMS/Kafka adapters + Object Lock + verify-chain CLI + anchor job.
- **gateway-api** real undici+opossum downstream with per-service circuit breakers + Redis token-bucket limiter.

---

## Conclusion

The prior report's Phase 0-2 "completion" was overstated. The codebase has real adapters and stores, but many are **not wired into the prod path** — silent stub fallback, in-memory default, or "not yet implemented" fatal. 15/21 services lack auth. The custody core still defaults to private-key reconstruction. BTC/Solana withdrawals sign placeholder sighashes. The observability stack is absent from compose. Fresh audit aggregate: **4.9/10** (prior claimed 6.6/10).

**Revised estimated time to production-readiness: 4–6 weeks.** The highest-leverage fixes are: (1) make custody-provider default + fix BTC/Solana sighashes, (2) add auth to 12 services, (3) wire real adapters in the 6 stub-default services, (4) make ledger/audit chain extension atomic, (5) wire the observability stack in compose. The original Phase 3 (release/ops/UI/credentials/runbooks) remains.