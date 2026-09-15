#!/usr/bin/env bash
# Phase 08 — Reusability / final platform checklist validation
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass=0; fail=0
check() { local d="$1"; shift; if "$@"; then echo "  OK   $d"; pass=$((pass+1)); else echo "  FAIL $d"; fail=$((fail+1)); fi; }

echo "Phase 08 — Reusability validation"
echo "================================="
echo ""

check "onboarding guide exists" test -s docs/reusability/onboarding.md
check "new project workflow documented" grep -q '<project>-web' docs/reusability/onboarding.md
check "standard env contract documented" grep -q 'KEYCLOAK_ISSUER' docs/reusability/onboarding.md
check "ownership matrix documented" grep -qi 'Application teams' docs/reusability/onboarding.md
check "upgrade strategy referenced" grep -qi 'Backup' docs/reusability/onboarding.md
check "integration guide exists" test -s docs/integration/application-integration.md
check "authorization model exists" test -s docs/security/authorization-model.md
check "authentication policies exist" test -s docs/security/authentication-policies.md
check "production deployment guide exists" test -s docs/operations/production-deployment.md
check "customization guide exists" test -s docs/customization/customization-guide.md
check "app env template exists" test -s config/apps/env.application.example
check "realm import exists" test -s keycloak/import/platform-realm.json
check "platform theme exists" test -s keycloak/themes/platform/login/theme.properties

# Prior phase validators should be present
for s in validate-foundation validate-infrastructure validate-keycloak \
         validate-authentication validate-authorization validate-integration \
         validate-customization validate-production-docs; do
  check "script ${s}.sh exists" test -x "scripts/${s}.sh" -o -f "scripts/${s}.sh"
done

echo ""
echo "Passed: $pass  Failed: $fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
echo "Phase 08 reusability validation passed."
echo "Platform documentation set is complete for Phases 00–08."
