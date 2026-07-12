# Makefile — docker compose aliases for the local dev stack.
#
# Usage:
#   make up            bring the full stack up (detached)
#   make down          stop and remove containers
#   make restart       restart all services
#   make ps            list running services
#   make logs          tail logs for all services
#   make build         (re)build all service images
#   make rebuild       rebuild all service images without cache
#   make pull          pull the postgres/redis/gatus base images
#   make dashboard     open the Gatus health dashboard in the browser
#   make test          run all Hurl integration suites (HTML report in reports/)
#   make up-<svc>      start one service:            make up-kyc, make up-identity-auth
#   make logs-<svc>    tail logs for one service:    make logs-policy
#   make test-<svc>    run one service's test suite: make test-pricing
#   make health        one-shot: show /healthz for every service that exposes it
#   make psql          psql into the shared postgres container
#   make redis-cli     redis-cli into the shared redis container
#   make nuke          down -v --rmi local (wipe containers, volumes, built images)
#   make fresh         nuke + up (full clean rebuild)

COMPOSE := docker compose

.PHONY: up down restart ps logs build rebuild pull test dashboard \
        health psql redis-cli nuke fresh

# Default target: start the whole stack
up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

ps:
	$(COMPOSE) ps

build:
	$(COMPOSE) build

rebuild:
	$(COMPOSE) build --no-cache

pull:
	$(COMPOSE) pull --ignore-pull-failures postgres redis gatus

logs:
	$(COMPOSE) logs -f --tail=200

# Open the Gatus health dashboard in the browser
dashboard:
	open http://localhost:8090

# Integration tests (Hurl suites in tests/, one directory per service).
# Writes an HTML report to reports/ (view with: open reports/index.html).
# The directory is wiped first so the report always reflects the latest run.
test:
	rm -rf reports
	hurl --test --report-html reports tests/*/*.hurl

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

# Start an individual service: make up-<alias|service>, e.g. make up-kyc
up-%:
	$(COMPOSE) up -d $(or $($*),$*)

# Tail logs for an individual service: make logs-<alias|service>
logs-%:
	$(COMPOSE) logs -f --tail=200 $(or $($*),$*)

# Run one service's integration test suite: make test-<alias|service>,
# e.g. make test-policy or make test-policy-risk-engine
test-%:
	hurl --test tests/$(or $($*),$*)/*.hurl

# Services that expose /healthz on :8080 inside the container.
HEALTH_SVC := aml-kyt-screening api-gateway audit-event-log blockchain-gateway \
              exchange-connectors fraud-detection fx-hedging identity-auth \
              ledger-accounting liquidity-routing mpc-signing-service notification \
              onboarding-kyc payment-orchestration policy-risk-engine pricing-quote \
              rail-connectors reconciliation transaction-orchestrator \
              treasury-orchestration wallet-management

health:
	@for svc in $(HEALTH_SVC); do \
		port=$$(docker compose port $$svc 8080 2>/dev/null | cut -d: -f2); \
		if [ -n "$$port" ]; then \
			status=$$(curl -fsS -m 2 http://localhost:$$port/healthz 2>/dev/null || echo "UNREACHABLE"); \
			printf "%-28s %s\n" "$$svc" "$$status"; \
		else \
			printf "%-28s %s\n" "$$svc" "not-running"; \
		fi; \
	done

psql:
	docker compose exec postgres psql -U postgres

redis-cli:
	docker compose exec redis redis-cli

nuke:
	$(COMPOSE) down -v --rmi local

fresh: nuke
	$(COMPOSE) up -d
