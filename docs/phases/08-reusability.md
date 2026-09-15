# Phase 08 — Reusable Platform

Turn the Keycloak installation into a reusable identity platform that
can serve many future applications.

---

## Objective

A new project should integrate with the platform using a documented,
repeatable process — without forking Keycloak, without sharing database
access, and without reinventing authentication.

Reusability is achieved through conventions, configuration, and
documentation, not through a large custom framework.

---

## New Project Workflow

```text
1.  Create application record (name, owners, environments)
2.  Create frontend client (<project>-web)
3.  Create backend client (<project>-api) as needed
4.  Configure redirect URIs (per environment, explicit)
5.  Configure web origins
6.  Configure roles (coarse; assign as needed)
7.  Configure scopes (openid profile email baseline)
8.  Configure application environment variables
9.  Integrate frontend (OIDC + PKCE / BFF pattern)
10. Integrate backend (JWT validation + authZ)
11. Test authentication
12. Test authorization
13. Deploy
```

Each step should reference Phase 02–05 detailed rules. Platform operators
perform client registration; application teams own app-side integration
and resource authorization.

---

## Client Naming Convention

```text
<project>-web
<project>-api
<project>-mobile
```

Examples: `billing-web`, `billing-api`, `billing-mobile`.

### Why consistent naming matters

- Makes Admin Console and exports readable
- Prevents collisions across teams
- Clarifies public vs confidential client expectations
- Simplifies automation and audit

Optional environment suffix only when separate clients per environment
are required (`billing-web-staging`). Prefer distinct redirect URIs on
one client only when policy allows; many teams use separate clients per
environment for clearer blast radius.

---

## Environment Naming

| Name | Purpose |
|------|---------|
| `development` / `local` | Developer workstations; Docker Compose |
| `staging` | Pre-production validation |
| `production` | Live issuer and live apps |

Use the same vocabulary in DNS, secret paths, client redirect lists, and
runbooks. Do not invent parallel nicknames per team.

---

## Standard Configuration

```text
KEYCLOAK_ISSUER
KEYCLOAK_CLIENT_ID
KEYCLOAK_CLIENT_SECRET
KEYCLOAK_AUDIENCE
KEYCLOAK_SCOPES
```

| Variable | Public or secret | Notes |
|----------|------------------|-------|
| `KEYCLOAK_ISSUER` | Public | Full realm issuer URL |
| `KEYCLOAK_CLIENT_ID` | Public for public clients | Client identifier |
| `KEYCLOAK_CLIENT_SECRET` | **Secret** | Confidential clients only |
| `KEYCLOAK_AUDIENCE` | Config | When APIs enforce audience |
| `KEYCLOAK_SCOPES` | Config | Space-delimited scopes |

Frontends must never embed confidential client secrets. Production values
come from a secret manager; Git holds `.env.example` placeholders only.

---

## Standard Application Contract

Every integrating application must provide:

### Authentication

- Login via Keycloak OIDC
- Logout (app session + IdP logout)
- Session handling with correct token refresh behavior

### Backend

- Access token validation (signature, issuer, expiry, audience as designed)
- Authorization enforcement for roles and resources
- Reliable user identity extraction (`sub` as primary key)

### Security

- HTTPS in staging/production
- Secure configuration and secret handling
- Correct **401** / **403** behavior
- No logging of passwords or tokens
- No trust of frontend-only authorization

---

## Documentation for New Projects

Each project should document:

1. Client IDs and types (web/api/mobile)
2. Redirect URIs and web origins per environment
3. Required roles and how they map to app permissions
4. Issuer URL and audience expectations
5. Token storage approach and threat notes
6. How to run local auth against the platform
7. Owners/on-call for auth breakages
8. Links to platform phase docs used during integration

Platform maintainers document the shared IdP; application teams document
their client-specific details.

---

## Reusable Scripts

Future automation may include scripts for:

- client creation
- realm configuration import/export
- environment setup checks
- backup
- restore
- health checks

Scripts should live under `scripts/` when introduced, read configuration
from env, and never hardcode secrets.

**Do not implement these scripts in this documentation phase unless they
already exist.** Document the intent so Phase 01/07/operations work can
add them deliberately.

---

## Versioning

Version the platform as a product:

| Artifact | Versioning approach |
|----------|---------------------|
| Keycloak image | Pinned semantic/version tags; changelog when upgrading |
| Realm/config exports | Versioned in Git; note breaking claim/client changes |
| Theme package | Version with platform releases |
| Docs | Updated in the same change as behavior |
| Compatibility | Document which app integration patterns work with which platform release |

### Compatibility expectations

- Prefer additive claim/client changes.
- Breaking issuer URL or claim renames require a coordinated migration guide.
- Application teams pin to a known platform release for staging/prod.

---

## Upgrade Strategy

```text
Backup
    ->
Test upgrade
    ->
Upgrade staging
    ->
Run authentication tests
    ->
Validate applications
    ->
Production upgrade
    ->
Monitor
```

Rules:

- Never upgrade production before a successful staging validation.
- Backup PostgreSQL and export realm config before upgrades.
- Read Keycloak migration notes for the pinned version jump.
- Keep rollback image/config ready until smoke tests pass.
- Communicate maintenance windows to application owners.

---

## Disaster Recovery

| Topic | Guidance |
|-------|----------|
| Backup | Regular PostgreSQL backups; retain realm exports |
| Restore | Documented restore onto clean infrastructure; re-verify issuer URL |
| Recovery testing | Periodically restore to a non-production target |
| RTO | Recovery time objective — define with business stakeholders |
| RPO | Recovery point objective — define with business stakeholders |

Do **not** invent numerical RTO/RPO values here. Real targets depend on
business impact of IdP downtime (all apps blocked from login). Record
agreed numbers in operations docs once stakeholders decide.

---

## Operational Ownership

| Area | Owner |
|------|-------|
| Identity platform (Keycloak, realm baseline, themes, IdP uptime) | Platform / IAM team |
| Application clients, redirect URIs, app sessions, resource authZ | Application teams |
| Hosts, networks, TLS, databases, backups at infrastructure layer | Infrastructure / platform ops |
| Threat review, secret standards, incident response for auth | Security (with platform) |

Clear ownership prevents “everyone thought someone else rotated the
client secret.”

---

## Final Acceptance Criteria

The platform is considered reusable when all of the following are true:

- [ ] A new project can integrate using documented steps
- [ ] Authentication works through OIDC
- [ ] Backend APIs validate tokens
- [ ] Authorization is enforced server-side
- [ ] Secrets are managed securely
- [ ] Production deployment is documented
- [ ] Backup and restore are documented
- [ ] Upgrades are documented
- [ ] Troubleshooting is documented
- [ ] Configuration is reproducible from version control (+ secret store)

---

## Final Deliverables

### Documentation

- Architecture docs (`docs/architecture/`)
- Phase docs (`docs/phases/` `00`–`08`)
- Security docs (`docs/security/`)
- Operations docs (`docs/operations/` — backup, restore, upgrades, troubleshooting)

### Configuration

- Docker Compose for local development
- Scrubbed realm export/import artifacts
- `.env.example` and secret-manager mappings for real environments
- Pinned image versions

### Scripts (as introduced over time)

- Health checks
- Backup/restore helpers
- Optional client/realm automation

### Operational artifacts

- Runbooks for deploy, rollback, upgrade
- Ownership matrix
- Agreed RTO/RPO once defined by the business
- Monitoring/alerting for Keycloak and PostgreSQL

---

## Tasks

- [ ] Publish new-project onboarding checklist
- [ ] Enforce client naming convention in registration process
- [ ] Publish standard env var contract
- [ ] Confirm application contract with first integrating teams
- [ ] Ensure ops docs cover backup, restore, upgrades, troubleshooting
- [ ] Define platform versioning and release notes practice
- [ ] Run a dry-run onboarding of a second application (or a sample)
- [ ] Record operational ownership
- [ ] Schedule backup restore drill
- [ ] Verify final acceptance checklist end-to-end

---

## Testing

| Test | Expected |
|------|----------|
| Onboarding dry-run | Second app integrates using only docs + client config |
| Auth E2E | Login/logout/refresh succeed |
| API authZ | 401/403 behave per contract |
| Config reproducibility | Fresh environment import matches baseline |
| Backup/restore drill | Identity data restored; login works |
| Upgrade dry-run on staging | Apps still authenticate after upgrade |

---

## Dependencies

**Requires:** Phases 00–07 completed to a usable degree (local + production path + authN/authZ contracts).

**Unblocks:** Scale-out of many applications onto one IdP with predictable operations.

---

## Completion Criteria

Phase 08 is complete when the platform behaves as a product: new
applications onboard through a checklist, conventions prevent drift,
ownership is clear, and operational procedures (backup, restore, upgrade,
troubleshoot) are documented and exercised.

At that point the repository is no longer “a Keycloak install” — it is a
**reusable identity platform** for multiple independent applications.
