# Production Deployment Guide

Deploy Keycloak securely behind HTTPS and a reverse proxy.

Related: [../phases/07-production.md](../phases/07-production.md)

Conceptual issuer host: **`auth.example.com`** (replace per environment).

---

## Architecture

```text
Internet → DNS → Reverse Proxy (TLS) → Keycloak → PostgreSQL (private)
```

| Component | Role |
|-----------|------|
| DNS | `auth.example.com` → edge |
| Reverse proxy | TLS, routing, headers, limits |
| Keycloak | Identity provider (`start` — not `start-dev`) |
| PostgreSQL | Private; backups; strong secrets |

Kubernetes is **not** required. A single VM + Compose/proxy is acceptable early production.

---

## Environment hostnames

| Environment | Example issuer |
|-------------|----------------|
| local | `http://localhost:8080/realms/platform` |
| staging | `https://auth.staging.example.com/realms/platform` |
| production | `https://auth.example.com/realms/platform` |

Issuer URLs must stay stable — changing them breaks all clients.

---

## HTTPS and cookies

- Terminate TLS at the reverse proxy (trusted CA or ACME).
- Redirect HTTP → HTTPS.
- Enable automatic certificate renewal.
- Use `Secure` cookies once HTTPS is on.
- Never disable TLS or certificate validation in production.

---

## Reverse proxy

Keycloak must trust the proxy:

| Setting | Guidance |
|---------|----------|
| Forwarded headers | `X-Forwarded-Proto`, `X-Forwarded-For`, `X-Forwarded-Host` |
| Hostname | Match public URL (`KC_HOSTNAME`, `KC_PROXY_HEADERS=xforwarded`) |
| Trusted proxies | Only the proxy network |
| Admin console | Restrict (VPN / IP allow list) |
| Limits | Reasonable body size and rate limits |

Example nginx config (TLS paths are environment-specific — do not commit private keys):

See [`nginx/conf.d/keycloak.conf.example`](../../nginx/conf.d/keycloak.conf.example).

---

## Database

Production PostgreSQL must:

- Not be internet-reachable
- Use secret-manager credentials
- Have automated backups with tested restore ([backup.md](../operations/backup.md), [restore.md](../operations/restore.md))
- Prefer TLS to the database where available
- Be monitored (disk, connections, availability)

Applications never connect to the Keycloak database.

---

## Secrets

Never store production secrets in Git.

| Secret | Storage |
|--------|---------|
| DB / admin / client / SMTP / TLS keys | Secret manager or restricted host store |

---

## Firewall (minimum)

| Path | Exposure |
|------|----------|
| 443 → proxy | Public |
| Keycloak HTTP | Private to proxy |
| PostgreSQL 5432 | Private to Keycloak / DBA path |
| SSH | Bastion / VPN |

---

## Scaling and HA

- Prefer a well-run single Keycloak node early.
- Horizontal Keycloak needs shared DB and correct cache/session settings.
- HA is a business decision — document RTO/RPO with stakeholders ([../phases/08-reusability.md](../phases/08-reusability.md)).

---

## Deployment flow

```text
Validate config → Deploy → Health checks → OIDC discovery smoke test
→ App login smoke test → Monitor → Rollback plan ready
```

Use pinned image tags (never `latest` in production). Prefer `keycloak start` (production mode), not `start-dev`.

---

## Acceptance checklist

- [ ] HTTPS issuer URL stable and documented
- [ ] Proxy headers / hostname correct
- [ ] PostgreSQL private + backed up
- [ ] Secrets outside Git
- [ ] Minimal firewall exposure
- [ ] Health checks and rollback documented
- [ ] At least one app completes login against production issuer
- [ ] Admin console access controlled
- [ ] Images pinned

```bash
make validate-production-docs
```
