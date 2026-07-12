#!/bin/bash

# Script to renew the MongoDB container (mongo-infra)
# This will remove all existing data and restart the container

set -e  # Exit on error

echo "=========================================="
echo "Recreating MongoDB Container (mongo-infra)"
echo "=========================================="
echo ""

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in current directory"
    echo "Please run this script from the db-samples directory"
    exit 1
fi

# Stop and remove containers
echo "1. Stopping and removing existing MongoDB container..."
docker-compose stop mongo
docker-compose rm -f mongo

# Remove the volume to ensure fresh data
echo ""
echo "2. Removing data volume for fresh installation..."
docker volume rm db-samples_mongo_data 2>/dev/null || echo "   (No existing volume to remove)"

# Start the service
echo ""
echo "3. Starting MongoDB container..."
docker-compose up -d mongo

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Success!"
    echo "=========================================="
    echo "mongo-infra container is running."
    echo "To stop: docker-compose down"
    echo "=========================================="
    echo ""
    echo "Next: load sample data, e.g."
    echo "  cd mongo/ecommerce && ./mongo_import.sh"
    echo "  cd mongo/data && ./mongo_import.sh"
else
    echo ""
    echo "✗ Failed to start mongo-infra container"
    echo "Check logs with: docker-compose logs mongo"
    exit 1
fi
