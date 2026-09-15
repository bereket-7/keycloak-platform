# Phase 03 — Authentication

Implement and validate the complete user authentication lifecycle using
Keycloak and OpenID Connect.

---

## Objective

Support secure authentication for applications using standard OpenID
Connect (OIDC) with Keycloak as the sole identity provider for user
credentials, sessions, and MFA.

Applications integrate via OIDC. They must not store user passwords or
re-implement login protocols.

---

## Authentication Architecture

```text
User
 |
 v
Application
 |
 v
Keycloak
 |
 +-- Authentication
 +-- Session
 +-- MFA
 |
 v
OIDC tokens
 |
 v
Application
```

Keycloak authenticates the user and issues tokens. The application
consumes tokens to establish an application session or authorize API
calls. Business authorization remains an application concern (Phase 04).

---

## Authentication Flows

| Flow | Description |
|------|-------------|
| **Login** | User is redirected to Keycloak; authenticates; returns to app with authorization code; app exchanges code for tokens (PKCE for public clients) |
| **Logout** | Application ends local session and triggers Keycloak logout (RP-initiated logout) so IdP session ends |
| **Registration** | Optional self-registration if enabled for the realm; otherwise admin/invite-only |
| **Email verification** | Optional/required verification before full access, per realm policy |
| **Password reset** | User resets password through Keycloak email/flow; app never handles raw password storage |
| **Session expiration** | IdP and application sessions expire per configured lifetimes |
| **Token refresh** | Client uses refresh token (confidentially / securely stored) to obtain new access tokens |

---

## OpenID Connect

### Endpoints and discovery

Applications should prefer the realm discovery document:

```text
{issuer}/.well-known/openid-configuration
```

| Concept | Purpose |
|---------|---------|
| **Issuer** | Canonical realm identifier; must match token `iss` |
| **Authorization endpoint** | Browser redirect for interactive login |
| **Token endpoint** | Code exchange, refresh, client credentials (when used) |
| **UserInfo endpoint** | Optional user profile claims with access token |
| **JWKS** | Public keys for JWT signature validation |
| **Discovery document** | Machine-readable endpoint and capability metadata |

### Token types (do not confuse)

| Token | Audience / use | Contains identity? | Used to call APIs? |
|-------|----------------|--------------------|--------------------|
| **ID token** | Client application | Yes (OIDC identity) | **No** — not an API credential |
| **Access token** | Resource servers / APIs | May include claims | **Yes** — Authorization: Bearer |
| **Refresh token** | Token endpoint only | Indirect | **No** — never send to APIs |

---

## Token Strategy

### Access token

- Short-lived credential for APIs.
- Validate signature, issuer, expiry, and audience/azp as appropriate.
- Prefer opaque-to-business-data: include subject and coarse roles/groups only as needed.

### Refresh token

- Used only with the token endpoint to obtain new access (and possibly ID) tokens.
- Store with care (secure HTTP-only cookies or backend-managed storage).
- Rotate/revoke according to Keycloak realm settings.

### Expiration and validation

Applications and APIs must validate:

1. **Signature** — using JWKS from Keycloak
2. **Issuer (`iss`)** — exact realm issuer
3. **Expiration (`exp`)** — reject expired tokens
4. **Audience (`aud`) / authorized party** — as appropriate for the client/API design
5. **Not-before / issued-at** — when relevant

### What not to put in tokens

Do not place unnecessary sensitive business data in tokens (PII beyond need,
permissions for every resource, secrets). Tokens are often inspectable by
clients and intermediate systems.

---

## MFA

### Why MFA matters

Password-only authentication is vulnerable to phishing, stuffing, and
reuse. MFA significantly raises attacker cost for account takeover.

### TOTP / authenticator applications

- Prefer TOTP authenticator apps as a baseline MFA method.
- Configure realm policies for when MFA is required (all users, admins, or step-up).

### Recovery considerations

- Document recovery codes or admin-assisted recovery procedures.
- Avoid recovery paths that permanently bypass MFA without audit.

### Enforcement strategy

- Start with MFA for privileged roles (`admin`, `super-admin`) if not globally enforced yet.
- Move toward broader enforcement as the platform matures.
- Keep MFA policy in Keycloak, not reimplemented per application.

---

## Password Security

- Passwords are managed exclusively by Keycloak.
- Applications must never store user passwords.
- Applications must never log passwords or tokens.
- Password policies (length, history, brute-force lockout) are realm settings.

---

## Session Management

| Concern | Guidance |
|---------|----------|
| Session lifetime | Configure SSO session idle/max in Keycloak intentionally |
| Application session | Derive from tokens; clear on logout |
| Logout | Clear app session + Keycloak logout |
| Token expiration | Access tokens short-lived; refresh as needed |
| Refresh | Only through secure client paths |
| Revocation | Prefer logout/session termination; understand refresh token revocation settings |

---

## Error Handling

| Condition | Expected behavior |
|-----------|-------------------|
| Invalid credentials | Keycloak rejects login; generic error to user; no password echo |
| Expired session | Re-authenticate via OIDC; do not silently trust stale local state |
| Invalid token | API returns **401**; client starts re-auth if appropriate |
| Expired token | API returns **401**; client attempts refresh once, then re-auth |
| Unauthorized user (no permission) | After valid auth, application returns **403** (Phase 04) |

---

## Testing

### Authentication test matrix

| Case | Steps | Expected |
|------|-------|----------|
| Successful login | Valid user completes OIDC code flow | Tokens issued; app authenticated |
| Failed login | Wrong password | Login denied; no tokens |
| Registration | If enabled, new user registers | User created per policy; verification gates applied |
| Email verification | User verifies email | Account state updates; access policy honored |
| Password reset | Request reset; set new password | Can log in with new password; old rejected |
| Logout | App + IdP logout | Session ended; protected routes require login |
| Expired access token | Call API with expired Bearer token | **401** |
| Refresh | Valid refresh token | New access token; API succeeds |
| MFA | User with MFA required | Login blocked until MFA succeeds |
| Invalid session | Tampered/missing cookies or tokens | Re-auth required |

Automate where practical; manually verify browser redirects and cookie flags in local HTTPS-less setups carefully.

---

## Security Considerations

| Threat | Mitigation |
|--------|------------|
| Phishing | User education; MFA; avoid lookalike login pages outside Keycloak |
| Credential stuffing | Brute-force protection; MFA; breach password checks if available |
| Brute force | Keycloak lockout/temporary lock policies |
| Token theft | Short access token TTL; secure storage; HTTPS in non-local envs |
| Session hijacking | Secure cookies; logout; session timeouts |
| Redirect attacks | Exact redirect URI allow lists; no production wildcards |

---

## Tasks

- [ ] Confirm OIDC discovery for `platform` realm
- [ ] Validate authorization code + PKCE for public clients
- [ ] Validate token endpoint code exchange
- [ ] Document issuer, JWKS, and token validation rules for apps
- [ ] Configure session and token lifetimes deliberately
- [ ] Enable and test logout (app + Keycloak)
- [ ] Configure registration/verification/reset policies as required
- [ ] Configure MFA baseline for privileged users (minimum)
- [ ] Ensure apps never store passwords
- [ ] Execute authentication test matrix and record results

---

## Acceptance Criteria

1. Users can log in via OIDC to a registered client.
2. ID, access, and refresh tokens are issued and used for their correct purposes.
3. Token validation rules (signature, issuer, expiry, audience as designed) are documented.
4. Logout ends application and IdP sessions.
5. Password reset and email verification behave per realm policy.
6. MFA path exists for at least privileged accounts (or globally, if chosen).
7. Failed auth and expired tokens produce safe, predictable errors.
8. No application stores user passwords.
9. Security threats above have documented mitigations.

---

## Deliverables

- Documented OIDC authentication architecture
- Configured authentication-related realm policies
- Token strategy and validation requirements
- MFA and password policy decisions
- Executed authentication test matrix results
- Error-handling expectations for integrating apps

---

## Dependencies

**Requires:** Phase 01 (runtime), Phase 02 (realm/clients).

**Unblocks:** Phase 04 (authorization separation), Phase 05 (application integration patterns).

---

## Completion Criteria

Authentication is considered production-quality for platform purposes when
the full OIDC lifecycle works against the `platform` realm, token semantics
are correct, MFA and password policies are intentional, and the test matrix
passes without relying on custom non-standard auth protocols.

**Authorization design is Phase 04. Application integration patterns are Phase 05.**
