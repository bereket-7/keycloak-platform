#!/usr/bin/env bash
# Phase 07 — Production documentation validation (no live production deploy).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass=0; fail=0
check() { local d="$1"; shift; if "$@"; then echo "  OK   $d"; pass=$((pass+1)); else echo "  FAIL $d"; fail=$((fail+1)); fi; }

echo "Phase 07 — Production documentation validation"
echo "=============================================="
echo ""

check "production deployment guide exists" test -s docs/operations/production-deployment.md
check "documents HTTPS requirements" grep -qi 'HTTPS' docs/operations/production-deployment.md
check "documents reverse proxy headers" grep -q 'X-Forwarded-Proto' docs/operations/production-deployment.md
check "documents private PostgreSQL" grep -qi 'Not be internet-reachable' docs/operations/production-deployment.md
check "forbids secrets in Git" grep -qi 'Never store production secrets in Git' docs/operations/production-deployment.md
check "documents pinned images / no latest" grep -qi 'never `latest`' docs/operations/production-deployment.md || grep -qi 'never.*latest' docs/operations/production-deployment.md
check "nginx example exists" test -s nginx/conf.d/keycloak.conf.example
check "nginx example has no private key material" \
  bash -c '! grep -qiE "BEGIN (RSA |EC )?PRIVATE KEY|BEGIN CERTIFICATE" nginx/conf.d/keycloak.conf.example'
check "backup docs linked/exist" test -s docs/operations/backup.md
check "restore docs exist" test -s docs/operations/restore.md
check "upgrades docs exist" test -s docs/operations/upgrades.md
check "troubleshooting docs exist" test -s docs/operations/troubleshooting.md
check "local compose still uses start-dev (not production mode)" \
  grep -q 'start-dev' docker-compose.yml
check "local compose does not publish postgres ports" \
  bash -c '! docker compose config 2>/dev/null | awk "/^  postgres:/,/^  [a-z]/ {print}" | grep -q "^    ports:"'

echo ""
echo "Passed: $pass  Failed: $fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
echo "Phase 07 production documentation validation passed."
echo "Next: Phase 08 — Reusability"
