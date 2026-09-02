# Applies ordered SQL migrations to the IDHAR UDHAR PostgreSQL database.
# Reads records_database/.env. Does not print secrets.
#
# DATABASE_MODE=local     (default) — docker exec into idhar_udhar_postgres
# DATABASE_MODE=external  — host psql using DATABASE_HOST / PORT / SSL

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

function Require-EnvValue {
  param([Parameter(Mandatory = $true)][string]$Name)
  if (-not $envMap.ContainsKey($Name) -or [string]::IsNullOrWhiteSpace($envMap[$Name])) {
    throw "$Name is required in .env"
  }
  return $envMap[$Name]
}

$dbHost = Require-EnvValue "DATABASE_HOST"
$dbPort = Require-EnvValue "DATABASE_PORT"
$dbName = Require-EnvValue "DATABASE_NAME"
$dbUser = Require-EnvValue "DATABASE_USER"
$dbPassword = Require-EnvValue "DATABASE_PASSWORD"
$dbSslRaw = (Require-EnvValue "DATABASE_SSL").ToLowerInvariant()

if ($dbPort -notmatch '^\d+$') {
  throw "DATABASE_PORT must be a number"
}

if ($dbSslRaw -ne "true" -and $dbSslRaw -ne "false") {
  throw "DATABASE_SSL must be true or false"
}
$dbSsl = $dbSslRaw -eq "true"

$modeRaw = ""
if ($envMap.ContainsKey("DATABASE_MODE")) {
  $modeRaw = $envMap["DATABASE_MODE"].Trim().ToLowerInvariant()
}
if ($modeRaw -eq "") {
  $modeRaw = "local"
  Write-Host "DATABASE_MODE unset; defaulting to local"
}
if ($modeRaw -ne "local" -and $modeRaw -ne "external") {
  throw "DATABASE_MODE must be local or external"
}
$mode = $modeRaw

$sslRootCert = $null
if ($envMap.ContainsKey("DATABASE_SSL_ROOT_CERT") -and -not [string]::IsNullOrWhiteSpace($envMap["DATABASE_SSL_ROOT_CERT"])) {
  $sslRootCert = $envMap["DATABASE_SSL_ROOT_CERT"].Trim()
}

$pgSslMode = "disable"
if ($dbSsl) {
  $pgSslMode = "verify-full"
}

if ($mode -eq "external" -and $dbSsl) {
  if ([string]::IsNullOrWhiteSpace($sslRootCert)) {
    throw "DATABASE_SSL_ROOT_CERT is required when DATABASE_MODE=external and DATABASE_SSL=true"
  }
  if (-not (Test-Path -LiteralPath $sslRootCert)) {
    throw "DATABASE_SSL_ROOT_CERT file was not found"
  }
}

function Restore-EnvVar {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    $Previous
  )
  if ($null -eq $Previous) {
    Remove-Item -Path "Env:$Name" -ErrorAction SilentlyContinue
  }
  else {
    Set-Item -Path "Env:$Name" -Value $Previous
  }
}

function Invoke-Psql {
  param(
    [Parameter(Mandatory = $true)][string]$Sql,
    [switch]$Quiet,
    [switch]$TuplesOnly
  )

  $output = ""
  if ($script:mode -eq "local") {
    $argList = @("exec", "-i", $script:Container, "psql", "-U", $script:dbUser, "-d", $script:dbName, "-v", "ON_ERROR_STOP=1")
    if ($Quiet) { $argList += @("--quiet", "-X") }
    if ($TuplesOnly) { $argList += @("-t", "-A", "-q") }
    $output = $Sql | & docker @argList | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw "psql failed (exit $LASTEXITCODE)"
    }
    return $output
  }

  $psqlCmd = Get-Command psql -ErrorAction SilentlyContinue
  if (-not $psqlCmd) {
    throw "psql was not found on PATH. Install the PostgreSQL client or add it to PATH. This script does not install software."
  }

  $argList = @(
    "-h", $script:dbHost,
    "-p", $script:dbPort,
    "-U", $script:dbUser,
    "-d", $script:dbName,
    "-v", "ON_ERROR_STOP=1"
  )
  if ($Quiet) { $argList += @("--quiet", "-X") }
  if ($TuplesOnly) { $argList += @("-t", "-A", "-q") }

  $prevPassword = $env:PGPASSWORD
  $prevSslMode = $env:PGSSLMODE
  $prevSslRoot = $env:PGSSLROOTCERT
  try {
    $env:PGPASSWORD = $script:dbPassword
    $env:PGSSLMODE = $script:pgSslMode
    if ($script:pgSslMode -eq "verify-full") {
      $env:PGSSLROOTCERT = $script:sslRootCert
    }
    else {
      Remove-Item Env:PGSSLROOTCERT -ErrorAction SilentlyContinue
    }
    $output = $Sql | & psql @argList | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw "psql failed (exit $LASTEXITCODE)"
    }
  }
  finally {
    Restore-EnvVar -Name "PGPASSWORD" -Previous $prevPassword
    Restore-EnvVar -Name "PGSSLMODE" -Previous $prevSslMode
    Restore-EnvVar -Name "PGSSLROOTCERT" -Previous $prevSslRoot
  }
  return $output
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
  Invoke-Psql -Sql $sql -Quiet | Out-Null
}

Write-Host "Target: ${dbHost}:${dbPort}  database=$dbName  user=$dbUser  ssl=$dbSslRaw  mode=$mode"
if ($mode -eq "local") {
  Write-Host "Local mode uses docker exec $Container (published host/port in .env are for documentation and backend use)."
}
elseif ($dbSsl) {
  Write-Host "SSL mode=verify-full"
  Write-Host "SSL root cert file is set (path not printed)."
}

if ($mode -eq "local") {
  $running = docker inspect -f "{{.State.Running}}" $Container 2>$null
  if ($running -ne "true") {
    throw "Docker container $Container is not running"
  }
}

Write-Host "Preflight: checking PostgreSQL connectivity..."
try {
  $preflight = Invoke-Psql -Sql "SELECT 1;" -Quiet -TuplesOnly
  if ($preflight.Trim() -ne "1") {
    throw "unexpected preflight result"
  }
}
catch {
  throw "PostgreSQL preflight failed (credentials or network). Password is not printed. $_"
}
Write-Host "Preflight OK"

Write-Host "Bootstrapping schema_migrations..."
Invoke-Psql -Quiet -Sql @"
CREATE TABLE IF NOT EXISTS schema_migrations (
  version     TEXT PRIMARY KEY,
  filename    TEXT NOT NULL,
  checksum    TEXT NOT NULL,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
"@ | Out-Null

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
  try {
    $exists = Invoke-Psql -Sql $checkSql -Quiet -TuplesOnly
  }
  catch {
    throw "Failed checking schema_migrations for $version"
  }

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
