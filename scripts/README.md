# Scripts

Operational helper scripts for the Keycloak platform.

## Available scripts

| Script | Purpose |
|--------|---------|
| `validate-foundation.sh` | Phase 00 |
| `validate-infrastructure.sh` | Phase 01 |
| `validate-keycloak.sh` | Phase 02 |
| `import-realm.sh` | Create/update realm from Git |
| `apply-authentication-policies.sh` | Phase 03 policies/users |
| `validate-authentication.sh` | Phase 03 OIDC lifecycle |
| `apply-authorization-config.sh` | Phase 04 groups mapper |
| `validate-authorization.sh` | Phase 04 authZ contract |
| `validate-integration.sh` | Phase 05 integration contract |
| `apply-customization.sh` | Phase 06 theme on realm |
| `validate-customization.sh` | Phase 06 theme/docs |
| `validate-production-docs.sh` | Phase 07 production docs |
| `validate-reusability.sh` | Phase 08 onboarding completeness |

```bash
make validate-all
```

## Rules

- Read configuration from environment variables — never hardcode secrets.
- Scripts must be idempotent where possible.
- Document usage in `docs/operations/` when behavior affects production.
