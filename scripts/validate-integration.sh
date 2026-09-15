#!/usr/bin/env bash
# Phase 05 — Application integration contract validation
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
REALM=platform
CLIENT_ID=demo-web
REDIRECT_URI="http://localhost:3000/callback"
DEMO_PASSWORD="${DEMO_USER_PASSWORD:-changeme-demo-12}"
DEMO_LOGIN="${DEMO_USERNAME:-demo@example.com}"
API_SECRET="${DEMO_API_CLIENT_SECRET:-local-dev-only-change-me}"

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
  printf '%s' "$1" | openssl dgst -binary -sha256 | openssl base64 -A | tr '+/' '-_' | tr -d '='
}

echo "Phase 05 — Application integration validation"
echo "=============================================="
echo ""

echo "Documentation and templates"
check "integration guide exists" test -s docs/integration/application-integration.md
check "registration checklist documented" \
  grep -qi 'Register frontend client' docs/integration/application-integration.md
check "standard env vars documented" \
  grep -q 'KEYCLOAK_ISSUER' docs/integration/application-integration.md
check "token storage threats documented" \
  grep -qi 'localStorage' docs/integration/application-integration.md
check "CORS and logging rules documented" \
  grep -qi 'never.*tokens' docs/integration/application-integration.md
check "auth and authZ cross-links present" \
  bash -c 'grep -q authentication-policies.md docs/integration/application-integration.md && grep -q authorization-model.md docs/integration/application-integration.md'
check "application env example exists" test -s config/apps/env.application.example
check "env example includes KEYCLOAK_CLIENT_ID" \
  grep -q 'KEYCLOAK_CLIENT_ID' config/apps/env.application.example
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

DISCOVERY="$(curl -sf "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration")"
echo "$DISCOVERY" >"${TMP}/discovery.json"
ISSUER="$(jq -r .issuer "${TMP}/discovery.json")"
AUTH_EP="$(jq -r .authorization_endpoint "${TMP}/discovery.json")"
TOKEN_EP="$(jq -r .token_endpoint "${TMP}/discovery.json")"
USERINFO_EP="$(jq -r .userinfo_endpoint "${TMP}/discovery.json")"
JWKS_URI="$(jq -r .jwks_uri "${TMP}/discovery.json")"

check "issuer matches local platform realm" \
  test "$ISSUER" = "${KEYCLOAK_URL}/realms/${REALM}"
check "JWKS available for backend validation" \
  bash -c "curl -sf \"$JWKS_URI\" | jq -e '.keys | length > 0' >/dev/null"
echo ""

CODE_VERIFIER="phase05-int-$(openssl rand -hex 16)"
CODE_CHALLENGE="$(pkce_challenge "$CODE_VERIFIER")"
STATE="phase05-$(openssl rand -hex 8)"
COOKIE_JAR="${TMP}/cookies.txt"
AUTH_URL="${AUTH_EP}?client_id=${CLIENT_ID}&response_type=code&scope=openid%20profile%20email&redirect_uri=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${REDIRECT_URI}', safe=''))")&state=${STATE}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256"

echo "Reference OIDC + API patterns (demo clients)"
curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" -o "${TMP}/login.html" "$AUTH_URL" >/dev/null
ACTION="$(python3 - <<'PY' "${TMP}/login.html"
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
print(re.search(r'<form[^>]+action="([^"]+)"', html).group(1).replace("&amp;", "&"))
PY
)"
curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" -D "${TMP}/ok.headers" -o /dev/null \
  -X POST "$ACTION" \
  --data-urlencode "username=${DEMO_LOGIN}" \
  --data-urlencode "password=${DEMO_PASSWORD}" \
  --data-urlencode "credentialId="

LOCATION="$(grep -i '^Location:' "${TMP}/ok.headers" | tail -1 | sed 's/[Ll]ocation: //' | tr -d '\r')"
for _ in 1 2 3 4 5; do
  printf '%s' "$LOCATION" | grep -q '[?&]code=' && break
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
print(urllib.parse.parse_qs(urllib.parse.urlparse(sys.argv[1]).query).get("code", [""])[0])
PY
)"
check "frontend-style PKCE login yields code" test -n "$AUTH_CODE"

TOKENS="$(curl -sf -X POST "$TOKEN_EP" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "code=${AUTH_CODE}" \
  -d "redirect_uri=${REDIRECT_URI}" \
  -d "code_verifier=${CODE_VERIFIER}")"
ACCESS="$(echo "$TOKENS" | jq -r .access_token)"
check "token endpoint returns access token" test -n "$ACCESS" -a "$ACCESS" != "null"

CLAIMS_RC=0
python3 - <<'PY' "$ACCESS" "$ISSUER" "${TMP}/claims.json" || CLAIMS_RC=$?
import json, sys, base64, time

def b64url(data: str) -> bytes:
    pad = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + pad)

claims = json.loads(b64url(sys.argv[1].split(".")[1]))
open(sys.argv[3], "w", encoding="utf-8").write(json.dumps(claims, indent=2))
now = int(time.time())
errors = []
if claims.get("iss") != sys.argv[2]:
    errors.append("iss")
if claims.get("exp", 0) <= now:
    errors.append("exp")
if not claims.get("sub"):
    errors.append("sub")
if "user" not in (claims.get("realm_access") or {}).get("roles", []):
    errors.append("role")
sys.exit(1 if errors else 0)
PY
check "backend can validate iss/exp/sub/roles from access token" test "$CLAIMS_RC" -eq 0

check "unauthenticated userinfo returns 401" \
  bash -c "test \"\$(curl -s -o /dev/null -w '%{http_code}' \"$USERINFO_EP\")\" = \"401\""
check "invalid bearer returns 401" \
  bash -c "test \"\$(curl -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer invalid.token' \"$USERINFO_EP\")\" = \"401\""
check "valid access token accepted by userinfo" \
  bash -c "curl -sf -H \"Authorization: Bearer ${ACCESS}\" \"$USERINFO_EP\" | jq -e '.sub' >/dev/null"

API_TOKEN="$(curl -sf -X POST "$TOKEN_EP" \
  -d "grant_type=client_credentials" \
  -d "client_id=demo-api" \
  -d "client_secret=${API_SECRET}" | jq -r .access_token)"
check "confidential API client credentials pattern works" \
  test -n "$API_TOKEN" -a "$API_TOKEN" != "null"
echo ""

echo "=============================================="
echo "Passed: $pass  Failed: $fail"
echo ""

if [ "$fail" -gt 0 ]; then
  echo "Integration validation failed."
  exit 1
fi

echo "Phase 05 application integration validation passed."
echo "Guide: docs/integration/application-integration.md"
echo "Next: Phase 06 — Customization"
