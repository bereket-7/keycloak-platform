#!/usr/bin/env bash
# Apply Phase 03 authentication policies to the running platform realm.
# Idempotent — safe to re-run. Updates realm settings and ensures demo users.
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

DEMO_PASSWORD="${DEMO_USER_PASSWORD:-changeme-demo-12}"
ADMIN_DEMO_PASSWORD="${ADMIN_DEMO_PASSWORD:-changeme-admin-12}"

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

echo "Updating realm authentication policies ..."
REALM_JSON="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}")"
UPDATED="$(echo "$REALM_JSON" | jq \
  --arg policy 'length(12) and notUsername and notEmail and passwordHistory(3)' \
  '.passwordPolicy = $policy
   | .revokeRefreshToken = true
   | .refreshTokenMaxReuse = 0
   | .accessTokenLifespan = 300
   | .ssoSessionIdleTimeout = 1800
   | .ssoSessionMaxLifespan = 36000
   | .registrationAllowed = false
   | .registrationEmailAsUsername = false
   | .resetPasswordAllowed = true
   | .verifyEmail = false
   | .bruteForceProtected = true
   | .otpPolicyType = "totp"
   | .otpPolicyDigits = 6
   | .otpPolicyPeriod = 30
  ')"

HTTP="$(curl -s -o /tmp/kc-auth-policy.txt -w "%{http_code}" \
  -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$UPDATED")"
if [ "$HTTP" != "204" ] && [ "$HTTP" != "200" ]; then
  echo "error: realm policy update failed (HTTP ${HTTP})"
  cat /tmp/kc-auth-policy.txt || true
  exit 1
fi
echo "  realm policies updated"

ensure_user() {
  local username="$1"
  local email="$2"
  local first="$3"
  local last="$4"
  local password="$5"
  local roles_csv="$6"
  local required_actions_json="$7"

  local users
  users="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=${username}&exact=true")"
  local user_id
  user_id="$(echo "$users" | jq -r '.[0].id // empty')"

  if [ -z "$user_id" ]; then
    users="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}/users?email=${email}&exact=true")"
    user_id="$(echo "$users" | jq -r '.[0].id // empty')"
  fi

  if [ -z "$user_id" ]; then
    echo "  creating user ${username} ..."
    HTTP="$(curl -s -o /tmp/kc-user-create.txt -w "%{http_code}" \
      -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/users" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$(jq -n \
        --arg username "$username" \
        --arg email "$email" \
        --arg first "$first" \
        --arg last "$last" \
        --argjson actions "$required_actions_json" \
        '{username:$username,email:$email,firstName:$first,lastName:$last,enabled:true,emailVerified:true,requiredActions:$actions}')")"
    if [ "$HTTP" = "409" ]; then
      users="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}/users?email=${email}&exact=true")"
      user_id="$(echo "$users" | jq -r '.[0].id // empty')"
      if [ -z "$user_id" ]; then
        echo "error: create user ${username} conflict and lookup failed"
        cat /tmp/kc-user-create.txt || true
        exit 1
      fi
      echo "  found existing user by email for ${username}"
    elif [ "$HTTP" != "201" ]; then
      echo "error: create user ${username} failed (HTTP ${HTTP})"
      cat /tmp/kc-user-create.txt || true
      exit 1
    else
      user_id="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=${username}&exact=true" | jq -r '.[0].id')"
    fi
  fi

  if [ -n "$user_id" ]; then
    echo "  updating user ${username} (${user_id}) ..."
    existing_username="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${user_id}" | jq -r .username)"
    HTTP="$(curl -s -o /tmp/kc-user-update.txt -w "%{http_code}" \
      -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${user_id}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$(jq -n \
        --arg username "$existing_username" \
        --arg email "$email" \
        --arg first "$first" \
        --arg last "$last" \
        --argjson actions "$required_actions_json" \
        '{username:$username,email:$email,firstName:$first,lastName:$last,enabled:true,emailVerified:true,requiredActions:$actions}')")"
    if [ "$HTTP" != "204" ] && [ "$HTTP" != "200" ]; then
      echo "error: update user ${username} failed (HTTP ${HTTP})"
      cat /tmp/kc-user-update.txt || true
      exit 1
    fi
  fi

  HTTP="$(curl -s -o /tmp/kc-reset-pw.txt -w "%{http_code}" \
    -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${user_id}/reset-password" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg password "$password" '{type:"password",value:$password,temporary:false}')")"
  if [ "$HTTP" = "204" ] || [ "$HTTP" = "200" ]; then
    :
  elif [ "$HTTP" = "400" ] && grep -q invalidPasswordHistoryMessage /tmp/kc-reset-pw.txt; then
    echo "  password for ${username} already satisfies policy/history — leaving unchanged"
  else
    echo "error: reset password for ${username} failed (HTTP ${HTTP})"
    cat /tmp/kc-reset-pw.txt || true
    exit 1
  fi

  IFS=',' read -r -a roles <<<"$roles_csv"
  for role in "${roles[@]}"; do
    role_json="$(auth "${KEYCLOAK_URL}/admin/realms/${REALM}/roles/${role}")"
    curl -sf -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${user_id}/role-mappings/realm" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "[${role_json}]" -o /dev/null || true
  done
}

echo "Ensuring authentication demo users ..."
ensure_user "demo" "demo@example.com" "Demo" "User" "$DEMO_PASSWORD" "user" '[]'
ensure_user "admin-demo" "admin-demo@example.com" "Admin" "Demo" "$ADMIN_DEMO_PASSWORD" "user,admin" '["CONFIGURE_TOTP"]'

echo "Authentication policies applied."
echo "  demo / ${DEMO_PASSWORD}"
echo "  admin-demo / ${ADMIN_DEMO_PASSWORD} (required action: CONFIGURE_TOTP)"
