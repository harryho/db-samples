# Script to renew the PostgreSQL container (pgsql-infra)
# This will remove all existing data and restart the container

# Enable strict error handling
$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Recreating PostgreSQL Container (pgsql-infra)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if docker-compose.yml exists
if (-Not (Test-Path "docker-compose.yml")) {
    Write-Host "Error: docker-compose.yml not found in current directory" -ForegroundColor Red
    Write-Host "Please run this script from the db-samples directory" -ForegroundColor Red
    exit 1
}

# Stop and remove containers
Write-Host "1. Stopping and removing existing PostgreSQL container..." -ForegroundColor Yellow
try {
    docker-compose stop postgres
    docker-compose rm -f postgres
} catch {
    Write-Host "Warning: Error stopping/removing container (may not exist)" -ForegroundColor Yellow
}

# Remove the volume to ensure fresh data
Write-Host ""
Write-Host "2. Removing data volume for fresh installation..." -ForegroundColor Yellow
try {
    docker volume rm db-samples_postgres_data 2>$null
} catch {
    Write-Host "   (No existing volume to remove)" -ForegroundColor Gray
}

# Start the service
Write-Host ""
Write-Host "3. Starting PostgreSQL container..." -ForegroundColor Yellow
try {
    docker-compose up -d postgres
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "✓ Success!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "pgsql-infra container is running." -ForegroundColor Green
    Write-Host "To stop: docker-compose down" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "✗ Failed to start pgsql-infra container" -ForegroundColor Red
    Write-Host "Check logs with: docker-compose logs postgres" -ForegroundColor Red
    exit 1
}