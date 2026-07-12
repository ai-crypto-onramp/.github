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

## Setup instructions per tool

### Kener (:8200)
1. Open http://localhost:8200 — first-run setup creates admin account.
2. Add each service as an API monitor:
   - Monitor type: API
   - URL: `<health URL from table above>`
   - Method: GET
   - Eval: custom JS — `return responseRaw.includes('"status":"ok"') ? "UP" : "DOWN"`
   - Name: `<service name>`
   - Description: `<description from table>`
   - Tags: `lang:Go`, `group:core`, etc.
   - Severity: critical / moderate / minor (assign per service)
3. Group monitors on the status page by the `group` tag.

### Uptime Kuma (:8300)
1. Open http://localhost:8300 — first-run creates admin account.
2. Add each service as an HTTP(s)-JsonQuery monitor:
   - Monitor type: HTTP(s)-JsonQuery
   - URL: `<health URL from table above>`
   - JSON Query: `$.status` == `ok`
   - Name: `<service name>`
   - Tags: `lang=Go`, `group=core`, etc.
3. Create a Status Page, assign all 21 monitors, set friendly names/descriptions.

### Healthchecks (:8400)
1. Open http://localhost:8400 — create admin account.
2. Create a Project (e.g. "AI Crypto On-Ramp").
3. Add 21 checks — one per service:
   - Name: `<service name>`
   - Description: `<description from table>`
   - Tags: `Go core` (space-separated)
   - Schedule: every 1 min
4. Each check gets a ping URL. Add a `curl <ping_url>` cron or sidecar to each service.
   Note: Healthchecks is push-based — it does not probe `/healthz` directly.

### Cachet (:8500)
1. Open http://localhost:8500 — first-run setup (mail, user, etc.).
2. Create Component Groups: core, edge, chain, liquidity, risk, treasury, fiat.
3. Add each service as a Component:
   - Name: `<service name>`
   - Description: `<description from table>`
   - Link: `https://github.com/ai-crypto-onramp/<service>`
   - Group: `<group from table>`
   - Status: Operational (1)
4. Cachet has no built-in prober. Use the API to update component status:
   `PATCH /api/v1/components/<id>` with `{"status": 1}` (operational) or `{"status": 4}` (major outage).
   Write a small sidecar script that curls each `/healthz` and updates Cachet.