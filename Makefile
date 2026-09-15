.PHONY: help validate-foundation validate-infrastructure config up down reset logs ps health

COMPOSE := docker compose
COMPOSE_FILE := docker-compose.yml

help:
	@echo "Keycloak Platform — available targets"
	@echo ""
	@echo "  validate-foundation       Run Phase 00 acceptance checks"
	@echo "  validate-infrastructure   Run Phase 01 runtime checks (stack must be up)"
	@echo "  config                    Validate docker compose configuration"
	@echo "  up                        Start local infrastructure"
	@echo "  down                      Stop local infrastructure"
	@echo "  reset                     Stop and remove volumes (destroys database data)"
	@echo "  ps                        Show container status"
	@echo "  logs                      Follow service logs"
	@echo "  health                    Check service health"
	@echo ""
	@echo "Documentation: docs/README.md"
	@echo "Current phase:  docs/phases/01-infrastructure.md"

validate-foundation:
	@./scripts/validate-foundation.sh

validate-infrastructure:
	@./scripts/validate-infrastructure.sh

config:
	@test -f .env || (echo "error: copy .env.example to .env and set values" && exit 1)
	$(COMPOSE) config -q

up:
	@test -f $(COMPOSE_FILE) && grep -qv '^[[:space:]]*$$' $(COMPOSE_FILE) || \
		(echo "error: docker-compose.yml is not configured yet — complete Phase 01" && exit 1)
	@test -f .env || (echo "error: copy .env.example to .env and set values" && exit 1)
	$(COMPOSE) up -d

down:
	@test -f $(COMPOSE_FILE) && grep -qv '^[[:space:]]*$$' $(COMPOSE_FILE) || \
		(echo "error: docker-compose.yml is not configured yet — complete Phase 01" && exit 1)
	$(COMPOSE) down

reset:
	@echo "warning: this removes the PostgreSQL volume and all Keycloak data"
	@test -f $(COMPOSE_FILE) && grep -qv '^[[:space:]]*$$' $(COMPOSE_FILE) || \
		(echo "error: docker-compose.yml is not configured yet — complete Phase 01" && exit 1)
	$(COMPOSE) down -v

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
	@status=$$($(COMPOSE) ps --format '{{.Service}} {{.Health}}' 2>/dev/null); \
	 echo "$$status"; \
	 echo "$$status" | grep -q 'postgres healthy' && \
	 echo "$$status" | grep -q 'keycloak healthy' && \
	 echo "All services healthy" || \
	 (echo "One or more services unhealthy — run: make ps && make logs" && exit 1)
