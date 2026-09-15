# Phase 01 — Local Infrastructure

Build the local Docker infrastructure required to run Keycloak and
PostgreSQL reliably.

---

## Objective

Run Keycloak and PostgreSQL locally using Docker Compose so that
developers can:

- start a complete identity stack with one command
- rely on health checks and restart behavior
- keep database data across container recreation
- avoid committing secrets or database files

This phase creates the runtime foundation. It does not configure realms,
clients, themes, or application integrations.

---

## Architecture

```text
Developer machine
        |
        v
  Docker Compose
        |
        +---- Keycloak
        |
        +---- PostgreSQL
```

### Relationship between services

- **Docker Compose** defines both services, their network, volumes,
  health checks, and dependency order.
- **PostgreSQL** is the sole persistent store for Keycloak state
  (users, clients, sessions metadata, realm config persisted by Keycloak).
- **Keycloak** depends on PostgreSQL being healthy before it starts
  accepting traffic.
- Applications are **not** part of this Compose stack in Phase 01.
  They will consume Keycloak over HTTP(S) in later phases.

---

## Components

| Component | Role |
|-----------|------|
| **Keycloak** | Identity provider; OAuth2/OIDC; admin console |
| **PostgreSQL** | Persistent database for Keycloak only |
| **Docker network** | Private bridge for service-to-service DNS |
| **PostgreSQL named volume** | Survives `docker compose down` (without `-v`) |
| **Health checks** | Gate startup order and readiness signaling |
| **Environment variables** | Inject DB and admin credentials without hardcoding |

No additional microservices are required for local identity runtime.

---

## Docker Compose Requirements

### Service names

Use stable, explicit names, for example:

- `postgres` (or `keycloak-db`)
- `keycloak`

Names should match documentation and scripts.

### Image version strategy

- Pin important image versions (for example `postgres:16.x`, a specific Keycloak release).
- Do **not** use `latest` for production, and avoid `latest` locally when reproducibility matters.
- Record chosen versions in Compose and in docs when they change.

### Restart policy

- Use a restart policy suitable for local development (for example `unless-stopped`)
  so accidental container exits do not silently leave the stack half-dead.

### Health checks

- PostgreSQL: verify the database accepts connections (for example `pg_isready`).
- Keycloak: verify the management/health or HTTP readiness endpoint for the deployed version.
- Keycloak must `depends_on` PostgreSQL with a **healthy** condition, not merely “started”.

### Environment configuration

- Read secrets and environment-specific values from `.env` / Compose `env_file`.
- Keep placeholders in `.env.example`.
- Never bake passwords into the Compose file or Dockerfiles.

### Network

- Place Keycloak and PostgreSQL on the same user-defined Docker network.
- Prefer service DNS names (`postgres`, `keycloak`) for internal URLs.

### Volumes

- Use a **named volume** for PostgreSQL data.
- Do not bind-mount database files into the Git tree.
- Keycloak itself should remain largely ephemeral; state lives in PostgreSQL.

### Dependency ordering

1. PostgreSQL starts and becomes healthy.
2. Keycloak starts and connects to PostgreSQL.
3. Keycloak becomes healthy.

### Port exposure

- Expose Keycloak to the host only as needed for local admin/UI and OIDC
  (commonly `8080` or a documented alternative).
- **Do not unnecessarily publish PostgreSQL to the host.** Internal Docker
  networking is enough for Keycloak. Host exposure of Postgres increases
  accidental external access and credential leakage risk.

---

## Environment Variables

Document and use placeholders such as:

| Variable | Purpose |
|----------|---------|
| `POSTGRES_DB` | Database name used by Keycloak |
| `POSTGRES_USER` | Database user |
| `POSTGRES_PASSWORD` | Database password |
| `KEYCLOAK_ADMIN` | Initial Keycloak admin username |
| `KEYCLOAK_ADMIN_PASSWORD` | Initial Keycloak admin password |
| `KC_DB` / vendor settings | Database vendor (`postgres`) |
| `KC_DB_URL` / host/port/db | JDBC or Keycloak DB connection settings |
| `KC_DB_USERNAME` | Keycloak DB user (often same as Postgres user) |
| `KC_DB_PASSWORD` | Keycloak DB password |

### Rules

- Never include real secrets in documentation or Git.
- `.env.example` may show values like `changeme` or empty placeholders.
- Local `.env` is developer-specific and gitignored.
- Rotate any credential that was ever committed by mistake.

---

## Persistence

- PostgreSQL data **must** survive ordinary container recreation.
- Use Docker **named volumes**, not Git-tracked directories.
- `docker compose down` should keep data; `docker compose down -v` destroys volumes and must be treated as destructive.
- Database dumps for backup/restore belong in operational procedures (later), not in the repo as live DB files.

---

## Networking

```text
Host browser / apps
        |
        | published port (Keycloak only)
        v
   +----------+       Docker network        +-----------+
   | Keycloak | --------------------------> | PostgreSQL|
   +----------+   (service DNS, private)    +-----------+
```

- **Internal communication:** Keycloak connects to PostgreSQL using the
  Compose service hostname and internal port `5432`.
- **External access:** Developers reach Keycloak via localhost and the
  published HTTP port.
- **Why PostgreSQL stays private:** Only Keycloak needs the database.
  Publishing Postgres invites misconfiguration, weak host firewall
  assumptions, and accidental exposure of credentials.

---

## Health Checks

### PostgreSQL

Expected behavior:

- Health check succeeds when the server accepts connections for the configured user/database.
- Unhealthy status blocks Keycloak startup via Compose dependency conditions.

### Keycloak

Expected behavior:

- Health/readiness check succeeds only after Keycloak has started and can serve basic HTTP.
- Prefer the official health endpoints appropriate to the pinned Keycloak version.
- Do not mark Keycloak healthy merely because the process started.

---

## Startup Flow

```text
PostgreSQL starts
        |
        v
PostgreSQL becomes healthy
        |
        v
Keycloak starts
        |
        v
Keycloak connects to PostgreSQL
        |
        v
Keycloak becomes healthy
```

Failure at any step should be visible via `docker compose ps` and service logs.

---

## Tasks

- [x] Create `docker-compose.yml` with `postgres` and `keycloak` services
- [x] Pin image versions (no `latest`)
- [x] Configure shared Docker network
- [x] Configure PostgreSQL named volume
- [x] Wire environment variables from `.env` / `.env.example`
- [x] Configure Keycloak DB connection to PostgreSQL over the Docker network
- [x] Add PostgreSQL health check
- [x] Add Keycloak health check
- [x] Set `depends_on` with healthy condition for Keycloak → PostgreSQL
- [x] Publish Keycloak port to host; keep PostgreSQL unpublished unless there is a documented local debugging need
- [x] Set restart policies
- [x] Add Makefile targets: `up`, `down`, `logs`, `ps` (optional but recommended)
- [x] Document how to start, stop, and reset (including volume destroy warning)
- [x] Verify `.gitignore` excludes `.env` and does not track volume data

---

## Testing

| Test | Expected result |
|------|-----------------|
| `docker compose config` | Valid configuration; no unresolved required vars |
| Container startup | Both services reach running state |
| Container health | Both report healthy |
| Database connectivity | Keycloak logs show successful DB connection; no repeated auth failures |
| Keycloak availability | Admin console / HTTP endpoint responds on published port |
| Restart test | `docker compose restart` returns stack to healthy |
| Persistence test | Create a marker (for example admin login or realm later); recreate containers **without** `-v`; data remains |
| Destructive reset awareness | Document that `down -v` wipes DB volume |

Suggested commands (illustrative):

```bash
docker compose config
docker compose up -d
docker compose ps
docker compose logs keycloak
curl -sf http://localhost:<keycloak-port>/  # or health URL for pinned version
```

---

## Troubleshooting

| Symptom | Likely causes | What to check |
|---------|---------------|---------------|
| Database connection failure | Wrong host/user/password/db name; Keycloak started before Postgres healthy | Env vars, `depends_on`, Postgres logs |
| Port conflict | Host port already in use | Change published Keycloak port; `ss`/`lsof` |
| Invalid credentials | `.env` mismatch vs Compose expectations | Compare `.env` to `.env.example`; recreate if DB initialized with old password |
| Unhealthy containers | Failing healthcheck command/path | Healthcheck syntax, Keycloak version endpoints, DB readiness |
| Volume problems | Accidental `-v`, wrong volume name, permissions | `docker volume ls`, Compose volume definition |
| Keycloak startup failure | DB unreachable, bad KC_* settings, insufficient memory | Full Keycloak logs, resource limits |

---

## Acceptance Criteria

1. `docker compose up -d` starts PostgreSQL and Keycloak successfully.
2. Health checks report both services healthy.
3. Keycloak persists state in PostgreSQL via a named volume.
4. Recreating containers without removing volumes retains data.
5. PostgreSQL is not published to the host without an explicit, documented reason.
6. Image tags are pinned.
7. Secrets come from environment files, not committed source.
8. Startup order waits for PostgreSQL health before Keycloak.
9. Basic HTTP access to Keycloak from the host works.
10. Troubleshooting notes cover the common failure modes above.

---

## Deliverables

- `docker-compose.yml` (created in implementation; specified here)
- `.env.example` with required variable names
- gitignored `.env` for local secrets
- Named PostgreSQL volume configuration
- Health checks and dependency ordering
- Short runbook section in root or ops docs for start/stop/reset
- Evidence of persistence and health tests

---

## Security Considerations

- Do not commit `.env`.
- Do not log passwords.
- Prefer not exposing PostgreSQL on the host.
- Use strong local passwords even in development to avoid bad habits.
- Admin credentials grant full control of the IdP; treat them carefully on shared machines.

---

## Dependencies

**Requires:** Phase 00 (foundation, secrets policy, structure).

**Unblocks:** Phase 02 (Keycloak realm/client configuration against a running instance).

---

## Completion Criteria

Phase 01 is complete when a developer can clone the repo, copy
`.env.example` to `.env`, fill placeholders, run Compose, observe healthy
Keycloak + PostgreSQL, and confirm data survives container recreation —
without committing secrets or database files.

**Realm and client configuration belongs in Phase 02, not this phase.**
