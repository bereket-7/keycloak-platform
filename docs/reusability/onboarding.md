# Reusable Platform Onboarding

Turn Keycloak into a multi-application identity product.

Related: [../phases/08-reusability.md](../phases/08-reusability.md),
[../integration/application-integration.md](../integration/application-integration.md)

---

## New project workflow

1. Create application record (name, owners, environments).
2. Create `<project>-web` client (public + PKCE).
3. Create `<project>-api` client as needed (confidential).
4. Configure redirect URIs (per environment, exact).
5. Configure web origins.
6. Configure coarse roles only.
7. Configure scopes (`openid profile email` [+ `groups`]).
8. Configure app env from `config/apps/env.application.example`.
9. Integrate frontend (OIDC).
10. Integrate backend (JWT + authZ).
11. Test authentication.
12. Test authorization.
13. Deploy.

---

## Naming

```text
<project>-web
<project>-api
<project>-mobile
```

Environments: `local` / `development`, `staging`, `production`.

---

## Standard configuration

`KEYCLOAK_ISSUER`, `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_CLIENT_SECRET` (secret),
`KEYCLOAK_AUDIENCE`, `KEYCLOAK_SCOPES`.

---

## Application contract

| Area | Must provide |
|------|----------------|
| Auth | Login, logout, session/refresh |
| Backend | Token validation, authZ, `sub` extraction |
| Security | HTTPS (non-local), secure secrets, 401/403, no token logging |

---

## Versioning

| Artifact | Practice |
|----------|----------|
| Keycloak image | Pinned tags; changelog on upgrade |
| Realm/config | Versioned in Git; scrub secrets |
| Theme | Version with platform releases |
| Docs | Update with behavior changes |

Upgrade flow: Backup → test → staging → auth tests → apps → production → monitor.

See [../operations/upgrades.md](../operations/upgrades.md).

---

## Disaster recovery

Backup and restore are documented under operations. Define numerical RTO/RPO
with business stakeholders — do not invent them here.

---

## Ownership

| Area | Owner |
|------|-------|
| IdP / realm baseline / themes | Platform / IAM |
| App clients, redirects, resource authZ | Application teams |
| Hosts, TLS, DB, backups | Infrastructure |
| Threat review / incidents | Security + platform |

---

## Final acceptance

A platform is reusable when:

- [ ] New projects onboard from docs alone
- [ ] OIDC authentication works
- [ ] APIs validate tokens server-side
- [ ] Authorization enforced in backends
- [ ] Secrets managed outside Git
- [ ] Production deployment documented
- [ ] Backup/restore/upgrades/troubleshooting documented
- [ ] Configuration is reproducible

```bash
make validate-reusability
```
