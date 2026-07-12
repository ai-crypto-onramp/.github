# Monitoring Dashboard Setup Guide

This guide lists all 21 microservices with metadata for seeding into Kener, Uptime Kuma, Cachet, and Healthchecks.

All services expose `GET /healthz` returning `{"status":"ok"}` on port `8080` (inside the compose network).

## Port assignments

| Dashboard tool | Host port | URL |
|---|---|---|
| Gatus | 8090 | http://localhost:8090 |
| Kener | 8200 | http://localhost:8200 |
| Uptime Kuma | 8300 | http://localhost:8300 |
| Healthchecks | 8400 | http://localhost:8400 |
| Cachet | 8500 | http://localhost:8500 |

## Service catalog

Each row: name, group, lang, description, health URL (compose internal).

| Service | Group | Lang | Description | Health URL |
|---|---|---|---|---|
| aml-kyt-screening | core | Go | Pre-settlement KYT checks on destination addresses; blocks tainted flows. | http://aml-kyt-screening:8080/healthz |
| api-gateway | edge | TS | Public edge: authN/Z, rate limiting, request shaping, backend aggregation. | http://api-gateway:8080/healthz |
| audit-event-log | core | Go | Append-only audit trail for compliance and incident forensics. | http://audit-event-log:8080/healthz |
| blockchain-gateway | chain | Go | Per-chain broadcast, gas estimation, confirmation tracking, reorg handling. | http://blockchain-gateway:8080/healthz |
| exchange-connectors | liquidity | Go | Venue adapters (Binance, Kraken, OTC): orders, fills, balances. | http://exchange-connectors:8080/healthz |
| fraud-detection | risk | Python | ML scoring on payment + behavioral signals; feeds the policy engine. | http://fraud-detection:8080/healthz |
| fx-hedging | treasury | Go | Currency exposure management: hedge execution and slippage tracking. | http://fx-hedging:8080/healthz |
| identity-auth | core | Go | User accounts, sessions, MFA, API keys, RBAC. | http://identity-auth:8080/healthz |
| ledger-accounting | core | Rust | Immutable double-entry ledger — the single source of financial truth. | http://ledger-accounting:8080/healthz |
| liquidity-routing | liquidity | Go | Smart order routing + TWAP across exchanges/OTC desks. | http://liquidity-routing:8080/healthz |
| mpc-signing-service | chain | Rust | Threshold-signature (t-of-n) signing across distributed nodes. No single key. | http://mpc-signing-service:8080/healthz |
| notification | core | TS | Email/SMS/push + partner webhooks for tx status. | http://notification:8080/healthz |
| onboarding-kyc | core | Go | Identity verification via vendors: document + liveness, sanctions/PEP screening. | http://onboarding-kyc:8080/healthz |
| payment-orchestration | fiat | Go | Fiat ingress: 3DS, auth/capture, settlement webhooks, chargebacks. | http://payment-orchestration:8080/healthz |
| policy-risk-engine | risk | Go | Per-tx caps, velocity limits, whitelisting; auto-approve or route to review. | http://policy-risk-engine:8080/healthz |
| pricing-quote | core | Go | Real-time rate quotes with 30s rate-lock; sourced spreads + fee markup. | http://pricing-quote:8080/healthz |
| rail-connectors | fiat | Go | Per-rail adapters (card, ACH/SEPA/PIX/UPI); one deployable per family. | http://rail-connectors:8080/healthz |
| reconciliation | core | Python | Matches internal ledger vs bank/exchange/on-chain state; flags breaks. | http://reconciliation:8080/healthz |
| transaction-orchestrator | core | Go | Saga engine: payment -> policy -> sign -> deliver, with compensation. | http://transaction-orchestrator:8080/healthz |
| treasury-orchestration | treasury | Go | Batches orders into aggregate buys; manages T+0 vs T+2/3 float, hot wallet funding. | http://treasury-orchestration:8080/healthz |
| wallet-management | chain | Go | Hot/warm wallet inventory, address derivation/rotation, per-chain balances. | http://wallet-management:8080/healthz |

## Auto-seeding (no manual UI required)

All four tools can be pre-configured programmatically. The seed files are in this directory.

### Kener (:8200) — auto-seeded on first start
- `kener-seed.ts` is mounted into the container at `/app/src/lib/server/db/seedMonitorData.ts`
- Kener's Knex migrations run on first DB creation and insert all 21 monitors automatically
- No API key needed — the seed runs during DB initialization
- After first run, open http://localhost:8200 and create your admin account
- All 21 monitors will already be present with descriptions, categories, and health checks

### Uptime Kuma (:8300) — seeded via Socket.io sidecar
- `uptime-kuma-seed` init container runs `seed-uptime-kuma.js` after Kuma starts
- **First**: open http://localhost:8300 and create admin account (user: admin, pass: admin)
- **Then**: `docker compose up -d uptime-kuma-seed` to run the seed
- Creates 21 HTTP-keyword monitors checking for `"status":"ok"` in response body
- After seeding, create a Status Page in the UI and assign all 21 monitors

### Healthchecks (:8400) — seeded via Management API sidecar
- `healthchecks-seed` init container runs `seed-healthchecks.sh`
- **First**: open http://localhost:8400, create admin account, create a Project, generate a Read-Write API key in Project Settings
- **Then**: `HC_API_KEY=<your-key> docker compose up -d healthchecks-seed` to run the seed
- Creates 21 checks with descriptions, tags, and upsert semantics (idempotent)
- Healthchecks is push-based: each service must `curl http://healthchecks:8000/ping/<slug>` periodically

### Cachet (:8500) — seeded via REST API sidecar
- `cachet-seed` init container runs `seed-cachet.sh`
- **First**: open http://localhost:8500, complete first-run setup, generate an API key in Settings → API Keys
- **Then**: `CACHET_TOKEN=<your-token> docker compose up -d cachet-seed` to run the seed
- Creates 7 component groups (Core, Edge, Chain, Liquidity, Risk, Treasury, Fiat) + 21 components
- Each component has name, description, GitHub link, group, and order
- Cachet has no built-in prober — run a sidecar that curls `/healthz` and updates component status via API