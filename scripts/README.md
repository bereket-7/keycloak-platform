# Scripts

Operational helper scripts for the Keycloak platform.

## Available scripts

| Script | Purpose |
|--------|---------|
| `validate-foundation.sh` | Phase 00 acceptance checks (structure, rules, secrets hygiene) |
| `validate-infrastructure.sh` | Phase 01 runtime checks (requires `make up`) |
| `validate-keycloak.sh` | Phase 02 realm/client/role/group checks |
| `import-realm.sh` | Create or update `platform` realm from Git import JSON |
| `apply-authentication-policies.sh` | Apply Phase 03 password/MFA/session policies and demo users |
| `validate-authentication.sh` | Phase 03 OIDC lifecycle (PKCE login, refresh, logout) |
| `apply-authorization-config.sh` | Phase 04 groups claim mapper on sample clients |
| `validate-authorization.sh` | Phase 04 authorization contract and token signals |

Additional scripts for backup, restore, health checks, and client
registration will be added in later phases as needed.

## Rules

- Read configuration from environment variables — never hardcode secrets.
- Scripts must be idempotent where possible.
- Document usage in `docs/operations/` when behavior affects production.
