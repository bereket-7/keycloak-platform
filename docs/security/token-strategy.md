# Token Strategy

## 1. Purpose

This document defines how OAuth2 and OpenID Connect tokens are issued, consumed, validated, and protected across the platform.

The goal is to establish a consistent token strategy that future applications can reuse.

---

# 2. Token Types

The platform primarily uses:

* ID tokens.
* Access tokens.
* Refresh tokens.

Each token has a different purpose.

## ID Token

The ID token represents the authenticated user's identity to the client application.

It is primarily used by the OIDC client to understand the authentication result.

It should not be treated as an API authorization token.

## Access Token

The access token authorizes access to protected APIs.

Backend APIs should validate access tokens before processing protected requests.

## Refresh Token

A refresh token allows an authorized client to obtain new access tokens without requiring the user to authenticate again.

Refresh tokens are highly sensitive credentials and must be protected accordingly.

---

# 3. Token Flow

A typical authorization code flow is:

```text
User
 |
 v
Application
 |
 | Authorization Request
 v
Keycloak
 |
 | Authentication
 v
User
 |
 | Authorization Code
 v
Application
 |
 | Token Exchange
 v
Keycloak
 |
 +--> Access Token
 +--> ID Token
 +--> Refresh Token (when applicable)
 |
 v
Application
```

The application then uses the access token when calling protected APIs.

```text
Application
    |
    | Authorization: Bearer <access-token>
    v
Backend API
```

---

# 4. Authorization Code Flow

Browser-based applications should use Authorization Code Flow with appropriate modern protections.

The platform should prefer standards-based OIDC flows over custom authentication protocols.

Applications should not implement their own password authentication against Keycloak.

---

# 5. Token Validation

Every protected backend API must validate access tokens.

At minimum, validation should include:

```text
Signature
Issuer
Expiration
Not Before
Audience
Scopes
Roles
```

The exact validation requirements depend on the API and client architecture.

A valid signature alone is insufficient.

---

# 6. Issuer Validation

The backend must validate that the token was issued by the expected Keycloak realm.

Example conceptual issuer:

```text
https://auth.example.com/realms/platform
```

The expected issuer must be environment-specific.

A token issued by another realm or identity provider must not automatically be accepted.

---

# 7. Signature Validation

JWT signatures must be validated using trusted Keycloak signing keys.

Applications should obtain public signing keys through the standard OIDC discovery/JWKS mechanism.

Applications must not hardcode signing keys unless there is a deliberate operational reason.

Signing key rotation must be supported.

---

# 8. Audience Validation

APIs should validate that the access token is intended for the API when the architecture requires audience validation.

Example:

```text
Token Audience
      |
      v
project-a-api
```

A token intended for another API should not automatically grant access to the current API.

Audience design should be consistent across applications.

---

# 9. Token Lifetime

Access tokens should be short-lived.

Short-lived access tokens reduce the impact of token theft.

The exact lifetime should balance:

* Security.
* User experience.
* Infrastructure reliability.
* Application requirements.

Refresh tokens may be used to maintain sessions without making access tokens long-lived.

Token lifetime values must be documented and environment-specific where necessary.

---

# 10. Refresh Tokens

Refresh tokens must be treated as highly sensitive credentials.

Applications must:

* Protect refresh tokens from unauthorized access.
* Never log refresh tokens.
* Never expose refresh tokens to unrelated services.
* Rotate or invalidate them according to the configured Keycloak behavior.
* Handle refresh failures safely.

If refresh token reuse is detected or a refresh token becomes invalid, the application should require an appropriate re-authentication flow.

---

# 11. JWT Claims

Only necessary claims should be included in tokens.

Potential claims include:

```text
sub
iss
aud
exp
iat
scope
roles
```

Application-specific claims should be added only when there is a clear requirement.

Avoid putting large amounts of business data into JWTs.

Avoid putting sensitive information into tokens unless required.

---

# 12. User Identity

The `sub` claim should be treated as the stable identifier for the authenticated identity within the token's issuer context.

Applications should not rely on:

```text
email
username
display name
```

as the primary immutable user identifier.

Email addresses and usernames may change.

---

# 13. Roles and Scopes

Tokens may contain coarse-grained authorization information.

Examples:

```text
user
admin
super-admin
```

or scopes such as:

```text
profile
email
project:read
project:write
```

However, tokens should not become a complete database of business permissions.

For example, avoid creating thousands of roles such as:

```text
project-123-edit
project-124-edit
project-125-edit
```

Resource-level authorization should remain in the application.

---

# 14. Token Storage

Token storage depends on the application architecture.

Browser applications must minimize exposure of sensitive tokens to JavaScript.

Where possible, applications should prefer secure session mechanisms such as:

* Secure cookies.
* HttpOnly cookies.
* SameSite protections.
* Backend-for-Frontend patterns where appropriate.

Avoid storing sensitive long-lived credentials in:

```text
localStorage
sessionStorage
URLs
logs
```

without a strong, documented reason.

---

# 15. Authorization Header

API requests normally use:

```text
Authorization: Bearer <access-token>
```

Access tokens must not be passed through URLs.

Avoid:

```text
https://api.example.com/users?token=<token>
```

because URLs can leak through logs, browser history, monitoring systems, and referrer information.

---

# 16. Token Revocation and Logout

Applications must distinguish between:

* Local application logout.
* Keycloak session logout.
* Access-token expiration.
* Refresh-token invalidation.

Logging out from an application does not necessarily mean that every already-issued access token immediately becomes invalid.

Therefore, short access-token lifetimes and appropriate session management are important.

---

# 17. Key Rotation

Keycloak signing keys may be rotated.

Applications must therefore support retrieving current signing keys through JWKS rather than assuming a permanent signing key.

JWKS caches should respect key rotation and refresh behavior.

A new signing key must not cause all applications to fail authentication.

---

# 18. Token Security Requirements

The following are mandatory:

1. Never log access tokens.
2. Never log refresh tokens.
3. Never expose tokens in URLs.
4. Validate JWT signatures.
5. Validate issuer.
6. Validate expiration.
7. Validate audience where required.
8. Validate required scopes or roles.
9. Protect refresh tokens.
10. Use HTTPS in production.
11. Use short-lived access tokens.
12. Support signing key rotation.
13. Do not trust unvalidated JWT claims.
14. Do not treat ID tokens as API access tokens.

---

# 19. Token Validation Failure

Invalid tokens must be rejected.

Examples:

```text
Missing token       -> 401
Expired token       -> 401
Invalid signature   -> 401
Invalid issuer      -> 401
Invalid audience    -> 401
Missing permission  -> 403
```

Applications must not attempt to "fix" or accept partially invalid tokens.

---

# 20. Token Strategy Acceptance Criteria

The token strategy is considered implemented correctly when:

* Applications use standard OAuth2/OIDC.
* Access tokens are used for API authorization.
* ID tokens are not used as API credentials.
* Backend APIs validate JWT signatures.
* Issuer validation is implemented.
* Expiration is validated.
* Audience validation is implemented where required.
* Required scopes/roles are validated.
* Tokens are not logged.
* Tokens are not passed through URLs.
* Refresh tokens are appropriately protected.
* Signing key rotation is supported.
* Token lifetimes are documented.
