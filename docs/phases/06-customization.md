# Phase 06 — Customization

Customize Keycloak so it becomes a reusable branded identity platform.

---

## Objective

Provide consistent branding and identity-provider presentation so that
all consuming applications share a coherent login and account experience
without each app implementing custom credential UIs.

Customization must not weaken Keycloak’s security controls.

---

## Custom Theme

Deliver a Keycloak theme covering:

| Surface | Requirements |
|---------|--------------|
| Login page | Clear branding, readable form, error states |
| Registration page | Consistent branding if self-registration is enabled |
| Account page | Account console theme alignment where applicable |
| Logo | Platform or organization mark |
| Colors | Documented palette via theme CSS variables/files |
| Typography | Readable type; avoid illegible decorative fonts for forms |
| Accessibility | Keyboard usable; sufficient contrast; labeled fields; visible focus |

### Implementation notes

- Prefer Keycloak theme packaging under `keycloak/themes/` (or equivalent).
- Keep theme assets in Git; keep environment-specific logos documented.
- Do not inject third-party scripts into login pages without security review.
- Test both light layouts and error/validation messaging.

---

## Email

### Message types

| Email | Purpose |
|-------|---------|
| Verification | Confirm email ownership |
| Password reset | Secure reset link flow |
| Login/security notifications | Optional alerts for sensitive account events |

### SMTP configuration

- Configure SMTP via environment-specific settings (not committed secrets).
- Use different sender identities per environment when helpful (`noreply@…`).
- Verify SPF/DKIM/DMARC in staging/production mail domains.

### Templates

- Theme or realm email templates should match brand voice.
- Links in emails must point to the correct Keycloak base URL for that environment.
- Never include passwords or long-lived tokens in email bodies beyond required one-time links.

---

## Identity Providers

Optional social/enterprise brokers:

- Google
- GitHub
- Microsoft
- Enterprise OIDC/SAML IdPs

Rules:

- Optional per business need; not required for phase completion unless a consuming app demands them.
- Button styling may follow the theme, but protocol settings remain security-critical.
- First-broker-login and account linking policies must be deliberate.
- Redirect URIs registered with external IdPs must be exact.

---

## Branding Strategy

| Environment | Branding guidance |
|-------------|-------------------|
| Local | May show “local” badge or non-production styling to prevent confusion |
| Staging | Clearly marked non-production if users might confuse it with prod |
| Production | Final brand; no staging watermarks |

Environment-specific branding is encouraged when it reduces accidental
use of the wrong environment. Structural theme code can stay shared with
overlays for logos/colors/copy.

---

## Security

Customization boundaries:

- Do **not** disable CSRF protections, password policies, or SSL requirements for cosmetic reasons.
- Do **not** weaken redirect URI validation.
- Do **not** add unconstrained HTML/JS that enables XSS on login pages.
- Do **not** bypass MFA requirements in themed flows.
- Treat email reset links as sensitive; keep TTLs short via Keycloak settings.
- Review third-party fonts/CDNs; prefer self-hosted theme assets when practical.

Security-critical authentication flows remain Keycloak’s responsibility.
Themes change presentation, not protocol guarantees.

---

## Tasks

- [x] Create base Keycloak theme structure
- [x] Brand login (and registration if enabled)
- [x] Align account UI branding where in scope
- [x] Add logo, color, and typography tokens/files
- [x] Review accessibility (contrast, labels, keyboard)
- [x] Configure SMTP for non-local environments (and local mail trap if used)
- [x] Customize verification and reset email templates
- [x] Document optional IdP enablement + branding buttons
- [x] Mark non-production environments visually when appropriate
- [x] Security-review theme for script injection / external dependencies

---

## Testing

| Test | Expected |
|------|----------|
| Login UI | Renders branded page; login still succeeds |
| Registration | Branded form works if enabled |
| Password reset | Email sent; link resets password successfully |
| Email verification | Verification completes; account state updates |
| Mobile responsiveness | Usable on narrow viewports |
| Accessibility | Keyboard login path works; critical contrasts pass review |
| Identity-provider login | Optional IdP button works end-to-end when configured |
| Security regression | Standard OIDC flows unchanged; no wildcard redirects introduced |

---

## Acceptance Criteria

1. Login experience uses the platform theme.
2. Registration/account surfaces match branding where enabled.
3. Email verification and password reset work with branded templates.
4. SMTP is configured through environment-specific secrets, not Git.
5. Accessibility baseline is reviewed and acceptable for forms.
6. Optional IdPs can be enabled without breaking theme or security settings.
7. Non-production environments are distinguishable when required.
8. No security control was weakened for cosmetic customization.

---

## Deliverables

- Keycloak theme artifacts in version control
- Email template customizations
- SMTP configuration documentation (placeholders only in Git)
- Optional IdP branding/enablement notes
- Accessibility and security review notes

---

## Dependencies

**Requires:** Phase 02 realm exists; Phase 03 auth flows to exercise themed pages.

**Unblocks:** Polished multi-app user experience; production readiness perception (Phase 07).

---

## Completion Criteria

Phase 06 is complete when users authenticate through a branded Keycloak
experience, email-driven account flows work in configured environments,
and customization has been reviewed so it does not reduce Keycloak’s
security posture.
