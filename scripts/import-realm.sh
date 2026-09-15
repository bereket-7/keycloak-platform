#!/usr/bin/env bash
# Import or update the platform realm from keycloak/import/platform-realm.json
# via the Admin REST API. Use when the realm already exists or after editing Git.
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

REALM_FILE="${REALM_FILE:-keycloak/import/platform-realm.json}"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:${KEYCLOAK_HTTP_PORT:-8080}}"
ADMIN_USER="${KEYCLOAK_ADMIN:?KEYCLOAK_ADMIN is required}"
ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD:?KEYCLOAK_ADMIN_PASSWORD is required}"

if [ ! -f "$REALM_FILE" ]; then
  echo "error: realm file not found: $REALM_FILE"
  exit 1
fi

echo "Waiting for Keycloak at ${KEYCLOAK_URL} ..."
deadline=$((SECONDS + 180))
until curl -sf "${KEYCLOAK_URL}/" -o /dev/null; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "error: Keycloak not reachable"
    exit 1
  fi
  sleep 3
done

echo "Obtaining admin token ..."
TOKEN="$(curl -sf \
  -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')"

if [ -z "$TOKEN" ]; then
  echo "error: failed to obtain admin access token"
  exit 1
fi

REALM_NAME="$(sed -n 's/.*"realm"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$REALM_FILE" | head -1)"
if [ -z "$REALM_NAME" ]; then
  echo "error: could not parse realm name from $REALM_FILE"
  exit 1
fi

STATUS="$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}")"

if [ "$STATUS" = "200" ]; then
  echo "Realm '${REALM_NAME}' exists — updating from ${REALM_FILE} ..."
  HTTP="$(curl -s -o /tmp/kc-import-body.txt -w "%{http_code}" \
    -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    --data-binary @"${REALM_FILE}")"
  if [ "$HTTP" != "204" ] && [ "$HTTP" != "200" ]; then
    echo "error: update failed (HTTP ${HTTP})"
    cat /tmp/kc-import-body.txt || true
    exit 1
  fi
  echo "Realm '${REALM_NAME}' updated."
else
  echo "Realm '${REALM_NAME}' missing — creating from ${REALM_FILE} ..."
  HTTP="$(curl -s -o /tmp/kc-import-body.txt -w "%{http_code}" \
    -X POST "${KEYCLOAK_URL}/admin/realms" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    --data-binary @"${REALM_FILE}")"
  if [ "$HTTP" != "201" ] && [ "$HTTP" != "204" ] && [ "$HTTP" != "200" ]; then
    echo "error: create failed (HTTP ${HTTP})"
    cat /tmp/kc-import-body.txt || true
    exit 1
  fi
  echo "Realm '${REALM_NAME}' created."
fi

echo "OIDC discovery: ${KEYCLOAK_URL}/realms/${REALM_NAME}/.well-known/openid-configuration"
curl -sf "${KEYCLOAK_URL}/realms/${REALM_NAME}/.well-known/openid-configuration" -o /dev/null
echo "Import complete."
