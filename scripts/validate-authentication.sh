#!/usr/bin/env bash
# Phase 03 — Authentication lifecycle validation (OIDC + PKCE)
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
# Existing realms may have email-as-username from earlier imports.
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

echo "Phase 03 — Authentication validation"
echo "====================================="
echo ""

echo "Applying authentication policies ..."
./scripts/apply-authentication-policies.sh >/tmp/apply-auth.log
echo "  policies applied (see /tmp/apply-auth.log)"
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
ISSUER="$(echo "$DISCOVERY" | jq -r .issuer)"
AUTH_EP="$(echo "$DISCOVERY" | jq -r .authorization_endpoint)"
TOKEN_EP="$(echo "$DISCOVERY" | jq -r .token_endpoint)"
USERINFO_EP="$(echo "$DISCOVERY" | jq -r .userinfo_endpoint)"
JWKS_URI="$(echo "$DISCOVERY" | jq -r .jwks_uri)"
END_SESSION="$(echo "$DISCOVERY" | jq -r .end_session_endpoint)"

echo "OIDC discovery"
check "discovery document resolves" test -n "$ISSUER"
check "authorization_endpoint present" test -n "$AUTH_EP"
check "token_endpoint present" test -n "$TOKEN_EP"
check "userinfo_endpoint present" test -n "$USERINFO_EP"
check "jwks_uri present" test -n "$JWKS_URI"
check "end_session_endpoint present" test -n "$END_SESSION"
check "issuer is platform realm" test "$ISSUER" = "${KEYCLOAK_URL}/realms/${REALM}"
check "JWKS returns keys" bash -c "curl -sf \"$JWKS_URI\" | jq -e '.keys | length > 0' >/dev/null"
echo ""

echo "Realm authentication policies"
ADMIN_TOKEN="$(curl -sf \
  -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  | jq -r .access_token)"
REALM_CFG="$(curl -sf -H "Authorization: Bearer ${ADMIN_TOKEN}" "${KEYCLOAK_URL}/admin/realms/${REALM}")"
echo "$REALM_CFG" >"${TMP}/realm.json"
check "registration disabled (invite/admin only)" \
  bash -c "jq -e '.registrationAllowed == false' \"${TMP}/realm.json\" >/dev/null"
check "password reset allowed" \
  bash -c "jq -e '.resetPasswordAllowed == true' \"${TMP}/realm.json\" >/dev/null"
check "brute force protection enabled" \
  bash -c "jq -e '.bruteForceProtected == true' \"${TMP}/realm.json\" >/dev/null"
check "password policy requires length 12" \
  bash -c "jq -r .passwordPolicy \"${TMP}/realm.json\" | grep -q 'length(12)'"
check "access token lifespan is 300s" \
  bash -c "jq -e '.accessTokenLifespan == 300' \"${TMP}/realm.json\" >/dev/null"
check "refresh tokens revoked on reuse policy" \
  bash -c "jq -e '.revokeRefreshToken == true' \"${TMP}/realm.json\" >/dev/null"
check "OTP policy is TOTP" \
  bash -c "jq -e '.otpPolicyType == \"totp\"' \"${TMP}/realm.json\" >/dev/null"

ADMIN_DEMO="$(curl -sf -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/users?search=admin-demo")"
echo "$ADMIN_DEMO" >"${TMP}/admin-demo.json"
# Prefer exact username match; fall back to email-style username from older imports.
ADMIN_DEMO_FILTERED="$(jq '[.[] | select(.username == "admin-demo" or .username == "admin-demo@example.com" or .email == "admin-demo@example.com")]' "${TMP}/admin-demo.json")"
echo "$ADMIN_DEMO_FILTERED" >"${TMP}/admin-demo.json"
check "admin-demo user exists for MFA baseline" \
  bash -c "jq -e 'length >= 1' \"${TMP}/admin-demo.json\" >/dev/null"
check "admin-demo requires CONFIGURE_TOTP" \
  bash -c "jq -e '.[0].requiredActions | index(\"CONFIGURE_TOTP\") != null' \"${TMP}/admin-demo.json\" >/dev/null"
echo ""

CODE_VERIFIER="phase03-auth-code-verifier-$(openssl rand -hex 16)"
CODE_CHALLENGE="$(pkce_challenge "$CODE_VERIFIER")"
STATE="phase03-$(openssl rand -hex 8)"
COOKIE_JAR="${TMP}/cookies.txt"

AUTH_URL="${AUTH_EP}?client_id=${CLIENT_ID}&response_type=code&scope=openid%20profile%20email&redirect_uri=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${REDIRECT_URI}', safe=''))")&state=${STATE}&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256"

echo "Successful login (authorization code + PKCE)"
curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" -o "${TMP}/login.html" -w "%{http_code}" "$AUTH_URL" >"${TMP}/login.code"
check "login form HTTP 200" grep -qx 200 "${TMP}/login.code"

ACTION="$(python3 - <<'PY' "${TMP}/login.html"
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'<form[^>]+action="([^"]+)"', html)
if not m:
    raise SystemExit(1)
action = m.group(1).replace("&amp;", "&")
print(action)
PY
)" || ACTION=""
check "login form action extracted" test -n "$ACTION"

# Failed login first (wrong password)
FAIL_HEADERS="${TMP}/fail.headers"
curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" -D "$FAIL_HEADERS" -o "${TMP}/fail.html" \
  -X POST "$ACTION" \
  --data-urlencode "username=${DEMO_LOGIN}" \
  --data-urlencode "password=wrong-password-!!! " \
  --data-urlencode "credentialId="
check "failed login does not redirect with code" \
  bash -c "! grep -qiE 'Location:.*[?&]code=' \"$FAIL_HEADERS\""
check "failed login shows error without echoing password" \
  bash -c "grep -qiE 'Invalid username or password|invalid_user_credentials|error' \"${TMP}/fail.html\" && ! grep -q 'wrong-password-!!!' \"${TMP}/fail.html\""

# Re-open login form for successful attempt (new auth request / fresh cookies)
rm -f "$COOKIE_JAR"
curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" -o "${TMP}/login2.html" "$AUTH_URL" >/dev/null
ACTION="$(python3 - <<'PY' "${TMP}/login2.html"
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'<form[^>]+action="([^"]+)"', html)
print(m.group(1).replace("&amp;", "&"))
PY
)"

SUCCESS_HEADERS="${TMP}/ok.headers"
curl -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" -D "$SUCCESS_HEADERS" -o "${TMP}/ok.body" \
  -X POST "$ACTION" \
  --data-urlencode "username=${DEMO_LOGIN}" \
  --data-urlencode "password=${DEMO_PASSWORD}" \
  --data-urlencode "credentialId="

# Keycloak may return 302 to redirect_uri with code, or intermediate pages
LOCATION="$(grep -i '^Location:' "$SUCCESS_HEADERS" | tail -1 | sed 's/[Ll]ocation: //' | tr -d '\r')"
# Follow up to a few redirects while capturing final Location with code
for _ in 1 2 3 4 5; do
  if printf '%s' "$LOCATION" | grep -q '[?&]code='; then
    break
  fi
  if [ -z "$LOCATION" ]; then
    break
  fi
  # Relative location
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
loc = sys.argv[1]
q = urllib.parse.urlparse(loc).query
print(urllib.parse.parse_qs(q).get("code", [""])[0])
PY
)"
check "authorization code issued after login" test -n "$AUTH_CODE"

TOKENS="$(curl -sf -X POST "$TOKEN_EP" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "code=${AUTH_CODE}" \
  -d "redirect_uri=${REDIRECT_URI}" \
  -d "code_verifier=${CODE_VERIFIER}")"
echo "$TOKENS" >"${TMP}/tokens.json"

ACCESS="$(jq -r .access_token "${TMP}/tokens.json")"
ID_TOKEN="$(jq -r .id_token "${TMP}/tokens.json")"
REFRESH="$(jq -r .refresh_token "${TMP}/tokens.json")"

check "access token issued" test -n "$ACCESS" -a "$ACCESS" != "null"
check "id token issued" test -n "$ID_TOKEN" -a "$ID_TOKEN" != "null"
check "refresh token issued" test -n "$REFRESH" -a "$REFRESH" != "null"

CLAIMS_RC=0
python3 - <<'PY' "$ACCESS" "$ID_TOKEN" "$ISSUER" "${TMP}/claims.json" || CLAIMS_RC=$?
import json, sys, base64, time

def b64url(data: str) -> bytes:
    pad = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + pad)

def claims(token: str) -> dict:
    return json.loads(b64url(token.split(".")[1]))

access, id_token, issuer, out = sys.argv[1:5]
ac = claims(access)
ic = claims(id_token)
now = int(time.time())
errors = []
if ac.get("iss") != issuer:
    errors.append(f"access iss mismatch: {ac.get('iss')}")
if ic.get("iss") != issuer:
    errors.append(f"id iss mismatch: {ic.get('iss')}")
if not ac.get("exp") or ac["exp"] <= now:
    errors.append("access exp invalid")
if not ic.get("exp") or ic["exp"] <= now:
    errors.append("id exp invalid")
ttl = ac["exp"] - ac.get("iat", now)
if ttl > 360:
    errors.append(f"access ttl too long: {ttl}")
if "sub" not in ac or "sub" not in ic:
    errors.append("missing sub")
result = {"access": ac, "id": ic, "errors": errors, "access_ttl": ttl}
open(out, "w", encoding="utf-8").write(json.dumps(result, indent=2))
sys.exit(1 if errors else 0)
PY
check "token claims validate (iss, exp, sub, short TTL)" test "$CLAIMS_RC" -eq 0
check "access token TTL approximately 5 minutes" \
  bash -c "test -f \"${TMP}/claims.json\" && jq -e '.access_ttl <= 360 and .access_ttl >= 60' \"${TMP}/claims.json\" >/dev/null"

USERINFO="$(curl -sf -H "Authorization: Bearer ${ACCESS}" "$USERINFO_EP")"
echo "$USERINFO" >"${TMP}/userinfo.json"
check "userinfo accepts access token" \
  bash -c "jq -e '.preferred_username == \"demo\" or .preferred_username == \"demo@example.com\" or .email == \"demo@example.com\"' \"${TMP}/userinfo.json\" >/dev/null"
check "userinfo rejects missing token with 401" \
  bash -c "code=\$(curl -s -o /dev/null -w '%{http_code}' \"$USERINFO_EP\"); test \"\$code\" = \"401\""
check "userinfo rejects garbage token with 401" \
  bash -c "code=\$(curl -s -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer not-a-jwt' \"$USERINFO_EP\"); test \"\$code\" = \"401\""
echo ""

echo "Token refresh"
REFRESHED="$(curl -sf -X POST "$TOKEN_EP" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=${CLIENT_ID}" \
  -d "refresh_token=${REFRESH}")"
echo "$REFRESHED" >"${TMP}/refreshed.json"
NEW_ACCESS="$(jq -r .access_token "${TMP}/refreshed.json")"
NEW_REFRESH="$(jq -r .refresh_token "${TMP}/refreshed.json")"
check "refresh issues new access token" test -n "$NEW_ACCESS" -a "$NEW_ACCESS" != "null"
check "refresh rotates refresh token" test -n "$NEW_REFRESH" -a "$NEW_REFRESH" != "null" -a "$NEW_REFRESH" != "$REFRESH"

# Old refresh should fail when revokeRefreshToken is enabled
OLD_REFRESH_CODE="$(curl -s -o /dev/null -w "%{http_code}" -X POST "$TOKEN_EP" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=${CLIENT_ID}" \
  -d "refresh_token=${REFRESH}")"
check "reused refresh token is rejected" test "$OLD_REFRESH_CODE" = "400"
echo ""

echo "Logout"
LOGOUT_URL="${END_SESSION}?id_token_hint=${ID_TOKEN}&post_logout_redirect_uri=$(python3 -c "import urllib.parse; print(urllib.parse.quote('http://localhost:3000/', safe=''))")&client_id=${CLIENT_ID}"
LOGOUT_CODE="$(curl -s -o /dev/null -w "%{http_code}" -c "$COOKIE_JAR" -b "$COOKIE_JAR" "$LOGOUT_URL")"
check "RP-initiated logout endpoint responds" bash -c "test \"$LOGOUT_CODE\" = \"302\" -o \"$LOGOUT_CODE\" = \"200\""

# After logout, previous refresh should not work
POST_LOGOUT_CODE="$(curl -s -o /dev/null -w "%{http_code}" -X POST "$TOKEN_EP" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=${CLIENT_ID}" \
  -d "refresh_token=${NEW_REFRESH}")"
check "refresh after logout is rejected" test "$POST_LOGOUT_CODE" = "400"
echo ""

echo "Password / registration policy notes"
check "apps must not store passwords (documented)" \
  grep -qi "never store user passwords" docs/security/authentication-policies.md
check "token validation rules documented" \
  grep -qi "JWKS" docs/security/authentication-policies.md
echo ""

echo "====================================="
echo "Passed: $pass  Failed: $fail"
echo ""

if [ "$fail" -gt 0 ]; then
  echo "Authentication validation failed."
  echo "See docs/phases/03-authentication.md and docs/security/authentication-policies.md"
  exit 1
fi

echo "Phase 03 authentication validation passed."
echo "Discovery: ${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration"
echo "Demo user: demo / ${DEMO_PASSWORD}"
echo "Admin MFA baseline: admin-demo (CONFIGURE_TOTP required on next login)"
echo "Next step: Phase 04 — Authorization (docs/phases/04-authorization.md)"
