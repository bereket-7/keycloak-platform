# Theme packaging

Custom Keycloak themes for the platform.

## Layout

```text
keycloak/themes/
└── platform/
    └── login/
        ├── theme.properties
        └── resources/css/platform.css
```

## Apply

Compose mounts `./keycloak/themes` into `/opt/keycloak/themes`.
The `platform` realm sets `loginTheme=platform` (see import JSON / apply script).

```bash
make apply-customization
make validate-customization
```

## Rules

- Extend `keycloak.v2`; do not fork security-critical templates unless required.
- No third-party scripts/CDNs without security review.
- Prefer self-hosted CSS; keep contrast and focus styles accessible.
- Local theme may show a non-production cue; production branding should not look like staging.
