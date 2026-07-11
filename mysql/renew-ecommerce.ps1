# Script to renew the ecommerce database in MySQL
# Loads mysql/ecommerce.sql (the file includes DROP/CREATE DATABASE)

$ErrorActionPreference = "Stop"

# Default connection parameters
$DbHost   = if ($env:MYSQL_HOST) { $env:MYSQL_HOST } else { "localhost" }
$DbPort   = if ($env:MYSQL_PORT) { $env:MYSQL_PORT } else { "3306" }
$DbUser   = if ($env:MYSQL_USER) { $env:MYSQL_USER } else { "root" }
$DbPass   = if ($env:MYSQL_PASSWORD) { $env:MYSQL_PASSWORD } else { "YourStrong!Passw0rd" }
$Database = "ecommerce"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SqlFile   = Join-Path $ScriptDir "ecommerce.sql"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Renewing Ecommerce Database (MySQL)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Server: ${DbHost}:${DbPort}"
Write-Host "Database: ${Database}"
Write-Host ""

if (-Not (Test-Path $SqlFile)) {
    Write-Host "Error: SQL file not found: $SqlFile" -ForegroundColor Red
    exit 1
}

# Prefer local mysql; fall back to the mysql-infra container
$UseDocker = $false
if (Get-Command mysql -ErrorAction SilentlyContinue) {
    Write-Host "Using local mysql"
} elseif ((docker ps --format '{{.Names}}') -contains 'mysql-infra') {
    Write-Host "Using mysql from Docker container"
    $UseDocker = $true
} else {
    Write-Host "Error: mysql not found and Docker container 'mysql-infra' is not running" -ForegroundColor Red
    Write-Host ""
    Write-Host "Options:"
    Write-Host "1. Install MySQL client tools"
    Write-Host "2. Run the Docker container: docker-compose up -d mysql"
    exit 1
}

function Invoke-MySql {
    param([string[]]$MySqlArgs)
    if ($UseDocker) {
        $result = docker exec -i mysql-infra mysql -u root -p"$DbPass" @MySqlArgs
    } else {
        $result = mysql -h $DbHost -P $DbPort -u $DbUser -p"$DbPass" @MySqlArgs
    }
    if ($LASTEXITCODE -ne 0) { throw "mysql failed: $MySqlArgs" }
    return $result
}

Write-Host "1. Testing connection to MySQL..." -ForegroundColor Yellow
Invoke-MySql @("-e", "SELECT VERSION();") | Out-Null
Write-Host "   ✓ Connected successfully" -ForegroundColor Green

Write-Host ""
Write-Host "2. Loading ecommerce.sql (includes DROP/CREATE DATABASE)..." -ForegroundColor Yellow
if ($UseDocker) {
    docker cp $SqlFile mysql-infra:/tmp/ecommerce.sql
    docker exec -i mysql-infra bash -c "mysql -u root -p'$DbPass' < /tmp/ecommerce.sql"
    if ($LASTEXITCODE -ne 0) { Write-Host "   ✗ Load failed" -ForegroundColor Red; exit 1 }
    docker exec mysql-infra rm -f /tmp/ecommerce.sql
} else {
    Get-Content $SqlFile -Raw | mysql -h $DbHost -P $DbPort -u $DbUser -p"$DbPass"
    if ($LASTEXITCODE -ne 0) { Write-Host "   ✗ Load failed" -ForegroundColor Red; exit 1 }
}
Write-Host "   ✓ Loaded successfully" -ForegroundColor Green

Write-Host ""
Write-Host "3. Verifying database..." -ForegroundColor Yellow
$TableCount = (Invoke-MySql @("-D", $Database, "-N", "-e",
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$Database' AND table_type = 'BASE TABLE';") |
    Out-String).Trim()
Write-Host "   ✓ Database contains $TableCount tables (expected 16)" -ForegroundColor Green
if ($TableCount -ne "16") {
    Write-Host "   ✗ Unexpected table count" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "✓ Success!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Connect using:"
if ($UseDocker) {
    Write-Host "  docker exec -it mysql-infra mysql -u root -p -D $Database"
} else {
    Write-Host "  mysql -h $DbHost -P $DbPort -u $DbUser -p -D $Database"
}
Write-Host ""
Write-Host "Sample query:"
Write-Host "  SELECT * FROM products LIMIT 5;"
Write-Host "=========================================="
