# Request: temporary production read-only DB access

**Project:** IDHAR UDHAR (SWIFTSEND INNOVATIONS PRIVATE LIMITED)
**Audience:** DBA / security administrator / change approver
**Related:** `docs/production-migration-history-verification.md`, `docs/cashfree_staging_preparation.md`

**This document is a request only.** It does not create roles, secrets, network rules, or AWS resources. It does not authorize agents or CI to connect to production.

---

## 1. Why this verification is necessary

The repository contains **duplicate numeric migration prefixes** for `0026`, `0027`, and `0028` (two SQL files each). The Node migrator (`backend/scripts/migrate.mjs`) refuses to run until prefixes are unique.

Resolving which file to keep requires knowing which **version stem**, **filename**, and **checksum** (if any) are already recorded in production `schema_migrations`. Renaming, deleting, or editing migration files **before** that confirmation risks breaking applied history and checksum integrity.

Cashfree staging (Checkpoint 2 → 3) cannot safely migrate a staging database until this history is verified and the duplicate set is resolved under approval.

---

## 2. Exact SELECT (from verification procedure)

```sql
SELECT version, filename, checksum, applied_at
FROM schema_migrations
WHERE version LIKE '0026%'
   OR version LIKE '0027%'
   OR version LIKE '0028%'
   OR filename LIKE '0026%'
   OR filename LIKE '0027%'
   OR filename LIKE '0028%'
ORDER BY version, filename;
```

Persist only these result columns (plus ticket / operator / timestamp metadata). Do not log passwords, connection strings, or other secrets.

---

## 3. Access method and operator (DBA/security chooses)

Please **choose and approve**:

1. The **access method** (e.g. private bastion/VPN + `psql`, approved Query Editor, or equivalent private path).
2. The **named operator identity** who may run the SELECT.
3. The **time window** and change/ticket ID for this temporary access.

Engineering will not invent or self-provision the path.

---

## 4. Least-privilege requirements

If a temporary database principal is approved:

- **SELECT only** on `schema_migrations` (or the minimum object set needed for the query above).
- **No** DDL (`CREATE` / `ALTER` / `DROP`).
- **No** `INSERT` / `UPDATE` / `DELETE` / `TRUNCATE`.
- **No** privilege to run migrations, own application schemas for write, or use the application runtime role.
- Prefer a dedicated short-lived principal — **not** the ECS/API application user.

---

## 5. Connectivity and audit

- Database connectivity must be **encrypted** (TLS), with certificate verification consistent with production RDS practice (e.g. approved CA / `rejectUnauthorized` equivalent — not disabled).
- **Audit logging** must record: who ran the query, when, from where (session/bastion), and the ticket ID.
- Results shared with engineering should contain only `version`, `filename`, `checksum`, `applied_at`.

---

## 6. Explicit prohibitions

Do **not** approve or use any of the following for this check:

- Application / ECS task `DATABASE_USER` credentials for an ad-hoc production query
- ECS Exec into a production task
- Public exposure of the RDS endpoint (e.g. `0.0.0.0/0`)
- Production migration apply (`MIGRATE_CONFIRM=apply-missing` or `migrate.ps1` against production)
- Production migration dry-run (`MIGRATE_DRY_RUN=1` against production)
- Agent/CI automation connecting to production

---

## 7. Scope of this task

Creating this request document (or filing a ticket that references it):

- **Does not** create a database role
- **Does not** create or rotate Secrets Manager secrets
- **Does not** change security groups, IAM, or other AWS resources
- **Does not** run the SELECT

All of the above require **separate, explicit production approval** and execution by authorized personnel.

---

## 8. Cleanup / revocation (required after verification)

After the SELECT results are captured and shared securely:

1. Revoke temporary network rules (if any were opened for the window).
2. Disable or drop the temporary read-only principal (unless a permanent RO role was separately approved).
3. Rotate credentials if a temporary password was issued.
4. Close the change ticket with: operator name, window, row count (or “zero rows”), and confirmation that access was revoked.
5. Engineering proceeds only then to an approved keep/archive decision for the twin migration files — still without bypassing checksum/history rules.

---

## Approval block (for DBA / security)

| Field | Value |
|-------|--------|
| Ticket / change ID | |
| Approved access method | |
| Approved operator | |
| Window (start–end, timezone) | |
| RO principal name (if any) | |
| Approver signature / date | |

---

## After approval

Operator runs the SELECT in §2 via the approved method, completes the checklist in `docs/production-migration-history-verification.md`, then performs §8 cleanup.
