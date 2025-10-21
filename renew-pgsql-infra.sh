#!/bin/bash

# Script to renew the PostgreSQL container (pgsql-infra)
# This will remove all existing data and restart the container

set -e  # Exit on error

echo "=========================================="
echo "Recreating PostgreSQL Container (pgsql-infra)"
echo "=========================================="
echo ""

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in current directory"
    echo "Please run this script from the db-samples directory"
    exit 1
fi

# Stop and remove containers
echo "1. Stopping and removing existing PostgreSQL container..."
docker-compose stop postgres
docker-compose rm -f postgres

# Remove the volume to ensure fresh data
echo ""
echo "2. Removing data volume for fresh installation..."
docker volume rm db-samples_postgres_data 2>/dev/null || echo "   (No existing volume to remove)"

# Start the service
echo ""
echo "3. Starting PostgreSQL container..."
docker-compose up -d postgres

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Success!"
    echo "=========================================="
    echo "pgsql-infra container is running."
    echo "To stop: docker-compose down"
    echo "=========================================="
else
    echo ""
    echo "✗ Failed to start pgsql-infra container"
    echo "Check logs with: docker-compose logs postgres"
    exit 1
fi
