# Crypto On-Ramp — Microservices Architecture

Service breakdown to launch a crypto on-ramp end-to-end, mapped to the five-layer
architecture plus the treasury/ledger and platform plumbing.

## Language philosophy

Minimize language sprawl. Standardize on:

- **Go** — transactional backbone (concurrency, latency, ops maturity)
- **Rust** — the two things where a bug means lost funds (signing + ledger)
- **TypeScript** — edge / BFF
- **Python** — where ML/data genuinely wins (fraud, risk)

## Core Microservices

| Service | Language | Description |
|---|---|---|
| **API Gateway / BFF** | TypeScript | Public edge. AuthN/Z, rate limiting, request shaping, aggregates backend calls for web/mobile SDKs. |
| **Identity & Auth** | Go | User accounts, sessions, MFA, API keys for B2B partners, RBAC. |
| **Onboarding / KYC** | Go | Orchestrates identity verification via vendors (Onfido/Sumsub), document + liveness, sanctions/PEP screening at signup. |
| **AML / KYT Screening** | Go | Pre-settlement Know-Your-Transaction checks against destination addresses (Chainalysis/TRM); blocks tainted flows before broadcast. |
| **Policy / Risk Engine** | Go | Per-tx caps, velocity limits, whitelisting, source auth. Auto-approves or routes to manual review. The gatekeeper before signing. |
| **Fraud Detection** | Python | ML scoring on payment + behavioral signals (chargeback/velocity models); feeds the policy engine. |

## Fiat, Pricing & Liquidity

| Service | Language | Description |
|---|---|---|
| **Payment Orchestration** | Go | Fiat ingress. Normalizes across rails; manages 3DS, auth/capture, settlement webhooks, chargebacks. |
| **Rail Connectors** | Go | Adapter services per rail (card networks, ACH/SEPA/PIX/UPI). One deployable per rail family, common interface. |
| **Pricing / Quote** | Go | Real-time rate quotes with the ~30s rate-lock window; sources spreads and marks up fees. |
| **FX & Hedging** | Go | Manages currency exposure across daily flows, executes hedges, tracks slippage. |
| **Liquidity Routing** | Go | Smart order routing + TWAP execution across exchanges/OTC desks; splits large orders. |
| **Exchange Connectors** | Go | Venue-specific adapters (Binance, Kraken, OTC) — order placement, fills, balances. |

## Custody & On-Chain

| Service | Language | Description |
|---|---|---|
| **MPC Signing Service** | Rust | Threshold-signature (t-of-n) signing across distributed nodes. No single key. The most security-critical component. |
| **Wallet Management** | Go | Hot/warm wallet inventory, address derivation/rotation, balance tracking per chain. |
| **Blockchain Gateway** | Go | Per-chain broadcast, gas prepayment/estimation, confirmation tracking, reorg handling, mempool monitoring. |

## Treasury, Ledger & Platform

| Service | Language | Description |
|---|---|---|
| **Transaction Orchestrator** | Go | The saga engine tying payment → policy → sign → deliver into one atomic, recoverable flow with compensation. |
| **Ledger / Accounting** | Rust | Immutable double-entry ledger — the single source of financial truth. Correctness over everything. |
| **Treasury Orchestration** | Go | Batches user orders into aggregate buys, manages the T+0 vs T+2/3 float, funding of hot wallets. |
| **Reconciliation** | Python | Continuously matches internal ledger vs bank/exchange/on-chain state; flags breaks (a top-4 failure mode). |
| **Notification** | TypeScript | Email/SMS/push + partner webhooks for tx status. |
| **Audit / Event Log** | Go | Append-only audit trail for compliance and incident forensics; consumes the event bus. |

## Launch sequencing

You don't build 24 services on day one. MVP cut (single region, cards + one instant
rail, one or two chains):

- **Must-have for v1:** API Gateway, Auth, KYC, KYT, Policy Engine, Payment
  Orchestration, Pricing, Transaction Orchestrator, MPC Signing (**buy this**),
  Wallet Mgmt, Blockchain Gateway, Ledger, Notification.
- **Fast-follow:** FX/Hedging, Liquidity Routing, Treasury batching, Reconciliation,
  Fraud ML.

**Key recommendation:** In-house custody is ~$5–10M and 18–24 months. Do **not**
build MPC Signing in-house for v1 — integrate a custody provider
(Fireblocks/Dfns/Turnkey) behind our own Wallet Management + Policy interfaces,
keeping the boundary clean so we can bring it in-house later.
