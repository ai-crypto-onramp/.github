# Makefile — docker compose aliases for the local dev stack.
#
# Postgres data is fresh on every `make up`: `make down` removes the named
# pg-data volume (so the next `make up` boots an empty cluster and each
# service re-runs its migrations). To preserve Postgres across down/up
# cycles (e.g. iterating on a single service without wiping data), use
# `make down KEEP_DB=1`. For an in-place data reset against a live stack,
# `make reset-db` truncates every service database without bouncing it.
#
# Usage:
#
#   make up            bring the full stack up (detached; fresh Postgres)
#   make down          stop, remove containers and volumes (fresh DB next up)
#   make restart       restart all services
#   make ps            list running services
#   make build         (re)build all service images
#   make pull          pull base images
#   make logs          tail logs for all services
#   make dashboard     open the Gatus health dashboard in the browser
#   make clean         cleanup Hurl HTML reports
#   make test          run all Hurl integration suites (HTML report in `reports/`)
#
#   make build-go      (re)build all Go services
#   make build-py      (re)build all Python services
#   make build-rs      (re)build all Rust services
#   make build-ts      (re)build all TypeScript services
#
#   make up-<svc>      start one service:            `make up-kyc`, `make up-identity-auth`
#   make down-<svc>    stop & remove one service:    `make down-kyc`, `make down-front-office-ui`
#   make build-<svc>   rebuild one service image without cache
#   make logs-<svc>    tail logs for one service:    `make logs-policy`
#   make test-<svc>    run one service's test suite: `make test-pricing`
#
#   make psql          psql into the shared postgres container
#   make redis-cli     redis-cli into the shared redis container
#   make seed-db       populate all postgres databases with dummy fixture data
#   make reset-db      truncate all tables across all postgres databases

COMPOSE := docker compose
REPORTS := reports

# Hurl test variables generated per run. gen-token.py mints the HS256
# service-token JWT; gen-trm-sig.py mints a fresh TRM webhook event_id +
# HMAC signature so the aml-kyt dedup table doesn't suppress alert creation
# on re-runs. Each script prints `name=value` token lines; the sed here
# prepends `--variable ` to each line and tr joins them into a single
# space-separated string inlined into the hurl call.
HURL_TOKEN_VARS := $(shell python3 scripts/gen-token.py | sed 's/^/--variable /' | tr '\n' ' ')
HURL_TRM_VARS   := $(shell python3 scripts/gen-trm-sig.py | sed 's/^/--variable /' | tr '\n' ' ')

.PHONY: all clean up down restart ps logs build build-go build-ts build-rs build-py pull test seed-db reset-db dashboard psql redis-cli up-% down-% build-% logs-% test-%

# Default target: start the whole stack.
# DB reset ordering is handled in docker-compose.yml via the db-reset
# one-shot service (depends_on postgres: service_healthy; every app
# service depends_on db-reset: service_completed_successfully), so a plain
# `docker compose up -d` truncates all service DBs before any app boots.
all: up

up:
	$(COMPOSE) up -d

# Stop and remove containers. By default also removes named volumes (so
# Postgres starts fresh on the next `make up`). Pass KEEP_DB=1 to preserve
# the pg-data volume across down/up cycles (persistent dev data).
down:
	$(COMPOSE) down $(if $(KEEP_DB),,-v)

restart:
	$(COMPOSE) restart

ps:
	$(COMPOSE) ps

build:
	DOCKER_BUILDKIT=1 $(COMPOSE) build

pull:
	$(COMPOSE) pull

logs:
	$(COMPOSE) logs -f --tail=200

# Open the Gatus health dashboard in the browser
dashboard:
	open http://localhost:8090

# Run Hurl test suite
test: clean
	hurl --test $(HURL_TOKEN_VARS) $(HURL_TRM_VARS) --report-html $(REPORTS) tests/*/*.hurl

clean:
	rm -rf $(REPORTS)

# Build only the Go services (shared module + build cache via BuildKit mounts).
GO_SERVICES := audit-logger engine-liquidity engine-policy-risk engine-pricing \
	fx-hedger gateway-auth gateway-blockchain gateway-exchange gateway-fiat \
	kyc-onboarding kyt-aml-screening orchestrator-fiat orchestrator-treasury \
	orchestrator-tx wallet-manager

build-go:
	DOCKER_BUILDKIT=1 $(COMPOSE) build $(GO_SERVICES)

# Build only the Python services.
PY_SERVICES := engine-fraud engine-recon ui-back-office

build-py:
	DOCKER_BUILDKIT=1 $(COMPOSE) build $(PY_SERVICES)

# Build only the Rust services.
RS_SERVICES := accounting-ledger mpc-signer

build-rs:
	DOCKER_BUILDKIT=1 $(COMPOSE) build $(RS_SERVICES)

# Build only the TypeScript services.
TS_SERVICES := gateway-api notifier ui-front-office ui-middle-office

build-ts:
	DOCKER_BUILDKIT=1 $(COMPOSE) build $(TS_SERVICES)

# Short aliases for service names, used by the up-%, logs-% and test-%
# patterns. Services without an alias (postgres, redis, gatus) are addressed
# by full name.
audit     := audit-logger
auth      := gateway-auth
back      := ui-back-office
chain     := gateway-blockchain
exchange  := gateway-exchange
fraud     := engine-fraud
front     := ui-front-office
fx        := fx-hedger
gateway   := gateway-api
kyc       := kyc-onboarding
kyt       := kyt-aml-screening
ledger    := accounting-ledger
liquidity := engine-liquidity
middle    := ui-middle-office
mpc       := mpc-signer
notify    := notifier
payment   := orchestrator-fiat
policy    := engine-policy-risk
pricing   := engine-pricing
rails     := gateway-fiat
recon     := engine-recon
treasury  := orchestrator-treasury
txo       := orchestrator-tx
wallet    := wallet-manager

# Start an individual service: make up-<alias|service>, e.g. make up-kyc
up-%:
	$(COMPOSE) up -d $(or $($*),$*)

# Stop & remove an individual service: make down-<alias|service>,
# e.g. make down-kyc or make down-front
down-%:
	$(COMPOSE) rm -sf $(or $($*),$*)

# Build one service withour cache: make build-<alias|service>
build-%:
	$(COMPOSE) build --no-cache $(or $($*),$*)

# Tail logs for an individual service: make logs-<alias|service>
logs-%:
	$(COMPOSE) logs -f --tail=200 $(or $($*),$*)

# Run one service's integration test suite: make test-<alias|service>,
# e.g. make test-policy or make test-engine-policy-risk
test-%:
	hurl --test $(HURL_TOKEN_VARS) $(HURL_TRM_VARS) tests/$(or $($*),$*)/*.hurl

# One-shot / interactive tools
psql:
	$(COMPOSE) exec postgres psql -U postgres

redis-cli:
	$(COMPOSE) exec redis redis-cli

# Populate all databases with synthetic fixture data via scripts/seed.py.
# Runs the seed compose service inside the network. MODE selects dataset
# size: 10, 100 (default), or 1000 records per table. The seeder inserts
# only (no truncate); run `make reset-db` first for a clean slate.
#   make seed-db
#   make seed-db MODE=100
#   make seed-db MODE=1000
seed-db:
	SEED_MODE=$(or $(MODE),100) $(COMPOSE) run --rm --no-deps seed

# Truncate all data in every service database (tables and migrations
# preserved). Pipes scripts/reset.sql through psql once per DB. Use
# `make reset-db seed-db` to wipe and repopulate in one shot.
reset-db:
	@set -e; for db in $$(grep -oE 'CREATE DATABASE [a-z_]+' postgres-init.sql | awk '{print $$3}'); do \
		echo "  resetting $$db..."; \
		$(COMPOSE) exec -T postgres psql -q -U postgres -d $$db -v ON_ERROR_STOP=1 < scripts/reset.sql; \
	done
