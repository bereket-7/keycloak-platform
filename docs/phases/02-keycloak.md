# Phase 02 — Keycloak Configuration

Configure Keycloak as a reusable centralized identity provider.

---

## Objective

Define the Keycloak realm, clients, roles, groups, and configuration
strategy so that multiple independent applications can authenticate
against one platform without forking Keycloak or embedding business
authorization into the IdP.

This phase assumes Phase 01 infrastructure is healthy.

---

## Realm Strategy

Start with a **single realm**:

```text
platform
```

### Why a single realm initially

- One user directory simplifies reuse across applications.
- Shared login UX and MFA policies stay consistent.
- Client registration per application is enough to isolate apps.
- Operational cost (backup, upgrade, monitoring) stays lower.
- Most multi-app platforms do not need realm isolation on day one.

### When multiple realms may become appropriate

Consider additional realms only when there is a hard boundary, such as:

- strict tenant isolation requiring separate user stores and admins
- incompatible password/MFA/IdP policies that cannot share one realm
- regulatory separation of identity domains
- a dedicated operational/admin realm distinct from customer identities

Do not create a realm per application by default. Prefer clients,
groups, and application-level authorization instead.

---

## Realm Architecture

```text
platform
|
+-- users
+-- groups
+-- roles
+-- clients
+-- identity providers (optional)
```

| Object | Purpose |
|--------|---------|
| Users | Human (and occasionally service) identities |
| Groups | Coarse membership (org/team/project) |
| Roles | Coarse-grained access signals for apps |
| Clients | Per-application OAuth2/OIDC registrations |
| Identity providers | Optional external login (Google, GitHub, Microsoft, enterprise IdPs) |

---

## Client Strategy

Register **separate clients per application surface**.

Examples:

```text
project-a-web
project-a-api
project-b-web
project-b-api
```

### Frontend clients

- Typically **public** clients (SPA / native) using Authorization Code + PKCE.
- Explicit redirect URIs for each environment.
- Explicit web origins for browser clients.
- No long-lived embedded client secrets in public frontends.

### Backend / resource-server clients

- Typically **confidential** clients when the backend must authenticate to Keycloak
  (for example token introspection, confidential flows, or service accounts when justified).
- APIs that only **validate** JWTs may primarily act as resource servers using
  realm/issuer settings rather than holding a user-facing client secret.

### Client authentication

- Public clients: PKCE; no confidential secret in the browser.
- Confidential clients: store secrets in environment / secret manager, never in Git.
- Disable unused flows (implicit where not required; avoid legacy insecure grants).

### Redirect URIs and web origins

- List exact URIs per environment (`http://localhost:3000/*` only if required locally;
  prefer exact paths when possible).
- **Never use wildcard redirect URIs in production.**
- Web origins must be explicit for browser-based clients.

### Scopes

- Start with standard OIDC scopes: `openid`, `profile`, `email`.
- Add custom scopes only when multiple apps need a shared, well-defined claim set.
- Do not stuff business permissions into scopes as a substitute for application authorization.

---

## Role Strategy

### Realm roles

Use for **coarse, cross-application** signals, for example:

- `user`
- `admin`
- `super-admin`

Realm roles are visible across clients and should stay few.

### Client roles

Use when a permission signal is meaningful only for one application,
and even then keep them coarse.

### Guidance

- Prefer a small role vocabulary.
- Avoid thousands of business-specific roles in Keycloak.
- Resource ownership (“can edit project X”) belongs in the application
  (Phase 04), not as an explosion of realm roles.

---

## Group Strategy

Groups can represent:

- organization membership
- team membership
- project membership

Groups are useful for assigning baseline roles and for conveying
membership claims. They are **not** a full replacement for application
authorization. Applications must still enforce resource-level rules.

---

## Realm Configuration Management

Realm configuration must be **reproducible and version controlled**.

### Recommended approach

1. Maintain realm export/import artifacts under `keycloak/` or `config/`.
2. Treat the Git artifact as the desired baseline for local/staging rebuilds.
3. Document which values are environment-specific (redirect URIs, origins, secrets).
4. Prefer declarative import for bootstrap; use Admin UI for exploration, then export back.

### Export / import

- Export after meaningful Admin Console changes.
- Import on fresh environments to avoid snowflake realms.
- Keep secrets out of exported files committed to Git (use placeholders or env substitution).

### Configuration drift

Drift happens when production is changed in the UI without updating Git.
Mitigations:

- change process: UI experiment → export → review → commit
- periodic export comparison
- restrict who can change production realm settings

### Environment-specific values

Redirect URIs, web origins, frontend URLs, and SMTP settings differ by
environment. Keep a clear split between:

- shared structural config (roles, client IDs, flows)
- environment overlays (URIs, secrets, hostnames)

---

## Identity Providers

Optional external IdPs:

- Google
- GitHub
- Microsoft
- Enterprise SAML/OIDC IdPs

Rules:

- External IdPs are **optional**, not mandatory for platform completeness.
- Enable only when a consuming application needs them.
- Map IdP users into the `platform` realm with clear first-login linking policies.
- Do not weaken redirect URI or account linking controls for convenience.

---

## Configuration Security

| Concern | Practice |
|---------|----------|
| Admin credentials | Strong passwords; limited distribution; rotate if leaked |
| Client secrets | Env/secret manager only; never in Git |
| Redirect URIs | Explicit allow lists; no production wildcards |
| Least privilege | Minimal roles; disable unused client features |
| Secrets management | `.env` locally; secret manager in staging/production |
| Admin Console exposure | Local only initially; protect heavily in production (Phase 07) |

---

## Tasks

- [ ] Create realm `platform` (UI or import)
- [ ] Define baseline realm roles (`user`, `admin`, `super-admin` or documented equivalents)
- [ ] Define group naming convention (org/team/project)
- [ ] Register sample clients for at least one fictional or real app pair (`*-web`, `*-api`)
- [ ] Configure public frontend client with PKCE and explicit redirect URIs
- [ ] Configure backend/resource-server client settings appropriately
- [ ] Set web origins explicitly
- [ ] Configure default scopes
- [ ] Export realm baseline to version control (secrets scrubbed)
- [ ] Document environment-specific overlays for redirect URIs
- [ ] Document optional IdP enablement procedure (without making IdPs mandatory)
- [ ] Restrict who can change production realm settings (process note)

---

## Testing

| Test | Expected result |
|------|-----------------|
| Realm availability | `platform` realm reachable; OpenID discovery URL resolves |
| Realm import/export | Fresh import recreates clients/roles/groups structure |
| Client configuration | Clients appear with correct access type and URIs |
| Login | User can authenticate via realm login |
| Redirect URI validation | Unknown redirect URI is rejected |
| Role assignment | Assigned realm/client roles appear for the user |
| Group membership | Group membership can be assigned and observed |
| Secret hygiene | No real client secrets committed in Git |

Discovery URL pattern (conceptual):

```text
http://localhost:<port>/realms/platform/.well-known/openid-configuration
```

---

## Acceptance Criteria

1. A single `platform` realm exists and is the default integration target.
2. Client naming supports multiple applications (`<project>-web`, `<project>-api`).
3. Frontend and backend client types are correctly distinguished.
4. Redirect URIs and web origins are explicit; production wildcards are forbidden by policy.
5. Roles remain coarse-grained.
6. Groups are documented for membership, not as full authZ replacement.
7. Realm configuration can be exported/imported reproducibly.
8. Optional IdPs are documented but not required.
9. Secrets are excluded from version control.

---

## Deliverables

- `platform` realm
- Baseline roles and group conventions
- Example application clients
- Version-controlled realm export/import artifacts (scrubbed)
- Client and redirect URI documentation
- Security notes for admin and client secrets

---

## Dependencies

**Requires:** Phase 01 healthy Keycloak + PostgreSQL.

**Unblocks:** Phase 03 authentication lifecycle validation; later application integration.

---

## Completion Criteria

Phase 02 is complete when the `platform` realm is reproducibly configured,
sample clients exist with safe redirect settings, roles/groups conventions
are documented, and configuration can be restored via import without relying
on a snowflake Admin Console state.

**Do not implement application code in this phase.**
