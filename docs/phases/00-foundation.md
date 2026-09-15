# Phase 00 — Foundation

Establish the repository structure, engineering standards, documentation
conventions, development workflow, and project rules before implementing
infrastructure.

---

## Objective

This phase establishes the foundation for a reusable Keycloak-based
Identity and Access Management (IAM) platform.

The goal is not to run Keycloak yet. The goal is to make subsequent
phases predictable, secure, and consistent by defining:

- how the repository is organized
- how decisions are constrained (Cursor rules)
- how documentation is structured
- how environments and secrets are handled
- how Git and day-to-day development work

A strong foundation reduces configuration drift, accidental secret
commits, and architectural inconsistency across future applications.

---

## Scope

This phase covers:

- Repository structure
- Cursor rules
- Documentation layout and conventions
- Environment configuration strategy
- Git strategy
- Development workflow
- Engineering principles

This phase does **not** cover:

- Docker Compose implementation
- Keycloak realm/client configuration
- Application integration code
- Production deployment

---

## Project Structure

Expected high-level repository layout:

```text
.
├── .cursor/
│   └── rules/                 # Always-on engineering constraints
├── docs/
│   ├── README.md
│   ├── architecture/
│   ├── phases/
│   ├── security/
│   └── operations/
├── config/                    # Declarative, non-secret configuration
├── keycloak/                  # Realm themes, import artifacts, providers
├── scripts/                   # Operational helper scripts
├── docker-compose.yml         # Local infrastructure (Phase 01+)
├── .env                       # Local secrets (never committed)
├── .env.example               # Documented placeholder values
├── .gitignore
├── README.md
└── Makefile                   # Common developer commands
```

### Structure rules

| Path | Purpose | Committed? |
|------|---------|------------|
| `.cursor/rules/` | Persistent AI/engineering constraints | Yes |
| `docs/` | Architecture, phases, security, operations | Yes |
| `config/` | Environment-aware non-secret config | Yes |
| `keycloak/` | Reproducible Keycloak artifacts | Yes (no secrets) |
| `scripts/` | Backup, health, import helpers | Yes |
| `docker-compose.yml` | Local service definitions | Yes |
| `.env.example` | Required variable names and safe examples | Yes |
| `.env` | Real local credentials | **No** |
| PostgreSQL data / Docker volumes | Persistent DB state | **No** |

Database files must never be committed to Git. Persistence belongs in
Docker named volumes (Phase 01), not in the repository.

---

## Cursor Rules

Cursor rules encode non-negotiable project constraints so that humans
and agents make consistent decisions.

| Rule | Purpose |
|------|---------|
| `00-project.mdc` | Overall product goals: secure, reproducible, Docker-first, environment-aware IAM platform |
| `01-architecture.mdc` | Boundaries: Keycloak owns identity/auth; apps own business authorization; PostgreSQL for Keycloak |
| `02-security.mdc` | Secret handling, TLS expectations, token logging bans, least privilege |
| `03-docker.mdc` | Pinned images, health checks, named volumes, no secrets in Dockerfiles |
| `04-keycloak.mdc` | OAuth2/OIDC standards, explicit redirect URIs, coarse roles, no wildcard redirects in production |
| `05-development.mdc` | Smallest reasonable change, validate, test, document behavior changes |

Rules are constraints, not a substitute for documentation. When rules
and docs conflict, update the outdated artifact; do not silently ignore
either.

---

## Environment Strategy

The platform targets three environments:

| Environment | Purpose |
|-------------|---------|
| **local** | Developer machines; Docker Compose; fast iteration |
| **staging** | Pre-production validation; production-like config without production secrets |
| **production** | Live identity provider for real applications |

### Why secrets must not be committed

- Git history is long-lived and often widely readable.
- Rotating a leaked password/token committed to Git is expensive.
- Different environments need different credentials.
- Production must not depend on values copied from a developer laptop.

Use:

- `.env` for local secrets (gitignored)
- `.env.example` for variable names and safe placeholders
- a secret manager in staging/production (Phase 07+)

Never commit real passwords, client secrets, API keys, or tokens.

---

## Git Strategy

### Commit style

- Prefer small, meaningful commits over large mixed dumps.
- One logical change per commit when practical.
- Write commit messages that explain **why**, not only what changed.

### Commit categories

| Type | Examples |
|------|----------|
| Feature | New realm import path, new Makefile target |
| Documentation | Phase docs, architecture updates |
| Infrastructure | Compose services, health checks, networking |
| Security | Secret handling, redirect URI hardening |
| Chore | `.gitignore`, formatting, non-behavioral cleanup |

### Avoid giant commits

Do not mix unrelated documentation, infrastructure, and configuration
in a single commit. Giant commits make review, rollback, and blame
harder.

Recommended habit:

1. Document the intended change (if behavior/architecture changes).
2. Implement the smallest slice.
3. Validate.
4. Commit that slice.

---

## Engineering Principles

1. **Simplicity** — Prefer boring, well-understood solutions.
2. **Reproducibility** — Another engineer (or CI) must be able to recreate the environment from Git + documented secrets.
3. **Security** — Treat credentials, tokens, and redirect configuration as security-critical.
4. **Least privilege** — Clients, roles, network exposure, and secrets should grant only what is required.
5. **Standard protocols** — OAuth 2.0 and OpenID Connect; avoid custom auth protocols.
6. **Minimal dependencies** — Do not introduce technologies when existing ones already solve the problem.
7. **Explicit configuration** — Prefer declared redirect URIs, pinned image versions, and named env vars over implicit defaults.
8. **Documentation as operational truth** — Docs must track real behavior. Outdated docs are defects.

### Source-of-truth hierarchy

1. Running system
2. Configuration / code
3. Architecture and phase documentation
4. Cursor rules

If documentation becomes outdated, update it in the same change set
when behavior changes.

---

## Development Workflow

Before significant work:

1. Understand existing architecture and phase status.
2. Identify affected files.
3. Explain the proposed approach.
4. Implement the smallest reasonable change.
5. Validate configuration.
6. Test the change.
7. Update documentation when behavior changes.

When modifying infrastructure, always record:

- what changed
- why it changed
- how to test it
- how to roll it back

---

## Tasks

- [x] Confirm repository root contains (or plans) `.cursor/`, `docs/`, `config/`, `keycloak/`, `scripts/`
- [x] Confirm Cursor rules `00`–`05` exist and align with platform goals
- [x] Confirm `docs/` structure includes architecture, phases, security, operations
- [x] Confirm `docs/phases/` contains phases `00`–`08` with preserved filenames
- [x] Create or verify `.gitignore` excludes `.env`, secrets, and database artifacts
- [x] Create or verify `.env.example` listing required variable names with placeholders only
- [x] Ensure `.env` is never tracked
- [x] Create or verify root `README.md` describing purpose and how to find docs
- [x] Plan `Makefile` targets for later phases (`up`, `down`, `logs`, `ps`, health helpers)
- [x] Document local vs staging vs production environment intent
- [x] Agree Git commit conventions with the team
- [x] Review engineering principles against Cursor rules for conflicts
- [x] Mark Phase 00 complete only after acceptance criteria pass

---

## Testing

Foundation validation is documentation and repository hygiene, not
runtime.

Validate:

1. **Structure** — Expected top-level directories and docs paths exist.
2. **Rules** — All six Cursor rule files are present and readable.
3. **Secrets hygiene** — `.env` is ignored; no real secrets appear in Git status for tracked files.
4. **Docs navigation** — `docs/README.md` links resolve to existing phase files.
5. **Phase completeness** — Each phase file has substantive content (no empty stubs, no TODO/TBD placeholders).
6. **Consistency** — Architecture docs and rules agree on Keycloak/app boundaries and PostgreSQL usage.

Example checks:

```bash
test -f .cursor/rules/00-project.mdc
test -f docs/phases/00-foundation.md
git check-ignore -v .env
git status --ignored
```

---

## Acceptance Criteria

Phase 00 is accepted when all of the following are true:

1. Repository layout for the platform is documented and reflected in the tree (or explicitly planned with directories present).
2. Cursor rules encode project, architecture, security, Docker, Keycloak, and development constraints.
3. Phase documentation `00`–`08` exists under `docs/phases/` with clear objectives and completion criteria.
4. Environment strategy distinguishes local, staging, and production.
5. Secret-handling policy forbids committing `.env` and real credentials.
6. Git strategy discourages giant mixed commits.
7. Engineering principles are explicit and aligned with Cursor rules.
8. No placeholder text remains in Phase 00 itself.

---

## Deliverables

- Documented repository structure
- Active Cursor rules (`00`–`05`)
- Populated phase documentation set
- Environment and secrets strategy
- Git and development workflow expectations
- `.gitignore` / `.env.example` strategy (files may be created in later implementation work, but requirements are defined here)
- Clear handoff criteria for Phase 01

---

## Dependencies

Phase 01 (Local Infrastructure) depends on Phase 00 for:

- agreed service layout and Docker-first approach
- secret/env variable conventions
- documentation update expectations
- security constraints (no public PostgreSQL without reason, pinned images, health checks)
- confirmation that implementation has not started prematurely without standards

Without Phase 00, Phase 01 risks inconsistent naming, committed secrets,
and undocumented infrastructure decisions.

---

## Completion Criteria

Phase 00 is complete when:

1. The foundation documentation in this file is accurate and actionable.
2. Repository and documentation conventions are agreed and discoverable.
3. Secrets and environment strategy are unambiguous.
4. The team can begin Phase 01 without inventing new foundational policy.

**Do not start Docker Compose implementation until Phase 00 is complete.**
