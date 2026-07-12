#!/bin/sh
set -e

CACHET_URL="${CACHET_URL:-http://localhost:8500}"
CACHET_TOKEN="${CACHET_TOKEN:-}"

if [ -z "$CACHET_TOKEN" ]; then
  echo "CACHET_TOKEN not set — skipping Cachet seed"
  exit 0
fi

# Create component groups first
GROUPS="Core
Edge
Chain
Liquidity
Risk
Treasury
Fiat"

echo "$GROUPS" | while read -r GROUP; do
  curl -sf -X POST "$CACHET_URL/api/component-groups" \
    -H "Authorization: Bearer $CACHET_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$GROUP\",\"visible\":1,\"collapsed\":0}" >/dev/null && echo "Group: $GROUP OK" || echo "Group: $GROUP FAILED"
done

# Fetch group IDs
GROUP_IDS=$(curl -sf "$CACHET_URL/api/component-groups" -H "Authorization: Bearer $CACHET_TOKEN")

SERVICES='aml-kyt-screening:AML/KYT Screening:Core:1:Pre-settlement KYT checks on destination addresses; blocks tainted flows.
api-gateway:API Gateway:Edge:2:Public edge: authN/Z, rate limiting, request shaping, backend aggregation.
audit-event-log:Audit Event Log:Core:3:Append-only audit trail for compliance and incident forensics.
blockchain-gateway:Blockchain Gateway:Chain:4:Per-chain broadcast, gas estimation, confirmation tracking, reorg handling.
exchange-connectors:Exchange Connectors:Liquidity:5:Venue adapters (Binance, Kraken, OTC): orders, fills, balances.
fraud-detection:Fraud Detection:Risk:6:ML scoring on payment + behavioral signals; feeds the policy engine.
fx-hedging:FX Hedging:Treasury:7:Currency exposure management: hedge execution and slippage tracking.
identity-auth:Identity & Auth:Core:8:User accounts, sessions, MFA, API keys, RBAC.
ledger-accounting:Ledger Accounting:Core:9:Immutable double-entry ledger, the single source of financial truth.
liquidity-routing:Liquidity Routing:Liquidity:10:Smart order routing + TWAP across exchanges/OTC desks.
mpc-signing-service:MPC Signing Service:Chain:11:Threshold-signature (t-of-n) signing across distributed nodes. No single key.
notification:Notification:Core:12:Email/SMS/push + partner webhooks for tx status.
onboarding-kyc:Onboarding & KYC:Core:13:Identity verification via vendors: document + liveness, sanctions/PEP screening.
payment-orchestration:Payment Orchestration:Fiat:14:Fiat ingress: 3DS, auth/capture, settlement webhooks, chargebacks.
policy-risk-engine:Policy & Risk Engine:Risk:15:Per-tx caps, velocity limits, whitelisting; auto-approve or route to review.
pricing-quote:Pricing & Quote:Core:16:Real-time rate quotes with 30s rate-lock; sourced spreads + fee markup.
rail-connectors:Rail Connectors:Fiat:17:Per-rail adapters (card, ACH/SEPA/PIX/UPI); one deployable per family.
reconciliation:Reconciliation:Core:18:Matches internal ledger vs bank/exchange/on-chain state; flags breaks.
transaction-orchestrator:Transaction Orchestrator:Core:19:Saga engine: payment -> policy -> sign -> deliver, with compensation.
treasury-orchestration:Treasury Orchestration:Treasury:20:Batches orders into aggregate buys; manages T+0 vs T+2/3 float, hot wallet funding.
wallet-management:Wallet Management:Chain:21:Hot/warm wallet inventory, address derivation/rotation, per-chain balances.'

echo "$SERVICES" | while IFS=: read -r REPO NAME GROUP ORDER DESC; do
  GROUP_ID=$(echo "$GROUP_IDS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for g in data.get('data', []):
    if g['attributes']['name'] == '$GROUP':
        print(g['id'])
        break
" 2>/dev/null || echo "")

  if [ -z "$GROUP_ID" ]; then
    GROUP_ID=1
  fi

  curl -sf -X POST "$CACHET_URL/api/components" \
    -H "Authorization: Bearer $CACHET_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$NAME\",\"description\":\"$DESC\",\"status\":1,\"link\":\"https://github.com/ai-crypto-onramp/$REPO\",\"order\":$ORDER,\"enabled\":true,\"component_group_id\":$GROUP_ID}" >/dev/null \
    && echo "Component: $NAME OK" || echo "Component: $NAME FAILED"
done

echo "Cachet seed complete."