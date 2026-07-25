# Service Taxonomy

The repo's services follow a role-based naming convention. Each suffix denotes the
**role** the service plays in the system, not its domain. Domain is conveyed by the
prefix. Picking the right suffix means identifying the service's **dominant** trait,
since most real services are hybrids of several roles.

## Archetypes

### `gateway-*` — boundary service

Services that sit on a **boundary** between two zones and translate between them.
Two flavors:

- **External-system boundary** — I/O translators between the platform and an outside
  system. They speak some external protocol (REST / FIX / RPC / chain RPC) and emit or
  consume a canonical internal representation. They do **not** make business decisions.
  - `gateway-api` — public REST / BFF entry point
  - `gateway-blockchain` — chain RPC adapter
  - `gateway-exchange` — exchange / OTC venue adapter
  - `gateway-fiat` — bank / rail adapter
- **Trust boundary** — the control plane that separates untrusted callers from the
  trusted internal estate. They authenticate, authorize, and credential callers
  before any internal service will accept their requests.
  - `gateway-auth` — user accounts, sessions, MFA, API keys, RBAC; the boundary every
    inbound caller crosses before reaching `gateway-api` and downstream services.

**Rule:** if the service's job is "translate between us and the outside world" **or**
"gate who is allowed into the inside", it is a gateway. The `gateway-` prefix means
*boundary*; the boundary may be a protocol boundary or a trust boundary.

### `engine-*` — domain computation / decision

Stateless or stateful services that take inputs and produce a **decision, transform,
or computation**. The business algorithm lives here.

- `engine-fraud` — fraud scoring
- `engine-policy-risk` — policy / risk evaluation
- `engine-pricing` — quote computation
- `engine-liquidity` — smart order routing + TWAP / VWAP execution
- `engine-recon` — reconciliation matching and break detection

**Rule:** if the service's value is "the algorithm", it is an engine.

### `orchestrator-*` — workflow coordination

Saga / state-machine coordinators that **sequence calls** across multiple services,
own transactional flow, and handle compensation. They do not compute the domain
answer themselves — they direct who does.

- `orchestrator-tx` — transaction (buy) lifecycle
- `orchestrator-fiat` — fiat payment / capture lifecycle
- `orchestrator-treasury` — aggregate funding / hedging workflow

**Rule:** if the service's value is "the workflow", it is an orchestrator.

### Domain-specific nouns — unique archetypes

Services whose role is singular enough that a generic suffix would obscure rather
than clarify. Kept as domain nouns.

- `accounting-ledger` — append-only ledger is its own archetype.
- `audit-logger` — event sink.
- `notifier` — fan-out sink.
- `wallet-manager` — custody inventory: hot / warm / cold wallets, address
  derivation, UTXO and nonce management, MPC key mapping. The `wallet-manager`
  name is established industry vocabulary; treated as a domain noun rather than
  an instance of a generic `-manager` archetype.
- `fx-hedger` — domain noun (FX hedging desk role).
- `kyc-onboarding`, `kyt-aml-screening` — process nouns.

### `ui-*` — presentation layer

Separate axis entirely; not subject to the backend taxonomy.

- `ui-front-office`, `ui-middle-office`, `ui-back-office`

## Choosing a suffix

1. Is it a protocol boundary to an external system, or a trust boundary that gates
   callers into the inside? -> `gateway-*`
2. Is its value the algorithm / decision? -> `engine-*`
3. Is its value coordinating a multi-service workflow? -> `orchestrator-*`
4. Is its role singular enough that a generic suffix would obscure it? -> domain noun
5. Is it presentation? -> `ui-*`

Most real services are hybrids. Pick the **dominant** trait; the taxonomy is a
useful discriminator, not a pure classification.

---

## Renamings Plan

| Current | New | Role | Notes |
|---|---|---|---|
| `auth-identity` | `gateway-auth` | gateway (trust boundary) | user accounts, sessions, MFA, API keys, RBAC; gates every inbound caller |
| `pricing-quote` | `engine-pricing` | engine | quote computation; rate lock |
| `reconciliation` | `engine-recon` | engine | matching + break detection |
| `liquidity-router` | `engine-liquidity` | engine | SOR + TWAP/VWAP execution |
| `fraud-engine` | `engine-fraud` | engine | convention fix (prefix form) |
| `policy-risk-engine` | `engine-policy-risk` | engine | convention fix (prefix form) |
| `payment-orchestrator` | `orchestrator-fiat` | orchestrator | clarifies fiat-side scope vs. `orchestrator-tx`; prefix-form convention |
| `tx-orchestrator` | `orchestrator-tx` | orchestrator | convention fix (prefix form) |
| `treasury-orchestrator` | `orchestrator-treasury` | orchestrator | convention fix (prefix form) |
| `fx-hedger` | keep | domain noun | FX hedging desk role |
| `wallet-manager` | keep | domain noun | established industry vocabulary; custody inventory |
| `gateway-api`, `gateway-blockchain`, `gateway-exchange`, `gateway-fiat`, `ui-*`, `accounting-ledger`, `audit-logger`, `notifier`, `kyc-onboarding`, `kyt-aml-screening` | keep | as classified | already fit the taxonomy |