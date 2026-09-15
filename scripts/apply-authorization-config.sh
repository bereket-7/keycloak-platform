#!/usr/bin/env bash
# Apply Phase 04 authorization signal config (groups claim mapper on sample clients).
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
SCOPE_NAME=groups

echo "Waiting for Keycloak at ${KEYCLOAK_URL} ..."
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
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  | jq -r .access_token)"

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "error: failed to obtain admin token"
  exit 1
fi

auth() {
  curl -sf -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" "$@"
}

echo "Ensuring client scope '${SCOPE_NAME}' with group membership mapper ..."
SCOPES="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes")"
SCOPE_ID="$(echo "$SCOPES" | jq -r --arg n "$SCOPE_NAME" '.[] | select(.name == $n) | .id' | head -1)"

if [ -z "$SCOPE_ID" ]; then
  HTTP="$(curl -s -o /tmp/kc-scope-create.txt -w "%{http_code}" \
    -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg name "$SCOPE_NAME" '{
      name: $name,
      description: "Group membership paths for application authorization signals",
      protocol: "openid-connect",
      attributes: {
        "include.in.token.scope": "true",
        "display.on.consent.screen": "false"
      }
    }')")"
  if [ "$HTTP" != "201" ]; then
    echo "error: create client scope failed (HTTP ${HTTP})"
    cat /tmp/kc-scope-create.txt || true
    exit 1
  fi
  SCOPE_ID="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes" | jq -r --arg n "$SCOPE_NAME" '.[] | select(.name == $n) | .id')"
  echo "  created client scope ${SCOPE_NAME} (${SCOPE_ID})"
else
  echo "  client scope ${SCOPE_NAME} exists (${SCOPE_ID})"
fi

MAPPERS="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes/${SCOPE_ID}/protocol-mappers/models")"
MAPPER_ID="$(echo "$MAPPERS" | jq -r '.[] | select(.name == "groups") | .id' | head -1)"

if [ -z "$MAPPER_ID" ]; then
  HTTP="$(curl -s -o /tmp/kc-mapper-create.txt -w "%{http_code}" \
    -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes/${SCOPE_ID}/protocol-mappers/models" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "groups",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-group-membership-mapper",
      "consentRequired": false,
      "config": {
        "full.path": "true",
        "id.token.claim": "false",
        "access.token.claim": "true",
        "claim.name": "groups",
        "userinfo.token.claim": "true"
      }
    }')"
  if [ "$HTTP" != "201" ]; then
    echo "error: create groups mapper failed (HTTP ${HTTP})"
    cat /tmp/kc-mapper-create.txt || true
    exit 1
  fi
  echo "  created groups protocol mapper"
else
  echo "  groups protocol mapper exists"
fi

assign_default_scope() {
  local client_id_name="$1"
  local clients client_uuid
  clients="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${client_id_name}")"
  client_uuid="$(echo "$clients" | jq -r '.[0].id // empty')"
  if [ -z "$client_uuid" ]; then
    echo "  warning: client ${client_id_name} not found — skip scope assignment"
    return 0
  fi

  local defaults
  defaults="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${client_uuid}/default-client-scopes")"
  if echo "$defaults" | jq -e --arg n "$SCOPE_NAME" 'map(.name) | index($n) != null' >/dev/null; then
    echo "  ${client_id_name}: groups already a default scope"
    return 0
  fi

  HTTP="$(curl -s -o /tmp/kc-scope-assign.txt -w "%{http_code}" \
    -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${client_uuid}/default-client-scopes/${SCOPE_ID}" \
    -H "Authorization: Bearer ${TOKEN}")"
  if [ "$HTTP" != "204" ] && [ "$HTTP" != "200" ]; then
    echo "error: assign groups scope to ${client_id_name} failed (HTTP ${HTTP})"
    cat /tmp/kc-scope-assign.txt || true
    exit 1
  fi
  echo "  ${client_id_name}: groups added as default client scope"
}

echo "Assigning groups scope to sample clients ..."
assign_default_scope "demo-web"
assign_default_scope "demo-api"

echo "Authorization signal configuration applied."
echo "Access tokens from demo-web should include realm roles and groups paths."
