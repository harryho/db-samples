# Script to renew the ecommerce database in PostgreSQL
# Drops and recreates the database, then loads pgsql/ecommerce.sql

$ErrorActionPreference = "Stop"

# Default connection parameters
$DbHost   = if ($env:POSTGRES_HOST) { $env:POSTGRES_HOST } else { "localhost" }
$DbPort   = if ($env:POSTGRES_PORT) { $env:POSTGRES_PORT } else { "5432" }
$DbUser   = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { "postgres" }
$DbPass   = if ($env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD } else { "YourStrong!Passw0rd" }
$Database = "ecommerce"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SqlFile   = Join-Path $ScriptDir "ecommerce.sql"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Renewing Ecommerce Database (PostgreSQL)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Server: ${DbHost}:${DbPort}"
Write-Host "Database: ${Database}"
Write-Host ""

if (-Not (Test-Path $SqlFile)) {
    Write-Host "Error: SQL file not found: $SqlFile" -ForegroundColor Red
    exit 1
}

# Prefer local psql; fall back to the pgsql-infra container
$UseDocker = $false
if (Get-Command psql -ErrorAction SilentlyContinue) {
    Write-Host "Using local psql"
} elseif ((docker ps --format '{{.Names}}') -contains 'pgsql-infra') {
    Write-Host "Using psql from Docker container"
    $UseDocker = $true
} else {
    Write-Host "Error: psql not found and Docker container 'pgsql-infra' is not running" -ForegroundColor Red
    Write-Host ""
    Write-Host "Options:"
    Write-Host "1. Install PostgreSQL client tools"
    Write-Host "2. Run the Docker container: docker-compose up -d postgres"
    exit 1
}

function Invoke-Psql {
    param([string[]]$PsqlArgs)
    if ($UseDocker) {
        $result = docker exec -i pgsql-infra psql -U postgres @PsqlArgs
    } else {
        $env:PGPASSWORD = $DbPass
        $result = psql -h $DbHost -p $DbPort -U $DbUser @PsqlArgs
    }
    if ($LASTEXITCODE -ne 0) { throw "psql failed: $PsqlArgs" }
    return $result
}

Write-Host "1. Testing connection to PostgreSQL..." -ForegroundColor Yellow
Invoke-Psql @("-c", "SELECT version();") | Out-Null
Write-Host "   ✓ Connected successfully" -ForegroundColor Green

Write-Host ""
Write-Host "2. Dropping existing database (if exists)..." -ForegroundColor Yellow
Invoke-Psql @("-c", "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$Database' AND pid <> pg_backend_pid();") | Out-Null
Invoke-Psql @("-c", "DROP DATABASE IF EXISTS $Database;") | Out-Null
Write-Host "   ✓ Database dropped (if existed)" -ForegroundColor Green

Write-Host ""
Write-Host "3. Creating new database..." -ForegroundColor Yellow
Invoke-Psql @("-c", "CREATE DATABASE $Database WITH ENCODING='UTF8' TEMPLATE=template0;") | Out-Null
Write-Host "   ✓ Database created" -ForegroundColor Green

Write-Host ""
Write-Host "4. Loading schema and data from ecommerce.sql..." -ForegroundColor Yellow
if ($UseDocker) {
    docker cp $SqlFile pgsql-infra:/tmp/ecommerce.sql
    docker exec -i pgsql-infra psql -U postgres -d $Database -v ON_ERROR_STOP=1 -q -f /tmp/ecommerce.sql | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host "   ✗ Load failed" -ForegroundColor Red; exit 1 }
    docker exec -i pgsql-infra rm -f /tmp/ecommerce.sql
} else {
    $env:PGPASSWORD = $DbPass
    psql -h $DbHost -p $DbPort -U $DbUser -d $Database -v ON_ERROR_STOP=1 -q -f $SqlFile | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host "   ✗ Load failed" -ForegroundColor Red; exit 1 }
}
Write-Host "   ✓ Loaded successfully" -ForegroundColor Green

Write-Host ""
Write-Host "5. Verifying database..." -ForegroundColor Yellow
$TableCount = (Invoke-Psql @("-d", $Database, "-t", "-c",
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';") |
    Out-String).Trim()
Write-Host "   ✓ Database contains $TableCount tables (expected 16)" -ForegroundColor Green

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "✓ Success!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Connect using:"
if ($UseDocker) {
    Write-Host "  docker exec -it pgsql-infra psql -U postgres -d $Database"
} else {
    Write-Host "  psql -h $DbHost -p $DbPort -U $DbUser -d $Database"
}
Write-Host ""
Write-Host "Sample query:"
Write-Host "  SELECT * FROM products LIMIT 5;"
Write-Host "=========================================="
