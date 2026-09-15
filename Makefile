.PHONY: help validate-foundation validate-infrastructure validate-keycloak \
	validate-authentication validate-authorization validate-integration \
	validate-customization validate-production-docs validate-reusability \
	apply-auth apply-authorization apply-customization \
	config up down reset logs ps health import-realm validate-all

COMPOSE := docker compose
COMPOSE_FILE := docker-compose.yml

help:
	@echo "Keycloak Platform — available targets"
	@echo ""
	@echo "  validate-foundation / validate-infrastructure / validate-keycloak"
	@echo "  apply-auth / validate-authentication"
	@echo "  apply-authorization / validate-authorization"
	@echo "  validate-integration"
	@echo "  apply-customization / validate-customization"
	@echo "  validate-production-docs / validate-reusability"
	@echo "  validate-all              Run all phase validators (stack must be up)"
	@echo "  import-realm / config / up / down / reset / ps / logs / health"
	@echo ""
	@echo "Documentation: docs/README.md"

validate-foundation:
	@./scripts/validate-foundation.sh

validate-infrastructure:
	@./scripts/validate-infrastructure.sh

validate-keycloak:
	@./scripts/validate-keycloak.sh

apply-auth:
	@./scripts/apply-authentication-policies.sh

validate-authentication:
	@./scripts/validate-authentication.sh

apply-authorization:
	@./scripts/apply-authorization-config.sh

validate-authorization:
	@./scripts/validate-authorization.sh

validate-integration:
	@./scripts/validate-integration.sh

apply-customization:
	@./scripts/apply-customization.sh

validate-customization:
	@./scripts/validate-customization.sh

validate-production-docs:
	@./scripts/validate-production-docs.sh

validate-reusability:
	@./scripts/validate-reusability.sh

validate-all: validate-foundation validate-infrastructure validate-keycloak \
	validate-authentication validate-authorization validate-integration \
	validate-customization validate-production-docs validate-reusability
	@echo "All phase validations passed."

import-realm:
	@./scripts/import-realm.sh

config:
	@test -f .env || (echo "error: copy .env.example to .env and set values" && exit 1)
	$(COMPOSE) config -q

up:
	@test -f .env || (echo "error: copy .env.example to .env and set values" && exit 1)
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

reset:
	@echo "warning: this removes the PostgreSQL volume and all Keycloak data"
	$(COMPOSE) down -v

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

health:
	@status=$$($(COMPOSE) ps --format '{{.Service}} {{.Health}}' 2>/dev/null); \
	 echo "$$status"; \
	 echo "$$status" | grep -q 'postgres healthy' && \
	 echo "$$status" | grep -q 'keycloak healthy' && \
	 echo "All services healthy" || \
	 (echo "One or more services unhealthy — run: make ps && make logs" && exit 1)
