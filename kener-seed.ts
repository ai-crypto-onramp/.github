const healthzEval = "(async function (statusCode, responseTime, responseRaw, modules) { let s = Math.floor(statusCode/100); if (s>=2 && s<=3 && responseRaw.includes('\"status\":\"ok\"')) { return {status:'UP',latency:responseTime}; } return {status:'DOWN',latency:responseTime}; })";

function apiMonitor(tag, name, description, category) {
  return {
    tag,
    name,
    description,
    cron: "* * * * *",
    default_status: "UP",
    status: "ACTIVE",
    category_name: category,
    monitor_type: "API",
    down_trigger: null,
    degraded_trigger: null,
    type_data: JSON.stringify({
      url: `http://${tag}:8080/healthz`,
      method: "GET",
      headers: [],
      body: "",
      timeout: 10000,
      eval: healthzEval,
      allowSelfSignedCert: false,
    }),
    day_degraded_minimum_count: 1,
    day_down_minimum_count: 1,
    include_degraded_in_downtime: "NO",
    is_hidden: "NO",
  };
}

let seedMonitorData = [
  apiMonitor("aml-kyt-screening", "AML/KYT Screening", "Pre-settlement KYT checks on destination addresses; blocks tainted flows.", "Core"),
  apiMonitor("api-gateway", "API Gateway", "Public edge: authN/Z, rate limiting, request shaping, backend aggregation.", "Edge"),
  apiMonitor("audit-event-log", "Audit Event Log", "Append-only audit trail for compliance and incident forensics.", "Core"),
  apiMonitor("blockchain-gateway", "Blockchain Gateway", "Per-chain broadcast, gas estimation, confirmation tracking, reorg handling.", "Chain"),
  apiMonitor("exchange-connectors", "Exchange Connectors", "Venue adapters (Binance, Kraken, OTC): orders, fills, balances.", "Liquidity"),
  apiMonitor("fraud-detection", "Fraud Detection", "ML scoring on payment + behavioral signals; feeds the policy engine.", "Risk"),
  apiMonitor("fx-hedging", "FX Hedging", "Currency exposure management: hedge execution and slippage tracking.", "Treasury"),
  apiMonitor("identity-auth", "Identity & Auth", "User accounts, sessions, MFA, API keys, RBAC.", "Core"),
  apiMonitor("ledger-accounting", "Ledger Accounting", "Immutable double-entry ledger — the single source of financial truth.", "Core"),
  apiMonitor("liquidity-routing", "Liquidity Routing", "Smart order routing + TWAP across exchanges/OTC desks.", "Liquidity"),
  apiMonitor("mpc-signing-service", "MPC Signing Service", "Threshold-signature (t-of-n) signing across distributed nodes. No single key.", "Chain"),
  apiMonitor("notification", "Notification", "Email/SMS/push + partner webhooks for tx status.", "Core"),
  apiMonitor("onboarding-kyc", "Onboarding & KYC", "Identity verification via vendors: document + liveness, sanctions/PEP screening.", "Core"),
  apiMonitor("payment-orchestration", "Payment Orchestration", "Fiat ingress: 3DS, auth/capture, settlement webhooks, chargebacks.", "Fiat"),
  apiMonitor("policy-risk-engine", "Policy & Risk Engine", "Per-tx caps, velocity limits, whitelisting; auto-approve or route to review.", "Risk"),
  apiMonitor("pricing-quote", "Pricing & Quote", "Real-time rate quotes with 30s rate-lock; sourced spreads + fee markup.", "Core"),
  apiMonitor("rail-connectors", "Rail Connectors", "Per-rail adapters (card, ACH/SEPA/PIX/UPI); one deployable per family.", "Fiat"),
  apiMonitor("reconciliation", "Reconciliation", "Matches internal ledger vs bank/exchange/on-chain state; flags breaks.", "Core"),
  apiMonitor("transaction-orchestrator", "Transaction Orchestrator", "Saga engine: payment -> policy -> sign -> deliver, with compensation.", "Core"),
  apiMonitor("treasury-orchestration", "Treasury Orchestration", "Batches orders into aggregate buys; manages T+0 vs T+2/3 float, hot wallet funding.", "Treasury"),
  apiMonitor("wallet-management", "Wallet Management", "Hot/warm wallet inventory, address derivation/rotation, per-chain balances.", "Chain"),
];

export default seedMonitorData;