# Realm configuration overlays

Environment-specific notes for the `platform` realm. The committed baseline
lives in [`keycloak/import/platform-realm.json`](../../keycloak/import/platform-realm.json).

## Shared vs environment-specific

| Shared (Git) | Environment-specific (not secrets in Git) |
|--------------|-------------------------------------------|
| Realm name `platform` | Issuer hostname |
| Realm roles `user`, `admin`, `super-admin` | Redirect URIs |
| Group paths `/orgs/*`, `/teams/*`, `/projects/*` | Web origins |
| Client IDs (`demo-web`, `demo-api`, …) | Client secrets |
| PKCE / flow flags | SMTP, external IdP credentials |

## Local defaults (demo clients)

| Client | Type | Redirect URIs | Web origins |
|--------|------|---------------|-------------|
| `demo-web` | Public + PKCE | `http://localhost:3000/*`, `/callback`, `/silent-renew` | `http://localhost:3000` |
| `demo-api` | Confidential + service account | none | none |

## Staging / production checklist

1. Create or update clients with **exact** HTTPS redirect URIs (no wildcards).
2. Set explicit web origins matching the application origin.
3. Store `demo-api` (and other confidential) secrets in a secret manager.
4. Disable unused grants; keep PKCE for public clients.
5. Confirm OIDC discovery: `{issuer}/.well-known/openid-configuration`

## Operational ownership

| Change | Owner |
|--------|-------|
| Baseline realm structure | Platform / IAM |
| App redirect URIs and client registration | Application team + platform approval |
| Production Admin Console access | Restricted platform operators |
