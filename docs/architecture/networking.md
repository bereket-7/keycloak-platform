# Networking Architecture

## 1. Purpose

This document defines the networking architecture for the centralized Keycloak identity platform.

The goals are to:

* Provide a clear network model for local development, staging, and production.
* Keep internal infrastructure private wherever possible.
* Expose only the services that require external access.
* Establish consistent connectivity between Keycloak, PostgreSQL, reverse proxies, and future applications.
* Define the expected authentication traffic flow.
* Provide a foundation for secure production deployment.
* Make the platform reusable across multiple applications.

The networking architecture must support the principle:

> **Public traffic enters through a controlled edge, while internal infrastructure remains private.**

---

# 2. High-Level Architecture

The platform consists of the following logical components:

```text
                        Internet
                           |
                           |
                     DNS / Domain
                           |
                           v
                  +------------------+
                  |  Reverse Proxy   |
                  | HTTPS / TLS      |
                  +------------------+
                           |
                           | HTTPS
                           v
                  +------------------+
                  |    Keycloak      |
                  | Identity Provider|
                  +------------------+
                           |
                           | PostgreSQL
                           v
                  +------------------+
                  |   PostgreSQL     |
                  |   Keycloak DB    |
                  +------------------+
```

Keycloak is the central identity provider.

PostgreSQL stores Keycloak's persistent state.

The reverse proxy is the public entry point in production and is responsible for terminating TLS and forwarding valid requests to Keycloak.

PostgreSQL must not be directly accessible from the public internet.

---

# 3. Network Boundaries

The platform should be designed around explicit network boundaries.

## Public Network

The public network is the internet-facing portion of the platform.

Only services that intentionally provide public functionality should be exposed here.

In production, this normally means:

* DNS
* HTTPS
* Reverse proxy
* Keycloak HTTP/HTTPS endpoint through the reverse proxy

PostgreSQL must not be exposed publicly.

## Application Network

Applications using the identity platform may run separately from Keycloak.

For example:

```text
Project A
Project B
Project C
     |
     | OIDC
     v
Keycloak
```

Applications do not need direct access to PostgreSQL.

Applications communicate with Keycloak through its public or internally routable OIDC endpoints depending on the deployment architecture.

## Internal Infrastructure Network

Internal infrastructure contains services that should not be directly accessible from the internet.

Example:

```text
+---------------------------+
| Internal Network          |
|                           |
|   +---------+             |
|   | Keycloak|             |
|   +----+----+             |
|        |                  |
|        v                  |
|   +----------+            |
|   |PostgreSQL|            |
|   +----------+            |
|                           |
+---------------------------+
```

PostgreSQL belongs exclusively to the internal infrastructure network.

---

# 4. Local Development Networking

Local development uses Docker Compose.

The initial local architecture is:

```text
                    Developer
                        |
                        |
                  localhost
                        |
                        v
               +----------------+
               |    Keycloak    |
               |     :8080      |
               +-------+--------+
                       |
                       | Docker network
                       |
                       v
               +----------------+
               |   PostgreSQL   |
               |      :5432     |
               +----------------+
```

Docker Compose creates an isolated network for the platform.

Example logical service names:

```text
keycloak
postgres
```

Keycloak connects to PostgreSQL using the Docker service name rather than `localhost`.

For example:

```text
postgres:5432
```

Inside the Docker network:

* `keycloak` can resolve `postgres`.
* PostgreSQL accepts connections from Keycloak.
* PostgreSQL does not need to be exposed to the host.
* Keycloak exposes its development port to the developer's machine.

---

# 5. Docker Network

The Docker Compose environment should use a dedicated application network.

Conceptually:

```text
platform-network
       |
       +---- keycloak
       |
       +---- postgres
```

The network provides service-to-service communication without requiring services to communicate through host networking.

Services should use Docker DNS/service discovery.

For example:

```text
Keycloak
   |
   | postgres:5432
   v
PostgreSQL
```

Do not configure Keycloak to connect to:

```text
localhost:5432
```

because `localhost` inside the Keycloak container refers to the Keycloak container itself.

---

# 6. Port Exposure

Ports should be exposed only when necessary.

## Local Development

Keycloak may expose a development port such as:

```text
localhost:8080
```

This allows developers to access:

```text
http://localhost:8080
```

PostgreSQL should normally remain internal to Docker.

Preferred:

```text
Developer
    |
    v
localhost:8080
    |
    v
Keycloak
    |
    v
PostgreSQL:5432
```

Avoid unnecessarily exposing:

```text
localhost:5432
```

If database access from the host is required for development or debugging, it should be an intentional development-only configuration.

## Production

Production should expose only the required public HTTPS endpoint.

For example:

```text
Internet
   |
   v
443
   |
   v
Reverse Proxy
   |
   v
Keycloak
```

PostgreSQL should not have a public port exposed.

---

# 7. Production Networking

The production architecture should follow this model:

```text
                         Internet
                            |
                            v
                     +-------------+
                     |     DNS     |
                     +------+------+
                            |
                            v
                     +-------------+
                     |   Firewall  |
                     +------+------+
                            |
                            v
                  +-------------------+
                  |   Reverse Proxy   |
                  |    HTTPS / TLS    |
                  +---------+---------+
                            |
                            | HTTP/HTTPS
                            v
                  +-------------------+
                  |     Keycloak      |
                  +---------+---------+
                            |
                            | PostgreSQL
                            v
                  +-------------------+
                  |    PostgreSQL     |
                  |   Private Network |
                  +-------------------+
```

The reverse proxy acts as the public boundary.

Keycloak should not require PostgreSQL to be internet-accessible.

---

# 8. DNS

Production Keycloak should use a stable domain.

A conceptual example is:

```text
auth.example.com
```

The domain represents the centralized identity service.

Applications can then use the same issuer:

```text
https://auth.example.com/...
```

The exact production domain is environment-specific and must not be hardcoded into application source code.

Recommended environment model:

```text
Development:
http://localhost:8080

Staging:
https://auth-staging.example.com

Production:
https://auth.example.com
```

The actual domains should be provided through environment-specific configuration.

---

# 9. HTTPS and TLS

Production authentication traffic must use HTTPS.

The expected flow is:

```text
Browser
   |
   | HTTPS
   v
Reverse Proxy
   |
   | internal connection
   v
Keycloak
```

TLS certificates should be managed at the production edge.

The reverse proxy is responsible for:

* TLS termination
* Certificate handling
* HTTPS enforcement
* Secure forwarding to Keycloak
* Forwarded request metadata

Authentication endpoints must never rely on plaintext HTTP in production.

HTTP may be acceptable for local development where the environment is isolated and no real credentials or production data are being used.

---

# 10. Reverse Proxy

The reverse proxy is the controlled entry point to Keycloak in production.

Responsibilities include:

* Accepting incoming HTTPS connections.
* Terminating TLS.
* Forwarding requests to Keycloak.
* Preserving required forwarded headers.
* Enforcing request limits where appropriate.
* Preventing unintended direct exposure of internal services.
* Supporting certificate renewal.
* Optionally providing access logging and metrics.

Conceptually:

```text
Client
  |
  | HTTPS
  v
Reverse Proxy
  |
  | Internal HTTP/HTTPS
  v
Keycloak
```

The reverse proxy must be configured consistently with Keycloak's hostname and proxy settings.

Incorrect proxy configuration can cause issues with:

* Redirect URLs
* Issuer URLs
* Cookies
* OIDC discovery
* Browser authentication flows
* Logout
* Secure session handling

---

# 11. Forwarded Headers

When Keycloak is behind a reverse proxy, the original request information may need to be forwarded.

Typical information includes:

```text
Host
X-Forwarded-Host
X-Forwarded-Proto
X-Forwarded-For
```

The exact headers and configuration depend on the selected reverse proxy and Keycloak deployment model.

The platform must ensure that Keycloak correctly understands:

* Original hostname
* Original protocol
* Client IP information where required

Forwarded headers must only be trusted from known and controlled proxies.

The system must not blindly trust client-supplied forwarding headers.

---

# 12. Keycloak to PostgreSQL Networking

Keycloak communicates with PostgreSQL over the internal network.

```text
Keycloak
    |
    | TCP 5432
    v
PostgreSQL
```

PostgreSQL should accept connections only from authorized application infrastructure.

At minimum:

```text
Internet
    X
    |
PostgreSQL
```

There should be no direct internet route to PostgreSQL.

The database hostname and connection configuration should be provided through environment-specific configuration.

Example:

```text
DB_HOST=postgres
DB_PORT=5432
```

Actual credentials must never be committed to Git.

---

# 13. Application to Keycloak Networking

Future applications authenticate users through Keycloak.

A typical browser-based flow is:

```text
User
 |
 | 1. Open application
 v
Frontend
 |
 | 2. Redirect to Keycloak
 v
Keycloak
 |
 | 3. Authenticate user
 |
 | 4. Return authorization result
 v
Frontend
 |
 | 5. Call backend API
 v
Backend
 |
 | 6. Validate access token
 v
Keycloak JWKS / configured identity metadata
```

The application backend does not need direct access to the Keycloak database.

It should communicate with Keycloak through standard OAuth2/OIDC mechanisms.

---

# 14. Authentication Traffic

The platform should use standard OAuth2/OIDC endpoints.

Applications should discover the provider configuration using the OIDC discovery mechanism rather than hardcoding individual endpoints whenever practical.

The conceptual flow is:

```text
Application
     |
     | OIDC
     v
Keycloak
     |
     | Authentication
     v
User
```

For API authentication:

```text
Client
   |
   | Authorization: Bearer <token>
   v
Backend API
   |
   | Validate token
   v
Authorization decision
```

The backend should validate tokens locally using the issuer's signing keys where appropriate.

The backend should not query PostgreSQL for authentication.

---

# 15. JWKS and Token Validation

Keycloak publishes signing keys through its OIDC metadata/JWKS mechanisms.

Backend applications can use these keys to validate JWT signatures.

Conceptually:

```text
Keycloak
   |
   | OIDC metadata / JWKS
   v
Backend
   |
   | validates JWT
   v
Authorized request
```

The backend should validate at least:

* JWT signature
* Issuer
* Expiration
* Not-before where applicable
* Audience where applicable
* Required scopes
* Required roles

Token validation configuration must be environment-specific.

---

# 16. Network Security Principles

The following principles apply to all environments.

### Principle 1 — Default deny

Network access should be denied unless explicitly required.

### Principle 2 — Minimize exposed ports

Only required public services should expose public ports.

### Principle 3 — Keep databases private

PostgreSQL must never be directly exposed to the public internet.

### Principle 4 — Separate environments

Development, staging, and production should have independent infrastructure and configuration.

### Principle 5 — Encrypt authentication traffic

Production authentication traffic must use HTTPS.

### Principle 6 — Do not trust the client

Network visibility or frontend behavior must never be treated as authorization.

Authorization must be enforced by the backend.

### Principle 7 — Do not expose internal services unnecessarily

Services should communicate through private networks whenever possible.

### Principle 8 — Secrets are configuration

Passwords, client secrets, certificates, and other sensitive values must not be stored in source code.

---

# 17. Environment Networking

The platform should support separate network configurations for:

```text
Development
     |
     v
Local Docker Network

Staging
     |
     v
Private/Staging Infrastructure

Production
     |
     v
Production Private Network
```

Environment-specific values include:

* Keycloak hostname
* Database hostname
* Database credentials
* Public ports
* TLS configuration
* Reverse proxy configuration
* Client redirect URIs
* Web origins
* Allowed network ranges

Application source code should not contain environment-specific infrastructure addresses.

---

# 18. Network Flow Summary

## Local

```text
Developer
    |
    | localhost:8080
    v
Keycloak Container
    |
    | platform Docker network
    v
PostgreSQL Container
```

## Production

```text
User
 |
 | HTTPS :443
 v
DNS
 |
 v
Firewall / Load Balancer
 |
 v
Reverse Proxy
 |
 | internal network
 v
Keycloak
 |
 | private database connection
 v
PostgreSQL
```

## Application Authentication

```text
User
 |
 v
Application
 |
 | OIDC
 v
Keycloak
 |
 | authentication
 v
User
 |
 | authorization result / tokens
 v
Application
 |
 v
Backend API
 |
 | JWT validation
 v
Business Authorization
```

---

# 19. Failure Scenarios

The networking architecture should account for common failures.

## PostgreSQL unavailable

Expected behavior:

```text
Keycloak
   X
   |
PostgreSQL
```

Keycloak may fail to start or become unhealthy depending on the failure state.

The deployment system should detect the unhealthy dependency.

## Keycloak unavailable

Applications cannot perform new authentication flows.

Existing application behavior depends on token/session lifetime and application design.

Applications should not treat Keycloak database access as a fallback mechanism.

## Reverse proxy unavailable

Public access to Keycloak becomes unavailable even if Keycloak itself is healthy.

Monitoring should distinguish between:

* Reverse proxy failure
* Keycloak failure
* PostgreSQL failure

## DNS failure

Clients cannot resolve the Keycloak hostname.

Production monitoring should therefore include external DNS and endpoint checks.

---

# 20. Health Checks

Each infrastructure component should expose an appropriate health signal.

At minimum, the deployment should be able to determine:

```text
PostgreSQL
    |
    +--> Healthy / Unhealthy

Keycloak
    |
    +--> Healthy / Unhealthy

Reverse Proxy
    |
    +--> Healthy / Unhealthy
```

Health checks should verify actual service availability rather than only checking whether a process is running.

For example:

```text
Container running
        !=
Application healthy
```

Health checks must be suitable for the specific Keycloak and PostgreSQL versions used by the project.

---

# 21. Observability

Network and infrastructure monitoring should provide enough information to diagnose failures without exposing sensitive authentication data.

Useful signals include:

* Request availability
* HTTP error rates
* Response latency
* Connection failures
* PostgreSQL connection health
* Keycloak health
* Reverse proxy health
* TLS certificate expiration
* Resource utilization
* Network connectivity

Logs must not contain:

* Passwords
* Access tokens
* Refresh tokens
* Client secrets
* Session credentials

---

# 22. Scalability Considerations

The initial architecture is intentionally simple:

```text
Reverse Proxy
      |
   Keycloak
      |
 PostgreSQL
```

As usage grows, the architecture can evolve toward:

```text
                    Internet
                       |
                       v
                Load Balancer
                       |
             +---------+---------+
             |                   |
             v                   v
         Keycloak             Keycloak
             |                   |
             +---------+---------+
                       |
                       v
                 PostgreSQL
```

Keycloak instances should remain stateless from the application's perspective, while persistent identity data remains in PostgreSQL.

Scaling decisions must consider:

* Database capacity
* Session behavior
* Cache behavior
* Load balancing
* Health checks
* TLS termination
* Monitoring
* Backup and recovery
* Keycloak clustering requirements

High availability should not be introduced until the operational requirements justify the additional complexity.

---

# 23. Network Configuration Rules

The following rules are mandatory architectural guidelines:

1. PostgreSQL must remain private.
2. Production authentication endpoints must use HTTPS.
3. Production traffic should enter through a controlled reverse proxy or equivalent edge.
4. Internal services should communicate through private networks.
5. Development and production networking must remain separate.
6. Environment-specific hostnames must be configurable.
7. No production configuration should depend on `localhost`.
8. Public ports must be explicitly justified.
9. Forwarded headers must only be trusted from controlled proxies.
10. Authentication and authorization must not depend on network location alone.
11. Secrets must not be embedded in Dockerfiles, source code, or committed configuration.
12. Network logs must not expose authentication credentials or tokens.

---

# 24. Architecture Decision

The platform adopts the following networking model:

```text
                    PUBLIC
                      |
                   HTTPS
                      |
                      v
              Reverse Proxy
                      |
                PRIVATE NETWORK
                      |
                      v
                  Keycloak
                      |
                PRIVATE NETWORK
                      |
                      v
                 PostgreSQL
```

This architecture provides a clear separation between:

* Public access
* Identity services
* Persistent infrastructure

It also provides a reusable foundation for connecting multiple future applications to a single centralized identity platform.

The initial implementation should prioritize simplicity and correctness. More advanced networking such as load balancing, multi-node Keycloak, multi-region deployment, service meshes, or complex network segmentation should only be introduced when actual operational requirements justify them.
