# Service Rename Plan

## Final rename table (alphabetical by proposed name)

| Current | Proposed |
|---|---|
| `audit-event-log` | `audit-logger` |
| `identity-auth` | `auth-identity` |
| `exchange-connectors` | `exchange-connector` |
| `fx-hedging` | `fx-hedger` |
| `api-gateway` | `gateway-api` |
| `blockchain-gateway` | `gateway-blockchain` |
| `liquidity-routing` | `liquidity-router` |
| `mpc-signing-service` | `mpc-signer` |
| `notification` | `notifier` |
| `payment-orchestration` | `payment-orchestrator` |
| `rail-connectors` | `rail-connector` |
| `treasury-orchestration` | `treasury-orchestrator` |
| `back-office-ui` | `ui-back-office` |
| `front-office-ui` | `ui-front-office` |
| `middle-office-ui` | `ui-middle-office` |
| `wallet-management` | `wallet-manager` |

Unchanged: `aml-kyt-screening`, `fraud-detection`, `ledger-accounting`,
`onboarding-kyc`, `policy-risk-engine`, `pricing-quote`, `reconciliation`,
`transaction-orchestrator`.

## Implementation plan

### Step 0 — Rename GitHub repos (run first, so URLs resolve throughout)

For each rename, run `gh repo rename` to align the remote with the new
name. Order doesn't matter; they're independent repos under
`ai-crypto-onramp`.

```sh
gh repo rename audit-logger         --repo ai-crypto-onramp/audit-event-log        --yes
gh repo rename auth-identity        --repo ai-crypto-onramp/identity-auth          --yes
gh repo rename exchange-connector   --repo ai-crypto-onramp/exchange-connectors    --yes
gh repo rename fx-hedger            --repo ai-crypto-onramp/fx-hedging             --yes
gh repo rename gateway-api          --repo ai-crypto-onramp/api-gateway            --yes
gh repo rename gateway-blockchain   --repo ai-crypto-onramp/blockchain-gateway     --yes
gh repo rename liquidity-router     --repo ai-crypto-onramp/liquidity-routing      --yes
gh repo rename mpc-signer           --repo ai-crypto-onramp/mpc-signing-service     --yes
gh repo rename notifier             --repo ai-crypto-onramp/notification          --yes
gh repo rename payment-orchestrator --repo ai-crypto-onramp/payment-orchestration --yes
gh repo rename rail-connector       --repo ai-crypto-onramp/rail-connectors        --yes
gh repo rename treasury-orchestrator --repo ai-crypto-onramp/treasury-orchestration --yes
gh repo rename ui-back-office       --repo ai-crypto-onramp/back-office-ui         --yes
gh repo rename ui-front-office      --repo ai-crypto-onramp/front-office-ui        --yes
gh repo rename ui-middle-office     --repo ai-crypto-onramp/middle-office-ui       --yes
gh repo rename wallet-manager       --repo ai-crypto-onramp/wallet-management      --yes
```

After renaming, update each service's local `.git` remote `origin` URL:

```sh
for old_new in \
  "audit-event-log:audit-logger" \
  "identity-auth:auth-identity" \
  "exchange-connectors:exchange-connector" \
  "fx-hedging:fx-hedger" \
  "api-gateway:gateway-api" \
  "blockchain-gateway:gateway-blockchain" \
  "liquidity-routing:liquidity-router" \
  "mpc-signing-service:mpc-signer" \
  "notification:notifier" \
  "payment-orchestration:payment-orchestrator" \
  "rail-connectors:rail-connector" \
  "treasury-orchestration:treasury-orchestrator" \
  "back-office-ui:ui-back-office" \
  "front-office-ui:ui-front-office" \
  "middle-office-ui:ui-middle-office" \
  "wallet-management:wallet-manager"; do
  old=${old_new%:*}; new=${old_new#*:}
  git -C "$new" remote set-url origin "ssh://git@github.com/ai-crypto-onramp/$new.git"
done
```

**Requires admin rights on the `ai-crypto-onramp` org.** The `pavel-bc`
account used for initial attempt has only pull access
(`permissions.admin=false, push=false`). Run with an org-admin account.

### Step 1 — Rename top-level directories (16 `mv`s)

```sh
mv audit-event-log        audit-logger
mv identity-auth          auth-identity
mv exchange-connectors    exchange-connector
mv fx-hedging             fx-hedger
mv api-gateway            gateway-api
mv blockchain-gateway     gateway-blockchain
mv liquidity-routing     liquidity-router
mv mpc-signing-service    mpc-signer
mv notification           notifier
mv payment-orchestration  payment-orchestrator
mv rail-connectors        rail-connector
mv treasury-orchestration treasury-orchestrator
mv back-office-ui         ui-back-office
mv front-office-ui        ui-front-office
mv middle-office-ui       ui-middle-office
mv wallet-management      wallet-manager
```

### Step 2 — Per-service internal files

#### Go services

Affected: `audit-logger`, `auth-identity`, `exchange-connector`, `fx-hedger`,
`gateway-blockchain`, `liquidity-router`, `payment-orchestrator`,
`rail-connector`, `treasury-orchestrator`, `wallet-manager`.

Per service:
- `go.mod` — `module github.com/ai-crypto-onramp/<old>` → `<new>`
- `cmd/<old>/main.go` → `mv cmd/<old> cmd/<new>`, update `package` if it matches
- All `*.go` — `github.com/ai-crypto-onramp/<old>/` →
  `github.com/ai-crypto-onramp/<new>/` (per-service scoped sed)
- `Makefile` — docker image tag `ai-crypto-onramp/<old>` → `<new>`
- `README.md` — GitHub + codecov URLs
- `Dockerfile` — verify `CMD`/`ENTRYPOINT` binary path (usually `/<old>`,
  e.g. `/audit-event-log`)

Implement as a per-service loop:

```sh
for old_new in \
  "audit-event-log:audit-logger" \
  "identity-auth:auth-identity" \
  "exchange-connectors:exchange-connector" \
  "fx-hedging:fx-hedger" \
  "blockchain-gateway:gateway-blockchain" \
  "liquidity-routing:liquidity-router" \
  "payment-orchestration:payment-orchestrator" \
  "rail-connectors:rail-connector" \
  "treasury-orchestration:treasury-orchestrator" \
  "wallet-management:wallet-manager"; do
  old=${old_new%:*}; new=${old_new#*:}
  rg -l "github.com/ai-crypto-onramp/$old" "$new" \
    | xargs sed -i '' "s|github.com/ai-crypto-onramp/$old|github.com/ai-crypto-onramp/$new|g"
  sed -i '' "s|ai-crypto-onramp/$old|ai-crypto-onramp/$new|g" "$new/Makefile" "$new/README.md"
  sed -i '' "s|module github.com/ai-crypto-onramp/$old|module github.com/ai-crypto-onramp/$new|" "$new/go.mod"
  if [ -d "$new/cmd/$old" ]; then mv "$new/cmd/$old" "$new/cmd/$new"; fi
done
```

#### TS services (gateway-api, notifier, ui-front-office, ui-middle-office)

- `package.json` — `"name": "<old>"` → `<new>`
- `Makefile`, `README.md` — image tags + URLs
- UI services: `src/lib/config.ts` / `src/config.ts` — check for self-name
  references (likely only in comments)

#### Python UI (ui-back-office)

- `pyproject.toml` — `name = "back-office-ui"` → `"ui-back-office"`
- `src/back_office_ui/` → `src/ui_back_office/` (directory + all
  `from back_office_ui` imports across `*.py`)
- `Makefile`, `README.md`

#### Rust (mpc-signer)

- `Cargo.toml` — `name = "mpc-signing-service"` → `"mpc-signer"`
- `Dockerfile` — `COPY --from=build /app/target/release/mpc-signing-service`
  → `mpc-signer`
- `Makefile`, `README.md`
- Binary name in `src/main.rs` (verify)

### Step 3 — `.github/` orchestration repo

#### `docker-compose.yml`
- 16 service block keys: `audit-event-log:` → `audit-logger:` etc.
- `build: ../<old>` → `../<new>`
- All `depends_on:` service keys
- Env-var hostname references: `http://fx-hedging:8080` →
  `http://fx-hedger:8080`, etc. Specifically the `SERVICE_TOKEN_SECRET`
  block, `KAFKA_BROKERS`, `DB_URL`/`DATABASE_URL` hostnames, `REDIS_URL`,
  `WALLET_SERVICE_URL`, `BLOCKCHAIN_GATEWAY_URL`, etc. — every
  `http://<old-svc-name>` reference.

#### `Makefile`
- Alias map: `audit := audit-event-log` → `audit := audit-logger`,
  `gateway := api-gateway` → `gateway-api`, etc.
- Service lists: `GO_SERVICES`, `TS_SERVICES`, `RS_SERVICES`,
  `PY_SERVICES` — update each renamed member.

#### `gatus.yml`
- 16 `name:` entries + 16 `url: http://<old>:port/...` entries.

#### `scripts/gen-certs.sh`
- `SERVICES` env list: `mpc-signing-service` → `mpc-signer`,
  `blockchain-gateway` → `gateway-blockchain`.

#### `scripts/sloc.py`
- Service directory list (verify and update).

#### `tests/<svc>/` directory renames (16)
```sh
for old_new in \
  "audit-event-log:audit-logger" \
  "identity-auth:auth-identity" \
  "exchange-connectors:exchange-connector" \
  "fx-hedging:fx-hedger" \
  "api-gateway:gateway-api" \
  "blockchain-gateway:gateway-blockchain" \
  "liquidity-routing:liquidity-router" \
  "mpc-signing-service:mpc-signer" \
  "notification:notifier" \
  "payment-orchestration:payment-orchestrator" \
  "rail-connectors:rail-connector" \
  "treasury-orchestration:treasury-orchestrator" \
  "back-office-ui:ui-back-office" \
  "front-office-ui:ui-front-office" \
  "middle-office-ui:ui-middle-office" \
  "wallet-management:wallet-manager"; do
  mv "tests/${old_new%:*}" "tests/${old_new#:*}"
done
```
`.hurl` files inside reference `localhost:<port>` (unchanged) — no content
edits needed except service name in comments.

#### `tests/README.md`, `README.md`, `docs/*.md`
- Prose references to old service names → new names.

#### `postgres-init.sql` & `fixtures/seed/*.sql`
- **No change.** DB names are stable identifiers decoupled from service
  hostnames.

### Step 4 — `.github/profile/` regeneration

The `profile/README.md` is a service directory table with GitHub + CI +
codecov badges. Regenerate from the rename table with new URLs. Output
format (one row per service, sorted by current name alphabetically):

```md
| Emoji | [Name](repo URL) | Lang | CI badge | Codecov badge | SLOC |
```

For each of the 24 services (16 renamed + 8 unchanged), emit:
- Emoji (preserved from current file)
- Link: `https://github.com/ai-crypto-onramp/<new-name>`
- Lang (preserved)
- CI badge:
  `https://github.com/ai-crypto-onramp/<new-name>/actions/workflows/ci.yml/badge.svg`
- Codecov badge:
  `https://codecov.io/gh/ai-crypto-onramp/<new-name>/branch/main/graph/badge.svg`
- SLOC number (preserved or re-counted via `scripts/sloc.py`)

The regeneration script:

```sh
python3 scripts/sloc.py --format markdown > .github/profile/README.md
```

or hand-edit the existing file replacing every `<old-name>` → `<new-name>`
URL path segment.

---

## Execution order summary

1. **`gh repo rename`** for all 16 (Step 0) — remote repos renamed first
   so all subsequent URL updates resolve. **Requires org admin.**
2. **`git remote set-url`** per service to fix local `.git/origin`.
3. **`mv` top-level dirs** (Step 1).
4. **Per-service sed + go.mod/package.json/Cargo.toml/pyproject.toml**
   (Step 2).
5. **`.github/` orchestration files** — docker-compose.yml, Makefile,
   gatus.yml, scripts, tests dir renames, READMEs (Step 3).
6. **`.github/profile/README.md` regeneration** (Step 4).

## Risks / decisions before executing

- **GitHub repo renames require org admin.** The `pavel-bc` account used
  for the initial attempt has only pull access
  (`permissions.admin=false, push=false`). Run Step 0 with an org-admin
  account, or skip and keep URLs pointing at existing repo names.
- **DB names stay** — `postgres-init.sql` and `fixtures/seed/*.sql` keep
  `audit`, `identity_auth`, etc. Service hostname changes don't propagate
  to DB names.
- **Kafka topic names stay** — `audit.v1`, `notification.v1` are stable
  contracts, not tied to service names.
- **Proto package names stay** — `mpc.v1`, `notification.v1`,
  `blockchain.v1` in `contracts/proto/` are versioned contracts, not
  service identifiers.
- **Per-service CI workflows** — each service's `.github/workflows/ci.yml`
  runs in its own repo and doesn't reference the service name in URLs; no
  edits needed.
- **Local working state** — each service repo may have uncommitted
  changes; the `mv` + sed is safe to run on a clean tree but should be
  staged/committed per-service after verification (`go build ./...`,
  `npm test`, `cargo build`, `make test`).