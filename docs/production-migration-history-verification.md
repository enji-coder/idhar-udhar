# Production migration history verification (0026 / 0027 / 0028)

**Purpose:** Read-only confirmation of which Cashfree wallet/payout-related migration stems (if any) are recorded in production `schema_migrations`, so duplicate numeric-prefix files in the repo can be resolved without breaking applied history or checksums.

**Status:** Procedure document only. Production history is **unverified** until an approved operator runs the SELECT below and records the results.

**Related offline audit:** Six files under `records_database/migrations/` with prefixes `0026`, `0027`, and `0028` were hashed offline (SHA-256 of raw file bytes). Compare those digests to the `checksum` column returned by this query.

---

## Access rules (mandatory)

1. Run this query **only** through a **DBA/security-approved, read-only** database access method (dedicated least-privilege role and private path as approved by your change process).
2. **Do not** use:
   - Application / ECS task `DATABASE_USER` credentials for an ad-hoc production query
   - ECS Exec
   - `backend/scripts/migrate.mjs` or `records_database/migrate.ps1` against production
   - `MIGRATE_DRY_RUN=1` (or apply mode) against production
3. **Do not** create roles, secrets, security-group rules, or infrastructure from this document alone — those require separate explicit production approval.
4. Agents and CI must not connect to production to perform this check.

---

## How the migrator records history

From `backend/scripts/migrate.mjs`:

| Column | Meaning |
|--------|---------|
| `version` | Full filename stem (e.g. `0026_rider_wallet_topup_withdrawal`), **not** just `0026` |
| `filename` | Full SQL filename including `.sql` |
| `checksum` | SHA-256 hex of the file’s raw bytes at apply time |
| `applied_at` | Timestamp when the row was inserted |

Twin files under the same numeric prefix are **different versions** if both were ever applied.

---

## Read-only SELECT (production)

Run **only** via an approved read-only path:

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

**Expected row shape:** zero or more rows. Empty result means none of those stems are recorded (yet). Multiple rows sharing the same four-digit prefix mean more than one twin was applied.

Do not print or store database passwords, connection strings, or other secrets when saving results. Persist only `version`, `filename`, `checksum`, and `applied_at` (and operator/ticket metadata).

---

## Recorded production versions

A read-only `schema_migrations` query (rolled back) recorded:

| Version | Filename | SHA-256 |
|---------|----------|---------|
| `0026_rider_wallet_topup_withdrawal` | `0026_rider_wallet_topup_withdrawal.sql` | `24e2ce4c19916df8049c578bebb95d5821cf2a5951b4c93147e433ac934756e8` |
| `0027_wallet_idempotency_scopes` | `0027_wallet_idempotency_scopes.sql` | `b635b1f8d34217eb08e930acf88dbb97fc086f2b469b39ff046405ef9f09583e` |
| `0028_payout_provider_references` | `0028_payout_provider_references.sql` | `87731dfe7527925d9c98a92baef24abd9788a849e19d931e8515c896f3a082ba` |

`0026` and `0027` in this repository are the `5ce4d74` blobs and match those checksums. The `0028` checksum is not in Git history or the working tree. Do not replace it with a guessed file. `0033_rider_withdrawal_payout_columns.sql` preserves the known payout columns, including `provider_transfer_id`, with `IF NOT EXISTS`.

---

## Checklist: verify filenames and checksums

After the approved SELECT returns:

- [ ] Ticket / approval ID for the read-only access window is recorded.
- [ ] Operator name and time of query are recorded (audit).
- [ ] Result set contains only the columns above (no credential leakage in logs/screenshots).
- [ ] For each returned row, `filename` matches a known twin under `records_database/migrations/` (or is documented if unexpected).
- [ ] For each returned row, `version` equals the filename stem (without `.sql`).
- [ ] For each returned row, local file SHA-256 of that exact filename equals `checksum` (byte-for-byte match).
- [ ] If checksum **mismatches**, stop — do not rename or “fix” the applied file; escalate (history/file drift).
- [ ] For prefix **0026**: the recorded file is `0026_rider_wallet_topup_withdrawal.sql`.
- [ ] For prefix **0027**: the recorded file is `0027_wallet_idempotency_scopes.sql`.
- [ ] For prefix **0028**: the recorded checksum is not in this repository. Do not reapply that version. `0033` adds the known columns only when it has not already been applied.
- [ ] If **no rows** for a prefix: that prefix is not in production history; staging/canonical choice is a later approved decision, not implied by empty result.
- [ ] If **both** twins appear for one prefix: document both; do not delete either row; resolution needs DBA review.
- [ ] Cleanup of temporary access (if any) follows the approved change ticket — not this document alone.
- [ ] Do **not** rename, edit, or delete applied migration SQL until this checklist is complete and a keep/archive decision is approved.

---

## Out of scope

- Creating RO roles, Secrets Manager secrets, or network paths
- Running migrations or dry-runs against production
- Staging DB migrate or Checkpoint 3 deployment
- Inventing the missing `0028_payout_provider_references.sql` bytes

---

## After verification

`0026` and `0027` duplicates are removed. The unrecorded `0026` column `provider_transfer_id` and the payout indexes are in `0033_rider_withdrawal_payout_columns.sql`. `0028` stays unrecovered: the runner accepts only the recorded checksum when that file is absent, and refuses any other file under that version.
