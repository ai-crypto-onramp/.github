# Makefile — docker compose aliases for the local dev stack.
#
# Usage:
#   make up          bring the full stack up (detached)
#   make down        stop and remove containers
#   make restart     restart all services
#   make ps          list running services
#   make logs        tail logs for all services
#   make logs-svc    tail logs for one service: make logs-svc SVC=aml-kyt-screening
#   make build       (re)build all service images
#   make pull        pull the postgres/redis/gatus base images
#   make health      one-shot: show /healthz for every service that exposes it
#   make psql        psql into the shared postgres container
#   make redis-cli   redis-cli into the shared redis container
#   make nuke        down -v --rmi local (wipe containers, volumes, built images)
#   make fresh       nuke + up (full clean rebuild)

SVC        ?=
COMPOSE    := docker compose
WORKDIR    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Services that expose /healthz on :8080 inside the container.
HEALTH_SVC := aml-kyt-screening api-gateway audit-event-log blockchain-gateway \
              exchange-connectors fraud-detection fx-hedging identity-auth \
              ledger-accounting liquidity-routing mpc-signing-service notification \
              onboarding-kyc payment-orchestration policy-risk-engine pricing-quote \
              rail-connectors reconciliation transaction-orchestrator \
              treasury-orchestration wallet-management

.PHONY: up down restart ps logs logs-svc build pull health psql redis-cli nuke fresh

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f --tail=200

logs-svc:
	@test -n "$(SVC)" || (echo "usage: make logs-svc SVC=<service>" && exit 2)
	$(COMPOSE) logs -f --tail=200 $(SVC)

build:
	$(COMPOSE) build

pull:
	$(COMPOSE) pull --ignore-pull-failures postgres redis gatus

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