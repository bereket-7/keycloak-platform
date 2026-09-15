# Threat Model

## 1. Purpose

This document identifies major security threats to the centralized Keycloak identity platform and defines the controls used to reduce their impact.

The threat model focuses on:

* Authentication.
* Authorization.
* Tokens.
* Sessions.
* Infrastructure.
* Network security.
* Secrets.
* User accounts.
* Administrative access.
* Application integration.

This is a living document and should be updated when the architecture changes.

---

# 2. System Under Analysis

The system contains:

```text
                    Internet
                       |
                       v
                Reverse Proxy
                       |
                       v
                   Keycloak
                       |
                       v
                  PostgreSQL
                       |
                       |
             Future Applications
                       |
                       v
                  Application
                   Backends
```

Primary assets include:

* User accounts.
* Password credentials.
* MFA configuration.
* Keycloak sessions.
* Access tokens.
* Refresh tokens.
* Client credentials.
* Keycloak signing keys.
* Database contents.
* Application authorization data.
* Backup data.
* Administrative access.

---

# 3. Security Objectives

The platform must protect:

## Confidentiality

Prevent unauthorized access to:

* Credentials.
* Tokens.
* User information.
* Database contents.
* Secrets.

## Integrity

Prevent unauthorized modification of:

* User accounts.
* Roles.
* Clients.
* Authentication configuration.
* Application permissions.
* Infrastructure configuration.

## Availability

Keep authentication available when required.

Important dependencies include:

* DNS.
* Reverse proxy.
* Keycloak.
* PostgreSQL.
* Network connectivity.

---

# 4. Threat Categories

The main threat categories are:

```text
Credential Attacks
Token Attacks
Session Attacks
Authorization Bypass
Web Attacks
Infrastructure Attacks
Secret Exposure
Configuration Errors
Denial of Service
Supply Chain Risks
Insider Threats
```

---

# 5. Credential Stuffing

## Threat

An attacker uses credentials leaked from another service to attempt login.

## Impact

Potential account compromise.

## Controls

* Strong password policies.
* MFA.
* Brute-force protection.
* Rate limiting where appropriate.
* Monitoring failed authentication attempts.
* User security notifications where appropriate.

---

# 6. Brute-Force Authentication

## Threat

An attacker repeatedly attempts passwords against a user account.

## Controls

* Keycloak brute-force protections.
* Rate limiting.
* Strong passwords.
* MFA.
* Monitoring.
* Appropriate account protection policies.

Authentication controls must not create an easy denial-of-service mechanism against legitimate users.

---

# 7. Phishing

## Threat

An attacker creates a fake login page to obtain user credentials.

## Impact

Account takeover.

## Controls

* HTTPS.
* Correct and stable authentication domain.
* MFA.
* Secure branding.
* User education.
* Avoid unnecessary authentication redirects.
* Clear authentication domain.

The platform cannot completely prevent phishing, so MFA is an important additional defense.

---

# 8. Token Theft

## Threat

An attacker obtains an access token or refresh token.

## Impact

Unauthorized API access.

## Controls

* HTTPS.
* Short-lived access tokens.
* Secure token storage.
* Avoid logging tokens.
* Avoid tokens in URLs.
* Protect browser storage.
* Refresh-token protection.
* Appropriate token rotation and invalidation.

---

# 9. Token Replay

## Threat

A stolen valid token is reused by an attacker.

## Controls

* Short access-token lifetime.
* TLS.
* Secure client architecture.
* Appropriate refresh-token handling.
* Token audience validation.
* Monitoring for suspicious activity where available.

---

# 10. Session Hijacking

## Threat

An attacker obtains a user's session information.

## Controls

* HTTPS.
* Secure cookies.
* HttpOnly cookies where applicable.
* SameSite controls.
* Session expiration.
* Keycloak session management.
* Protection against XSS.

---

# 11. Authorization Bypass

## Threat

An authenticated user accesses resources they do not own.

Example:

```text
User A
   |
   | GET /projects/project-B
   v
Backend
```

The backend incorrectly trusts that authentication means authorization.

## Controls

The backend must check:

```text
Identity
   +
Role / Scope
   +
Resource Ownership
   +
Business Rules
```

Frontend restrictions are not security controls.

---

# 12. Privilege Escalation

## Threat

A normal user attempts to obtain administrative permissions.

## Controls

* Least privilege.
* Server-side authorization.
* Restricted role assignment.
* Protected administrative interfaces.
* MFA for privileged users.
* Audit logging.
* No user-controlled role claims.

Roles received from the trusted identity provider may be used as inputs to authorization decisions, but the application must still enforce its own business rules.

---

# 13. Malicious JWT Claims

## Threat

An attacker modifies JWT claims such as:

```text
role=admin
```

## Controls

The backend must verify the JWT signature before trusting claims.

Never decode a JWT and trust its payload without signature validation.

---

# 14. JWT Confusion

## Threat

A token issued for another application or API is accepted by the wrong API.

## Controls

* Issuer validation.
* Audience validation.
* Appropriate client/API configuration.
* Explicit scopes.
* Backend token validation.

---

# 15. Redirect URI Attack

## Threat

An attacker attempts to manipulate the OIDC redirect URI so that authentication results are sent to an attacker-controlled location.

## Controls

* Explicit redirect URIs.
* No wildcard redirect URIs in production.
* Separate development and production clients.
* Review redirect URI changes.

---

# 16. Client Secret Exposure

## Threat

A confidential client secret is accidentally exposed in:

* Frontend source code.
* Git.
* Logs.
* Docker images.
* CI/CD output.

## Controls

* Never put confidential client secrets in browser applications.
* Store secrets outside source code.
* Use environment-specific secret management.
* Rotate compromised secrets.
* Review Git history if a secret is accidentally committed.

---

# 17. Database Exposure

## Threat

An attacker connects directly to PostgreSQL.

## Impact

Potential compromise of the entire identity platform.

## Controls

* Private database network.
* Firewall rules.
* No public database port.
* Strong credentials.
* Least-privilege database accounts.
* Encrypted backups.
* Monitoring.

---

# 18. Database Credential Theft

## Threat

PostgreSQL credentials are leaked.

## Controls

* Environment/secret management.
* Never commit credentials.
* Rotate credentials.
* Restrict database access.
* Audit configuration.

---

# 19. Keycloak Administrative Account Compromise

## Threat

An attacker obtains administrative access to Keycloak.

## Impact

Potential full compromise of identities and applications.

## Controls

* MFA for administrators.
* Strong administrator credentials.
* Restricted administrative access.
* Separate administrative accounts.
* Minimal number of administrators.
* Monitoring.
* Regular credential review.

Administrative credentials should never be reused across unrelated systems.

---

# 20. XSS

## Threat

Malicious JavaScript executes in an authenticated user's browser.

## Impact

Potential theft of application data or authentication material.

## Controls

* Secure application development.
* Output encoding.
* Content Security Policy where appropriate.
* Dependency security.
* Secure token storage.
* Avoid unnecessary token exposure to browser JavaScript.

Keycloak customization must also be reviewed for XSS risks.

---

# 21. CSRF

## Threat

An attacker causes a browser to perform an unwanted authenticated action.

## Controls

Depending on the application architecture:

* SameSite cookies.
* CSRF tokens.
* Origin validation.
* Appropriate HTTP methods.
* Secure cookie configuration.

APIs using bearer tokens in authorization headers have different CSRF characteristics than cookie-based authentication.

---

# 22. CORS Misconfiguration

## Threat

An overly permissive CORS policy allows unintended origins to interact with authenticated APIs.

## Controls

* Explicit allowed origins.
* No unrestricted production wildcard policy for authenticated APIs.
* Environment-specific configuration.
* Regular review of allowed origins.

---

# 23. Denial of Service

## Threat

Attackers overload:

* Keycloak.
* Reverse proxy.
* PostgreSQL.
* Authentication endpoints.

## Controls

* Rate limiting.
* Connection limits.
* Resource monitoring.
* Infrastructure scaling where required.
* Reverse proxy protections.
* Database capacity planning.
* Authentication abuse detection.

Availability controls should be implemented carefully so legitimate users are not unnecessarily blocked.

---

# 24. Malicious Configuration

## Threat

An administrator or deployment process introduces insecure configuration.

Examples:

```text
Wildcard redirect URI
Public PostgreSQL port
Disabled HTTPS
Overly broad CORS
Weak administrator credentials
Excessive roles
```

## Controls

* Configuration review.
* Infrastructure as code.
* Version control.
* Automated validation where practical.
* Environment separation.
* Security checklist.
* Staging validation.

---

# 25. Supply Chain Threats

## Threat

A compromised dependency or container image introduces malicious code.

## Controls

* Pin infrastructure image versions.
* Keep dependencies updated.
* Review dependency changes.
* Use trusted image registries.
* Scan dependencies/images where available.
* Avoid unnecessary dependencies.

Production must not rely on unreviewed `latest` images.

---

# 26. Backup Theft

## Threat

An attacker obtains a Keycloak/PostgreSQL backup.

## Impact

Potential exposure of sensitive identity data.

## Controls

* Encrypt backups.
* Restrict backup access.
* Separate backup credentials.
* Secure backup storage.
* Monitor access.
* Define retention policies.
* Test restoration.

Backups must be treated as production-sensitive data.

---

# 27. Insider Threat

## Threat

A person with legitimate infrastructure access abuses their privileges.

## Controls

* Least privilege.
* Separate administrator accounts.
* MFA.
* Audit logging.
* Access reviews.
* Restricted production access.
* Credential rotation.
* Documented operational procedures.

---

# 28. Threat Matrix

| Threat                | Impact      | Primary Controls                    |
| --------------------- | ----------- | ----------------------------------- |
| Credential stuffing   | High        | MFA, brute-force protection         |
| Brute force           | High        | Rate limiting, MFA                  |
| Phishing              | High        | MFA, HTTPS                          |
| Token theft           | Critical    | HTTPS, secure storage, short TTL    |
| Session hijacking     | High        | Secure cookies, HTTPS               |
| Authorization bypass  | Critical    | Backend authorization               |
| Privilege escalation  | Critical    | Least privilege, server-side checks |
| JWT tampering         | Critical    | Signature validation                |
| Redirect attack       | High        | Explicit redirect URIs              |
| Client secret leak    | Critical    | Secret management                   |
| Database exposure     | Critical    | Private network                     |
| Admin compromise      | Critical    | MFA, restricted access              |
| XSS                   | High        | Secure application development      |
| CSRF                  | High        | SameSite/CSRF protections           |
| CORS misconfiguration | Medium/High | Explicit origins                    |
| DoS                   | High        | Rate limiting, monitoring           |
| Supply chain attack   | High        | Version pinning/scanning            |
| Backup theft          | Critical    | Encryption/access control           |

---

# 29. Incident Response

Security incidents should follow a documented process.

Minimum response flow:

```text
Detect
  |
  v
Contain
  |
  v
Investigate
  |
  v
Recover
  |
  v
Rotate compromised credentials
  |
  v
Validate systems
  |
  v
Document incident
  |
  v
Improve controls
```

Potential actions include:

* Revoke compromised sessions.
* Rotate client secrets.
* Rotate database credentials.
* Rotate affected API keys.
* Disable compromised accounts.
* Review administrative activity.
* Restore from a known-good backup where necessary.
* Review logs and monitoring data.

---

# 30. Security Testing

Security-sensitive functionality should be tested before production.

Testing should include:

* Invalid login.
* Brute-force protection.
* MFA.
* Password reset.
* Email verification.
* Expired tokens.
* Invalid signatures.
* Invalid issuer.
* Invalid audience.
* Missing roles.
* Missing scopes.
* Unauthorized resource access.
* Redirect URI validation.
* CORS behavior.
* Session expiration.
* Logout.
* Secret handling.
* Backup restoration.

---

# 31. Security Review Checklist

Before production:

* [ ] HTTPS enabled.
* [ ] PostgreSQL private.
* [ ] Admin MFA enabled.
* [ ] Strong administrator credentials.
* [ ] No secrets in Git.
* [ ] No tokens in logs.
* [ ] Explicit redirect URIs.
* [ ] CORS restricted.
* [ ] Access-token lifetime configured.
* [ ] Backend JWT validation implemented.
* [ ] Backend resource authorization implemented.
* [ ] Database backups configured.
* [ ] Backup restoration tested.
* [ ] Monitoring enabled.
* [ ] Keycloak upgrade strategy documented.
* [ ] Incident response process documented.

---

# 32. Threat Model Maintenance

This document must be updated when significant architectural changes occur.

Examples:

* Adding a new application type.
* Adding a new identity provider.
* Introducing mobile applications.
* Introducing a new reverse proxy.
* Moving to cloud infrastructure.
* Adding high availability.
* Changing token architecture.
* Introducing multi-tenancy.
* Changing database architecture.

Security documentation must evolve with the platform.
