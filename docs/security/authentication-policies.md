# Authentication Policies

Phase 03 decisions for the `platform` realm. Applications integrate with
Keycloak using standard OpenID Connect; they never store user passwords.

Related documents:

- [token-strategy.md](token-strategy.md) — token types and validation
- [security-model.md](security-model.md) — broader security model
- [../phases/03-authentication.md](../phases/03-authentication.md) — phase plan

---

## Architecture

```text
User → Application → Keycloak (auth, session, MFA) → OIDC tokens → Application
```

Keycloak is the only credential store. Applications consume tokens and
enforce business authorization separately (Phase 04).

---

## Realm policies (local baseline)

| Policy | Value | Rationale |
|--------|-------|-----------|
| Self-registration | **Disabled** | Admin/invite-only until product needs public signup |
| Email verification | Off until SMTP is configured | Avoid blocking logins without mail (Phase 06) |
| Password reset | **Allowed** | Requires SMTP for email delivery in real environments |
| Brute-force protection | **Enabled** | Mitigate credential stuffing / guessing |
| Password policy | length ≥ 12, not username/email, history 3 | Raise baseline password strength |
| Access token lifespan | **300 seconds** | Limit theft window |
| SSO session idle / max | 1800 / 36000 seconds | Balance UX and risk |
| Refresh token reuse | **Revoke on reuse** (`refreshTokenMaxReuse=0`) | Detect refresh token theft |
| OTP | TOTP (6 digits, 30s) | MFA baseline for privileged accounts |

Apply or refresh these on a running stack:

```bash
make apply-auth
```

---

## OIDC integration contract

Prefer discovery:

```text
{KEYCLOAK_URL}/realms/platform/.well-known/openid-configuration
```

| Endpoint | Use |
|----------|-----|
| `authorization_endpoint` | Browser login (Authorization Code + PKCE for public clients) |
| `token_endpoint` | Code exchange and refresh |
| `userinfo_endpoint` | Optional profile claims with access token |
| `jwks_uri` | Signature keys for JWT validation |
| `end_session_endpoint` | RP-initiated logout |

### Token roles

| Token | Client use | API use |
|-------|------------|---------|
| ID token | Establish who logged in | **Never** as API credential |
| Access token | — | `Authorization: Bearer` |
| Refresh token | Token endpoint only | **Never** send to APIs |

### Backend validation checklist

1. Fetch JWKS from `jwks_uri` (cache; refresh on unknown `kid`)
2. Verify JWT signature
3. Verify `iss` equals the realm issuer exactly
4. Verify `exp` (and `nbf`/`iat` when present)
5. Verify `aud` / `azp` according to client design
6. On failure → **401 Unauthorized**
7. On authenticated but forbidden → **403 Forbidden** (Phase 04)

Do not put unnecessary business data or fine-grained permissions into tokens.

---

## MFA baseline

| Account | Policy |
|---------|--------|
| Standard users (`demo`) | Password only for local development |
| Privileged (`admin`, `super-admin`) | `CONFIGURE_TOTP` required (`admin-demo` sample) |

Enforcement lives in Keycloak (required actions / conditional OTP flows),
not in each application. Broader MFA can be enabled later without changing
app protocols.

**Recovery:** admin-assisted reset of OTP via Admin Console; avoid permanent
MFA bypass without audit. Recovery codes may be introduced when operational
process is ready.

---

## Password security

- Passwords are managed **exclusively** by Keycloak.
- Applications must **never store user passwords**.
- Applications must **never log passwords, access tokens, or refresh tokens**.
- Failed login responses must not echo the submitted password.

---

## Session and logout

1. Application clears its local session/cookies.
2. Application redirects to Keycloak `end_session_endpoint` (RP-initiated logout)
   with `id_token_hint` and `post_logout_redirect_uri` when available.
3. Subsequent refresh-token use must fail.

---

## Error handling expectations

| Condition | Platform / API behavior |
|-----------|-------------------------|
| Invalid credentials | Keycloak login error; no tokens |
| Invalid / expired access token | API **401** |
| Refresh after logout or reuse | Token endpoint error |
| Authenticated but not permitted | API **403** (Phase 04) |

---

## Email-dependent flows

Password reset and email verification require SMTP (Phase 06). Until then:

- Reset remains **allowed** in realm config so the flow exists.
- Local testing of email delivery is deferred.
- Registration stays disabled.

---

**Local demo accounts**

| Intended username | May appear as (legacy) | Password |
|-------------------|------------------------|----------|
| `demo` | `demo@example.com` | `changeme-demo-12` |
| `admin-demo` | `admin-demo@example.com` | `changeme-admin-12` |

Fresh imports with `registrationEmailAsUsername=false` keep short usernames.
Existing local DBs may retain email-style usernames (login still works with email).
Override login with `DEMO_USERNAME` in `.env` if needed.

---

## Validation

```bash
make validate-authentication
```

Covers discovery, policies, failed login, PKCE login, token claims, userinfo
401s, refresh rotation/reuse rejection, and logout.
