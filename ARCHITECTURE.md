# Crypto On-Ramp — Service Architecture Diagram

End-to-end service topology. Solid arrows = synchronous request/response on the
transaction path. Dashed arrows = asynchronous events (event bus / webhooks).

```mermaid
flowchart TB
    Client([Web / Mobile / Partner SDK])

    subgraph Edge["Edge & Identity"]
        GW[API Gateway / BFF<br/>TypeScript]
        AUTH[Identity & Auth<br/>Go]
    end

    subgraph Compliance["Compliance & Risk"]
        KYC[Onboarding / KYC<br/>Go]
        KYT[AML / KYT Screening<br/>Go]
        POLICY[Policy / Risk Engine<br/>Go]
        FRAUD[Fraud Detection<br/>Python]
    end

    subgraph Fiat["Fiat, Pricing & Liquidity"]
        PAY[Payment Orchestration<br/>Go]
        RAILS[Rail Connectors<br/>Go]
        PRICE[Pricing / Quote<br/>Go]
        FX[FX & Hedging<br/>Go]
        LIQ[Liquidity Routing<br/>Go]
        EXCH[Exchange Connectors<br/>Go]
    end

    subgraph Custody["Custody & On-Chain"]
        MPC[MPC Signing Service<br/>Rust]
        WALLET[Wallet Management<br/>Go]
        CHAIN[Blockchain Gateway<br/>Go]
    end

    subgraph Platform["Treasury, Ledger & Platform"]
        ORCH[Transaction Orchestrator<br/>Go]
        LEDGER[Ledger / Accounting<br/>Rust]
        TREAS[Treasury Orchestration<br/>Go]
        RECON[Reconciliation<br/>Python]
        NOTIF[Notification<br/>TypeScript]
        AUDIT[Audit / Event Log<br/>Go]
    end

    %% Client entry
    Client --> GW
    GW --> AUTH
    GW --> KYC
    GW --> PRICE
    GW --> ORCH

    %% Compliance wiring
    KYC --> POLICY
    FRAUD --> POLICY
    KYT --> POLICY

    %% Orchestrator saga (transaction path)
    ORCH --> POLICY
    ORCH --> PAY
    ORCH --> KYT
    ORCH --> MPC
    ORCH --> CHAIN
    ORCH --> LEDGER

    %% Fiat rails
    PAY --> RAILS
    PAY --> FRAUD

    %% Pricing & FX
    PRICE --> FX

    %% Liquidity
    LIQ --> EXCH

    %% Custody & on-chain
    MPC --> WALLET
    CHAIN --> WALLET

    %% Treasury (async aggregation)
    ORCH -.-> TREAS
    TREAS -.-> LIQ
    TREAS -.-> WALLET
    TREAS --> FX

    %% Reconciliation inputs
    LEDGER -.-> RECON
    EXCH -.-> RECON
    RAILS -.-> RECON
    CHAIN -.-> RECON

    %% Cross-cutting async
    ORCH -.-> NOTIF
    CHAIN -.-> NOTIF
    ORCH -.-> AUDIT
    PAY -.-> AUDIT
    MPC -.-> AUDIT
    POLICY -.-> AUDIT
    LEDGER -.-> AUDIT
```

## Reading the diagram

- **Transaction path (solid):** `Client → API Gateway → Transaction Orchestrator`,
  which drives the saga: Policy check → Payment capture → KYT screen → MPC sign →
  Blockchain broadcast → Ledger posting.
- **Compliance gate:** KYC (signup), Fraud, and KYT all feed the **Policy Engine**,
  the single gatekeeper before signing.
- **Async layer (dashed):** Treasury batches orders into aggregate buys via Liquidity
  Routing (handling the T+0 vs T+2/3 float); Reconciliation matches Ledger against
  bank, exchange, and on-chain state; Notification and Audit consume the event bus.
