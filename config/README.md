# Config

Declarative, non-secret configuration for the Keycloak platform.

## Purpose

This directory holds environment-aware configuration that can be safely
committed to Git. Secrets never belong here — use `.env` (local) or a
secret manager (staging/production).

## Layout

```text
config/
└── realm/          Realm import artifacts and overlays (Phase 02+)
```

## Rules

- No passwords, client secrets, or API keys in committed files.
- Environment-specific values (redirect URIs, hostnames) may use separate
  overlay files documented in phase docs.
- Prefer version-controlled exports over snowflake Admin Console changes.

See [docs/phases/02-keycloak.md](../docs/phases/02-keycloak.md) for realm
configuration management.
