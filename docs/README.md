# Keycloak Platform Documentation

This documentation describes the architecture, implementation,
security model, deployment, and operational procedures for the
reusable Keycloak identity platform.

## Documentation Structure

### Architecture

Contains system architecture and infrastructure decisions.

- [overview.md](architecture/overview.md)
- [components.md](architecture/components.md)
- [networking.md](architecture/networking.md)
- [environments.md](architecture/environments.md)

### Phases

Contains the implementation plan and progress for each development phase.

- [00-foundation.md](phases/00-foundation.md)
- [01-infrastructure.md](phases/01-infrastructure.md)
- [02-keycloak.md](phases/02-keycloak.md)
- [03-authentication.md](phases/03-authentication.md)
- [04-authorization.md](phases/04-authorization.md)
- [05-application-integration.md](phases/05-application-integration.md)
- [06-customization.md](phases/06-customization.md)
- [07-production.md](phases/07-production.md)
- [08-reusability.md](phases/08-reusability.md)

### Integration

- [application-integration.md](integration/application-integration.md)

### Customization

- [customization-guide.md](customization/customization-guide.md)

### Reusability

- [onboarding.md](reusability/onboarding.md)

### Security

Contains authentication, authorization, token, and threat-model documentation.

- [security-model.md](security/security-model.md)
- [authentication-policies.md](security/authentication-policies.md)
- [authorization-model.md](security/authorization-model.md)
- [token-strategy.md](security/token-strategy.md)
- [threat-model.md](security/threat-model.md)

### Operations

Contains backup, restore, upgrade, production, and troubleshooting procedures.

- [backup.md](operations/backup.md)
- [restore.md](operations/restore.md)
- [upgrades.md](operations/upgrades.md)
- [production-deployment.md](operations/production-deployment.md)
- [troubleshooting.md](operations/troubleshooting.md)

## Development Principle

The platform is developed incrementally.

Each phase should:

1. Have a clearly defined objective.
2. Have explicit implementation tasks.
3. Have acceptance criteria.
4. Be tested before moving to the next phase.
5. Document important architectural decisions.

## Source of Truth

The following hierarchy applies:

1. Running system
2. Configuration/code
3. Architecture documentation
4. Cursor rules

If documentation becomes outdated, it must be updated.
