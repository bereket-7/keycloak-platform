# Keycloak Artifacts

Reproducible Keycloak configuration and customization, version controlled
without production secrets.

## Layout

```text
keycloak/
├── import/         Realm export/import JSON (local placeholders only)
│   ├── platform-realm.json
│   └── README.md
└── themes/         Custom login and account themes (Phase 06+)
```

## Import

Compose mounts `keycloak/import` and starts Keycloak with `--import-realm`.
The realm is created on first boot when it does not already exist.

```bash
make up
make import-realm          # create/update via Admin API from Git
make validate-keycloak     # Phase 02 checks
```

## Rules

- Export realm configuration after meaningful Admin Console changes.
- Scrub production secrets before committing exports.
- Themes change presentation only — do not weaken security controls.

See:

- [docs/phases/02-keycloak.md](../docs/phases/02-keycloak.md) — realm setup
- [keycloak/import/README.md](import/README.md) — overlays and conventions
- [docs/phases/06-customization.md](../docs/phases/06-customization.md) — themes
