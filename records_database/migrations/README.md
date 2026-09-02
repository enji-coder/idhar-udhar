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

Idempotent: already-applied versions in `schema_migrations` are skipped.

Do not run this against production RDS until that step is explicitly approved.
