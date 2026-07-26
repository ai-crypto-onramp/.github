# Production-Readiness Report v3 — AI Crypto On-Ramp Backend

> **Flattened 2026-07-26.** All completed items from v1/v2 removed. Scores, edges, and phases rebuilt from scratch against the current codebase state. Supersedes v1 (2026-07-22) and v2 (2026-07-25).

**Scope:** 21 backend services + 3 UIs + `.github/` local-testing harness.

---

## Headline Verdict

**Not production-ready.** Aggregate score **6.8/10** (was 4.9 at v2 audit). 21 items were completed across Phases 1-3 (float64→decimal, atomic chains, auth on 14 services, Argon2id, readyz, gRPC TLS, nonroot Dockerfiles, proto regeneration, velocity counter, mempool monitoring, treasury path fix, wallet decimal). **Remaining blockers:** custody-provider still defaults to in-house threshold signing (private-key reconstruction); BTC/Solana withdrawals sign placeholder sighashes; 4 real adapter implementations still missing (stub-gated + prod-fatal, not silent); audit-logger S3/KMS/Kafka fallback not `DEV_MODE`-gated; plaintext gRPC/OTLP in 5 services; observability stack absent from compose; 9 services still have static `/readyz`; in-memory idempotency in 2 money-moving services; outbox-after-commit in 4 treasury callbacks; UI services unfinished. Estimated time to production-readiness: **2–3 weeks**.

---

## Service Readiness Scores

| # | Service | Lang | Score | Top residual blocker |
|---|---|---|---|---|
| 1 | gateway-api | TS | 7 | Mock downstream + hardcoded `dev-internal-secret` when env unset (src/index.ts:59,66-67) |
| 2 | gateway-auth | Go | 8 | HS256 only (no RS256) — acceptable for internal IDP; all else fixed (Argon2id, JWKS, Kafka audit, real readyz) |
| 3 | kyc-onboarding | Go | 6 | Hardcoded `dev-webhook-secret`; in-memory sanctions/webhook stores (internal/webhooks.go:57, server.go:356) |
| 4 | kyt-aml-screening | Go | 6 | Empty webhook HMAC key when env unset; plaintext gRPC; in-memory dedup (cmd/kyt/main.go:166, grpcserver/server.go:40) |
| 5 | engine-policy-risk | Go | 8 | None critical — Redis velocity counter wired, ingest endpoints added, decimal caps, auth, canonical proto |
| 6 | engine-pricing | Go | 6 | Real Postgres store + feed subscriber not implemented (in-memory gated behind `DEV_MODE` + prod-fatal) |
| 7 | engine-liquidity | Go | 7 | Real gRPC exchange client not implemented (`FakeExchange` gated behind `DEV_MODE` + prod-fatal) |
| 8 | engine-fraud | Python | 7 | Real model registry/artifact path in prod (StubModel gated behind `DEV_MODE` + prod-fatal; Kafka audit + FeatureStoreClient wired) |
| 9 | engine-recon | Python | 8 | Upstream-feed readiness probes still report `down` in prod (all core defaults fixed; nonroot) |
| 10 | orchestrator-fiat | Go | 5 | Real rail/MPI clients not implemented (dummy gated + prod-fatal); in-memory idempotency; writes outside tx (handlers.go:42) |
| 11 | orchestrator-treasury | Go | 7 | Outbox-after-commit in 4 callbacks (OnAdjust/OnClose/funding/OnBatchOpen at app.go:141,178,194/200,224) |
| 12 | orchestrator-tx | Go | 8 | gateway-fiat/gateway-blockchain REST-only — gRPC server-side migration pending (gRPC adapters wired, stub mode in harness) |
| 13 | fx-hedger | Go | 6 | Real `FXProvider` not implemented (dummy gated + prod-fatal; `BankAdapter`/`VenueAdapter` wired; NUMERIC cols; nonroot) |
| 14 | notifier | TS | 7 | Stub-secret webhook fallback (Redis prod-fatal; KafkaBus wired; auth added) |
| 15 | mpc-signer | Rust | 5 | In-house threshold engine still default (private-key reconstruction); no HSM wired — `MockHsmStore` (cluster.rs:171, enclave/store.rs) |
| 16 | wallet-manager | Go | 6 | BTC/Solana sighash uses placeholder pubkey/blockhash (txbuilder.go:148,209) — every BTC/Solana withdrawal is invalid |
| 17 | gateway-blockchain | Go | 8 | RPC no TLS; OTLP `WithInsecure()` (adapters.go:80, otel.go:58) — mempool + real chain adapters now wired |
| 18 | gateway-fiat | Go | 7 | `dev-secret` webhook fallback (real ACH/SEPA/Card/Pix/UPI rails wired; decimal; auth; nonroot) |
| 19 | gateway-exchange | Go | 7 | OTLP `WithInsecure()` (otel.go:58) — `secrets.Manager` wired; auth; nonroot |
| 20 | accounting-ledger | Rust | 8 | Plaintext gRPC (no TLS); DB-empty silently in-memory (atomic chain; `PostDoubleEntry` added; gRPC auth) |
| 21 | audit-logger | Go | 6 | Silent fallback to fake S3/KMS/Kafka without `DEV_MODE` gate (app.go:61-137) — signed JWT + atomic chain done |

**Aggregate:** Average **6.8/10** (was 4.9 at v2, 6.2 after Phase 1-2). 8 services ≥7. 2 services ≤5. Remaining blockers cluster in: custody-provider default + BTC/Solana sighashes (P0), real adapter implementations (4 services), audit-logger S3/KMS/Kafka gating, plaintext gRPC/OTLP, observability stack, static `/readyz` residuals, in-memory idempotency, treasury outbox residuals, UI.

### Local-testing harness

| Area | Score | Note |
|---|---|---|
| `.github/` (compose, gatus, scripts) | 8/10 | 34 Hurl E2E suites all passing; gatus monitors 25 endpoints; gen-token mints reader + admin tokens. Missing: app healthchecks, observability stack, no release/CVE workflow. |
| `ui-front-office` | 3/10 | 1/52 tasks done; no auth, no pages, no API integration. |
| `ui-middle-office` | 3/10 | 1/53 tasks done; no auth/RBAC, no router, no API integration. |
| `ui-back-office` | 5/10 | 53/53 tasks done but dashboards thin; no auth; clients carry no service token; MPC dashboard placeholder. |

---

## Top 10 Critical (P0) Production Blockers

1. **mpc-signer default reconstructs the full private key.** In-house threshold engine still the default; `CUSTODY_PROVIDER=in_house`. Real adapters (Fireblocks/Dfns/Turnkey) exist but aren't selected. HSM not wired (`MockHsmStore`). Control-plane RPCs now authenticated. (src/engine/threshold/cluster.rs:171, src/enclave/store.rs)
2. **wallet-manager BTC/Solana withdrawals sign placeholder sighashes.** BTC P2WPKH uses 20-byte zero placeholder pubkey hash; Solana uses `sha256(walletID)` as `from` and `solana-recent-blockhash-placeholder`. MPC signs an invalid sighash → signature won't validate onchain. (internal/withdrawal/txbuilder.go:148,156,194,209)
3. **Real adapters unimplemented in 4 prod-gated services.** orchestrator-fiat (rail/MPI), engine-liquidity (gRPC exchange), engine-pricing (Postgres store + feed subscriber), fx-hedger (FXProvider). All gated behind `DEV_MODE` + prod-fatal — no longer silent, but the real integrations are missing.
4. **audit-logger silent fallback to fake S3/KMS/Kafka without `DEV_MODE` gate.** Unlike the other stubs fixed in Phase 1, audit-logger's S3/KMS/Kafka fallback paths were not addressed. (app.go:61-137)
5. **Plaintext gRPC / OTLP in 5 services.** kyt-aml-screening, accounting-ledger, gateway-blockchain, gateway-exchange, orchestrator-tx (to some partners) still dial/emit plaintext. mpc-signer + wallet-manager fixed.
6. **No observability stack in compose.** No Prometheus/Grafana/Loki/Tempo/OTel services, no `OTEL_*` env. The system is unobservable in the actual harness.
7. **Static `/readyz` in 9 services.** orchestrator-fiat, gateway-fiat, gateway-exchange, fx-hedger, kyc-onboarding, kyt-aml-screening, mpc-signer, wallet-manager, notifier still return unconditional 200 OK.
8. **In-memory idempotency/dedup in orchestrator-fiat + kyt-aml-screening** (when Redis unset) — money-loss on retry across replicas. notifier Redis now prod-fatal.
9. **Outbox-after-commit in 4 orchestrator-treasury callbacks.** OnFill fixed, but OnAdjust/OnClose/funding/OnBatchOpen at app.go:141,178,194/200,224 still append outbox after the state change commits.
10. **UI services unfinished.** ui-front-office 1/52, ui-middle-office 1/53 tasks; ui-back-office no auth, clients carry no service token.

---

## Major (P1) Gaps

- **Hardcoded `dev-webhook-secret` in kyc-onboarding** (internal/webhooks.go:57) — webhook spoofing in prod.
- **In-memory sanctions/webhook stores in kyc-onboarding** (server.go:356) — not durable.
- **No release pipeline** — no SBOM, cosign, SHA tags, CODEOWNERS, branch protection.
- **No CVE scanning** except mpc-signer (cargo-deny/audit).
- **No runbooks** for 20/21 services (only mpc-signer).
- **No shared Go module** — 15 separate `go.mod`, no shared logging/auth/otel library (auth middleware vendored 10x).
- **Hurl E2E suites not in CI** (run manually via `make test` only).
- **No schema versioning** on non-audit event topics; no schema registry.
- **KYC document encryption at rest** — currently base64 in `object_key` column.
- **Migrations tooling non-standard** — no `golang-migrate`/Alembic/`refinery`; run ad-hoc.
- **Kafka single-broker in compose** — no RF=3, no explicit topic provisioning, no retention config.
- **Postgres single instance** — no HA, no PITR.

---

## Integration Edge Matrix

| Edge | Contract | Call | Tested | Status |
|---|---|---|---|---|
| txo → policy | ✅ canonical | ✅ gRPC | ✅ Hurl | ✅ Working (proto regenerated, canonical `Money`) |
| txo → kyt | ✅ canonical | ✅ gRPC | ✅ Hurl | ✅ Working (proto regenerated) |
| txo → mpc | ✅ canonical | ✅ gRPC | ✅ Hurl | ✅ Working (proto regenerated) |
| txo → ledger | ✅ canonical | ✅ gRPC | ✅ Hurl | ✅ Working (`PostDoubleEntry` added, proto regenerated) |
| txo → payment | ✅ canonical | ⚠️ gRPC dial | ✗ | ⚠️ Adapter wired but gateway-fiat is REST-only — gRPC server-side migration pending |
| txo → blockchain | ✅ canonical | ⚠️ gRPC dial | ✗ | ⚠️ Adapter wired but gateway-blockchain is REST-only — gRPC server-side migration pending |
| txo → audit | ✅ audit.v1 | ✅ Kafka | ✅ Hurl | ✅ Working (Kafka `audit.v1` adapter) |
| payment → rails | ✅ | ✅ real | ✅ Hurl | ✅ Working (real ACH/SEPA/Card/Pix/UPI in gateway-fiat) |
| payment → fraud | ✅ | ✅ HTTP | ✗ | ✅ Working (`fraud.NewHTTP` in orchestrator-fiat) |
| treasury → liquidity | ✅ | ✅ HTTP | ✅ Hurl | ✅ Working (path fixed `/v1/parent-orders`) |
| treasury → wallet | ✅ REST | ✅ HTTP | ✅ Hurl | ✅ Working |
| liquidity → exchange | ✅ | ⚠️ FakeExchange | ✗ | ⚠️ Stub-gated + prod-fatal; real gRPC exchange client not implemented |
| blockchain → wallet | ✅ REST | ✅ HTTP | ✅ Hurl | ✅ Working |
| mpc → wallet | ✅ gRPC | ✅ TLS | partial | ✅ Working (TLS wired; no E2E TLS handshake test) |
| all → notifier | ✅ notifier.v1 | ✅ Kafka | ✅ Hurl | ✅ Working (KafkaBus wired) |
| all → audit | ✅ audit.v1 | ⚠️ mixed | ✅ Hurl | ⚠️ Kafka in prod for most; audit-logger S3/KMS/Kafka fallback not gated |
| ledger → recon | ✅ ledger.events.v1 | ✅ Kafka | ✅ Hurl | ✅ Working (`enable_kafka` defaults true when brokers set) |

**Summary:** 13/17 edges fully working; 2 edges pending gRPC server-side migration (REST-only producers); 1 edge stub-gated (real client not implemented); 1 edge mixed (audit-logger fallback not gated). Was 6/16 at v2 audit.

---

## Recommended Path to Production

### Phase 1 — Custody & money safety (P0)

1. **Make custody-provider the default in mpc-signer.** Set `CUSTODY_PROVIDER=fireblocks|dfns|turnkey` in compose; gate in-house threshold engine behind `DEV_MODE=1` or remove it. Wire HSM/attestation (not `MockHsmStore`). Run integration tests against real sandboxes. (src/engine/threshold/cluster.rs:171, src/enclave/store.rs)

### Phase 2 — Transport security & observability

6. **Fix kyc-onboarding `dev-webhook-secret` + in-memory stores.** Fatal in prod when `WEBHOOK_SECRET` unset; use Postgres for sanctions/webhook stores.
7. **TLS all gRPC + OTLP connections.** kyt-aml-screening, accounting-ledger, gateway-blockchain, gateway-exchange, orchestrator-tx partner dials. Load certs from `TLS_*_FILE` envs; `DEV_MODE=1` keeps plaintext for harness.
8. **Fix static `/readyz` in 9 services.** Add real dependency checks: orchestrator-fiat, gateway-fiat, gateway-exchange, fx-hedger, kyc-onboarding, kyt-aml-screening, mpc-signer, wallet-manager, notifier.
9. **Standardize migrations tooling** (`golang-migrate` for Go, Alembic for Python, `refinery`/`sqlx` for Rust); run as separate `migrate up` step.
10. **Extract `platform-go` shared module** (logging, tracing, mtls, errors, kafka client, authtoken) consumed by all Go services — eliminates 10x vendored auth middleware.
11. **Schema versioning** on all non-audit event topics; schema registry.


### Phase 3 — Hardening

12. **Ledger notary posting + SIEM sink** in audit-logger; real S3/KMS creds in prod.
13. **W3C `traceparent` propagation** as shared interceptor across all services.
14. **Compose app healthchecks + `restart: unless-stopped` + resource limits + per-service networks.** Only postgres/redis/kafka have healthchecks today.
17. **KYC document encryption at rest** (currently base64 in `object_key` column).

### Phase 4 — Release & ops

20. **Reusable release workflow** (SBOM via syft + cosign image signing + SHA-tagged images); branch protection + CODEOWNERS.
21. **CVE scanning** (`govulncheck`, `npm audit --audit-level=high`, `pip-audit`, `bandit`, `cargo-audit`, Trivy) in all CI workflows.
22. **Finish UI services:**
    - ui-front-office: 51/52 tasks — signup, KYC wizard, quoting/checkout, dashboard, wallets, notifications, auth/session, error boundaries.
    - ui-middle-office: 52/53 tasks — KYC review queue, AML desk, policy dashboard, user mgmt, audit explorer, TanStack Query/Router, BFF proxy.
    - ui-back-office: dashboards thin, MPC monitor placeholder, no auth, clients carry no service token.
23. **Wire real third-party vendor API keys and drop `DEV_MODE=1`.** Per-service credential inventory: kyt (`CHAINALYSIS/TRM_API_KEY`), kyc (`ONFIDO_API_TOKEN`), fraud (`MODEL_PATH`), notifier (SES/SNS/Twilio/FCM/APNS creds), orchestrator-fiat (rail/MPI provider keys), fx-hedger (FX provider key), engine-pricing (oracle key), gateway-exchange (venue API keys/secrets), gateway-blockchain (RPC URLs), mpc-signer (`CUSTODY_PROVIDER` + custody creds), wallet-manager (real xpubs), all gRPC services (`TLS_*_FILE` for mTLS).
24. **Runbooks** for 20 services.

---

## What Actually Works (verified)

- **.github/contracts/** canonical proto + AsyncAPI definitions with buf lint + breaking CI; all consumers regenerated.
- **.github/ docker-compose** local harness: 23 services boot, gatus monitors 25 endpoints, 34 Hurl E2E suites pass, gen-token mints reader + admin JWTs.
- **accounting-ledger** invariants (balanced books, idempotency, hash chain with salt, immutability trigger, SERIALIZABLE) + atomic chain extension + `PostDoubleEntry` RPC.
- **orchestrator-tx saga mechanics**: outbox, `FOR UPDATE SKIP LOCKED` lease, recovery on boot, compensation cascade, tx+steps in one Postgres tx; Kafka `audit.v1`; OTel + `/metrics`; real `/readyz`.
- **engine-liquidity** decimal on REST surface + slicer notional + `BookLevel`; real Kafka audit/recon producers; real HTTP treasury client.
- **gateway-blockchain** reorg re-broadcast + funding-confirmation wait + decimal money + real mempool WS subscription + real chain adapters (EVM WS + Bitcoin RPC).
- **notifier** real provider SDKs + kafkajs + HMAC webhooks + Redis dedup + DLQ + KafkaBus + auth.
- **engine-recon** `LedgerFetcher` + 3 match strategies + 4 break types + aging + DLQ + prod defaults.
- **kyc-onboarding** real Onfido adapter with HMAC webhooks + retries + service-token auth.
- **kyt-aml-screening** real Chainalysis/TRM with circuit breaker + idempotency + audit emitter + canonical proto.
- **mpc-signer** SignTx pipeline is fail-closed (policy token + wallet binding + replay protection + signed audit); custody adapters (Fireblocks/Dfns/Turnkey) implemented; control-plane auth + gRPC TLS.
- **gateway-exchange** real Binance/Kraken connectors with HMAC signing + rate limits + decimal money + `secrets.Manager`.
- **audit-logger** real S3/KMS/Kafka adapters + Object Lock + verify-chain CLI + anchor job + atomic chain extension + signed JWT auth.
- **gateway-api** real undici+opossum downstream with per-service circuit breakers + Redis token-bucket limiter.
- **gateway-auth** Argon2id + JWKS + Kafka `audit.v1` + real `/readyz` + `JWT_SECRET` prod-fatal.
- **engine-policy-risk** Redis velocity counter (count+sum, 1m/1h/24h) + ingest endpoints + decimal caps + canonical proto + auth.
- **wallet-manager** gRPC TLS + decimal balance path + service-token auth.

---

## Conclusion

Aggregate **6.8/10** (was 4.9 at v2 audit). 21 items completed across Phases 1-3: float64→decimal (5 services), atomic chains (2), auth on 14 services, Argon2id, real readyz (6), gRPC TLS (2), nonroot Dockerfiles (5), proto regeneration (5 services), Redis velocity counter, mempool monitoring, treasury path fix, wallet decimal, fraud/recon defaults, orchestrator-tx partners+OTel, treasury outbox (OnFill). 13/17 integration edges now fully working (was 6/16). Remaining blockers are concentrated in: (1) custody-provider default + BTC/Solana sighashes — the two highest-severity P0s, (2) 4 real adapter implementations, (3) audit-logger S3/KMS/Kafka gating, (4) plaintext gRPC/OTLP + observability stack, (5) static readyz residuals + in-memory idempotency, (6) UI services. Estimated time to production-readiness: **2–3 weeks**.
