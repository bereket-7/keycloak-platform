.PHONY: help validate-foundation up down logs ps health

COMPOSE := docker compose
COMPOSE_FILE := docker-compose.yml

help:
	@echo "Keycloak Platform — available targets"
	@echo ""
	@echo "  validate-foundation  Run Phase 00 acceptance checks"
	@echo "  up                   Start local infrastructure (Phase 01+)"
	@echo "  down                 Stop local infrastructure"
	@echo "  ps                   Show container status"
	@echo "  logs                 Follow service logs"
	@echo "  health               Check service health (Phase 01+)"
	@echo ""
	@echo "Documentation: docs/README.md"
	@echo "Current phase:  docs/phases/00-foundation.md"

validate-foundation:
	@./scripts/validate-foundation.sh

up:
	@test -f $(COMPOSE_FILE) && grep -qv '^[[:space:]]*$$' $(COMPOSE_FILE) || \
		(echo "error: docker-compose.yml is not configured yet — complete Phase 01" && exit 1)
	@test -f .env || (echo "error: copy .env.example to .env and set values" && exit 1)
	$(COMPOSE) up -d

down:
	@test -f $(COMPOSE_FILE) && grep -qv '^[[:space:]]*$$' $(COMPOSE_FILE) || \
		(echo "error: docker-compose.yml is not configured yet — complete Phase 01" && exit 1)
	$(COMPOSE) down

ps:
	@test -f $(COMPOSE_FILE) && grep -qv '^[[:space:]]*$$' $(COMPOSE_FILE) || \
		(echo "error: docker-compose.yml is not configured yet — complete Phase 01" && exit 1)
	$(COMPOSE) ps

logs:
	@test -f $(COMPOSE_FILE) && grep -qv '^[[:space:]]*$$' $(COMPOSE_FILE) || \
		(echo "error: docker-compose.yml is not configured yet — complete Phase 01" && exit 1)
	$(COMPOSE) logs -f

health:
	@test -f $(COMPOSE_FILE) && grep -qv '^[[:space:]]*$$' $(COMPOSE_FILE) || \
		(echo "error: docker-compose.yml is not configured yet — complete Phase 01" && exit 1)
	$(COMPOSE) ps --format json | grep -q '"Health":"healthy"' && echo "All services healthy" || \
		(echo "One or more services unhealthy or health checks not configured" && exit 1)
