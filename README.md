# Keycloak Platform

A reusable Identity and Access Management (IAM) platform based on
[Keycloak](https://www.keycloak.org/). It provides centralized
authentication and identity services for multiple independent
applications using standard OAuth 2.0 and OpenID Connect.

## What this is

- **Keycloak** handles identity, authentication, sessions, MFA, and
  coarse-grained roles.
- **Applications** handle business authorization and resource ownership.
- **PostgreSQL** stores Keycloak state (not application data).

This repository is the platform itself — not an example application.

## Documentation

Start here: [docs/README.md](docs/README.md)

| Area | Description |
|------|-------------|
| [Architecture](docs/architecture/overview.md) | System design and components |
| [Phases](docs/phases/00-foundation.md) | Incremental implementation plan |
| [Security](docs/security/security-model.md) | Security model and token strategy |
| [Operations](docs/operations/backup.md) | Backup, restore, upgrades |

Implementation follows numbered phases (`00`–`08`). Each phase has
objectives, tasks, and acceptance criteria before the next begins.

## Repository structure

```text
.
├── .cursor/rules/       Engineering constraints for humans and agents
├── config/              Declarative, non-secret configuration
├── docs/                Architecture, phases, security, operations
├── keycloak/            Realm imports, themes, providers (Phase 02+)
├── scripts/             Operational helper scripts
├── docker-compose.yml   Local infrastructure (Phase 01+)
├── .env.example         Required variable names (safe placeholders)
├── .env                 Local secrets (gitignored — create from example)
├── Makefile             Common developer commands
└── README.md
```

## Getting started (local)

**Phase 00 (foundation)** establishes structure, secrets policy, and
documentation. **Phase 01** adds Docker Compose for Keycloak and
PostgreSQL.

```bash
cp .env.example .env
# Edit .env — replace changeme placeholders with strong local passwords

make config                  # Validate Compose configuration
make up                      # Start Keycloak and PostgreSQL
make ps                      # Check service status
make health                  # Verify both services are healthy
make validate-infrastructure # Full Phase 01 checks (stack must be up)
make logs                    # Follow logs
make down                    # Stop services (data retained)
make reset                   # Stop and wipe database volume (destructive)
```

Keycloak admin console: `http://localhost:8080/` (or `KEYCLOAK_HTTP_PORT` from `.env`).

**Warning:** `make reset` runs `docker compose down -v` and destroys all
Keycloak data in the local PostgreSQL volume.

Validate the foundation at any time:

```bash
make validate-foundation
```

## Environments

| Environment | Purpose |
|-------------|---------|
| **local** | Developer machines; Docker Compose |
| **staging** | Pre-production validation |
| **production** | Live identity provider (Phase 07+) |

Secrets for each environment stay out of Git. Use `.env` locally and a
secret manager in staging/production.

## Engineering principles

- Simplicity and reproducibility over unnecessary complexity
- Standard OAuth 2.0 / OpenID Connect — no custom auth protocols
- Least privilege for clients, roles, and network exposure
- Explicit redirect URIs — no wildcard redirects in production
- Documentation tracks real behavior

See [.cursor/rules/](.cursor/rules/) for persistent project constraints.

## License

Add license information when the project owner defines it.
