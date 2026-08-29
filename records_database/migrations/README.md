# IDHAR UDHAR — PostgreSQL migrator (local Docker)

Requires: Docker container `idhar_udhar_postgres` and `records_database/.env`.
Does not print the database password.

Usage (from repo, PowerShell):

    powershell -File records_database/migrate.ps1

Idempotent: already-applied versions in `schema_migrations` are skipped.
