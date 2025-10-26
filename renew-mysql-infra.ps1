# Script to renew the MySQL container (mysql-infra)
# This will remove all existing data and restart the container

# Enable strict error handling
$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Recreating MySQL Container (mysql-infra)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if docker-compose.yml exists
if (-Not (Test-Path "docker-compose.yml")) {
    Write-Host "Error: docker-compose.yml not found in current directory" -ForegroundColor Red
    Write-Host "Please run this script from the db-samples directory" -ForegroundColor Red
    exit 1
}

# Stop and remove containers
Write-Host "1. Stopping and removing existing MySQL container..." -ForegroundColor Yellow
try {
    docker-compose stop mysql
    docker-compose rm -f mysql
} catch {
    Write-Host "Warning: Error stopping/removing container (may not exist)" -ForegroundColor Yellow
}

# Remove the volume to ensure fresh data
Write-Host ""
Write-Host "2. Removing data volume for fresh installation..." -ForegroundColor Yellow
try {
    docker volume rm db-samples_mysql_data 2>$null
} catch {
    Write-Host "   (No existing volume to remove)" -ForegroundColor Gray
}

# Start the service
Write-Host ""
Write-Host "3. Starting MySQL container..." -ForegroundColor Yellow
try {
    docker-compose up -d mysql
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "✓ Success!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "mysql-infra container is running." -ForegroundColor Green
    Write-Host "To stop: docker-compose down" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "✗ Failed to start mysql-infra container" -ForegroundColor Red
    Write-Host "Check logs with: docker-compose logs mysql" -ForegroundColor Red
    exit 1
}