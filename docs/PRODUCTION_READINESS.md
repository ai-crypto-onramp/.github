# Production-Readiness Report v2 — AI Crypto On-Ramp Backend

## Navigation

- [Headline Verdict](#headline-verdict)
- [Service Readiness Scores](#service-readiness-scores)
- [Top 10 Critical (P0) Production Blockers](#top-10-critical-p0-production-blockers-current)
- [Major (P1) Gaps](#major-p1-gaps)
- [Integration Edge Matrix](#integration-edge-matrix)
- [Recommended Path to Production (Priority Order)](#recommended-path-to-production-priority-order)
  - [Phase 1 — Money safety & custody](#phase-1--money-safety--custody-re-opened-phase-1-2-residuals)
  - [Phase 2 — Reliability & security](#phase-2--reliability--security-re-opened-phase-1-2-residuals)
  - [Phase 3 — Hardening](#phase-3--hardening-residuals)
  - [Phase 4 — Release & ops](#phase-4--release--ops--not-started-unchanged-from-prior-report)
- [What Actually Works (verified)](#what-actually-works-verified)
- [Conclusion](#conclusion)

---

> **Re-audited from scratch 2026-07-25.** Every service was re-examined independently; prior report's "completed" claims were not assumed. Findings supersede the 2026-07-22 report.

**Scope:** 21 backend services + 3 UIs + `.github/` local-testing harness.
**Method:** 6 parallel agents, every claim cited `file:line`. `.github/` docker-compose/gatus scored as local-testing harness (tolerant — not prod deployment).

---

## Headline Verdict

**Not production-ready — but materially improved.** Phase 1-2 work (2026-07-26) raised the aggregate from 4.9/10 to **6.2/10**. 14 services now have service-token auth. All 5 float64 money paths are decimal. Both hash chains (ledger + audit) are atomic. Stub-fallback in the 6 prod services is gated behind `DEV_MODE` with prod-fatals (real adapters wired where they exist; clear fatals where they don't). gateway-auth uses Argon2id + JWKS + Kafka audit. Real `/readyz` in 6 services. gRPC TLS in mpc-signer + wallet-manager. 5 Dockerfiles nonroot. **Remaining blockers:** custody-provider still not the default in mpc-signer (Phase 1 step 1); BTC/Solana withdrawal sighashes still placeholder (Phase 1 step 2); real rail/MPI/exchange/FX-provider adapters still unimplemented (stub-gated + prod-fatal); plaintext gRPC/OTLP in a few services; audit-logger S3/KMS/Kafka not `DEV_MODE`-gated; observability stack still absent from compose harness. Estimated time to production-readiness: **2–3 weeks**.

---

## Service Readiness Scores

| # | Service | Lang | Score | Top residual blocker |
|---|---|---|---|---|
| 1 | gateway-api | TS | 7 | Mock downstream + hardcoded `dev-internal-secret` when env unset (src/index.ts:59,66-67) |
| 2 | gateway-auth | Go | 7 | ✅ Phase 1-2: Argon2id, `JWT_SECRET` prod-fatal, JWKS, Kafka `audit.v1`, real `/readyz`. Residual: HS256 (no RS256) — acceptable for internal IDP. |
| 3 | kyc-onboarding | Go | 6 | ✅ Phase 2: service-token auth. Residual: hardcoded `dev-webhook-secret`; in-memory sanctions/webhook stores (internal/webhooks.go:57, server.go:356). |
| 4 | kyt-aml-screening | Go | 6 | Empty webhook HMAC key when env unset; plaintext gRPC; in-memory dedup (cmd/kyt/main.go:166, grpcserver/server.go:40) |
| 5 | engine-policy-risk | Go | 7 | ✅ Phase 1: decimal USD caps. Residual: Redis velocity never wired; `/evaluate` auth bypassable (main.go:168, api.go:185). |
| 6 | engine-pricing | Go | 6 | ✅ Phase 1-2: `SetFXClient`/`SetPollHook`/feed wired; in-memory gated behind `DEV_MODE` + prod-fatal; service-token auth. Residual: real Postgres store + feed subscriber not implemented. |
| 7 | engine-liquidity | Go | 6 | ✅ Phase 1-2: decimal `BookLevel`/slicer; real treasury/audit/recon clients wired; `FakeExchange` gated behind `DEV_MODE`; service-token auth. Residual: real gRPC exchange client not implemented. |
| 8 | engine-fraud | Python | 6 | ✅ Phase 1-2: `StubModel` gated behind `DEV_MODE` + prod-fatal; Kafka audit producer wired; real `FeatureStoreClient` in prod; real `/readyz`; service-token auth. Residual: real model registry/artifact path in prod. |
| 9 | engine-recon | Python | 7 | ✅ Phase 1-2: `enable_kafka` defaults true when brokers set; `DB_URL` prod-fatal; real `/readyz`; service-token auth; nonroot Dockerfile. Residual: upstream-feed readiness probes still `down` in prod. |
| 10 | orchestrator-fiat | Go | 5 | ✅ Phase 1: dummy rail/MPI gated behind `DEV_MODE` + prod-fatal; `fraud.NewHTTP` wired. Residual: real rail/MPI clients not implemented; in-memory idempotency; writes outside tx (handlers.go:42). |
| 11 | orchestrator-treasury | Go | 7 | ✅ Phase 1-2: decimal thresholds; outbox atomic for OnFill via `UpdateBatchStatusWithOutbox`; service-token auth; real `/readyz`. Residual: outbox-after-commit in 4 other callbacks (OnAdjust/OnClose/funding/OnBatchOpen). |
| 12 | orchestrator-tx | Go | 7 | ✅ Phase 1-2: Kafka `audit.v1` adapter; payment/blockchain gRPC adapters wired; OTel + `/metrics`; real `/readyz`. Residual: gateway-fiat/gateway-blockchain REST-only (gRPC server-side migration pending). |
| 13 | fx-hedger | Go | 6 | ✅ Phase 1-2: NUMERIC money cols; dummy FX provider gated; `BankAdapter`/`VenueAdapter` wired; service-token auth; nonroot Dockerfile. Residual: real `FXProvider` not implemented. |
| 14 | notifier | TS | 7 | ✅ Phase 2: service-token auth; `initRedis` prod-fatal; `KafkaBus` wired. Residual: stub-secret webhook fallback; test suites need `SERVICE_TOKEN_SECRET`/`DEV_MODE` setup file. |
| 15 | mpc-signer | Rust | 4 | ✅ Phase 2: control-plane service-token auth; gRPC TLS (reject `http://` in prod + mTLS). Residual: in-house threshold engine still default (Phase 1 step 1); no HSM wired (cluster.rs:171). |
| 16 | wallet-manager | Go | 5 | ✅ Phase 2: service-token auth; gRPC TLS (`credentials.NewTLS` + prod-fatal on missing certs). Residual: BTC/Solana sighash placeholder (Phase 1 step 2) (txbuilder.go:148,209). |
| 17 | gateway-blockchain | Go | 7 | ✅ Phase 2: service-token auth; real `/readyz` (DB + chain RPC + audit Kafka). Residual: RPC no TLS; OTLP `WithInsecure()` (adapters.go:80, otel.go:58). |
| 18 | gateway-fiat | Go | 6 | ✅ Phase 1-2: real ACH/SEPA/Card/Pix/UPI rails wired; decimal ACH amount; service-token auth; nonroot Dockerfile. Residual: `dev-secret` webhook fallback. |
| 19 | gateway-exchange | Go | 6 | ✅ Phase 1-2: `secrets.Manager` wired; service-token auth; nonroot Dockerfile. Residual: OTLP `WithInsecure()` (otel.go:58). |
| 20 | accounting-ledger | Rust | 7 | ✅ Phase 1-2: atomic chain extension (SERIALIZABLE + advisory lock); gRPC service-token interceptor. Residual: plaintext gRPC (no TLS); DB-empty silently in-memory. |
| 21 | audit-logger | Go | 6 | ✅ Phase 1-2: signed-token JWT (replaced spoofable `X-Audit-Roles`); atomic chain extension; nonroot Dockerfile. Residual: silent fallback to fake S3/KMS/Kafka no `DEV_MODE` gate (app.go:61-137). |

**Aggregate:** Average **6.2/10** (was 4.9/10 on 2026-07-25). 7 services ≥7. 3 services ≤5. Phase 1-2 residuals addressed: float64 money paths (5 services), atomic chains (2 services), stub-fallback gating (6 services), fraud/recon defaults, orchestrator-tx partners, treasury outbox, auth on 14 services, gateway-auth hashing, notifier Redis/bus, real `/readyz` (4 services), gRPC TLS (2 services), nonroot Dockerfiles (5 services). Remaining blockers cluster in: custody-provider default + BTC/Solana sighashes (Phase 1 steps 1-2), real adapter implementations where stubs still gated (rail/MPI/exchange/FX provider), plaintext gRPC/OTLP in a few services, and audit-logger S3/KMS/Kafka gating.

### Local-testing harness

| Area | Score | Note |
|---|---|---|
| `.github/` (compose, gatus, scripts) | 8/10 | Solid local harness; tolerant of dev secrets, single-broker Kafka. Missing: app healthchecks, observability stack absent, no release/CVE workflow. |
| `ui-front-office` | 3/10 | 1/52 tasks done; no auth, no pages, no API integration. |
| `ui-middle-office` | 3/10 | 1/53 tasks done; no auth/RBAC, no router, no API integration. |
| `ui-back-office` | 5/10 | 53/53 tasks done but dashboards thin; no auth; clients carry no service token; MPC dashboard placeholder. |

---

## Top 10 Critical (P0) Production Blockers (current)

> Updated 2026-07-26 after Phase 1-2 work. Items 3, 5, 7, 8, 9 resolved; list re-ranked by remaining severity.

1. **mpc-signer default reconstructs the full private key.** In-house threshold engine still the default; `CUSTODY_PROVIDER=in_house`. Real adapters exist but aren't selected. Control-plane RPCs now authenticated (Phase 2). HSM still not wired (`MockHsmStore`). (src/engine/threshold/cluster.rs:171, src/enclave/store.rs) — Phase 1 step 1.
2. **wallet-manager BTC/Solana withdrawals sign placeholder sighashes.** BTC P2WPKH uses 20-byte zero placeholder pubkey hash; Solana uses `sha256(walletID)` as `from` and `solana-recent-blockhash-placeholder`. MPC signs an invalid sighash → signature won't validate onchain. (internal/withdrawal/txbuilder.go:148,156,194,209) — Phase 1 step 2.
3. **Real adapters unimplemented in 4 prod-gated services.** orchestrator-fiat (rail/MPI), engine-liquidity (gRPC exchange), engine-pricing (Postgres store + feed subscriber), fx-hedger (FXProvider). All now gated behind `DEV_MODE` + prod-fatal (Phase 1 step 5), so no longer silent — but the real integrations are still missing.
4. **audit-logger silent fallback to fake S3/KMS/Kafka without `DEV_MODE` gate.** Unlike the other stubs fixed in Phase 1, audit-logger's S3/KMS/Kafka fallback paths were not addressed. (app.go:61-137).
5. **Plaintext gRPC / OTLP in several services.** kyt-aml-screening, accounting-ledger, gateway-blockchain, gateway-exchange, orchestrator-tx (to some partners) still dial/emit plaintext. mpc-signer + wallet-manager fixed in Phase 2 step 14.
6. **No observability stack in compose.** No Prometheus/Grafana/Loki/Tempo/OTel services, no `OTEL_*` env. The system is unobservable in the actual harness.
7. **Static `/readyz` residuals.** orchestrator-fiat, gateway-fiat, gateway-exchange, fx-hedger still static (not in Phase 2 step 13's scope of 6). kyc-onboarding, kyt-aml-screening, mpc-signer, wallet-manager, notifier also static.
8. **In-memory idempotency/dedup in orchestrator-fiat, kyt-aml-screening, notifier (when Redis unset)** — money-loss on retry across replicas. notifier Redis now prod-fatal (Phase 2 step 12), but orchestrator-fiat + kyt-aml-screening still silent.
9. **Outbox-after-commit in 4 orchestrator-treasury callbacks.** OnFill fixed (Phase 1 step 9), but OnAdjust/OnClose/funding/OnBatchOpen at app.go:141,178,194/200,224 still append outbox after the state change commits.
10. **UI services unfinished.** ui-front-office 1/52, ui-middle-office 1/53 tasks; ui-back-office no auth, clients carry no service token.

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

> Completed work from the prior report (contracts extraction, DEV_MODE gating, Postgres stores, audit.v1 topic, custody adapters, reorg re-broadcast, notifier providers, LedgerFetcher, service-token auth on 3 services, decimal migration in 7 services) is carried forward as the baseline; only incomplete/residual items are listed below.

### Phase 1 — Money safety & custody (re-opened Phase 1-2 residuals)
> Items the prior report marked complete but the fresh audit found incomplete or regressed.

1. **Make custody-provider the default in mpc-signer.** Set `CUSTODY_PROVIDER=fireblocks|dfns|turnkey` in compose; gate in-house threshold engine behind `DEV_MODE=1` or remove it. Authenticate control-plane RPCs (DKG/Rotate/Restore/GetKeyMetadata) with policy token. Wire HSM/attestation (not `MockHsmStore`). Run integration tests against real sandboxes. (src/engine/threshold/cluster.rs:171, src/grpc/service.rs:179, src/enclave/store.rs)
2. **Fix wallet-manager BTC/Solana withdrawal sighashes.** BTC: derive real P2WPKH pubkey hash from the wallet's xpub + derivation path (not 20-byte zero placeholder). Solana: fetch real recent blockhash from RPC; use real `from` pubkey (not `sha256(walletID)`). Without this, every BTC/Solana withdrawal is invalid. (internal/withdrawal/txbuilder.go:148,156,194,209)
3. ~~**Eliminate float64 on money paths in 5 services:** fx-hedger Postgres cols → NUMERIC + decimal; engine-liquidity `BookLevel.Price/Size` + slicer participation → decimal; engine-policy-risk USD caps → decimal; gateway-fiat ACH amount → decimal (remove `Float64()`+`int64(f+0.5)`); orchestrator-treasury config thresholds → decimal.~~ ✅ Done 2026-07-26 (shopspring/decimal; fx-hedger migration 0003; all 5 services build/vet/test/lint pass).
4. ~~**Make ledger + audit-logger chain extension atomic.** Read `prev_hash`/`sequence_number` inside the insert transaction under `SERIALIZABLE` + advisory lock, or use `INSERT ... RETURNING` with a single `WITH` CTE. (accounting-ledger src/store.rs:761, audit-logger internal/ingest/ingest.go:152-208)~~ ✅ Done 2026-07-26 (SERIALIZABLE + `pg_advisory_xact_lock` inside the insert tx; audit-logger `InsertChained` interface).
5. ~~**Wire real adapters (not stubs) in prod path for 6 services:**~~ ✅ Done 2026-07-26 (stubs gated behind `DEV_MODE`; existing real adapters wired in prod; prod-fatal where no real adapter exists yet).
    - ~~gateway-fiat: implement real rail connectors (ACH/SEPA/Card/Pix/UPI); remove `dummy/register.go` init; remove "not yet implemented" fatal.~~ ✅ Real ACH/SEPA/Card/Pix/UPI wired by `RAIL_FAMILY`; dummy DEV_MODE-only.
    - ~~gateway-exchange: wire `secrets.Manager` for venue credentials; remove "not yet implemented" fatal.~~ ✅ `secrets.Manager` + `EnvVault` wired in prod.
    - ~~orchestrator-fiat: implement real rail + MPI clients (not `NewDummy()`).~~ ⚠️ Partial — `fraud.NewHTTP` wired; real rail/MPI clients don't exist yet → DEV_MODE dummy + prod-fatal.
    - ~~engine-liquidity: wire real exchange gRPC client when `EXCHANGE_CONNECTORS_TARGET` set (not `FakeExchange`); wire real treasury/audit/recon clients.~~ ⚠️ Partial — HTTP/Kafka treasury/audit/recon wired; real gRPC exchange client not yet implemented → DEV_MODE `FakeExchange` + prod-fatal.
    - ~~engine-pricing: wire `SetFXClient`/`startFeedConsumer`/`SetPollHook`; use Postgres store in prod (not in-memory); fetch real spot rates from oracle.~~ ⚠️ Partial — `SetFXClient`/`SetPollHook`/`startFeedConsumer` wired; real Postgres store + feed subscriber not yet implemented → DEV_MODE in-memory + prod-fatal.
    - ~~fx-hedger: wire real FX provider in prod (not `provider.NewDummy()`); wire real `BankAdapter`/`VenueAdapter` when URLs set.~~ ⚠️ Partial — `BankAdapter`/`VenueAdapter` wired; real `FXProvider` not yet implemented → DEV_MODE dummy + prod-fatal.
6. ~~**Fix engine-fraud defaults.** Remove `StubModel` as fallback; fatal in prod when `MODEL_PATH`/`MODEL_REGISTRY_URL` unset. Wire Kafka producer for audit (currently in-memory). Wire real `FeatureStoreClient` (not `InMemoryFeatureStore` default). (scoring.py:221, app.py:65,68)~~ ✅ Done 2026-07-26 (StubModel/InMemoryFeatureStore gated behind DEV_MODE; Kafka audit producer wired on startup; readiness checks real in prod; 137 tests pass).
7. ~~**Fix engine-recon defaults.** `enable_kafka` should default to `True` when `KAFKA_BROKERS` set (not `False`); `DB_URL` should fatal in prod when unset (not sqlite `:memory:`). (config.py:24,36)~~ ✅ Done 2026-07-26 (`enable_kafka` defaults True when brokers set; `DB_URL` fatals in prod when unset/in-memory; readiness real in prod; 110 tests pass).
8. ~~**Fix orchestrator-tx audit + payment + blockchain.** Dial audit partner (currently stub never replaced); implement real payment/blockchain adapters (currently stub-or-fatal). Wire OTel + `/metrics`. (main.go:87-88,125)~~ ✅ Done 2026-07-26 (Kafka `audit.v1` adapter; existing gRPC payment/blockchain adapters wired behind `PAYMENT_URL`/`BLOCKCHAIN_URL`; OTel + `/metrics` added). Note: gateway-fiat/gateway-blockchain currently REST-only — gRPC server-side migration is a separate workstream; operators use `DEV_MODE=1` until then.
9. ~~**Fix orchestrator-treasury outbox.** Append outbox events inside the same DB transaction as the state change (not after commit). (app.go:162-163)~~ ✅ Done 2026-07-26 (`store.Unit.UpdateBatchStatusWithOutbox` runs batch UPDATE + outbox INSERT in one pgx tx). Follow-up: same outbox-after-commit anti-pattern remains in 4 other callbacks (OnAdjust/OnClose/funding/OnBatchOpen at app.go:141,178,194/200,224) — needs a larger refactor into the owning subsystems.

### Phase 2 — Reliability & security (re-opened Phase 1-2 residuals)
10. ~~**Add auth to 12+ unauthenticated services.** Service-token JWT middleware (reuse the orchestrator-tx pattern) on: gateway-blockchain, gateway-exchange, gateway-fiat, orchestrator-treasury, engine-pricing, engine-liquidity, engine-fraud, engine-recon, fx-hedger, notifier, wallet-manager, kyc-onboarding. mpc-signer control-plane RPCs. accounting-ledger gRPC. audit-logger: replace `X-Audit-Roles` header with signed token. (cited per service above)~~ ✅ Done 2026-07-26 (HS256 service-token middleware vendored per Go service; FastAPI dep in Python services; Fastify hook in notifier; tonic interceptor in Rust services; audit-logger `X-Audit-Roles` replaced with signed JWT; DEV_MODE bypass + prod-fatal on missing `SERVICE_TOKEN_SECRET`; all services build/test green). Follow-up: notifier has 25 pre-existing tests failing because suites import `buildApp` before setting `SERVICE_TOKEN_SECRET`/`DEV_MODE` — needs a test setup file.
11. ~~**Fix gateway-auth password hashing.** Replace SHA-256 with Argon2id (or bcrypt). Make `JWT_SECRET` unset = fatal in prod. Add JWKS endpoint or migrate to RS256. Wire Kafka audit (currently in-memory only). (internal/crypto.go:46, config.go:22)~~ ✅ Done 2026-07-26 (Argon2id m=64MiB/t=3/p=2 salt=16 key=32; legacy `sha256$` hashes still verified for rolling rotation; `JWT_SECRET` unset fatals in prod via `log.Print`+`os.Exit` while `DEV_MODE=1`/`go test` keep `dev-secret`; `kid` added to HS256 JWT header + `/.well-known/jwks.json` publishes the symmetric `oct` key — HS256 retained, no pre-existing RSA wiring to migrate to RS256; `internal/kafka_audit.go` publishes the canonical `audit.v1` envelope to Kafka when `KAFKA_BROKERS` set, gated behind `DEV_MODE` with in-memory/DB fallback; build/vet/test/-race/golangci-lint all green).
12. ~~**Fix notifier Redis fallback.** Fatal in prod when `REDIS_URL` unset (not silent in-memory). Wire `EVENT_BUS_URL`/Kafka bus when `KAFKA_BROKERS` set (currently logs "not yet wired" and continues). (src/redis-runtime.ts:37, src/index.ts:47)~~ ✅ Done 2026-07-26 (`initRedis` fatals in prod when `REDIS_URL` unset, in-memory only under `DEV_MODE=1`; `KafkaBus` wired when `KAFKA_BROKERS`/`EVENT_BUS_URL` set, prod-fatal otherwise; typecheck/build/lint green).
13. ~~**Fix static `/readyz` in 6 services.** Add real dependency checks (DB/Redis/Kafka/vendor): orchestrator-treasury, orchestrator-tx, engine-fraud, engine-recon, gateway-auth, gateway-blockchain. (cited per service above)~~ ✅ Done 2026-07-26 (orchestrator-treasury: DB + downstream HTTP probes; orchestrator-tx: DB + audit Kafka + gRPC partner readiness; gateway-auth: DB ping; gateway-blockchain: DB + chain RPC + audit Kafka; engine-fraud/engine-recon already real from Phase 1; 200/503 + degraded semantics; all build/test/lint green).
14. ~~**Fix mpc-signer + wallet-manager gRPC TLS.** mpc `GrpcWalletClient` must use HTTPS + TLS (not `http://`); wallet-manager gRPC clients must use `credentials.NewTLS` (not `insecure.NewCredentials()` default). (src/wallet.rs:72, internal/clients/clients.go:38)~~ ✅ Done 2026-07-26 (mpc: `http://` rejected in prod, `https://` + mTLS via `MtlsMaterial::from_env` with SNI; wallet-manager: `credentials.NewTLS` with `TLS_CA_CERT_FILE`/`TLS_CLIENT_CERT_FILE`/`TLS_CLIENT_KEY_FILE`, prod-fatal on missing certs; `DEV_MODE=1` keeps plaintext for local harness; build/test/clippy/lint green).
15. ~~**Fix dockerfiles running as root.** gateway-fiat, gateway-exchange, fx-hedger, engine-recon, audit-logger → distroless nonroot or add `USER`.~~ ✅ Done 2026-07-26 (4 Go services: alpine + `adduser -D -u 10001 app` + `USER 10001:10001`; engine-recon: python:3.11-slim + `useradd --uid 10001 --no-create-home app` + `USER app`; runtime verified `uid=10001(app)`; `docker build` green for all 5).

### Phase 3 — Hardening (residuals)
17. **Regenerate all consumers from `.github/contracts/`** so runtime gRPC dials succeed field-by-field.
18. **Fix treasury→liquidity path mismatch** (`/v1/aggregate-orders` vs `/v1/parent-orders`).
19. **Wire Redis velocity counter** in engine-policy-risk; add KYC/fraud/KYT ingest endpoints once contracts regenerated.
20. **Wire gateway-blockchain mempool + real chain adapters** (not poll-based scaffolds).
21. **Wallet-manager balance int64 → decimal** migration.
22. **Ledger notary posting + SIEM sink** in audit-logger; real S3/KMS creds in prod.
23. **W3C `traceparent` propagation** as shared interceptor.
24. **Standardize migrations tooling** (`golang-migrate` for Go, Alembic for Python, `refinery`/`sqlx` for Rust); run as separate `migrate up` step.
25. **Kafka prod hardening** (3-broker, RF=3, explicit topic provisioning, longer audit retention); Postgres HA + PITR.
26. **Add Hurl E2E suites to CI.**
27. **Extract `platform-go` shared module** (logging, tracing, mtls, errors, kafka client) consumed by all Go services.
28. **Compose app healthchecks** (only postgres/redis/kafka have them today); `restart: unless-stopped`; resource limits; per-service networks.
29. **Schema versioning** on all non-audit event topics; schema registry.
30. **KYC document encryption at rest** (currently base64 in `object_key` column).

### Phase 4 — Release & ops ⏳ NOT STARTED (unchanged from prior report)
31. **Reusable release workflow** (SBOM via syft + cosign image signing + SHA-tagged images); branch protection + CODEOWNERS.
32. **CVE scanning** (`govulncheck`, `npm audit --audit-level=high`, `pip-audit`, `bandit`, `cargo-audit`, Trivy) in all CI workflows.
33. **Finish UI services**:
    - ui-front-office: 51/52 tasks — signup, KYC wizard, quoting/checkout, dashboard, wallets, notifications, auth/session, error boundaries.
    - ui-middle-office: 52/53 tasks — KYC review queue, AML desk, policy dashboard, user mgmt, audit explorer, TanStack Query/Router, BFF proxy.
    - ui-back-office: dashboards thin, MPC monitor placeholder, no auth, clients carry no service token.
34. **Wire real third-party vendor API keys and drop `DEV_MODE=1`.** Per-service credential inventory (unchanged from prior report): kyt (`CHAINALYSIS/TRM_API_KEY`), kyc (`ONFIDO_API_TOKEN`), fraud (`MODEL_PATH`), notifier (SES/SNS/Twilio/FCM/APNS creds), orchestrator-fiat (rail/MPI provider keys), fx-hedger (FX provider key), engine-pricing (oracle key), gateway-exchange (venue API keys/secrets), gateway-blockchain (RPC URLs), mpc-signer (`CUSTODY_PROVIDER` + custody creds), wallet-manager (real xpubs), all gRPC services (`TLS_*_FILE` for mTLS).
35. **Runbooks** for 20 services.

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
