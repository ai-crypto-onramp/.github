# Service Taxonomy

The repo's services follow a role-based naming convention. Each suffix denotes the
**role** the service plays in the system, not its domain. Domain is conveyed by the
prefix. Picking the right suffix means identifying the service's **dominant** trait,
since most real services are hybrids of several roles.

## Archetypes

### `gateway-*` — external protocol boundary

I/O translators between the platform and an outside system. They speak some external
protocol (REST / FIX / RPC / chain RPC) and emit or consume a canonical internal
representation. They do **not** make business decisions.

- `gateway-api` — public REST / BFF entry point
- `gateway-blockchain` — chain RPC adapter
- `gateway-exchange` — exchange / OTC venue adapter
- `gateway-fiat` — bank / rail adapter

**Rule:** if the service's job is "translate between us and the outside world", it is
a gateway. The `gateway-` prefix specifically means *protocol boundary to an external
system*; it is not a generic entry-point prefix.

### `engine-*` — domain computation / decision

Stateless or stateful services that take inputs and produce a **decision, transform,
or computation**. The business algorithm lives here.

- `engine-fraud` — fraud scoring
- `engine-policy-risk` — policy / risk evaluation
- `engine-pricing` — quote computation
- `engine-liquidity` — smart order routing + TWAP / VWAP execution
- `engine-recon` — reconciliation matching and break detection

**Rule:** if the service's value is "the algorithm", it is an engine.

### `*-orchestrator` — workflow coordination

Saga / state-machine coordinators that **sequence calls** across multiple services,
own transactional flow, and handle compensation. They do not compute the domain
answer themselves — they direct who does.

- `tx-orchestrator`
- `fiat-orchestrator`
- `treasury-orchestrator`

**Rule:** if the service's value is "the workflow", it is an orchestrator.

### `*-manager` — lifecycle ownership of a bounded resource

Stateful owners of a single bounded domain: CRUD + lifecycle + policy on that
resource. May run algorithms internally in service of that ownership, but
ownership is the dominant trait.

- `wallet-manager` — hot / warm / cold wallet inventory, address derivation,
  UTXO and nonce management, MPC key mapping.

**Rule:** if the service's value is "I own this thing", it is a manager.

### Domain-specific nouns — unique archetypes

Services whose role is singular enough that a generic suffix would obscure rather
than clarify. Kept as domain nouns.

- `accounting-ledger` — append-only ledger is its own archetype.
- `audit-logger` — event sink.
- `notifier` — fan-out sink.
- `kyc-onboarding`, `kyt-aml-screening` — process nouns.
- `fx-hedger` — domain noun (FX hedging desk role).

### `ui-*` — presentation layer

Separate axis entirely; not subject to the backend taxonomy.

- `ui-front-office`, `ui-middle-office`, `ui-back-office`

### `service-*` — lifecycle + computation hybrid

When a service owns a bounded resource **and** runs authoritative decisions on it,
and neither trait clearly dominates, `service-*` is the neutral default.

- `service-auth` — owns user / account / API-key / session lifecycle and runs
  authn / RBAC decisions; hybrid of manager + engine.

**Rule:** use `service-*` only when both `manager` and `engine` traits are materially
present and ownership alone would understate the service.

## Choosing a suffix

1. Is it a protocol boundary to an external system? -> `gateway-*`
2. Is its value the algorithm / decision? -> `engine-*`
3. Is its value coordinating a multi-service workflow? -> `*-orchestrator`
4. Is its value owning a bounded resource? -> `*-manager`
5. Is it a hybrid of resource-ownership + computation with no dominant trait? -> `service-*`
6. Is its role singular enough that a generic suffix would obscure it? -> domain noun
7. Is it presentation? -> `ui-*`

Most real services are hybrids. Pick the **dominant** trait; the taxonomy is a
useful discriminator, not a pure classification.

---

## Renamings Plan

| Current | New | Role | Notes |
|---|---|---|---|
| `auth-identity` | `service-auth` | service (manager + engine hybrid) | owns account/key/session lifecycle; runs authn/RBAC decisions |
| `pricing-quote` | `engine-pricing` | engine | quote computation; rate lock |
| `reconciliation` | `engine-recon` | engine | matching + break detection |
| `liquidity-router` | `engine-liquidity` | engine | SOR + TWAP/VWAP execution |
| `fraud-engine` | `engine-fraud` | engine | convention fix (prefix form) |
| `policy-risk-engine` | `engine-policy-risk` | engine | convention fix (prefix form) |
| `payment-orchestrator` | `fiat-orchestrator` | orchestrator | clarifies fiat-side scope vs. `tx-orchestrator` |
| `fx-hedger` | keep | domain noun | FX hedging desk role |
| `wallet-manager` | keep | manager | dominant trait is custody inventory ownership |
| `gateway-*`, `tx-orchestrator`, `treasury-orchestrator`, `ui-*`, `accounting-ledger`, `audit-logger`, `notifier`, `kyc-onboarding`, `kyt-aml-screening` | keep | as classified | already fit the taxonomy |