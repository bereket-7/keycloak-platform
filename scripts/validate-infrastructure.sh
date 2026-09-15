#!/usr/bin/env bash
# Phase 01 infrastructure validation — requires Docker and a configured .env
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMPOSE="${COMPOSE:-docker compose}"
export COMPOSE
KEYCLOAK_PORT="${KEYCLOAK_HTTP_PORT:-8080}"

pass=0
fail=0

check() {
  local description="$1"
  shift
  if "$@"; then
    echo "  OK   $description"
    pass=$((pass + 1))
  else
    echo "  FAIL $description"
    fail=$((fail + 1))
  fi
}

echo "Phase 01 — Infrastructure validation"
echo "====================================="
echo ""

if [ ! -f .env ]; then
  echo "error: .env not found — run: cp .env.example .env"
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

KEYCLOAK_HTTP_PORT="${KEYCLOAK_HTTP_PORT:-8080}"

echo "Configuration"
check "docker compose config is valid" $COMPOSE config -q
check "postgres service defined" bash -c '$COMPOSE config --services | grep -qx postgres'
check "keycloak service defined" bash -c '$COMPOSE config --services | grep -qx keycloak'
check "postgres is not published to host" bash -c '! $COMPOSE config | grep -A30 "^  postgres:" | grep -q "^    ports:"'
echo ""

echo "Waiting for services to become healthy (up to 3 minutes)..."
deadline=$((SECONDS + 180))
while [ "$SECONDS" -lt "$deadline" ]; do
  if $COMPOSE ps postgres 2>/dev/null | grep -q "(healthy)" && \
     $COMPOSE ps keycloak 2>/dev/null | grep -q "(healthy)"; then
    break
  fi
  sleep 5
done
echo ""

echo "Runtime"
check "postgres container running" bash -c '$COMPOSE ps --status running --services | grep -qx postgres'
check "keycloak container running" bash -c '$COMPOSE ps --status running --services | grep -qx keycloak'
check "postgres is healthy" bash -c '$COMPOSE ps postgres | grep -q "(healthy)"'
check "keycloak is healthy" bash -c '$COMPOSE ps keycloak | grep -q "(healthy)"'
echo ""

echo "Connectivity"
check "Keycloak HTTP responds" curl -sf "http://localhost:${KEYCLOAK_HTTP_PORT}/" -o /dev/null
check "Keycloak readiness (management port inside container)" bash -c \
  '$COMPOSE exec -T keycloak bash -c "exec 3<>/dev/tcp/127.0.0.1/9000; echo -e '\''GET /health/ready HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n'\'' >&3; cat <&3" | grep -q "HTTP/1.1 200"'
check "Keycloak logs show no repeated DB auth failures" bash -c \
  '! $COMPOSE logs keycloak 2>&1 | tail -100 | grep -qi "password authentication failed"'
echo ""

echo "====================================="
echo "Passed: $pass  Failed: $fail"
echo ""

if [ "$fail" -gt 0 ]; then
  echo "Infrastructure validation failed."
  echo "See docs/phases/01-infrastructure.md#troubleshooting"
  exit 1
fi

echo "Phase 01 infrastructure validation passed."
echo "Admin console: http://localhost:${KEYCLOAK_HTTP_PORT}/"
echo "Next step: Phase 02 — Keycloak Configuration (docs/phases/02-keycloak.md)"
