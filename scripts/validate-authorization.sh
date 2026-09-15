#!/usr/bin/env bash
# Phase 04 — Authorization signal validation (Keycloak coarse roles/groups).
# Does not implement application ACLs; verifies the platform contract signals.
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
CLIENT_ID=demo-web
REDIRECT_URI="http://localhost:3000/callback"
DEMO_PASSWORD="${DEMO_USER_PASSWORD:-changeme-demo-12}"
DEMO_LOGIN="${DEMO_USERNAME:-demo@example.com}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

pkce_challenge() {
  local verifier="$1"
  printf '%s' "$verifier" | openssl dgst -binary -sha256 | openssl base64 -A | tr '+/' '-_' | tr -d '='
}

echo "Phase 04 — Authorization validation"
echo "===================================="
echo ""

echo "Documentation contract"
check "authorization-model.md exists" test -s docs/security/authorization-model.md
check "documents Keycloak vs application boundary" \
  grep -qi "What are you allowed to do" docs/security/authorization-model.md
check "documents five-layer model" \
  grep -q "Layer 5: Resource ownership" docs/security/authorization-model.md
check "documents coarse roles user/admin/super-admin" \
  bash -c 'grep -q "| \`user\`" docs/security/authorization-model.md && grep -q "| \`admin\`" docs/security/authorization-model.md && grep -q "| \`super-admin\`" docs/security/authorization-model.md'
check "documents group path convention" \
  grep -q '/orgs/<organization>' docs/security/authorization-model.md
check "documents 401 vs 403" \
  grep -q '401 Unauthorized' docs/security/authorization-model.md
check "documents common mistakes" \
  grep -qi 'Trusting frontend authorization' docs/security/authorization-model.md
check "documents backend enforcement checklist" \
  grep -qi 'Validate JWT' docs/security/authorization-model.md
check "Phase 05 cross-link present" \
  grep -q '05-application-integration.md' docs/security/authorization-model.md
echo ""

echo "Applying authorization signal configuration ..."
./scripts/apply-authorization-config.sh >/tmp/apply-authz.log
echo "  applied (see /tmp/apply-authz.log)"
echo ""

echo "Waiting for Keycloak ..."
deadline=$((SECONDS + 180))
until curl -sf "${KEYCLOAK_URL}/" -o /dev/null; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "error: Keycloak not reachable"
    exit 1
  fi
  sleep 3
done

ADMIN_TOKEN="$(curl -sf \
  -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  | jq -r .access_token)"

echo "Role vocabulary"
for role in user admin super-admin; do
  check "realm role '${role}' exists" \
    bash -c "curl -sf -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \"${KEYCLOAK_URL}/admin/realms/${REALM}/roles/${role}\" >/dev/null"
done
echo ""

echo "Group convention"
check "orgs/example group path exists" \
  bash -c "curl -sf -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \"${KEYCLOAK_URL}/admin/realms/${REALM}/groups?search=example\" | grep -q '/orgs/example'"
check "teams/platform group path exists" \
  bash -c "curl -sf -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \"${KEYCLOAK_URL}/admin/realms/${REALM}/groups?search=platform\" | grep -q '/teams/platform'"
check "projects/demo group path exists" \
  bash -c "curl -sf -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \"${KEYCLOAK_URL}/admin/realms/${REALM}/groups?search=demo\" | grep -q '/projects/demo'"
echo ""

echo "Groups client scope"
SCOPES="$(curl -sf -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes")"
echo "$SCOPES" >"${TMP}/scopes.json"
check "groups client scope exists" \
  bash -c "jq -e 'map(.name) | index(\"groups\") != null' \"${TMP}/scopes.json\" >/dev/null"
SCOPE_ID="$(jq -r '.[] | select(.name == "groups") | .id' "${TMP}/scopes.json")"
MAPPERS="$(curl -sf -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes/${SCOPE_ID}/protocol-mappers/models")"
echo "$MAPPERS" >"${TMP}/mappers.json"
check "groups membership mapper configured" \
  bash -c "jq -e 'map(.protocolMapper) | index(\"oidc-group-membership-mapper\") != null' \"${TMP}/mappers.json\" >/dev/null"
echo ""

DISCOVERY="$(curl -sf "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration")"
AUTH_EP="$(echo "$DISCOVERY" | jq -r .authorization_endpoint)"
TOKEN_EP="$(echo "$DISCOVERY" | jq -r .token_endpoint)"
ISSUER="$(echo "$DISCOVERY" | jq -r .issuer)"

CODE_VERIFIER="phase04-authz-$(openssl rand -hex 16)"
CODE_CHALLENGE="$(pkce_challenge "$CODE_VERIFIER")"
STATE="phase04-$(openssl rand -hex 8)"
COOKIE_JAR="${TMP}/cookies.txt"
AUTH_URL="${AUTH_EP}?client_id=${CLIENT_ID}&response_type=code&scope=openid%20profile%20email&redirect_uri=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${REDIRECT_URI}', safe=''))")&state=${STATE}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256"

echo "Token authorization signals (demo user)"
curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" -o "${TMP}/login.html" "$AUTH_URL" >/dev/null
ACTION="$(python3 - <<'PY' "${TMP}/login.html"
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'<form[^>]+action="([^"]+)"', html)
print(m.group(1).replace("&amp;", "&"))
PY
)"
curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" -D "${TMP}/ok.headers" -o /dev/null \
  -X POST "$ACTION" \
  --data-urlencode "username=${DEMO_LOGIN}" \
  --data-urlencode "password=${DEMO_PASSWORD}" \
  --data-urlencode "credentialId="

LOCATION="$(grep -i '^Location:' "${TMP}/ok.headers" | tail -1 | sed 's/[Ll]ocation: //' | tr -d '\r')"
for _ in 1 2 3 4 5; do
  if printf '%s' "$LOCATION" | grep -q '[?&]code='; then
    break
  fi
  [ -z "$LOCATION" ] && break
  case "$LOCATION" in
    http*) NEXT="$LOCATION" ;;
    /*) NEXT="${KEYCLOAK_URL}${LOCATION}" ;;
    *) NEXT="${KEYCLOAK_URL}/${LOCATION}" ;;
  esac
  curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" -D "${TMP}/redir.headers" -o /dev/null "$NEXT"
  LOCATION="$(grep -i '^Location:' "${TMP}/redir.headers" | tail -1 | sed 's/[Ll]ocation: //' | tr -d '\r')"
done

AUTH_CODE="$(python3 - <<'PY' "$LOCATION"
import sys, urllib.parse
q = urllib.parse.urlparse(sys.argv[1]).query
print(urllib.parse.parse_qs(q).get("code", [""])[0])
PY
)"
check "obtained authorization code for claim inspection" test -n "$AUTH_CODE"

TOKENS="$(curl -sf -X POST "$TOKEN_EP" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "code=${AUTH_CODE}" \
  -d "redirect_uri=${REDIRECT_URI}" \
  -d "code_verifier=${CODE_VERIFIER}")"
echo "$TOKENS" >"${TMP}/tokens.json"
ACCESS="$(jq -r .access_token "${TMP}/tokens.json")"
check "access token present" test -n "$ACCESS" -a "$ACCESS" != "null"

python3 - <<'PY' "$ACCESS" "$ISSUER" "${TMP}/access-claims.json"
import json, sys, base64

def b64url(data: str) -> bytes:
    pad = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + pad)

token, issuer, out = sys.argv[1:4]
claims = json.loads(b64url(token.split(".")[1]))
open(out, "w", encoding="utf-8").write(json.dumps(claims, indent=2))
errors = []
if claims.get("iss") != issuer:
    errors.append("iss")
roles = (claims.get("realm_access") or {}).get("roles") or []
if "user" not in roles:
    errors.append("missing user role")
# groups may be list of paths
groups = claims.get("groups") or []
if not any(g.endswith("/orgs/example") or g == "/orgs/example" for g in groups):
    # also accept path without leading nuances
    if "/orgs/example" not in groups and not any("orgs/example" in g for g in groups):
        errors.append(f"missing orgs/example in groups={groups!r}")
if "sub" not in claims:
    errors.append("missing sub")
# Ensure we did not embed a fat permissions matrix
for banned in ("permissions", "acls", "resource_access_matrix"):
    if banned in claims:
        errors.append(f"unexpected claim {banned}")
sys.exit(1 if errors else 0)
PY
CLAIMS_RC=$?
check "access token includes user role and groups signal" test "$CLAIMS_RC" -eq 0
check "access token has stable sub claim" \
  bash -c "jq -e '.sub | type == \"string\" and length > 0' \"${TMP}/access-claims.json\" >/dev/null"
check "access token has realm_access.roles" \
  bash -c "jq -e '.realm_access.roles | index(\"user\") != null' \"${TMP}/access-claims.json\" >/dev/null"
check "access token has groups membership paths" \
  bash -c "jq -e '[.groups[]?] | map(select(test(\"orgs/example\"))) | length > 0' \"${TMP}/access-claims.json\" >/dev/null"
echo ""

echo "Admin role assignment (platform signal, not app ACL)"
ADMIN_USERS="$(curl -sf -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/users?search=admin-demo")"
ADMIN_ID="$(echo "$ADMIN_USERS" | jq -r '[.[] | select(.email == "admin-demo@example.com" or .username == "admin-demo" or .username == "admin-demo@example.com")][0].id // empty')"
check "admin-demo principal resolvable" test -n "$ADMIN_ID"
ADMIN_ROLES="$(curl -sf -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${ADMIN_ID}/role-mappings/realm")"
echo "$ADMIN_ROLES" >"${TMP}/admin-roles.json"
check "admin-demo has admin realm role" \
  bash -c "jq -e 'map(.name) | index(\"admin\") != null' \"${TMP}/admin-roles.json\" >/dev/null"
echo ""

echo "Application contract reminders (docs-only enforcement)"
check "forged header guidance documented" \
  grep -q 'X-Role' docs/security/authorization-model.md
check "resource ownership stays in application" \
  grep -qi 'Resource ownership' docs/security/authorization-model.md
check "test catalog defined for app teams" \
  grep -q 'Valid token, wrong role for admin route' docs/security/authorization-model.md
echo ""

echo "===================================="
echo "Passed: $pass  Failed: $fail"
echo ""

if [ "$fail" -gt 0 ]; then
  echo "Authorization validation failed."
  echo "See docs/security/authorization-model.md"
  if [ -f "${TMP}/access-claims.json" ]; then
    echo "Access token claims snapshot:"
    cat "${TMP}/access-claims.json"
  fi
  exit 1
fi

echo "Phase 04 authorization validation passed."
echo "Contract: docs/security/authorization-model.md"
echo "Next step: Phase 05 — Application Integration (docs/phases/05-application-integration.md)"
