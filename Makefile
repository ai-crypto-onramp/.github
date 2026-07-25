# Makefile — docker compose aliases for the local dev stack.
#
# Usage:
#   make up            bring the full stack up (detached)
#   make down          stop and remove containers
#   make restart       restart all services
#   make ps            list running services
#   make logs          tail logs for all services
#   make build         (re)build all service images
#   make build-go      (re)build all Go services
#   make build-ts      (re)build all TypeScript services
#   make build-rs      (re)build all Rust services
#   make build-py      (re)build all Python services
#   make pull          pull base images
#   make dashboard     open the Gatus health dashboard in the browser
#   make test          run all Hurl integration suites (HTML report in `reports/`)
#   make seed-db       populate all postgres databases with dummy fixture data
#   make reset-db      truncate all tables across all postgres databases
#   make up-<svc>      start one service:            `make up-kyc`, `make up-identity-auth`
#   make down-<svc>    stop & remove one service:    `make down-kyc`, `make down-front-office-ui`
#   make build-<svc>   rebuild one service image without cache
#   make logs-<svc>    tail logs for one service:    `make logs-policy`
#   make test-<svc>    run one service's test suite: `make test-pricing`
#   make psql          psql into the shared postgres container
#   make redis-cli     redis-cli into the shared redis container

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

down:
	$(COMPOSE) down

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

# Build only the Go services (shared module + build cache via BuildKit mounts).
GO_SERVICES := kyt-aml-screening audit-logger gateway-blockchain exchange-connector \
	fx-hedger auth-identity liquidity-router kyc-onboarding payment-orchestrator \
	policy-risk-engine pricing-quote rail-connector transaction-orchestrator \
	treasury-orchestrator wallet-manager

build-go:
	DOCKER_BUILDKIT=1 $(COMPOSE) build $(GO_SERVICES)

# Build only the TypeScript services.
TS_SERVICES := gateway-api notifier ui-front-office ui-middle-office

build-ts:
	DOCKER_BUILDKIT=1 $(COMPOSE) build $(TS_SERVICES)

# Build only the Rust services.
RS_SERVICES := accounting-ledger mpc-signer

build-rs:
	DOCKER_BUILDKIT=1 $(COMPOSE) build $(RS_SERVICES)

# Build only the Python services.
PY_SERVICES := fraud-detection reconciliation ui-back-office

build-py:
	DOCKER_BUILDKIT=1 $(COMPOSE) build $(PY_SERVICES)

# Open the Gatus health dashboard in the browser
dashboard:
	open http://localhost:8090

# Integration tests (Hurl suites in tests/, one directory per service).
# Writes an HTML report to reports/ (view with: open reports/index.html).
# The directory is wiped first so the report always reflects the latest run.
clean:
	rm -rf $(REPORTS)

test: clean
	hurl --test $(HURL_TOKEN_VARS) $(HURL_TRM_VARS) --report-html $(REPORTS) tests/*/*.hurl

# Short aliases for service names, used by the up-%, logs-% and test-%
# patterns. Services without an alias (postgres, redis, gatus) are addressed
# by full name.
kyt       := kyt-aml-screening
gateway   := gateway-api
audit     := audit-logger
chain     := gateway-blockchain
exchange  := exchange-connector
fraud     := fraud-detection
fx        := fx-hedger
auth      := auth-identity
ledger    := accounting-ledger
liquidity := liquidity-router
mpc       := mpc-signer
notify    := notifier
kyc       := kyc-onboarding
payment   := payment-orchestrator
policy    := policy-risk-engine
pricing   := pricing-quote
rails     := rail-connector
recon     := reconciliation
txo       := transaction-orchestrator
treasury  := treasury-orchestrator
wallet    := wallet-manager
front     := ui-front-office
middle    := ui-middle-office
back      := ui-back-office

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
# e.g. make test-policy or make test-policy-risk-engine
test-%:
	hurl --test $(HURL_TOKEN_VARS) $(HURL_TRM_VARS) tests/$(or $($*),$*)/*.hurl

# One-shot / interactive tools
psql:
	$(COMPOSE) exec postgres psql -U postgres

redis-cli:
	$(COMPOSE) exec redis redis-cli

# Populate all databases with dummy fixture data.
# Requires the postgres container to be running (make up or make up-postgres).
seed-db:
	@for f in fixtures/seed/*.sql; do \
		$(COMPOSE) exec -T postgres psql -U postgres -v ON_ERROR_STOP=1 < "$$f" || exit 1; \
	done

# Truncate all data in every service database (tables and migrations preserved).
# Requires the postgres container to be running with services migrated.
# Use `make reset-db seed-db` to wipe and repopulate in one shot.
#
# reset.sql runs once per database and uses a 5s lock_timeout with an
# EXCEPTION handler, so a database whose tables are locked by a running
# service is aborted atomically (left untouched, not half-truncated) and
# psql exits non-zero so the loop stops. The intended usage is `make up`
# (which starts postgres, runs reset-db, then starts app services); to
# reset against a live stack, stop the app services first:
# 
# `make down && make up postgres && make reset-db seed-db && make up`
#
reset-db:
	@for f in fixtures/seed/*.sql; do \
		db=$$(basename "$$f" .sql); \
		$(COMPOSE) exec -T postgres psql -q -U postgres -d $$db -v ON_ERROR_STOP=1 < fixtures/reset.sql; \
	done
