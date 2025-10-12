#!/bin/bash

# Script to renew the MySQL container (mysql-infra)
# This will remove all existing data and restart the container

set -e  # Exit on error

echo "=========================================="
echo "Recreating MySQL Container (mysql-infra)"
echo "=========================================="
echo ""

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in current directory"
    echo "Please run this script from the db-samples directory"
    exit 1
fi

# Stop and remove containers
echo "1. Stopping and removing existing MySQL container..."
docker-compose stop mysql
docker-compose rm -f mysql

# Remove the volume to ensure fresh data
echo ""
echo "2. Removing data volume for fresh installation..."
docker volume rm db-samples_mysql_data 2>/dev/null || echo "   (No existing volume to remove)"

# Start the service
echo ""
echo "3. Starting MySQL container..."
docker-compose up -d mysql

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Success!"
    echo "=========================================="
    echo "mysql-infra container is running."
    echo "To stop: docker-compose down"
    echo "=========================================="
else
    echo ""
    echo "✗ Failed to start mysql-infra container"
    echo "Check logs with: docker-compose logs mysql"
    exit 1
fi
