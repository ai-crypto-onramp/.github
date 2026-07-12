# Integration tests

Black-box HTTP integration tests for the services in `docker-compose.yml`,
written as [Hurl](https://hurl.dev) files — one directory per service, each
suite self-contained (no shared state between services or files).

## Setup

```bash
brew install hurl   # single binary, no runtime dependencies
```

## Running

```bash
make up                  # start the stack (wait for healthchecks to go green)
make test                # run all suites; writes an HTML report to reports/
make test-identity-auth  # run one service's suite (test-<alias|service>)
make test-policy         # aliases work too (see Makefile)
```

Or directly, without make:

```bash
hurl --test tests/*/*.hurl
hurl --test tests/pricing-quote/*.hurl
```

Useful flags: `--report-html <dir>` or `--report-junit <file>` for CI
reports, `--verbose` to see full requests/responses on failure.

## Conventions

- Tests hit the host ports published in `docker-compose.yml`
  (api-gateway on 8080, then 8081-8101 alphabetically, skipping 8090
  which is Gatus).
- Each `.hurl` file is a self-contained scenario; entries within a file run
  in order, and captures (`[Captures]`) carry values between steps.
- Suites are written to be idempotent against accumulated state (Postgres
  and Redis persist across runs): flows create fresh identities per run via
  the `{{newUuid}}` generator (identity-auth emails, KYC user ids, policy
  whitelist users, notification event ids), and asserts on shared state are
  tolerant (`count >= 1`, alerts are assigned but never closed).
- The aml-kyt-screening TRM webhook signature is HMAC-SHA256 over the exact
  request body with the compose secret `dev-secret-trm`. The signed bodies
  are one-line strings with precomputed signatures — if you edit a body,
  recompute with:
  `printf '%s' '<body>' | openssl dgst -sha256 -hmac dev-secret-trm -hex`

## Coverage notes

- **Full flows** — aml-kyt-screening (screen, cache hit, webhooks, alerts),
  identity-auth (register → verify → login → refresh → logout → close),
  onboarding-kyc (application state machine, documents, liveness,
  screening), policy-risk-engine (whitelist gating, OPA decisions, review
  queue), pricing-quote (quote → claim → refresh, bulk, validation), and
  notification (preferences, events, dedupe, partner webhooks).
- **Health only** — the remaining 15 services are scaffolds that expose
  just `GET /healthz`; their suites pin that contract until real endpoints
  land.
- **gRPC / async surfaces** — none of the services expose gRPC; the event
  bus is not yet wired, so webhook delivery is exercised via the
  notification service's confirm endpoint.
