# Config

Declarative, non-secret configuration for the Keycloak platform.

## Layout

```text
config/
├── realm/                 Realm overlay notes (Phase 02+)
└── apps/
    └── env.application.example   Standard app env contract (Phase 05+)
```

## Rules

- No passwords, client secrets, or API keys in committed files.
- Application teams copy `env.application.example` into their own repos.
- Prefer version-controlled realm exports under `keycloak/import/`.
