#!/usr/bin/env bash
# Phase 02 Keycloak configuration validation
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
REALM_FILE=keycloak/import/platform-realm.json
TMPDIR_KC="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_KC"' EXIT

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

echo "Phase 02 — Keycloak configuration validation"
echo "============================================="
echo ""

echo "Artifacts"
check "realm import file exists" test -s "$REALM_FILE"
check "import README exists" test -s keycloak/import/README.md
check "realm overlay docs exist" test -s config/realm/README.md
check "committed secret is local placeholder only" \
  grep -q "local-dev-only-change-me" keycloak/import/platform-realm.json
check "no production wildcard redirect policy documented" \
  grep -qi "Never use wildcard redirect URIs in production" keycloak/import/README.md
echo ""

echo "Waiting for Keycloak ..."
deadline=$((SECONDS + 180))
until curl -sf "${KEYCLOAK_URL}/" -o /dev/null; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "error: Keycloak not reachable at ${KEYCLOAK_URL}"
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
  | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')"

if [ -z "$TOKEN" ]; then
  echo "error: failed to obtain admin token"
  exit 1
fi

auth_get() {
  curl -sf -H "Authorization: Bearer ${TOKEN}" "$@"
}

echo "Realm"
check "platform realm exists" \
  auth_get "${KEYCLOAK_URL}/admin/realms/${REALM}" -o /dev/null
check "OIDC discovery resolves" \
  curl -sf "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration" -o /dev/null
check "issuer contains /realms/platform" \
  grep -q '/realms/platform' <(curl -sf "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration")
echo ""

echo "Roles"
for role in user admin super-admin; do
  check "realm role '${role}' exists" \
    auth_get "${KEYCLOAK_URL}/admin/realms/${REALM}/roles/${role}" -o /dev/null
done
echo ""

echo "Clients"
auth_get "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=demo-web" >"${TMPDIR_KC}/demo-web.json"
auth_get "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=demo-api" >"${TMPDIR_KC}/demo-api.json"

check "demo-web client exists" grep -q '"clientId":"demo-web"' "${TMPDIR_KC}/demo-web.json"
check "demo-api client exists" grep -q '"clientId":"demo-api"' "${TMPDIR_KC}/demo-api.json"
check "demo-web is public" grep -q '"publicClient":true' "${TMPDIR_KC}/demo-web.json"
check "demo-web has standard flow" grep -q '"standardFlowEnabled":true' "${TMPDIR_KC}/demo-web.json"
check "demo-web has no implicit flow" grep -q '"implicitFlowEnabled":false' "${TMPDIR_KC}/demo-web.json"
check "demo-web has explicit localhost redirect" grep -q 'localhost:3000' "${TMPDIR_KC}/demo-web.json"
check "demo-api is confidential" grep -q '"publicClient":false' "${TMPDIR_KC}/demo-api.json"
check "demo-api has service accounts" grep -q '"serviceAccountsEnabled":true' "${TMPDIR_KC}/demo-api.json"
echo ""

echo "Groups"
auth_get "${KEYCLOAK_URL}/admin/realms/${REALM}/groups?search=example" >"${TMPDIR_KC}/groups-example.json"
auth_get "${KEYCLOAK_URL}/admin/realms/${REALM}/groups?search=platform" >"${TMPDIR_KC}/groups-platform.json"
auth_get "${KEYCLOAK_URL}/admin/realms/${REALM}/groups?search=demo" >"${TMPDIR_KC}/groups-demo.json"

check "orgs/example group path exists" grep -q '/orgs/example' "${TMPDIR_KC}/groups-example.json"
check "teams/platform group path exists" grep -q '/teams/platform' "${TMPDIR_KC}/groups-platform.json"
check "projects/demo group path exists" grep -q '/projects/demo' "${TMPDIR_KC}/groups-demo.json"
echo ""

echo "Login and redirect validation"
auth_get "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=demo&exact=true" >"${TMPDIR_KC}/demo-user.json"
check "demo user exists" grep -q '"username":"demo"' "${TMPDIR_KC}/demo-user.json"

# PKCE is required for demo-web — include code_challenge on the authorize request.
CODE_VERIFIER="phase02-validation-code-verifier-0123456789"
CODE_CHALLENGE="$(printf '%s' "$CODE_VERIFIER" | openssl dgst -binary -sha256 | openssl base64 -A | tr '+/' '-_' | tr -d '=')"

curl -s \
  "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/auth?client_id=demo-web&response_type=code&scope=openid&redirect_uri=https%3A%2F%2Fevil.example%2Fcallback&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256" \
  >"${TMPDIR_KC}/invalid-redirect.html"
check "invalid redirect URI is rejected" \
  grep -qiE 'Invalid parameter|invalid_redirect|We are sorry' "${TMPDIR_KC}/invalid-redirect.html"

VALID_CODE="$(curl -s -o "${TMPDIR_KC}/login.html" -w "%{http_code}" \
  "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/auth?client_id=demo-web&response_type=code&scope=openid&redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fcallback&state=phase02&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256")"
check "valid redirect URI reaches login form (HTTP 200)" test "$VALID_CODE" = "200"
check "login form rendered for platform realm" \
  grep -qiE 'name="username"|id="username"|Sign in' "${TMPDIR_KC}/login.html"

DEMO_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "${TMPDIR_KC}/demo-user.json" | head -1)"
check "demo user id resolved" test -n "$DEMO_ID"

auth_get "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${DEMO_ID}/role-mappings/realm" >"${TMPDIR_KC}/demo-roles.json"
auth_get "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${DEMO_ID}/groups" >"${TMPDIR_KC}/demo-groups.json"
check "demo user has realm role user" grep -q '"name":"user"' "${TMPDIR_KC}/demo-roles.json"
check "demo user has group membership" grep -q '/orgs/example' "${TMPDIR_KC}/demo-groups.json"

CLIENT_TOKEN="$(curl -sf \
  -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=demo-api" \
  -d "client_secret=${DEMO_API_CLIENT_SECRET:-local-dev-only-change-me}" \
  | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p' || true)"
check "demo-api client_credentials login works" test -n "$CLIENT_TOKEN"
echo ""

echo "============================================="
echo "Passed: $pass  Failed: $fail"
echo ""

if [ "$fail" -gt 0 ]; then
  echo "Keycloak configuration validation failed."
  echo "See docs/phases/02-keycloak.md"
  exit 1
fi

echo "Phase 02 Keycloak configuration validation passed."
echo "Admin console: ${KEYCLOAK_URL}/admin/"
echo "Realm:         ${KEYCLOAK_URL}/realms/${REALM}"
echo "Discovery:     ${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration"
echo "Demo login:    username demo / password changeme (browser OIDC via demo-web)"
echo "Next step: Phase 03 — Authentication (docs/phases/03-authentication.md)"
