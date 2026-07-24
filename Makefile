# Makefile — docker compose aliases for the local dev stack.
#
# Usage:
#   make up            bring the full stack up (detached)
#   make down          stop and remove containers
#   make restart       restart all services
#   make ps            list running services
#   make logs          tail logs for all services
#   make build         (re)build all service images
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

.PHONY: all clean up down restart ps logs build pull test seed-db reset-db dashboard psql redis-cli up-% down-% build-% logs-% test-%

# Default target: start the whole stack
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

# buildx bake builds all services in parallel (faster than `compose build`
# for many services). Requires BuildKit (Docker Desktop default).
bake:
	DOCKER_BUILDKIT=1 docker buildx bake

build-no-cache:
	DOCKER_BUILDKIT=1 $(COMPOSE) build --no-cache

pull:
	$(COMPOSE) pull

logs:
	$(COMPOSE) logs -f --tail=200

# Open the Gatus health dashboard in the browser
dashboard:
	open http://localhost:8090

# Integration tests (Hurl suites in tests/, one directory per service).
# Writes an HTML report to reports/ (view with: open reports/index.html).
# The directory is wiped first so the report always reflects the latest run.
clean:
	rm -rf $(REPORTS)

test: clean
	hurl --test --report-html $(REPORTS) tests/*/*.hurl

# Short aliases for service names, used by the up-%, logs-% and test-%
# patterns. Services without an alias (postgres, redis, gatus) are addressed
# by full name.
kyt       := aml-kyt-screening
gateway   := api-gateway
audit     := audit-event-log
chain     := blockchain-gateway
exchange  := exchange-connectors
fraud     := fraud-detection
fx        := fx-hedging
auth      := identity-auth
ledger    := ledger-accounting
liquidity := liquidity-routing
mpc       := mpc-signing-service
notify    := notification
kyc       := onboarding-kyc
payment   := payment-orchestration
policy    := policy-risk-engine
pricing   := pricing-quote
rails     := rail-connectors
recon     := reconciliation
txo       := transaction-orchestrator
treasury  := treasury-orchestration
wallet    := wallet-management
front     := front-office-ui
middle    := middle-office-ui
back      := back-office-ui

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
	hurl --test tests/$(or $($*),$*)/*.hurl

# One-shot / interactive tools
psql:
	$(COMPOSE) exec postgres psql -U postgres

redis-cli:
	$(COMPOSE) exec redis redis-cli

# Populate all databases with dummy fixture data.
# Requires the postgres container to be running (make up or make up-postgres).
# Each fixture file uses \c <db> to switch to the correct database.
seed-db:
	@for f in fixtures/aml_kyt.sql fixtures/audit.sql fixtures/blockchain_gateway.sql fixtures/fraud.sql fixtures/fx_hedging.sql fixtures/identity_auth.sql fixtures/ledger_accounting.sql fixtures/liquidity.sql fixtures/notification.sql fixtures/onboarding_kyc.sql fixtures/policy_engine.sql fixtures/pricing_quote.sql fixtures/reconciliation.sql fixtures/transaction_orchestrator.sql fixtures/treasury.sql fixtures/wallet_management.sql; do \
		$(COMPOSE) exec -T postgres psql -U postgres -v ON_ERROR_STOP=1 < "$$f" || exit 1; \
	done

# Truncate all data in every service database (tables and migrations preserved).
# Requires the postgres container to be running with services migrated.
# Use `make reset-db seed-db` to wipe and repopulate in one shot.
reset-db:
	@$(COMPOSE) exec -T postgres psql -U postgres -v ON_ERROR_STOP=1 < fixtures/reset.sql
