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

$files = Get-ChildItem -Path $MigrationsDir -Filter "*.sql" |
  Where-Object { $_.Name -match '^\d{4}_.+\.sql$' } |
  Sort-Object Name
if ($files.Count -eq 0) {
  throw "No SQL files in $MigrationsDir"
}

$byPrefix = @{}
foreach ($file in $files) {
  $prefix = $file.Name.Substring(0, 4)
  if (-not $byPrefix.ContainsKey($prefix)) {
    $byPrefix[$prefix] = New-Object System.Collections.Generic.List[string]
  }
  $byPrefix[$prefix].Add($file.Name)
}
$duplicatePrefixes = @($byPrefix.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 })
if ($duplicatePrefixes.Count -gt 0) {
  $detail = ($duplicatePrefixes | ForEach-Object {
    "$($_.Key): $(($_.Value | Sort-Object) -join ', ')"
  }) -join "; "
  throw "Duplicate migration numeric prefixes. Refusing before any database connection: $detail"
}

$productionFileChecksums = @{
  "0026_rider_wallet_topup_withdrawal" = "24e2ce4c19916df8049c578bebb95d5821cf2a5951b4c93147e433ac934756e8"
  "0027_wallet_idempotency_scopes" = "b635b1f8d34217eb08e930acf88dbb97fc086f2b469b39ff046405ef9f09583e"
}
$historicalWithoutBytes = @{
  "0028_payout_provider_references" = "87731dfe7527925d9c98a92baef24abd9788a849e19d931e8515c896f3a082ba"
}
$checksumByVersion = @{}
foreach ($file in $files) {
  $version = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
  $checksumByVersion[$version] = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash.ToLowerInvariant()
}
foreach ($version in $productionFileChecksums.Keys) {
  if (-not $checksumByVersion.ContainsKey($version)) {
    throw "Production-applied migration file is missing: $version"
  }
  if ($checksumByVersion[$version] -ne $productionFileChecksums[$version]) {
    throw "Production-applied migration checksum does not match the file: $version"
  }
}
foreach ($version in $historicalWithoutBytes.Keys) {
  if ($checksumByVersion.ContainsKey($version) -and $checksumByVersion[$version] -ne $historicalWithoutBytes[$version]) {
    throw "Unrecovered production migration is present with a different checksum. Refusing to skip or apply: $version"
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

$recordedText = Invoke-Psql -Sql "SELECT version || '|' || lower(checksum) FROM schema_migrations ORDER BY version;" -Quiet -TuplesOnly
foreach ($line in ($recordedText -split "\r?\n")) {
  $trimmed = $line.Trim()
  if ($trimmed -eq "") { continue }
  $parts = $trimmed.Split("|", 2)
  if ($parts.Count -ne 2) {
    throw "Unexpected schema_migrations row"
  }
  $recordedVersion = $parts[0].Trim()
  $storedChecksum = $parts[1].Trim().ToLowerInvariant()
  if ($checksumByVersion.ContainsKey($recordedVersion)) { continue }
  $pinned = $null
  if ($historicalWithoutBytes.ContainsKey($recordedVersion)) {
    $pinned = $historicalWithoutBytes[$recordedVersion]
  }
  if ($pinned -and $storedChecksum -eq $pinned) {
    Write-Host "SKIP already applied without local file: $recordedVersion.sql"
    continue
  }
  if ($pinned) {
    throw "Recorded migration checksum does not match the known production checksum. Refusing to skip or apply: $recordedVersion"
  }
  throw "Recorded migration has no local file. Refusing to continue: $recordedVersion"
}

foreach ($file in $files) {
  $version = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
  $checksum = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash.ToLowerInvariant()
  $safeVersion = $version.Replace("'", "''")
  $checkSql = "SELECT checksum FROM schema_migrations WHERE version = '$safeVersion';"
  try {
    $recorded = (Invoke-Psql -Sql $checkSql -Quiet -TuplesOnly).Trim().ToLowerInvariant()
  }
  catch {
    throw "Failed checking schema_migrations for $version"
  }

  if ($recorded -ne "") {
    if ($recorded -ne $checksum) {
      throw "Recorded migration checksum does not match the file. Refusing to skip or apply: $version"
    }
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
