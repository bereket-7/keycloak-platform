# Customization Guide

Branding, email, and optional identity providers for the platform realm.

Related: [../phases/06-customization.md](../phases/06-customization.md)

---

## Login theme

Theme name: **`platform`** (extends `keycloak.v2`)

| Item | Location |
|------|----------|
| Properties | `keycloak/themes/platform/login/theme.properties` |
| Styles | `keycloak/themes/platform/login/resources/css/platform.css` |

Accent color: teal (`#0d9488`). Local builds show a “local identity” cue above the form.

Accessibility baseline:

- Visible focus outlines on inputs/buttons
- Labeled form fields (inherited from Keycloak)
- Error text uses a distinct danger color
- Keyboard-usable default Keycloak login flow

---

## SMTP (environment-specific)

Password reset and email verification require SMTP. Do **not** commit credentials.

Suggested env placeholders (staging/production secret manager):

```text
KC_SPI_EMAIL_DEFAULT_FROM=noreply@example.com
# Or configure via Admin Console → Realm settings → Email
# SMTP_HOST=
# SMTP_PORT=587
# SMTP_USER=
# SMTP_PASSWORD=
# SMTP_FROM=noreply@example.com
```

| Environment | Guidance |
|-------------|----------|
| Local | Optional mail trap (Mailhog/Mailpit) — not required for Phase 06 theme completion |
| Staging | Real or trap SMTP; mark non-prod in From name if helpful |
| Production | Verified domain (SPF/DKIM/DMARC); secrets in secret manager |

Email templates may stay on Keycloak defaults until brand copy is finalized.
Never put passwords or long-lived tokens in email bodies.

---

## Optional identity providers

Google, GitHub, Microsoft, and enterprise OIDC/SAML IdPs are **optional**.

Enable only when a consuming app needs them:

1. Register exact redirect URI at the external IdP.
2. Configure broker in realm Identity Providers.
3. Set first-login / account-linking policy deliberately.
4. Do not weaken platform redirect URI allow lists for convenience.

Theme buttons may be styled later; protocol settings remain security-critical.

---

## Security boundaries

- Do not disable CSRF, password policy, MFA, or redirect validation for cosmetics.
- Do not inject unconstrained HTML/JS into login templates.
- Prefer self-hosted assets over CDNs.
- Themes change presentation only — OIDC guarantees stay with Keycloak.

---

## Validation

```bash
make apply-customization
make validate-customization
```
