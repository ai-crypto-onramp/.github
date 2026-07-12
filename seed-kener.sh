#!/bin/sh
set -e

KC_URL="${KC_URL:-http://localhost:8200}"
KC_API_KEY="${KC_API_KEY:-}"

if [ -z "$KC_API_KEY" ]; then
  echo "KC_API_KEY not set — skipping Kener seed"
  exit 0
fi

SERVICES='aml-kyt-screening:AML/KYT Screening:Core:Pre-settlement KYT checks on destination addresses; blocks tainted flows.
api-gateway:API Gateway:Edge:Public edge: authN/Z, rate limiting, request shaping, backend aggregation.
audit-event-log:Audit Event Log:Core:Append-only audit trail for compliance and incident forensics.
blockchain-gateway:Blockchain Gateway:Chain:Per-chain broadcast, gas estimation, confirmation tracking, reorg handling.
exchange-connectors:Exchange Connectors:Liquidity:Venue adapters (Binance, Kraken, OTC): orders, fills, balances.
fraud-detection:Fraud Detection:Risk:ML scoring on payment + behavioral signals; feeds the policy engine.
fx-hedging:FX Hedging:Treasury:Currency exposure management: hedge execution and slippage tracking.
identity-auth:Identity & Auth:Core:User accounts, sessions, MFA, API keys, RBAC.
ledger-accounting:Ledger Accounting:Core:Immutable double-entry ledger — the single source of financial truth.
liquidity-routing:Liquidity Routing:Liquidity:Smart order routing + TWAP across exchanges/OTC desks.
mpc-signing-service:MPC Signing Service:Chain:Threshold-signature (t-of-n) signing across distributed nodes. No single key.
notification:Notification:Core:Email/SMS/push + partner webhooks for tx status.
onboarding-kyc:Onboarding & KYC:Core:Identity verification via vendors: document + liveness, sanctions/PEP screening.
payment-orchestration:Payment Orchestration:Fiat:Fiat ingress: 3DS, auth/capture, settlement webhooks, chargebacks.
policy-risk-engine:Policy & Risk Engine:Risk:Per-tx caps, velocity limits, whitelisting; auto-approve or route to review.
pricing-quote:Pricing & Quote:Core:Real-time rate quotes with 30s rate-lock; sourced spreads + fee markup.
rail-connectors:Rail Connectors:Fiat:Per-rail adapters (card, ACH/SEPA/PIX/UPI); one deployable per family.
reconciliation:Reconciliation:Core:Matches internal ledger vs bank/exchange/on-chain state; flags breaks.
transaction-orchestrator:Transaction Orchestrator:Core:Saga engine: payment -> policy -> sign -> deliver, with compensation.
treasury-orchestration:Treasury Orchestration:Treasury:Batches orders into aggregate buys; manages T+0 vs T+2/3 float, hot wallet funding.
wallet-management:Wallet Management:Chain:Hot/warm wallet inventory, address derivation/rotation, per-chain balances.'

EVAL='(async function (statusCode, responseTime, responseRaw, modules) { let s = Math.floor(statusCode/100); if (s>=2 && s<=3 && responseRaw.includes(\"status\":\"ok\")) { return {status:'"'"'UP'"'"',latency:responseTime}; } return {status:'"'"'DOWN'"'"',latency:responseTime}; })'

echo "$SERVICES" | while IFS=: read -r TAG NAME CATEGORY DESC; do
  BODY=$(cat <<ENDJSON
{
  "tag": "$TAG",
  "name": "$NAME",
  "description": "$DESC",
  "cron": "* * * * *",
  "default_status": "UP",
  "status": "ACTIVE",
  "category_name": "$CATEGORY",
  "monitor_type": "API",
  "type_data": "{\"url\":\"http://$TAG:8080/healthz\",\"method\":\"GET\",\"headers\":[],\"body\":\"\",\"timeout\":10000,\"eval\":\"$EVAL\",\"allowSelfSignedCert\":false}",
  "day_degraded_minimum_count": 1,
  "day_down_minimum_count": 1,
  "include_degraded_in_downtime": "NO",
  "is_hidden": "NO"
}
ENDJSON
)
  echo "Creating monitor: $NAME"
  curl -sf -X POST "$KC_URL/api/monitors" \
    -H "Authorization: Bearer $KC_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$BODY" && echo " OK" || echo " FAILED (may already exist)"
done

echo "Kener seed complete."