# Phase 05 — Application Integration

Create a repeatable pattern for integrating future applications with the
Keycloak platform.

---

## Objective

A new application should integrate with Keycloak using standard OIDC
**without modifying Keycloak’s internal code**. Integration is
configuration plus application-side libraries/middleware — not forks,
SPIs, or custom protocols.

---

## Architecture

```text
Frontend
   |
   | OIDC (authorization code + PKCE)
   v
Keycloak
   |
   | access token
   v
Backend API
   |
   | JWT validation
   v
Business Logic
   |
   v
Database
```

- Frontend authenticates users via Keycloak.
- Backend trusts only validated access tokens.
- Business authorization runs in the backend after authentication succeeds.
- Follow the Phase 04 contract in [authorization-model.md](../security/authorization-model.md)
  for roles, groups, 401/403, and resource ownership.

---

## Application Registration

Standard process for each new application:

1. Register frontend client (`<project>-web`).
2. Register backend client / resource server (`<project>-api`) as needed.
3. Configure redirect URIs (per environment, explicit).
4. Configure web origins (browser clients).
5. Configure scopes (`openid profile email` baseline).
6. Configure roles (assign coarse roles; avoid fine-grained IdP roles).
7. Configure issuer URL in the application.
8. Configure audience / client expectations for API validation.
9. Test authentication end-to-end.
10. Test authorization on protected APIs (Phase 04 rules).

Do not use wildcard redirect URIs in production.

---

## Frontend Integration

### Responsibilities

| Concern | Guidance |
|---------|----------|
| Login | Redirect to Keycloak authorization endpoint |
| Logout | Clear local state + RP-initiated logout |
| Session handling | Track authenticated state from tokens/session; refresh safely |
| Authorization state | Use roles/claims for UX only; never as sole enforcement |
| Protected routes | Gate navigation in UI; still protect APIs |
| Token leakage | Do not put tokens in URLs, logs, analytics, or localStorage without risk analysis |

### Token storage

There is no zero-risk browser storage option. Prefer patterns that reduce XSS impact:

- **BFF / backend-managed session** (often strongest for browser apps)
- **Secure, HTTP-only cookies** set by a backend
- If tokens must live in the SPA, understand XSS risk; prefer short-lived access tokens and careful CSP

Do not recommend insecure token storage casually. Document the chosen
pattern and its threats.

---

## Backend Integration

Backends must:

1. Extract `Authorization: Bearer <access_token>`
2. Validate JWT signature via JWKS
3. Validate issuer against Keycloak realm issuer
4. Validate audience / azp according to client design
5. Validate expiration
6. Validate required roles/scopes for the route class
7. Extract user identity (`sub`, email if needed)
8. Enforce resource-level authorization in business logic

Cache JWKS with sensible refresh on key rotation. Do not disable
certificate or signature validation.

---

## API Security

| Topic | Requirement |
|-------|-------------|
| **401** | Missing/invalid/expired authentication |
| **403** | Authenticated but not permitted |
| **CORS** | Explicit origins matching web origins strategy; no `*` with credentials |
| **Rate limiting** | Protect auth-sensitive and public endpoints as appropriate |
| **Request validation** | Validate bodies/params independently of identity |
| **Logging** | Log request metadata and `sub` if useful; **never** log access/refresh tokens or passwords |

---

## Reusable Integration Pattern

Standard environment configuration model:

```text
KEYCLOAK_ISSUER=https://auth.example.com/realms/platform
KEYCLOAK_CLIENT_ID=<project>-web-or-api
KEYCLOAK_CLIENT_SECRET=<only-for-confidential-clients>
KEYCLOAK_AUDIENCE=<api-audience-if-used>
KEYCLOAK_SCOPES=openid profile email
```

| Variable | Public? | Notes |
|----------|---------|-------|
| `KEYCLOAK_ISSUER` | Yes (discoverable) | Must match token `iss` |
| `KEYCLOAK_CLIENT_ID` | Yes for public clients | Identifies the OIDC client |
| `KEYCLOAK_CLIENT_SECRET` | **Secret** | Only for confidential clients; never in frontend bundles |
| `KEYCLOAK_AUDIENCE` | Config | Used when APIs enforce `aud` |
| `KEYCLOAK_SCOPES` | Config | Requested scopes |

Only include secrets where the application actually requires them.
Public SPAs should not ship client secrets.

---

## Example Applications

The platform should eventually support integration guides for common stacks:

- React
- Next.js
- NestJS
- Node.js
- Go
- Spring Boot
- Mobile applications

**This phase defines the pattern; it does not implement all of these.**
Implement reference integration only when a real consuming application
needs it. Prefer one solid reference over many incomplete samples.

---

## Tasks

- [ ] Publish application registration checklist
- [ ] Document frontend OIDC + PKCE expectations
- [ ] Document backend JWT validation checklist
- [ ] Define standard env var names
- [ ] Document token storage options and threats
- [ ] Document CORS and logging rules
- [ ] Create a minimal reference integration when a first real app exists
- [ ] Cross-link Phase 03 (auth) and Phase 04 (authZ)

---

## Testing

| Test | Expected |
|------|----------|
| Unauthenticated API | **401** |
| Authenticated API with valid token | Success when permitted |
| Invalid token | **401** |
| Expired token | **401** |
| Invalid issuer | **401** |
| Invalid audience (if enforced) | **401** |
| Insufficient role / resource permission | **403** |
| CORS disallowed origin | Browser blocks / server rejects per policy |
| Logs | No Bearer tokens present in log output |

---

## Acceptance Criteria

1. A documented, repeatable registration process exists for new apps.
2. Frontend and backend responsibilities are explicit.
3. Standard configuration variables are defined.
4. Token validation requirements are mandatory for APIs.
5. Security rules cover 401/403, CORS, and logging.
6. Integration does not require Keycloak source changes.
7. Test matrix covers auth failure modes and authorization denial.
8. Multi-stack support is planned without implementing every stack now.

---

## Deliverables

- Application integration architecture
- Registration runbook
- Standard env configuration model
- Frontend/backend security guidance
- Integration test matrix

---

## Dependencies

**Requires:** Phases 02–04 (clients, authentication, authorization contract).

**Unblocks:** Real application onboarding; Phase 08 reusability workflow polish.

---

## Completion Criteria

Phase 05 is complete when a new application team can register clients,
configure issuer/client settings, authenticate via OIDC, and protect APIs
with JWT validation and server-side authorization using only documented
steps — without modifying Keycloak internals.
