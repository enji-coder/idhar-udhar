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

## Offline reference (repo twins)

Use these stems when matching query output. Recompute SHA-256 of each local file’s raw bytes if you need a fresh offline digest (same algorithm as the migrator).

| Prefix | Candidate files in repo | Notes from offline audit |
|--------|-------------------------|--------------------------|
| 0026 | `0026_rider_wallet_topup_withdrawal.sql` | No `provider_transfer_id` at table create |
| 0026 | `0026_rider_wallet_topup_withdrawals.sql` | Includes `provider_transfer_id` at create; **different** checksum |
| 0027 | `0027_idempotency_wallet_scopes.sql` | Idempotency scopes `wallet-topup` / `wallet-withdraw` |
| 0027 | `0027_wallet_idempotency_scopes.sql` | **Identical** bytes/checksum to the other 0027 |
| 0028 | `0028_payout_provider_references.sql` | Adds `provider_transfer_id` if missing; **different** checksum |
| 0028 | `0028_withdrawal_payout_refs.sql` | Does not add `provider_transfer_id` |

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
- [ ] For prefix **0026**: note which stem (if any) is applied; do not assume the other was applied.
- [ ] For prefix **0027**: note which stem (if any) is applied; identical content means either stem is schema-equivalent, but the **recorded** stem must be kept for history.
- [ ] For prefix **0028**: note which stem (if any) is applied; if only `withdrawal_payout_refs` is recorded, `provider_transfer_id` may still be missing unless introduced elsewhere — confirm with a separate approved schema check if needed.
- [ ] If **no rows** for a prefix: that prefix is not in production history; staging/canonical choice is a later approved decision, not implied by empty result.
- [ ] If **both** twins appear for one prefix: document both; do not delete either row; resolution needs DBA review.
- [ ] Cleanup of temporary access (if any) follows the approved change ticket — not this document alone.
- [ ] Do **not** rename, edit, or delete applied migration SQL until this checklist is complete and a keep/archive decision is approved.

---

## Out of scope

- Creating RO roles, Secrets Manager secrets, or network paths
- Running migrations or dry-runs against production
- Staging DB migrate or Checkpoint 3 deployment
- Editing or removing the six twin files in the repo

---

## After verification

Use the recorded `version` / `filename` / `checksum` pairs to choose which twin to **keep** in `migrations/` and which to archive **outside** the migrator directory — only under a separate, explicit approval. Until then, the Node migrator correctly refuses duplicate numeric prefixes.
