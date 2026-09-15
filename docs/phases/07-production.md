# Phase 07 — Production Deployment

Move the platform from local development to secure production
infrastructure.

---

## Objective

Deploy Keycloak securely behind HTTPS and a reverse proxy so that
multiple applications can rely on a stable, hardened issuer.

Docker Compose remains the local development approach. Production may
use Compose on a single host initially or another boring deployment
model; **Kubernetes is not required** unless operational needs demand it.

---

## Architecture

```text
Internet
   |
  DNS
   |
Reverse Proxy
   |
 HTTPS
   |
Keycloak
   |
PostgreSQL
```

| Component | Production role |
|-----------|-----------------|
| DNS | Points `auth.example.com` (or real domain) to the edge |
| Reverse proxy | TLS termination, routing, headers, request limits |
| Keycloak | Identity provider |
| PostgreSQL | Private persistence; not internet-facing |

---

## Domain

Use a conceptual issuer host:

```text
auth.example.com
```

Real domains are environment-specific, for example:

- local: `localhost` / documented port
- staging: `auth.staging.example.com`
- production: `auth.example.com`

The OIDC issuer URL must be stable. Changing issuer hostnames breaks
token validation for all clients.

---

## HTTPS

Requirements:

- TLS for all public Keycloak traffic
- Certificates from a trusted CA (or automated ACME)
- Automatic renewal where possible
- HTTP to HTTPS redirect at the proxy
- Secure cookies (`Secure`, appropriate `SameSite`) once HTTPS is enabled
- Do **not** disable TLS or certificate validation in production

---

## Reverse Proxy

Configure Keycloak to trust the proxy correctly:

| Concern | Guidance |
|---------|----------|
| Forwarded headers | `X-Forwarded-Proto`, `X-Forwarded-For`, `X-Forwarded-Host` (or equivalent) |
| Hostname | Keycloak hostname settings must match public URL |
| Trusted proxies | Only trust headers from the real proxy network |
| Request limits | Body size and rate limits appropriate to auth traffic |
| Admin console | Restrict exposure (VPN, IP allow list, or separate admin path policy) |

Misconfigured proxy headers cause incorrect redirect URIs, mixed content,
and broken OIDC callbacks.

---

## Database

Production PostgreSQL must:

- **not** be publicly accessible on the internet
- use strong, unique credentials stored in a secret manager
- have automated backups with tested restore
- use encrypted connections where appropriate (`sslmode` / TLS to DB)
- have monitoring (availability, disk, connections, replication if used)

Application databases are separate. Applications never connect to the
Keycloak database.

---

## Secrets

| Secret | Storage |
|--------|---------|
| DB passwords | Secret manager / platform secrets — **not Git** |
| Keycloak admin credentials | Secret manager; tightly controlled |
| Client secrets | Secret manager; per environment |
| SMTP credentials | Secret manager |
| TLS private keys | Proxy/secret store; restricted filesystem permissions |

Never store production secrets in Git, Docker images, or chat logs.

---

## Firewall

Minimum exposure:

| Path | Exposure |
|------|----------|
| `443` to reverse proxy | Public |
| Keycloak HTTP port | Private to proxy network only |
| PostgreSQL `5432` | Private to Keycloak (and DBA access path) only |
| SSH/admin | Restricted bastion/VPN |

Do not expose PostgreSQL “temporarily” to the world for convenience.

---

## Scaling

Discuss scaling only as needed:

| Area | Guidance |
|------|----------|
| Keycloak horizontal scaling | Possible with shared DB and correct cache/session settings; add only under load |
| Database scaling | Vertical first; managed PostgreSQL if available |
| Sessions | Understand sticky sessions / cache requirements before multi-node |
| Load balancing | Terminate TLS at proxy; balance to Keycloak nodes when scaled |

Do **not** introduce distributed infrastructure unless required by
availability or load. A well-run single Keycloak node behind a proxy is
acceptable early production for many platforms.

---

## High Availability

HA is a business decision:

- Active/passive or multi-node Keycloak + highly available PostgreSQL increases complexity.
- Document RTO/RPO expectations with stakeholders (see Phase 08).
- Prefer proven backups and fast restore over premature multi-region designs.

Tradeoff: more nodes reduce downtime risk but increase configuration and
failure-mode complexity.

---

## Deployment Strategy

```text
Validate config
    ->
Deploy/restart Keycloak + dependencies
    ->
Health checks pass
    ->
Smoke-test OIDC discovery + login
    ->
Validate critical apps
    ->
Monitor
```

| Practice | Requirement |
|----------|-------------|
| Health checks | Proxy and orchestrator use Keycloak/DB health |
| Rollback | Prior image/config retained; DB migration awareness |
| Migrations | Keycloak upgrades may migrate schema — backup first |
| Config validation | Hostname, proxy, TLS, issuer URL verified pre-cutover |

---

## Tasks

- [ ] Choose production host/runtime (single VM + proxy is acceptable)
- [ ] Provision DNS for auth hostname
- [ ] Deploy reverse proxy with TLS and renewals
- [ ] Configure Keycloak hostname and trusted proxy settings
- [ ] Place PostgreSQL on private network with strong secrets
- [ ] Configure backups and monitoring
- [ ] Move secrets to secret manager
- [ ] Restrict admin console exposure
- [ ] Update client redirect URIs for production domains
- [ ] Run production smoke tests (discovery, login, logout, token validate)
- [ ] Document rollback steps

---

## Testing

| Test | Expected |
|------|----------|
| HTTPS | `https://auth.example.com` serves valid cert |
| HTTP redirect | HTTP upgrades to HTTPS |
| Discovery | OIDC discovery returns correct `issuer` with https |
| Login | End-user login succeeds through proxy |
| Callback | Redirect URIs work with https origins |
| DB isolation | Postgres port not reachable from internet |
| Backup restore drill | Restore succeeds in non-prod or controlled window |
| Health | Unhealthy instances removed/alerted |

---

## Acceptance Criteria

Production readiness requires:

1. Public access only via HTTPS on the auth domain.
2. Reverse proxy correctly forwards protocol/host to Keycloak.
3. PostgreSQL is private and backed up.
4. Secrets are not in Git.
5. Firewall/network exposure is minimal.
6. Health checks and rollback steps are documented.
7. At least one real or representative application completes login against production issuer.
8. Image versions are pinned (no `latest`).
9. Admin access is controlled.

---

## Deliverables

- Production architecture diagram (as-built)
- Proxy + TLS configuration (without private keys in Git)
- Secret management procedure
- Backup/restore linkage to operations docs
- Deployment and rollback runbook
- Production smoke-test checklist

---

## Dependencies

**Requires:** Phases 01–06 locally proven; authorization and integration contracts understood.

**Unblocks:** Phase 08 multi-app reusability in real environments.

---

## Completion Criteria

Phase 07 is complete when Keycloak is reachable at a stable HTTPS issuer
URL behind a reverse proxy, PostgreSQL is private and backed up, secrets
are managed outside Git, and login works for integrating applications
with a documented rollback path.

**Do not treat local Compose settings as production by merely opening ports.**
