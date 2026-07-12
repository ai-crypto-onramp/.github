# Dashboard Setup Guide

This guide lists all 21 microservices with metadata for monitoring with Gatus.

All services expose `GET /healthz` returning `{"status":"ok"}` on port `8080` (inside the compose network).

## Dashboard

| Tool | Host port | URL |
|---|---|---|
| Gatus | 8090 | http://localhost:8090 |

Gatus is the single status dashboard. It is configured declaratively via `gatus.yml`, which is mounted into the container at `/config/config.yaml`. No manual seeding or UI setup is required — bring up the stack and open http://localhost:8090.

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

## Running

```bash
docker compose -f .github/docker-compose.yml up -d --build
```

Then open http://localhost:8090. Gatus polls each `/healthz` endpoint every 30s and renders the status page from `gatus.yml`. To add or change monitors, edit `gatus.yml` and restart the `gatus` container.

## Gatus configuration

Monitors are defined in `gatus.yml`. Each endpoint block sets:

- `name`, `group` — shown on the dashboard
- `url` — the in-compose health URL (`http://<service>:8080/healthz`)
- `interval` — probe interval (default 30s)
- `conditions` — `[STATUS] == 200` and `[BODY].status == ok`