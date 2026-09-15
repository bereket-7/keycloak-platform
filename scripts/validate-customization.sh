#!/usr/bin/env bash
# Phase 06 — Customization validation
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
ADMIN_USER="${KEYCLOAK_ADMIN:?}"
ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD:?}"
REALM=platform

pass=0
fail=0
check() {
  local d="$1"; shift
  if "$@"; then echo "  OK   $d"; pass=$((pass+1)); else echo "  FAIL $d"; fail=$((fail+1)); fi
}

echo "Phase 06 — Customization validation"
echo "===================================="
echo ""

echo "Artifacts"
check "theme.properties exists" test -s keycloak/themes/platform/login/theme.properties
check "theme CSS exists" test -s keycloak/themes/platform/login/resources/css/platform.css
check "theme README exists" test -s keycloak/themes/README.md
check "customization guide exists" test -s docs/customization/customization-guide.md
check "theme extends keycloak.v2" grep -q 'parent=keycloak.v2' keycloak/themes/platform/login/theme.properties
check "no external script CDN in theme CSS" \
  bash -c '! grep -qiE "https?://|cdn\\.|googleapis|script" keycloak/themes/platform/login/resources/css/platform.css'
check "SMTP guidance documented without secrets" \
  grep -qi 'secret manager' docs/customization/customization-guide.md
check "optional IdP guidance documented" \
  grep -qi 'optional' docs/customization/customization-guide.md
check "security boundaries documented" \
  grep -qi 'Do not disable CSRF' docs/customization/customization-guide.md
echo ""

./scripts/apply-customization.sh >/tmp/apply-custom.log
echo "Theme apply log: /tmp/apply-custom.log"
echo ""

TOKEN="$(curl -sf -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "username=${ADMIN_USER}" -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" -d "client_id=admin-cli" | jq -r .access_token)"
REALM_JSON="$(curl -sf -H "Authorization: Bearer ${TOKEN}" "${KEYCLOAK_URL}/admin/realms/${REALM}")"
echo "$REALM_JSON" > /tmp/realm-theme.json

check "realm loginTheme is platform" \
  bash -c 'jq -e ".loginTheme == \"platform\"" /tmp/realm-theme.json >/dev/null'

# Login page should still render (theme missing falls back, but form must work)
CODE_CHALLENGE="$(printf 'phase06theme' | openssl dgst -binary -sha256 | openssl base64 -A | tr '+/' '-_' | tr -d '=')"
LOGIN_HTML="$(curl -sf "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/auth?client_id=demo-web&response_type=code&scope=openid&redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fcallback&state=t&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256")"
echo "$LOGIN_HTML" > /tmp/login-theme.html
check "login page still renders Sign in" grep -qi 'Sign in' /tmp/login-theme.html
check "login form username field present" grep -qiE 'name="username"|id="username"' /tmp/login-theme.html
# Theme resource may be served when theme is loaded
check "OIDC redirect policy unchanged (evil redirect rejected)" \
  bash -c "curl -s \"${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/auth?client_id=demo-web&response_type=code&scope=openid&redirect_uri=https%3A%2F%2Fevil.example%2Fcallback&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256\" | grep -qiE 'Invalid parameter|We are sorry|error'"
echo ""

echo "===================================="
echo "Passed: $pass  Failed: $fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
echo "Phase 06 customization validation passed."
echo "Next: Phase 07 — Production Deployment"
