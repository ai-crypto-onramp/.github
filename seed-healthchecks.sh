#!/bin/sh
set -e

HC_URL="${HC_URL:-http://localhost:8400}"
HC_API_KEY="${HC_API_KEY:-}"

if [ -z "$HC_API_KEY" ]; then
  echo "HC_API_KEY not set — skipping Healthchecks seed"
  exit 0
fi

SERVICES='aml-kyt-screening:AML/KYT Screening:go core:Pre-settlement KYT checks on destination addresses; blocks tainted flows.
api-gateway:API Gateway:ts edge:Public edge: authN/Z, rate limiting, request shaping, backend aggregation.
audit-event-log:Audit Event Log:go core:Append-only audit trail for compliance and incident forensics.
blockchain-gateway:Blockchain Gateway:go chain:Per-chain broadcast, gas estimation, confirmation tracking, reorg handling.
exchange-connectors:Exchange Connectors:go liquidity:Venue adapters (Binance, Kraken, OTC): orders, fills, balances.
fraud-detection:Fraud Detection:python risk:ML scoring on payment + behavioral signals; feeds the policy engine.
fx-hedging:FX Hedging:go treasury:Currency exposure management: hedge execution and slippage tracking.
identity-auth:Identity & Auth:go core:User accounts, sessions, MFA, API keys, RBAC.
ledger-accounting:Ledger Accounting:rust core:Immutable double-entry ledger, the single source of financial truth.
liquidity-routing:Liquidity Routing:go liquidity:Smart order routing + TWAP across exchanges/OTC desks.
mpc-signing-service:MPC Signing Service:rust chain:Threshold-signature (t-of-n) signing across distributed nodes. No single key.
notification:Notification:ts core:Email/SMS/push + partner webhooks for tx status.
onboarding-kyc:Onboarding & KYC:go core:Identity verification via vendors: document + liveness, sanctions/PEP screening.
payment-orchestration:Payment Orchestration:go fiat:Fiat ingress: 3DS, auth/capture, settlement webhooks, chargebacks.
policy-risk-engine:Policy & Risk Engine:go risk:Per-tx caps, velocity limits, whitelisting; auto-approve or route to review.
pricing-quote:Pricing & Quote:go core:Real-time rate quotes with 30s rate-lock; sourced spreads + fee markup.
rail-connectors:Rail Connectors:go fiat:Per-rail adapters (card, ACH/SEPA/PIX/UPI); one deployable per family.
reconciliation:Reconciliation:python core:Matches internal ledger vs bank/exchange/on-chain state; flags breaks.
transaction-orchestrator:Transaction Orchestrator:go core:Saga engine: payment -> policy -> sign -> deliver, with compensation.
treasury-orchestration:Treasury Orchestration:go treasury:Batches orders into aggregate buys; manages T+0 vs T+2/3 float, hot wallet funding.
wallet-management:Wallet Management:go chain:Hot/warm wallet inventory, address derivation/rotation, per-chain balances.'

echo "$SERVICES" | while IFS=: read -r SLUG NAME TAGS DESC; do
  BODY=$(cat <<ENDJSON
{
  "name": "$NAME",
  "slug": "$SLUG",
  "tags": "$TAGS",
  "desc": "$DESC",
  "timeout": 60,
  "grace": 60,
  "unique": ["name"]
}
ENDJSON
)
  echo "Creating check: $NAME"
  curl -sf -X POST "$HC_URL/api/v3/checks/" \
    -H "X-Api-Key: $HC_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$BODY" && echo " OK" || echo " FAILED"
done

echo "Healthchecks seed complete."