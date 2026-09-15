# Keycloak Artifacts

Reproducible Keycloak configuration and customization, version controlled
without secrets.

## Layout

```text
keycloak/
├── import/         Realm export/import JSON (scrubbed of secrets)
└── themes/         Custom login and account themes (Phase 06+)
```

## Rules

- Export realm configuration after meaningful Admin Console changes.
- Scrub client secrets and SMTP passwords before committing exports.
- Themes change presentation only — do not weaken security controls.

See:

- [docs/phases/02-keycloak.md](../docs/phases/02-keycloak.md) — realm setup
- [docs/phases/06-customization.md](../docs/phases/06-customization.md) — themes and branding
