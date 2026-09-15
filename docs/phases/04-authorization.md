# Phase 04 — Authorization

Define a clean authorization architecture between Keycloak and
application business logic.

---

## Objective

Clearly separate authentication from authorization so that Keycloak
remains a reusable identity platform while applications retain control
of business and resource-level permissions.

---

## Core Principle

**Authentication:** “Who are you?”

**Authorization:** “What are you allowed to do?”

| Concern | Owner |
|---------|-------|
| Identity proof, sessions, MFA, federation | Keycloak |
| Coarse-grained roles / group membership signals | Keycloak |
| Business permissions, resource ownership, domain rules | Application |

Keycloak answers identity and coarse access signals. Applications enforce
what a user may do to specific domain objects.

---

## Authorization Layers

```text
Layer 1: Identity          (Keycloak — subject / user id)
Layer 2: Roles             (Keycloak — coarse roles)
Layer 3: Groups            (Keycloak — org/team/project membership)
Layer 4: Application permissions  (Application — feature flags / ACLs)
Layer 5: Resource ownership       (Application — object-level checks)
```

| Layer | Example question | Enforced by |
|-------|------------------|-------------|
| Identity | Is this a valid user? | Token validation |
| Roles | Is this user an `admin`? | App checks role claim / mapping |
| Groups | Is this user in org Acme? | App checks group claim / sync |
| App permissions | May this user manage billing? | Application policy |
| Resource ownership | May this user edit project `42`? | Application + database |

---

## Example

```text
Organization
    |
    +-- Project
          |
          +-- Team
                |
                +-- User
```

### Division of responsibility

| Fact | Where it lives |
|------|----------------|
| User identity (`sub`, email) | Keycloak |
| User is member of Organization A (group) | Keycloak group (optional signal) |
| User has realm role `admin` | Keycloak |
| User can create projects in Organization A | Application permission |
| User can edit Project 123 | Application resource ownership / ACL |
| User can administer Team 9 | Application domain rule |

Keycloak should not become the system of record for every project ACL.
Applications store resource relationships in their own databases and
enforce them after authenticating the caller.

---

## Roles

Recommended coarse realm roles:

| Role | Intent |
|------|--------|
| `user` | Standard authenticated principal |
| `admin` | Privileged operator within an application or platform scope |
| `super-admin` | Break-glass / platform-wide administration |

### Why roles stay coarse-grained

- Fine-grained business roles multiply and drift across apps.
- Tokens become large and hard to reason about.
- Resource-level rules change faster than IdP config.
- Reuse across applications requires a small shared vocabulary.

Add client roles only when a signal is truly client-specific and still coarse.

---

## Groups

Groups may represent:

- **organization groups** — tenant or company membership
- **team groups** — departmental or functional membership
- **project groups** — loose association to a project community

Groups help bootstrap access and communicate membership. They do not
replace application checks such as “owner of document X”.

---

## JWT Claims

Roles and groups may appear in access tokens (or be fetched via UserInfo)
as claims, for example realm roles and group paths.

### Rules

- Include only claims needed for authorization decisions at the edge.
- Prefer stable identifiers (`sub`) over mutable display names for ownership.
- Do not embed full permission matrices or sensitive business payloads.
- Treat claims as **inputs** to application policy, not as proof that a
  specific resource action is allowed without further checks.

---

## Application Authorization

Examples that belong in the backend:

- User can read project X.
- User can edit project Y.
- User can administer team Z.

### Enforcement

- The **backend** must enforce these rules on every request.
- The frontend may hide buttons for UX, but UI hiding is not security.
- Prefer centralized policy helpers in the API layer to avoid duplicated checks.

---

## Backend Security

For every protected API request, the backend must:

1. Extract the Bearer access token
2. Validate JWT **signature** (JWKS)
3. Validate **issuer**
4. Validate **audience** (where appropriate)
5. Validate **expiration**
6. Validate required **roles/scopes** for the endpoint class
7. Enforce **resource authorization** against application data
8. Return correct **401** / **403** responses

Never trust roles sent by the client in request bodies or headers as
authoritative. Trust only validated token claims plus server-side data.

---

## 401 vs 403

| Status | Meaning | When to use |
|--------|---------|-------------|
| **401 Unauthorized** | Authentication is missing or invalid | No token, bad signature, wrong issuer, expired token |
| **403 Forbidden** | Authentication succeeded; permission insufficient | Valid user lacks role or resource permission |

Using 401 for “logged in but not allowed” confuses clients into
unnecessary re-login loops. Using 403 for “not logged in” hides the
need to authenticate.

---

## Common Mistakes

| Mistake | Why it hurts | Correct approach |
|---------|--------------|------------------|
| Trusting frontend authorization | UI can be bypassed | Enforce in API |
| Trusting user-provided roles | Attacker can forge headers/body | Use validated JWT claims |
| Putting all permissions into JWTs | Huge tokens; stale grants; IdP churn | Keep resource ACLs in app DB |
| Wildcard access | Accidental overexposure | Explicit allow rules |
| Excessive realm roles | Unmaintainable IdP | Coarse roles + app permissions |
| Authorization only in UI | Security theater | Server-side checks always |

---

## Tasks

- [x] Document identity vs authorization boundary for the platform
- [x] Finalize coarse role vocabulary (`user`, `admin`, `super-admin`)
- [x] Document group conventions for org/team/project
- [x] Specify which claims apps may consume from tokens
- [x] Define backend validation checklist (signature, iss, aud, exp, roles, resource)
- [x] Define 401 vs 403 API contract for integrating teams
- [x] Publish “common mistakes” guidance to application developers
- [x] Add authorization examples to application integration docs (Phase 05 cross-link)

---

## Testing

| Case | Expected | Where verified |
|------|----------|----------------|
| Valid token, permitted resource | **200** (or success) | Application test catalog |
| Missing token | **401** | Application test catalog |
| Invalid/expired token | **401** | Application test catalog |
| Valid token, wrong role for admin route | **403** | Application test catalog |
| Valid token, wrong resource ownership | **403** | Application test catalog |
| Client sends forged `X-Role: admin` header | Ignored | Documented contract |
| Frontend-only hide of admin button | API still rejects | Documented contract |
| Access token contains `user` role | Present | `make validate-authorization` |
| Access token contains group paths | `/orgs/...` etc. | `make validate-authorization` |
| Coarse role vocabulary exists | `user`/`admin`/`super-admin` | `make validate-authorization` |

Platform checks:

```bash
make apply-authorization
make validate-authorization
```

Contract: [authorization-model.md](../security/authorization-model.md).

---

## Acceptance Criteria

1. Documentation clearly separates authentication (Keycloak) from authorization (apps).
2. Five-layer model is defined and used consistently.
3. Roles remain coarse-grained by policy.
4. Groups are defined as membership signals, not full authZ.
5. JWT claim guidance forbids unnecessary business data.
6. Backend enforcement requirements are mandatory for integrating APIs.
7. 401 vs 403 semantics are explicit.
8. Common mistakes are documented with corrections.
9. Authorization test cases are defined for application teams.

---

## Deliverables

- Authorization architecture document (this phase)
- Role and group conventions
- Backend enforcement checklist
- API error semantics (401/403)
- Test case catalog for application authorization

---

## Dependencies

**Requires:** Phase 03 authentication/token semantics.

**Unblocks:** Phase 05 application integration patterns that include server-side authZ.

---

## Completion Criteria

Phase 04 is complete when integrating teams can explain where identity
ends and business authorization begins, implement backend checks using
validated tokens plus application data, and avoid encoding resource ACLs
into Keycloak roles.

**No application feature code is required in this documentation phase;
the contract must be clear enough to implement later without redesign.**
