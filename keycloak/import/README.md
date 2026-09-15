# Realm import artifacts

Version-controlled Keycloak realm configuration for reproducible bootstrap.

## Files

| File | Purpose |
|------|---------|
| `platform-realm.json` | Baseline `platform` realm: roles, groups, sample clients, demo user |

## Import behavior

Keycloak imports files from `/opt/keycloak/data/import` when started with
`--import-realm`. Import creates the realm **only if it does not already
exist**. Existing realms are not overwritten on restart.

To re-apply from Git after structural changes:

```bash
make import-realm
```

That uses the Admin API to create or update the realm from
`platform-realm.json`.

## Secrets policy

Committed JSON may contain **local development placeholders only**:

- Demo user password: `changeme-demo-12` (must meet length ≥ 12 policy)
- Admin demo password: `changeme-admin-12` (required action: CONFIGURE_TOTP)
- `demo-api` client secret: `local-dev-only-change-me`

Never commit production client secrets, SMTP passwords, or IdP credentials.
Production secrets belong in a secret manager.

## Environment overlays

Structural config (realm name, roles, client IDs, group conventions) is
shared. Environment-specific values differ:

| Value | Local | Staging / Production |
|-------|-------|----------------------|
| Redirect URIs | `http://localhost:3000/...` | Exact HTTPS app URLs |
| Web origins | `http://localhost:3000` | Exact HTTPS origins |
| Client secrets | Placeholder / `.env` | Secret manager |
| Hostname / issuer | `http://localhost:8080` | `https://auth.example.com` |

**Never use wildcard redirect URIs in production.**

When promoting a client to staging/production, register environment-specific
redirect URIs and origins in Keycloak (or a separate overlay export), then
update application env vars to match.

## Group naming convention

```text
/orgs/<organization>
/teams/<team>
/projects/<project>
```

Groups convey membership signals. They do not replace application
resource authorization.

## Client naming convention

```text
<project>-web      # public frontend (PKCE)
<project>-api      # confidential backend / resource server
<project>-mobile   # public native (when needed)
```

## Optional identity providers

External IdPs (Google, GitHub, Microsoft, enterprise OIDC/SAML) are
optional. Enable only when a consuming application needs them. Do not
weaken redirect URI or account-linking controls for convenience.

## Authorization signals (Phase 04)

The import includes a `groups` client scope with a group-membership
mapper so access tokens can carry `/orgs/*`, `/teams/*`, and
`/projects/*` paths. Sample clients include `groups` as a default scope.

On an already-running realm:

```bash
make apply-authorization
make validate-authorization
```

See [authorization-model.md](../../docs/security/authorization-model.md).

## Change process (avoid drift)

1. Experiment in Admin Console if needed.
2. Export or update `platform-realm.json`.
3. Scrub secrets.
4. Review and commit.
5. Re-import on other environments via `make import-realm` or fresh
   `--import-realm` bootstrap.

Production realm changes should be restricted to platform operators.
