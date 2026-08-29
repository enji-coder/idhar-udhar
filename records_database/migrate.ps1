# Applies ordered SQL migrations to the local IDHAR UDHAR PostgreSQL database.
# Reads records_database/.env. Does not print secrets.

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $Root ".env"
$MigrationsDir = Join-Path $Root "migrations"
$Container = "idhar_udhar_postgres"

if (-not (Test-Path $EnvFile)) {
  throw "Missing .env at $EnvFile"
}

$envMap = @{}
Get-Content $EnvFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq "" -or $line.StartsWith("#")) { return }
  $parts = $line.Split("=", 2)
  if ($parts.Count -eq 2) {
    $envMap[$parts[0].Trim()] = $parts[1].Trim()
  }
}

$dbName = $envMap["DATABASE_NAME"]
$dbUser = $envMap["DATABASE_USER"]
if (-not $dbName -or -not $dbUser) {
  throw "DATABASE_NAME and DATABASE_USER are required in .env"
}

$running = docker inspect -f "{{.State.Running}}" $Container 2>$null
if ($running -ne "true") {
  throw "Docker container $Container is not running"
}

function Invoke-Psql {
  param(
    [Parameter(Mandatory = $true)][string]$Sql,
    [switch]$Quiet
  )
  $argList = @("exec", "-i", $Container, "psql", "-U", $dbUser, "-d", $dbName, "-v", "ON_ERROR_STOP=1")
  if ($Quiet) { $argList += @("--quiet", "-X") }
  $Sql | & docker @argList
  if ($LASTEXITCODE -ne 0) {
    throw "psql failed (exit $LASTEXITCODE)"
  }
}

function Invoke-PsqlFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Filename,
    [Parameter(Mandatory = $true)][string]$Checksum
  )
  $body = [System.IO.File]::ReadAllText($Path)
  $safeName = $Filename.Replace("'", "''")
  $sql = @"
BEGIN;
$body
INSERT INTO schema_migrations (version, filename, checksum)
VALUES ('$Version', '$safeName', '$Checksum');
COMMIT;
"@
  Invoke-Psql -Sql $sql -Quiet
}

Write-Host "Bootstrapping schema_migrations..."
Invoke-Psql -Quiet -Sql @"
CREATE TABLE IF NOT EXISTS schema_migrations (
  version     TEXT PRIMARY KEY,
  filename    TEXT NOT NULL,
  checksum    TEXT NOT NULL,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
"@

$files = Get-ChildItem -Path $MigrationsDir -Filter "*.sql" |
  Where-Object { $_.Name -match '^\d{4}_.+\.sql$' } |
  Sort-Object Name
if ($files.Count -eq 0) {
  throw "No SQL files in $MigrationsDir"
}

foreach ($file in $files) {
  $version = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
  $checksum = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash.ToLowerInvariant()

  $checkSql = "SELECT 1 FROM schema_migrations WHERE version = " + ("'{0}'" -f $version.Replace("'", "''")) + ";"
  $exists = ($checkSql | docker exec -i $Container psql -U $dbUser -d $dbName -t -A -q | Out-String)
  if ($LASTEXITCODE -ne 0) { throw "Failed checking schema_migrations for $version" }

  if ($exists.Trim() -eq "1") {
    Write-Host "SKIP already applied: $($file.Name)"
    continue
  }

  Write-Host "APPLY $($file.Name)"
  try {
    Invoke-PsqlFile -Path $file.FullName -Version $version -Filename $file.Name -Checksum $checksum
    Write-Host "  OK $version"
  }
  catch {
    throw "Migration $($file.Name) failed: $_"
  }
}

Write-Host "All migrations applied."
