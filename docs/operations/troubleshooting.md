# Troubleshooting Guide

## 1. Purpose

This document provides a systematic approach to diagnosing problems in the centralized Keycloak identity platform.

The goal is to avoid random configuration changes and provide a repeatable troubleshooting process.

---

# 2. Troubleshooting Principles

When diagnosing an issue:

1. Identify the failing component.
2. Check health status.
3. Check logs.
4. Check network connectivity.
5. Check configuration.
6. Check dependencies.
7. Reproduce the issue.
8. Make the smallest safe change.
9. Validate the result.
10. Document the root cause.

Do not make multiple unrelated changes at once.

---

# 3. System Dependency Chain

The platform dependency chain is:

```text
DNS
 |
 v
Reverse Proxy
 |
 v
Keycloak
 |
 v
PostgreSQL
```

Applications additionally depend on:

```text
Application
    |
    v
Keycloak
    |
    v
Backend
```

Troubleshoot from the bottom of the dependency chain when appropriate.

---

# 4. First-Level Health Check

Start with:

```text
DNS
HTTPS
Reverse Proxy
Keycloak
PostgreSQL
```

Determine which layer is failing before changing configuration.

---

# 5. Keycloak Not Starting

Possible causes:

* PostgreSQL unavailable.
* Incorrect database credentials.
* Invalid configuration.
* Port conflict.
* Invalid environment variable.
* Unsupported configuration.
* Resource exhaustion.

Troubleshooting:

```text
Check container status
        |
        v
Check Keycloak logs
        |
        v
Check PostgreSQL status
        |
        v
Check database connectivity
        |
        v
Check configuration
```

---

# 6. PostgreSQL Not Starting

Possible causes:

* Invalid configuration.
* Corrupt data.
* Insufficient disk space.
* Permission problems.
* Version mismatch.
* Volume problems.

Check:

* Container status.
* PostgreSQL logs.
* Disk usage.
* Volume availability.
* Database version.
* Database configuration.

Do not delete the database volume as a troubleshooting shortcut.

---

# 7. Keycloak Cannot Connect to PostgreSQL

Verify:

```text
Database hostname
Database port
Database name
Database username
Database password
Docker network
PostgreSQL health
```

In Docker Compose, Keycloak should normally connect using the PostgreSQL service name.

Example:

```text
postgres:5432
```

Do not use `localhost` from inside the Keycloak container.

---

# 8. Keycloak Is Unreachable

Check:

```text
Keycloak container
       |
       v
Port mapping
       |
       v
Reverse proxy
       |
       v
Firewall
       |
       v
DNS
```

For local development, verify the host port.

For production, verify:

* DNS.
* TLS.
* Reverse proxy.
* Firewall.
* Keycloak listener.
* Health endpoint.

---

# 9. Login Redirect Error

Common causes:

* Incorrect redirect URI.
* Incorrect client configuration.
* Wrong Keycloak hostname.
* Incorrect reverse proxy configuration.
* Wrong environment configuration.

Verify:

```text
Application URL
Keycloak URL
Client ID
Redirect URI
Web origins
Issuer
```

Production redirect URIs must be explicit.

---

# 10. Invalid Issuer Error

If a backend rejects a token because of the issuer:

Check:

```text
Expected issuer
Actual token issuer
Keycloak hostname
Realm name
Reverse proxy configuration
```

The token issuer must match the backend's expected identity provider.

---

# 11. Invalid Audience Error

If the backend rejects the token because of audience:

Check:

```text
Token audience
API client configuration
Backend expected audience
Application client configuration
```

Do not simply disable audience validation to make the error disappear.

Determine why the wrong audience is being issued or accepted.

---

# 12. Invalid Signature Error

Possible causes:

* Incorrect JWKS configuration.
* Stale signing key cache.
* Wrong issuer.
* Token issued by another realm.
* Signing-key rotation.
* Corrupted token.

Check:

```text
Issuer
JWKS endpoint
Key ID
Signing algorithm
Token signature
```

Do not disable signature verification.

---

# 13. 401 Unauthorized

A `401` generally indicates an authentication problem.

Check:

* Authorization header.
* Bearer token.
* Token expiration.
* Token signature.
* Issuer.
* Audience.
* Token format.

Example:

```text
Authorization: Bearer <access-token>
```

Do not expose the token while troubleshooting.

---

# 14. 403 Forbidden

A `403` generally indicates an authorization problem.

Check:

* User role.
* Required scope.
* Application permission.
* Resource ownership.
* Tenant membership.
* Business authorization rules.

Remember:

```text
Authenticated != Authorized
```

---

# 15. CORS Error

Check:

```text
Frontend origin
Allowed origins
HTTP method
Headers
Credentials configuration
```

Do not immediately use:

```text
*
```

as a production workaround.

Determine the exact frontend origins that should be trusted.

---

# 16. HTTPS / TLS Problems

Check:

* Certificate validity.
* Certificate hostname.
* Certificate expiration.
* Reverse proxy configuration.
* Keycloak hostname configuration.
* HTTP-to-HTTPS redirects.
* Forwarded protocol headers.

The browser should ultimately see the correct HTTPS hostname.

---

# 17. Session Problems

Possible symptoms:

* User is repeatedly logged out.
* Login succeeds but session disappears.
* Logout does not behave correctly.
* Cookies are missing.

Check:

* HTTPS.
* Cookie settings.
* SameSite configuration.
* Domain.
* Reverse proxy headers.
* Keycloak hostname.
* Session timeout configuration.

---

# 18. Token Refresh Problems

Check:

* Refresh token validity.
* Session expiration.
* Client configuration.
* Refresh-token policy.
* Browser/session storage.
* Clock synchronization.

Do not log refresh tokens while troubleshooting.

---

# 19. Email Problems

If Keycloak cannot send email:

Check:

```text
SMTP hostname
SMTP port
SMTP credentials
TLS configuration
Sender address
Network connectivity
Provider restrictions
```

Never print SMTP passwords in logs.

Test:

* Email verification.
* Password reset.
* Security notifications.

---

# 20. Performance Problems

Check:

```text
CPU
Memory
Database connections
Database latency
Disk
Network latency
HTTP latency
Authentication request rate
```

Determine whether the bottleneck is:

```text
Reverse Proxy
      |
Keycloak
      |
PostgreSQL
```

Do not scale infrastructure before identifying the actual bottleneck.

---

# 21. Database Connection Problems

Possible causes:

* PostgreSQL unavailable.
* Connection pool exhausted.
* Incorrect credentials.
* Network failure.
* Database overloaded.
* Too many connections.

Check:

* PostgreSQL health.
* Active connections.
* Connection limits.
* Keycloak configuration.
* Database resource usage.

---

# 22. Disk Space Problems

Low disk space can affect:

* PostgreSQL.
* Docker.
* Logs.
* Backups.
* Keycloak.

Check:

```text
Disk usage
Docker volumes
Container logs
Backup storage
```

Do not delete unknown files or database volumes without understanding their purpose.

---

# 23. Docker Troubleshooting

Useful investigation steps include:

```text
Container status
Container logs
Network inspection
Volume inspection
Health status
Environment configuration
```

Check the dependency order:

```text
PostgreSQL
    |
    v
Keycloak
```

A running container does not necessarily mean the service is healthy.

---

# 24. Production Troubleshooting

Production troubleshooting must prioritize:

1. User impact.
2. Security.
3. Availability.
4. Data integrity.

Do not make risky changes directly in production without understanding their effect.

If possible:

```text
Observe
  |
  v
Reproduce in staging
  |
  v
Prepare fix
  |
  v
Deploy safely
```

---

# 25. Security Incident

If a problem may be security-related:

* Stop making unnecessary configuration changes.
* Preserve logs and evidence.
* Identify potentially compromised credentials.
* Restrict access if necessary.
* Rotate compromised credentials.
* Invalidate affected sessions where appropriate.
* Review administrative activity.
* Follow the incident response procedure.
* Document findings.

Do not treat a security incident as a normal configuration problem.

---

# 26. Troubleshooting Checklist

```text
[ ] Identify affected component
[ ] Check health status
[ ] Check recent changes
[ ] Check logs
[ ] Check network connectivity
[ ] Check configuration
[ ] Check dependencies
[ ] Check resource usage
[ ] Reproduce safely
[ ] Apply smallest safe change
[ ] Validate
[ ] Monitor
[ ] Document root cause
```

---

# 27. Common Anti-Patterns

Do not:

* Delete the PostgreSQL volume to fix startup problems.
* Disable JWT validation.
* Disable HTTPS in production as a permanent workaround.
* Allow all CORS origins to hide a CORS problem.
* Add wildcard redirect URIs to fix redirect errors.
* Print tokens to logs.
* Print passwords to logs.
* Disable authorization checks.
* Modify production configuration without recording the change.
* Upgrade production without a backup.

---

# 28. Root Cause Analysis

After significant incidents, identify:

```text
What happened?
Why did it happen?
Why was it not detected earlier?
What was the impact?
How was it resolved?
How can recurrence be prevented?
```

Document:

* Root cause.
* Contributing factors.
* Timeline.
* Impact.
* Resolution.
* Preventive actions.

---

# 29. Troubleshooting Acceptance Criteria

The troubleshooting process is considered complete when:

* Common infrastructure failures are documented.
* Keycloak startup failures are covered.
* PostgreSQL failures are covered.
* OIDC failures are covered.
* JWT validation failures are covered.
* 401/403 behavior is documented.
* CORS problems are documented.
* TLS problems are documented.
* Session problems are documented.
* Email problems are documented.
* Security incidents have a documented path.
* Troubleshooting avoids unsafe destructive actions.
* Root-cause analysis is documented for significant incidents.
