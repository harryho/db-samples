# Script to renew the MongoDB container (mongo-infra)
# This will remove all existing data and restart the container

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Recreating MongoDB Container (mongo-infra)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if docker-compose.yml exists
if (-Not (Test-Path "docker-compose.yml")) {
    Write-Host "Error: docker-compose.yml not found in current directory" -ForegroundColor Red
    Write-Host "Please run this script from the db-samples directory" -ForegroundColor Red
    exit 1
}

# Stop and remove containers
Write-Host "1. Stopping and removing existing MongoDB container..." -ForegroundColor Yellow
try {
    docker-compose stop mongo
    docker-compose rm -f mongo
} catch {
    Write-Host "Warning: Error stopping/removing container (may not exist)" -ForegroundColor Yellow
}

# Remove the volume to ensure fresh data
Write-Host ""
Write-Host "2. Removing data volume for fresh installation..." -ForegroundColor Yellow
try {
    docker volume rm db-samples_mongo_data 2>$null
} catch {
    Write-Host "   (No existing volume to remove)" -ForegroundColor Gray
}

# Start the service
Write-Host ""
Write-Host "3. Starting MongoDB container..." -ForegroundColor Yellow
try {
    docker-compose up -d mongo

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "✓ Success!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "mongo-infra container is running." -ForegroundColor Green
    Write-Host "To stop: docker-compose down" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next: load sample data, e.g."
    Write-Host "  cd mongo/ecommerce && ./mongo_import.sh"
    Write-Host "  cd mongo/data && ./mongo_import.sh"
} catch {
    Write-Host ""
    Write-Host "✗ Failed to start mongo-infra container" -ForegroundColor Red
    Write-Host "Check logs with: docker-compose logs mongo" -ForegroundColor Red
    exit 1
}
