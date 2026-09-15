# Authorization Model

Phase 04 contract: how Keycloak identity signals relate to application
authorization. Integrating applications must follow this model.

Related documents:

- [authentication-policies.md](authentication-policies.md) — OIDC login and tokens
- [token-strategy.md](token-strategy.md) — token types and validation
- [../phases/04-authorization.md](../phases/04-authorization.md) — phase plan
- [../phases/05-application-integration.md](../phases/05-application-integration.md) — app wiring

---

## Core principle

| Question | Owner |
|----------|-------|
| **Who are you?** (authentication) | Keycloak |
| **What are you allowed to do?** (authorization) | Application (using Keycloak signals + app data) |

Keycloak proves identity and emits **coarse** role/group signals.
Applications own business permissions and resource ownership.

---

## Five layers

```text
Layer 1: Identity                 Keycloak  — sub / user id
Layer 2: Roles                    Keycloak  — user | admin | super-admin
Layer 3: Groups                   Keycloak  — /orgs/* /teams/* /projects/*
Layer 4: Application permissions  Application — feature / ACL rules
Layer 5: Resource ownership       Application — object-level checks
```

| Layer | Example | Enforced by |
|-------|---------|-------------|
| Identity | Valid JWT for this issuer? | Backend token validation |
| Roles | Is caller an `admin`? | Backend reads validated `realm_access.roles` |
| Groups | Member of `/orgs/example`? | Backend reads validated `groups` claim (or sync) |
| App permissions | May manage billing? | Application policy store |
| Resource ownership | May edit project `42`? | Application DB / ACL |

---

## Division of responsibility (worked example)

```text
Organization
    |
    +-- Project
          |
          +-- Team
                |
                +-- User
```

| Fact | System of record |
|------|------------------|
| User `sub`, email | Keycloak |
| Member of organization (group path) | Keycloak group (optional signal) |
| Realm role `admin` | Keycloak |
| May create projects in Organization A | **Application** |
| May edit Project 123 | **Application** |
| May administer Team 9 | **Application** |

Do **not** encode every project ACL as a Keycloak role.

---

## Coarse realm roles

| Role | Intent |
|------|--------|
| `user` | Standard authenticated principal (default) |
| `admin` | Privileged operator within app/platform scope |
| `super-admin` | Break-glass platform administration |

Rules:

- Keep the vocabulary small and stable across applications.
- Prefer application permissions over new realm roles for business features.
- Client roles only when a signal is truly client-specific and still coarse.

---

## Group naming convention

```text
/orgs/<organization>
/teams/<team>
/projects/<project>
```

Groups convey membership. They bootstrap access; they do not replace
“owner of document X” checks in the application.

---

## JWT claims applications may consume

After **signature / issuer / expiry** validation, backends may use:

| Claim | Source | Use |
|-------|--------|-----|
| `sub` | Access / ID token | Stable user id for ownership foreign keys |
| `iss` | Access / ID token | Must match platform realm issuer |
| `exp` | Access token | Reject expired credentials |
| `realm_access.roles` | Access token | Coarse role gates (e.g. admin routes) |
| `groups` | Access token (mapper) | Org/team/project membership signals |
| `email` / `preferred_username` | Access / ID / UserInfo | Display / correlation — prefer `sub` for authZ |

### Do not put in tokens

- Full permission matrices
- Per-resource ACL lists
- Secrets or sensitive business payloads
- Trust anything from request headers such as `X-Role` or `X-User-Id`

Treat claims as **inputs** to application policy, not as proof of a
specific resource action by themselves.

---

## Backend enforcement checklist

For every protected API request:

1. Extract `Authorization: Bearer <access_token>`
2. Validate JWT **signature** (JWKS from discovery)
3. Validate **issuer** (`iss`)
4. Validate **audience** / `azp` where your API design requires it
5. Validate **expiration** (`exp`)
6. Validate required **roles/scopes** for the route class
7. Enforce **resource authorization** against application data
8. Return correct **401** / **403**

Never trust roles or user ids supplied in bodies or custom headers.

---

## 401 vs 403

| Status | Meaning |
|--------|---------|
| **401 Unauthorized** | Missing or invalid authentication |
| **403 Forbidden** | Authenticated, but not permitted |

Wrong status codes cause clients to loop on re-login (401 for “forbidden”)
or hide the need to authenticate (403 for “not logged in”).

---

## Application authorization examples

Belong in the **backend** (not only the UI):

- User can read project X
- User can edit project Y
- User can administer team Z

Frontend may hide controls for UX. That is **not** security.

---

## Common mistakes

| Mistake | Correct approach |
|---------|------------------|
| Trusting frontend authorization | Enforce in API |
| Trusting `X-Role` / body roles | Use validated JWT claims only |
| All permissions in JWTs | Keep resource ACLs in the app DB |
| Wildcard access | Explicit allow rules |
| Thousands of realm roles | Coarse roles + app permissions |
| AuthZ only in the UI | Server-side checks always |

---

## Test catalog (for application teams)

| Case | Expected |
|------|----------|
| Valid token, permitted resource | **200** (or success) |
| Missing token | **401** |
| Invalid / expired token | **401** |
| Valid token, wrong role for admin route | **403** |
| Valid token, wrong resource ownership | **403** |
| Forged `X-Role: admin` header | Ignored; policy from token + server data |
| UI hides admin button | API still rejects unauthorized caller |

Platform-side signal checks (roles/groups in tokens):

```bash
make apply-authorization
make validate-authorization
```

---

## Configuration helpers

| Command | Purpose |
|---------|---------|
| `make apply-authorization` | Ensure groups claim mapper on sample clients |
| `make validate-authorization` | Verify roles/groups signals and docs contract |

Application feature code is out of scope for Phase 04; Phase 05 covers
integration patterns that implement this checklist.
