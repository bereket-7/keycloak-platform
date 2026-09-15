#!/usr/bin/env bash
# Apply Phase 06 customization (login theme on platform realm).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -f .env ]; then
  echo "error: .env not found — run: cp .env.example .env"
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:${KEYCLOAK_HTTP_PORT:-8080}}"
ADMIN_USER="${KEYCLOAK_ADMIN:?KEYCLOAK_ADMIN is required}"
ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD:?KEYCLOAK_ADMIN_PASSWORD is required}"
REALM=platform
THEME=platform

echo "Waiting for Keycloak ..."
deadline=$((SECONDS + 180))
until curl -sf "${KEYCLOAK_URL}/" -o /dev/null; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "error: Keycloak not reachable"
    exit 1
  fi
  sleep 3
done

TOKEN="$(curl -sf \
  -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r .access_token)"

REALM_JSON="$(curl -sf -H "Authorization: Bearer ${TOKEN}" "${KEYCLOAK_URL}/admin/realms/${REALM}")"
UPDATED="$(echo "$REALM_JSON" | jq --arg theme "$THEME" '.loginTheme = $theme | .accountTheme = $theme | .emailTheme = $theme')"

HTTP="$(curl -s -o /tmp/kc-theme.txt -w "%{http_code}" \
  -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$UPDATED")"

if [ "$HTTP" != "204" ] && [ "$HTTP" != "200" ]; then
  echo "error: failed to set login theme (HTTP ${HTTP})"
  cat /tmp/kc-theme.txt || true
  exit 1
fi

echo "Realm '${REALM}' loginTheme/accountTheme/emailTheme set to '${THEME}'."
echo "Ensure themes are mounted: ./keycloak/themes -> /opt/keycloak/themes"
echo "Restart Keycloak if the theme was added after the container started: docker compose restart keycloak"
