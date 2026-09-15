# Restore Procedure

## 1. Purpose

This document defines the procedure for restoring the Keycloak identity platform after data loss or infrastructure failure.

The procedure is designed to provide a predictable and repeatable recovery process.

---

# 2. Restore Scenarios

Possible restore scenarios include:

* PostgreSQL data corruption.
* Accidental data deletion.
* Failed upgrade.
* Infrastructure failure.
* Host replacement.
* Disaster recovery.
* Security incident.
* Migration to new infrastructure.

---

# 3. Recovery Principles

The restore process must follow these principles:

1. Preserve the failed environment where possible.
2. Identify the recovery point.
3. Do not overwrite evidence during an investigation.
4. Restore into a controlled environment first when practical.
5. Verify the database before exposing Keycloak.
6. Run authentication tests after restoration.
7. Verify dependent applications.
8. Document the recovery.

---

# 4. Recovery Flow

```text
Incident
   |
   v
Assess Failure
   |
   v
Select Backup
   |
   v
Prepare Infrastructure
   |
   v
Restore PostgreSQL
   |
   v
Start Keycloak
   |
   v
Validate Realm / Clients / Users
   |
   v
Run Authentication Tests
   |
   v
Validate Applications
   |
   v
Return to Production
```

---

# 5. Before Restoring

Before restoring:

* Identify the failure.
* Determine whether the current database is usable.
* Identify the latest valid backup.
* Determine the required recovery point.
* Confirm the backup is readable.
* Record the incident.
* Stop affected services if necessary.

Do not immediately overwrite a potentially recoverable production database.

---

# 6. Infrastructure Recovery

If the infrastructure itself is lost, recreate the platform using the documented architecture.

Required components may include:

```text
Reverse Proxy
Keycloak
PostgreSQL
DNS
TLS Certificates
Network Configuration
Secrets
Monitoring
```

Infrastructure should be recreated from version-controlled configuration wherever possible.

---

# 7. PostgreSQL Restore

The exact restore commands depend on the backup mechanism.

The conceptual process is:

```text
Backup
  |
  v
Verify Backup
  |
  v
Create PostgreSQL Instance
  |
  v
Restore Database
  |
  v
Verify Database
```

The PostgreSQL version should be compatible with the Keycloak version being restored.

Database upgrades should not be mixed into an emergency restore unless necessary.

---

# 8. Keycloak Restore

After PostgreSQL recovery:

1. Configure Keycloak to use the restored database.
2. Start Keycloak.
3. Verify the expected realm exists.
4. Verify clients.
5. Verify roles and groups.
6. Verify authentication configuration.
7. Verify identity providers where configured.
8. Verify administrative access.

---

# 9. Authentication Validation

After restoration, test:

* OIDC discovery.
* Login.
* Logout.
* Token issuance.
* Token refresh.
* User session.
* MFA.
* Password reset where applicable.
* Email verification where applicable.
* Backend token validation.
* Application login.

Example:

```text
Keycloak
   |
   +--> Discovery works
   |
   +--> Login works
   |
   +--> Token issuance works
   |
   +--> Logout works
   |
   +--> Backend validation works
```

---

# 10. Application Validation

Each dependent application should be tested.

At minimum:

* Application can redirect to Keycloak.
* User can authenticate.
* Application receives the expected authentication result.
* Backend accepts valid tokens.
* Backend rejects invalid tokens.
* Application authorization still works.

---

# 11. DNS and HTTPS Validation

After infrastructure recovery, verify:

```text
DNS
 |
 v
auth.example.com
 |
 v
Reverse Proxy
 |
 v
Keycloak
```

Verify:

* DNS resolution.
* TLS certificate.
* Certificate hostname.
* HTTPS.
* Keycloak hostname.
* OIDC issuer.
* Redirect URIs.

---

# 12. Restore Verification

A restore is successful only when the platform passes functional checks.

Required checks:

* PostgreSQL healthy.
* Keycloak healthy.
* Realm available.
* Admin access works.
* User login works.
* OIDC discovery works.
* Token issuance works.
* API authentication works.
* Application authorization works.

---

# 13. Post-Restore Actions

After successful restoration:

1. Monitor Keycloak.
2. Monitor PostgreSQL.
3. Monitor authentication failures.
4. Validate dependent applications.
5. Verify backups are running again.
6. Review credentials if compromise is suspected.
7. Document the incident.
8. Record recovery duration.
9. Compare actual recovery against RTO.
10. Identify improvements.

---

# 14. Security Incident Restore

If restoration is caused by a security incident, do not simply restore the database and assume the problem is solved.

Consider:

* Compromised administrator credentials.
* Compromised client secrets.
* Compromised database credentials.
* Stolen tokens.
* Unauthorized users.
* Malicious configuration.
* Compromised infrastructure.

Credentials should be rotated where appropriate.

Active sessions may need to be invalidated.

---

# 15. Restore Testing

Restore procedures must be tested periodically.

Recommended process:

```text
Backup
  |
  v
Restore to isolated environment
  |
  v
Start Keycloak
  |
  v
Run authentication tests
  |
  v
Measure recovery time
  |
  v
Document findings
```

A backup that has never been restored should not be considered fully validated.

---

# 16. Restore Acceptance Criteria

The restore process is complete when:

* A valid backup can be identified.
* PostgreSQL can be restored.
* Keycloak can start using restored data.
* Authentication works.
* OIDC discovery works.
* Tokens can be issued.
* Backend APIs can validate tokens.
* Applications can authenticate.
* Authorization remains functional.
* Recovery time is measured.
* The procedure is documented and repeatable.
