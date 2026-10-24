# IDHAR UDHAR — PostgreSQL migrator

Reads `records_database/.env`. Does not print the database password.
Does not change migration SQL files.

## Modes

`DATABASE_MODE=local` (default if unset)

- Requires Docker container `idhar_udhar_postgres` running.
- Applies SQL via `docker exec` (same as the original runner).

`DATABASE_MODE=external`

- Requires `psql` on PATH (not installed by this script).
- Connects to `DATABASE_HOST`:`DATABASE_PORT` using `DATABASE_USER` / `DATABASE_NAME`.
- Password is passed only as `PGPASSWORD` for the `psql` child process.
- `DATABASE_SSL=true` requires `DATABASE_SSL_ROOT_CERT` (file must exist) and uses `PGSSLMODE=verify-full` with `PGSSLROOTCERT`. Certificate verification is not disabled.

## Usage (from repo, PowerShell)

    powershell -File records_database/migrate.ps1

Idempotent: already-applied versions in `schema_migrations` are skipped only
when the recorded checksum matches the file bytes. A mismatch stops the run
before that file is skipped or applied.

Both `backend/scripts/migrate.mjs` and `records_database/migrate.ps1` refuse
duplicate numeric prefixes before connecting. Applied `0026` and `0027` files
must match the production checksums. `0028_payout_provider_references` was
applied in production, but its exact bytes are not in this repository. Do not
put a guessed file under that name. `0033_rider_withdrawal_payout_columns.sql`
re-asserts the known payout columns idempotently and does not reuse version
`0028`. A recorded version with no local file stops the run unless it is that
unrecovered `0028` checksum.

`MIGRATE_DRY_RUN=1` lists missing versions only and does not create
`schema_migrations`. It still opens a DB connection — never point it at
production.

Do not run this against production RDS until that step is explicitly approved.
