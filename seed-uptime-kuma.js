const { io } = require("socket.io-client");

const KUMA_URL = process.env.KUMA_URL || "http://localhost:8300";
const KUMA_USER = process.env.KUMA_USER || "admin";
const KUMA_PASS = process.env.KUMA_PASS || "admin";

const services = [
  ["aml-kyt-screening", "AML/KYT Screening", "http://aml-kyt-screening:8080/healthz"],
  ["api-gateway", "API Gateway", "http://api-gateway:8080/healthz"],
  ["audit-event-log", "Audit Event Log", "http://audit-event-log:8080/healthz"],
  ["blockchain-gateway", "Blockchain Gateway", "http://blockchain-gateway:8080/healthz"],
  ["exchange-connectors", "Exchange Connectors", "http://exchange-connectors:8080/healthz"],
  ["fraud-detection", "Fraud Detection", "http://fraud-detection:8080/healthz"],
  ["fx-hedging", "FX Hedging", "http://fx-hedging:8080/healthz"],
  ["identity-auth", "Identity & Auth", "http://identity-auth:8080/healthz"],
  ["ledger-accounting", "Ledger Accounting", "http://ledger-accounting:8080/healthz"],
  ["liquidity-routing", "Liquidity Routing", "http://liquidity-routing:8080/healthz"],
  ["mpc-signing-service", "MPC Signing Service", "http://mpc-signing-service:8080/healthz"],
  ["notification", "Notification", "http://notification:8080/healthz"],
  ["onboarding-kyc", "Onboarding & KYC", "http://onboarding-kyc:8080/healthz"],
  ["payment-orchestration", "Payment Orchestration", "http://payment-orchestration:8080/healthz"],
  ["policy-risk-engine", "Policy & Risk Engine", "http://policy-risk-engine:8080/healthz"],
  ["pricing-quote", "Pricing & Quote", "http://pricing-quote:8080/healthz"],
  ["rail-connectors", "Rail Connectors", "http://rail-connectors:8080/healthz"],
  ["reconciliation", "Reconciliation", "http://reconciliation:8080/healthz"],
  ["transaction-orchestrator", "Transaction Orchestrator", "http://transaction-orchestrator:8080/healthz"],
  ["treasury-orchestration", "Treasury Orchestration", "http://treasury-orchestration:8080/healthz"],
  ["wallet-management", "Wallet Management", "http://wallet-management:8080/healthz"],
];

const socket = io(KUMA_URL, { transports: ["websocket"] });

socket.on("connect", () => {
  console.log("Connected to Uptime Kuma, logging in...");
  socket.emit("login", { username: KUMA_USER, password: KUMA_PASS });
});

socket.on("login", (res) => {
  if (!res.token) {
    console.error("Login failed:", res.msg || res);
    process.exit(1);
  }
  console.log("Logged in, creating monitors...");

  let pending = services.length;
  services.forEach(([name, friendly, url]) => {
    socket.emit("add", {
      type: "http-keyword",
      name: friendly,
      friendly_name: friendly,
      url: url,
      method: "GET",
      interval: 60,
      maxretries: 0,
      retryInterval: 60,
      resendInterval: 0,
      active: true,
      keyword: '"status":"ok"',
      invertKeyword: false,
      accepted_statuscodes_json: '["200-299"]',
    });
    console.log(`Created: ${friendly}`);
    if (--pending === 0) {
      console.log("Uptime Kuma seed complete.");
      socket.disconnect();
      process.exit(0);
    }
  });
});

socket.on("connect_error", (err) => {
  console.error("Connection error:", err.message);
  process.exit(1);
});

setTimeout(() => {
  console.error("Timeout waiting for Uptime Kuma");
  process.exit(1);
}, 30000);