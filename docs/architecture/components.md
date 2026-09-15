# Components

## Keycloak

Central identity provider.

Responsibilities:

- Authentication
- OAuth2
- OpenID Connect
- User management
- Roles
- Groups
- MFA
- Identity providers

## PostgreSQL

Persistent database used by Keycloak.

PostgreSQL is not directly accessed by application projects.

## Reverse Proxy

The reverse proxy provides:

- HTTPS termination
- Public routing
- Security headers
- Request forwarding

## Applications

Applications consume Keycloak through standard OAuth2/OIDC protocols.

Applications must not access Keycloak's database directly.

## Future Components

Potential future infrastructure:

- Monitoring
- Centralized logging
- Secret manager
- Backup storage
- Redis if required
- Kubernetes