#!/usr/bin/env bash
# Phase 00 foundation validation — repository hygiene, not runtime tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

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

check_not_ignored() {
  local description="$1"
  local path="$2"
  if git check-ignore -q "$path"; then
    echo "  FAIL $description"
    fail=$((fail + 1))
  else
    echo "  OK   $description"
    pass=$((pass + 1))
  fi
}

echo "Phase 00 — Foundation validation"
echo "=================================="
echo ""

echo "Structure"
check ".cursor/rules/ exists" test -d .cursor/rules
check "docs/ exists" test -d docs
check "config/ exists" test -d config
check "keycloak/ exists" test -d keycloak
check "scripts/ exists" test -d scripts
check "docs/architecture/ exists" test -d docs/architecture
check "docs/phases/ exists" test -d docs/phases
check "docs/security/ exists" test -d docs/security
check "docs/operations/ exists" test -d docs/operations
echo ""

echo "Cursor rules"
for rule in 00-project 01-architecture 02-security 03-docker 04-keycloak 05-development; do
  check "$rule.mdc exists" test -f ".cursor/rules/${rule}.mdc"
done
echo ""

echo "Phase documentation"
for phase in 00-foundation 01-infrastructure 02-keycloak 03-authentication \
             04-authorization 05-application-integration 06-customization \
             07-production 08-reusability; do
  check "docs/phases/${phase}.md exists and non-empty" test -s "docs/phases/${phase}.md"
done
echo ""

echo "Foundation files"
check ".gitignore exists and non-empty" test -s .gitignore
check ".env.example exists and non-empty" test -s .env.example
check "README.md exists and non-empty" test -s README.md
check "Makefile exists" test -f Makefile
echo ""

echo "Secrets hygiene"
check ".env is gitignored" git check-ignore -q .env
check ".env is not tracked by git" bash -c 'test -z "$(git ls-files .env)"'
check_not_ignored ".env.example is not gitignored" .env.example
echo ""

echo "Docs navigation"
check "docs/README.md exists" test -f docs/README.md
for link in \
  architecture/overview.md \
  phases/04-authorization.md \
  phases/05-application-integration.md \
  phases/07-production.md \
  phases/08-reusability.md; do
  check "docs/$link resolves" test -f "docs/$link"
done
echo ""

echo "=================================="
echo "Passed: $pass  Failed: $fail"
echo ""

if [ "$fail" -gt 0 ]; then
  echo "Foundation validation failed."
  exit 1
fi

echo "Phase 00 foundation validation passed."
echo "Next step: Phase 01 — Local Infrastructure (docs/phases/01-infrastructure.md)"
