# Protocol-Level Rationale

The onramp partitions transport protocols by **who calls the endpoint
and how**, not by feature. gRPC is not "instead of" HTTP — both coexist,
partitioned by caller identity and communication pattern.

## Transport by role

| Caller / role | Transport | Rationale |
|---|---|---|
| Browsers, mobile SDKs, partners | HTTP REST (+ WS) | Edge reachability, TLS, CORS, JSON |
| Saga orchestrator → engines/partners | gRPC | Typed, low-latency, mTLS, deadline propagation |
| External systems → us (webhooks) | HTTP POST + HMAC | Third parties only speak HTTPS |
| Async ingestion | Kafka | Decoupling, replay, backpressure |
| Server → browser streaming | WebSocket | Native browser support, small JSON frames |
| Server → server streaming (internal) | gRPC stream | e.g. `fx.StreamExposure` |

## gRPC (22 methods, 6 services) — internal synchronous hot path

### Genuinely gRPC-only (no HTTP equivalent)

- **mpc-signer** `SignTx` / `Dkg` / `RotateKey` / `GetKeyMetadata` /
  `RestoreShare` — security boundary via mTLS, binary payloads
  (`bytes` signature / tx / public_key), no REST surface at all. The
  `custody.events.v1` async gap is caused by `SignTx` being gRPC-only
  with no REST trigger.
- **fx-hedger** `StreamExposure` — only true server-streaming method in
  the codebase; HTTP polling would be a poor substitute
  (`fx.proto:16`, `grpc.go:106-139`).
- **wallet-manager** `OnConfirmation` / `OnReorg` — push callbacks from
  the blockchain gateway with no REST equivalent
  (`wallet.proto:12-15`).

### gRPC overlapping HTTP (same handler logic, different transport)

- **engine-policy-risk** `Evaluate` — same `Services.Evaluate` behind
  both transports (`api/grpc.go:28-29`: "decision logic is identical to
  the REST path"). gRPC for the orchestrator's saga gate (50 ms latency
  budget, `README.md:131-134`); HTTP for gateway-api pre-flight checks
  + ops dashboards.
- **kyt-aml-screening** `Screen` / `GetAlert` — same `Services` struct
  (`grpcserver/server.go:31`). gRPC for the orchestrator's inline KYT
  screen on the tx saga path; HTTP for the compliance dashboard + vendor
  webhooks (`README.md:108-110`).
- **accounting-ledger** `CreateAccount` / `PostPosting` / `GetPosting` /
  `GetBalance` / `VerifyChain` — same `Store` (`grpc.rs:44-155`).
  gRPC intended as the internal write path with `x-caller` authz
  (`grpc.rs:33-40`); HTTP for back-office / finance dashboards
  (`README.md:100-103`).

### Migration assessment

The overlapping gRPC endpoints are **not duplicative** — they serve
different callers (internal saga vs ops dashboard). No migration is
needed. The right next step is wiring the actual consumers (see
"Orchestrator proto divergence" below).

## HTTP (191 endpoints, 21 services) — edge, ops, webhooks, async-adjacent

### Gateway services (gateway-*)

HTTP by necessity — browsers and partners cannot speak gRPC.
`gateway-api` is a textbook BFF translating external JSON into internal
calls (`README.md`: "Shields internal service topology from clients").
`gateway-auth`, `gateway-fiat`, `gateway-exchange`, and
`gateway-blockchain` are REST-only. Some READMEs mention gRPC
aspirationally, but no `grpc.NewServer` exists in these services.

### Orchestrator services

HTTP for their own clients (gateway, ops dashboards); gRPC for saga
fan-out. `orchestrator-tx` is the only orchestrator that actually dials
gRPC partners (`grpcclient.go:143-197`, `cmd/orchestrator/main.go:193-249`).
`orchestrator-fiat` and `orchestrator-treasury` are HTTP + Kafka only.

### Engine services

HTTP for operator dashboards + ad-hoc queries; Kafka for async inputs.
Only `engine-policy-risk` serves gRPC (on-path synchronous gate).
`engine-fraud`, `engine-pricing`, `engine-recon`, and
`engine-liquidity` are HTTP + Kafka with no gRPC server.

### Webhook receivers (6 services)

HTTP by necessity — Stripe / Adyen / Onfido / Chainalysis / custody
providers POST JSON + HMAC over HTTPS. gRPC is not an option for
third-party push.

| Service | Endpoint | Caller |
|---|---|---|
| gateway-fiat | `POST /webhooks/:rail` | Stripe / Adyen / SEPA / PIX / UPI |
| orchestrator-fiat | `POST /v1/webhooks/:rail` | rail settlement / chargeback |
| kyc-onboarding | `POST /v1/webhooks/:vendor` | Onfido / Sumsub |
| kyt-aml-screening | `POST /v1/webhooks/:vendor` | Chainalysis / TRM |
| mpc-signer | `POST /v1/custody/webhook` | custody provider |
| notifier | `POST /v1/webhooks/partners` + `/verify` | partner webhook registry + delivery |

### WebSocket (2 endpoints)

`gateway-blockchain` `WS /v1/chains/:chain/heads` and `engine-pricing`
`WS /v1/rates/subscribe` — server-pushed streaming to browsers / SDKs.
WS chosen over gRPC streaming because clients are browsers (native WS
support, small JSON frames, no protobuf runtime needed). gRPC streaming
is reserved for the internal `fx-hedger.StreamExposure`, where both
peers are internal Go services with generated stubs.

## Orchestrator proto divergence — biggest integration gap

The orchestrator defines its **own** simplified protos
(`orchestrator-tx/proto/*.proto`) that do not match the canonical
service protos:

| Orchestrator proto | Canonical proto | Mismatch |
|---|---|---|
| `LedgerAccounting.PostDoubleEntry` | `ledger.v1.Ledger.PostPosting` | different request schema |
| `AmlKytScreening.Screen` | `KYTService.Screen` | different fields |
| `MpcSigningService.Sign` | `MpcSigningService.SignTx` | no `policy_decision_token`, `key_id`, `chain`, `wallet_id` |
| `PolicyRiskEngine.Evaluate` | `policy.v1.Policy.Evaluate` | subset of canonical fields |

No service in the tree actually dials the canonical `ledger.v1.Ledger`,
`KYTService`, `MpcSigningService`, or `policy.v1.Policy` clients — they
are served but unwired. This explains the 0% gRPC E2E coverage and is
the single biggest integration gap. Resolving it requires either
aligning the orchestrator's protos to the canonical ones or generating
adapters that bridge the two schemas.