# .github/contracts/

Canonical, versioned cross-service contracts for the AI Crypto On-Ramp backend.
This directory is the **single source of truth** for every gRPC, REST-to-gRPC,
and Kafka edge between the 21 backend services.

This is the remediation for **Production-Readiness Report P0 #1** ("The
transaction saga has never run against real partners") and the related
P0 #2 ("Audit pipeline is broken end-to-end") and P0 #8 ("Reconciliation
never fetches ledger entries") — all of which trace back to the absence of a
shared contract: every cross-service edge previously had two hand-written
`.proto` files that disagreed on package name, service name, RPC name, and
message fields.

## Layout

```
.github/contracts/
  README.md              this file
  buf.yaml               buf v2 workspace config (lint + breaking checks)
  buf.gen.yaml           codegen config: go, python, typescript, rust
  proto/
    common/v1/money.proto        canonical Money (int64 minor units + currency + scale)
    common/v1/ids.proto          TransactionId, UserId, WalletId, QuoteId, KeyId
    audit/v1/events.proto        Kafka envelope for topic audit.v1
    notification/v1/events.proto Kafka envelope for topic notification.v1
    ledger/v1/ledger.proto       LedgerService gRPC (includes PostDoubleEntry)
    ledger/v1/events.proto       Kafka envelope for topic ledger.events.v1
    policy/v1/policy.proto       PolicyService gRPC
    kyt/v1/kyt.proto             KytService gRPC
    mpc/v1/mpc.proto             MpcSigningService gRPC
    payment/v1/payment.proto     PaymentService gRPC (server is currently REST-only)
    blockchain/v1/blockchain.proto BlockchainService gRPC (server is currently REST-only)
    blockchain/v1/events.proto    Kafka envelope for topic blockchain.events.v1
    liquidity/v1/events.proto     Kafka envelope for topic liquidity.fills
  asyncapi/
    audit/v1/asyncapi.yaml
    notification/v1/asyncapi.yaml
    ledger/v1/asyncapi.yaml
    blockchain/v1/asyncapi.yaml
    liquidity/v1/asyncapi.yaml
```

## Regenerating

From this directory, with `buf` installed (>= 1.40):

```sh
buf dep update      # only if deps are added to buf.yaml
buf lint
buf breaking --against '.git#branch=main'   # optional: check breaking changes
buf generate        # writes generated code to gen/{go,python,ts,rust}
```

`buf generate` emits:

| language    | out path    | plugins                                  |
|-------------|-------------|------------------------------------------|
| Go          | `gen/go`    | `protocolbuffers/go`, `grpc/go`          |
| Python      | `gen/python`| `protocolbuffers/python`, `grpc/python`  |
| TypeScript  | `gen/ts`    | `bufbuild/es`                            |
| Rust        | `gen/rust`  | `protocolbuffers/rust`                   |

The generated `gen/` tree is intentionally not committed; each service
consumes the contracts via its own `buf generate` step in CI (or a published
module once a registry is wired).

## Versioning policy

Every contract lives under a versioned package path (`<domain>/v1/`).

- **v1 → v1.x:** additive changes only — new fields with new tag numbers, new
  RPCs, new messages, new enum values. These are wire-compatible and do not
  require consumers to regenerate simultaneously.
- **v1 → v2:** breaking changes — field removals/renames, type changes,
  service/RPC renames, enum value removals. A v2 package is published
  **alongside** v1 (parallel-publish) and producers support both during the
  migration window. Consumers switch to v2 at their own cadence. Once every
  consumer has switched, v1 is deprecated then removed.
- `buf breaking` is configured with the `WIRE_JSON` ruleset so CI catches
  accidental breaking changes against `main`.

Every `.proto` file carries a `// Version: v1` header and the breaking-change
policy note.

## Ownership

The **producer service** (the service that implements the server / owns the
topic) is the canonical owner of each contract. Changes must be reviewed by
the owner service's team.

| contract                         | owner (producer)          | consumer(s)                                  | transport |
|---------------------------------|---------------------------|----------------------------------------------|-----------|
| `policy/v1/policy.proto`        | policy-risk-engine        | transaction-orchestrator, api-gateway        | gRPC      |
| `kyt/v1/kyt.proto`              | aml-kyt-screening         | transaction-orchestrator                      | gRPC      |
| `mpc/v1/mpc.proto`              | mpc-signing-service       | transaction-orchestrator, wallet-management   | gRPC      |
| `payment/v1/payment.proto`      | payment-orchestration     | transaction-orchestrator                      | gRPC¹     |
| `blockchain/v1/blockchain.proto`| blockchain-gateway        | transaction-orchestrator, wallet-management  | gRPC¹     |
| `ledger/v1/ledger.proto`        | ledger-accounting        | transaction-orchestrator, treasury-orchestration | gRPC   |
| `audit/v1/events.proto`         | every service (producer) | audit-event-log                               | Kafka     |
| `notification/v1/events.proto`  | transaction-orchestrator, payment-orchestration, blockchain-gateway | notification | Kafka |
| `ledger/v1/events.proto`        | ledger-accounting        | reconciliation                                | Kafka²    |
| `blockchain/v1/events.proto`    | blockchain-gateway        | reconciliation, notification                  | Kafka     |
| `liquidity/v1/events.proto`     | liquidity-routing        | reconciliation                                | Kafka     |

¹ The producer currently exposes REST only; the gRPC contract is canonical
  and the producer is expected to add a gRPC server. See the proto header.
² The producer does not yet publish; this is the canonical contract to
  implement against.

## How consumer services switch from private proto copies to this package

Each consumer service currently keeps private `.proto` copies (e.g.
`transaction-orchestrator/proto/{policy,kyt,mpc,payment,blockchain,ledger}.proto`)
that disagree with the producer's server. The migration is per-edge and
non-breaking from the consumer's perspective:

1. **Add a buf workspace reference** to this `.github/contracts/` directory from the
   consumer service (or, post-registry, a `buf.yaml` `deps:` entry). The
   monorepo layout lets consumers reference the contracts via a relative
   path today.
2. **Regenerate** the consumer's gRPC client stubs from the canonical
   protos (`buf generate`). The generated Go package path is
   `github.com/ai-crypto-onramp/contracts/gen/go/<domain>/v1` (the Go module
   path is independent of the filesystem location of this directory).
3. **Update the client wiring** in the consumer to call the canonical RPC
   names and pass the canonical request messages. The mapping from the old
   private copy to the canonical contract is documented per-edge in the
   remediation workstream that follows this one.
4. **Delete the private `.proto` copy** from the consumer once the
   canonical client is wired and tests pass. Do not keep both — the whole
   point of this directory is that there is exactly one definition per edge.
5. **Re-run `buf lint` and `buf breaking`** in CI to prevent drift.

Producers should likewise regenerate their server stubs from the canonical
protos and delete their private copies once the server is aligned. Where a
producer has no gRPC server yet (`payment-orchestration`, `blockchain-gateway`),
the proto here documents the canonical surface the server should implement;
until then, consumers continue calling the REST endpoints and map the JSON
fields to the proto message field names defined here.

## Kafka topic naming convention

All topics follow `<source>.<event>.v<n>`:

- `audit.v1` — every service → audit-event-log
- `notification.v1` — lifecycle producers → notification
- `ledger.events.v1` — ledger-accounting → reconciliation
- `blockchain.events.v1` — blockchain-gateway → reconciliation, notification
- `liquidity.fills` — liquidity-routing → reconciliation (legacy name kept
  for continuity; a future v2 rename to `liquidity.fills.v1` is tracked
  separately)

Every event envelope carries a `schema_version` field (`"1"` for v1).