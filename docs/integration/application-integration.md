# Application Integration Guide

Repeatable pattern for integrating applications with the Keycloak
platform using standard OIDC — without modifying Keycloak internals.

Related:

- [authentication-policies.md](../security/authentication-policies.md)
- [authorization-model.md](../security/authorization-model.md)
- [../phases/05-application-integration.md](../phases/05-application-integration.md)

---

## Architecture

```text
Frontend
   | OIDC (authorization code + PKCE)
   v
Keycloak (platform realm)
   | access token
   v
Backend API
   | JWT validation + authZ
   v
Business Logic → Database
```

---

## Application registration checklist

1. Create application record (name, owners, environments).
2. Register frontend client: `<project>-web` (public + PKCE).
3. Register backend client: `<project>-api` (confidential / resource server as needed).
4. Set **explicit** redirect URIs per environment (no production wildcards).
5. Set **explicit** web origins for browser clients.
6. Use scopes: `openid profile email` (+ `groups` when membership signals are needed).
7. Assign only coarse realm roles (`user`, `admin`, `super-admin`).
8. Configure application env vars (see below).
9. Integrate frontend login/logout/session handling.
10. Integrate backend JWT validation + resource authorization.
11. Test authentication (Phase 03 matrix).
12. Test authorization (Phase 04 catalog).
13. Deploy.

Platform operators register clients; application teams own app code and ACLs.

---

## Standard environment variables

```text
KEYCLOAK_ISSUER=http://localhost:8080/realms/platform
KEYCLOAK_CLIENT_ID=<project>-web
KEYCLOAK_CLIENT_SECRET=          # confidential clients only
KEYCLOAK_AUDIENCE=               # when API enforces aud
KEYCLOAK_SCOPES=openid profile email
```

| Variable | Public? | Notes |
|----------|---------|-------|
| `KEYCLOAK_ISSUER` | Yes | Must equal token `iss` |
| `KEYCLOAK_CLIENT_ID` | Yes for public clients | OIDC client id |
| `KEYCLOAK_CLIENT_SECRET` | **Secret** | Never in SPA bundles |
| `KEYCLOAK_AUDIENCE` | Config | Optional API audience check |
| `KEYCLOAK_SCOPES` | Config | Space-delimited |

Copy from [`config/apps/env.application.example`](../../config/apps/env.application.example).

Local demo clients: `demo-web` (public), `demo-api` (confidential secret in `.env`).

---

## Frontend expectations

| Concern | Guidance |
|---------|----------|
| Login | Redirect to discovery `authorization_endpoint` with PKCE (S256) |
| Logout | Clear app session + RP-initiated logout (`end_session_endpoint`) |
| Session | Refresh via token endpoint; handle failure with re-auth |
| AuthZ in UI | Roles/claims for UX only — not security |
| Protected routes | Gate navigation; APIs remain authoritative |
| Tokens | Prefer BFF / HTTP-only cookies; avoid casual `localStorage` |

Threat note: any token in JS-readable storage is XSS-sensitive. Prefer
backend-managed sessions for browser apps when possible.

---

## Backend expectations

1. Extract `Authorization: Bearer <access_token>`
2. Validate signature (JWKS from `{issuer}/protocol/openid-connect/certs`)
3. Validate `iss` == `KEYCLOAK_ISSUER`
4. Validate `aud` / `azp` when designed
5. Validate `exp`
6. Check required roles/scopes for the route class
7. Extract `sub` as primary user id
8. Enforce resource authorization in application data
9. Return **401** / **403** correctly

Cache JWKS; refresh on unknown `kid`. Never disable signature checks.

---

## API security

| Topic | Requirement |
|-------|-------------|
| 401 | Missing/invalid/expired auth |
| 403 | Authenticated but not permitted |
| CORS | Explicit origins; no `*` with credentials |
| Rate limiting | Especially on auth-adjacent endpoints |
| Request validation | Independent of identity |
| Logging | May log `sub`; **never** passwords or tokens |

---

## Minimal reference validation

The platform ships a language-agnostic checker (not a full sample app):

```bash
make validate-integration
```

It verifies:

- Discovery and standard env contract documentation
- OIDC token acquisition for `demo-web`
- JWKS-backed claim checks (`iss`, `exp`, `sub`, roles)
- UserInfo **401** without/invalid token
- Client credentials for `demo-api` (confidential pattern)

Stack-specific guides (React, NestJS, Go, …) should reuse this contract
and be added when a real consuming app needs them — prefer one solid
reference over many stubs.

---

## Test matrix (application teams)

| Test | Expected |
|------|----------|
| Unauthenticated API | **401** |
| Valid token, permitted | Success |
| Invalid / expired token | **401** |
| Invalid issuer | **401** |
| Invalid audience (if enforced) | **401** |
| Insufficient role / ownership | **403** |
| CORS disallowed origin | Rejected / blocked |
| Logs | No Bearer tokens |
