#!/bin/bash

# Script to renew the MS SQL Server container with fresh Northwind database
# This will remove all existing data and reinitialize the database

set -e  # Exit on error

echo "=========================================="
echo "Recreating MS SQL Server Container (mssql-infra)"
echo "=========================================="
echo ""

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in current directory"
    echo "Please run this script from the db-samples directory"
    exit 1
fi


# Stop and remove only the mssql-infra container
echo "1. Stopping and removing existing mssql-infra container..."
docker-compose stop mssql
docker-compose rm -f mssql


# Remove the volume to ensure fresh data
echo ""
echo "2. Removing data volume for fresh installation..."
docker volume rm db-samples_mssql_data 2>/dev/null || echo "   (No existing volume to remove)"


# Start the mssql-infra container
echo ""
echo "3. Starting mssql-infra container..."
docker-compose up -d mssql

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Success!"
    echo "=========================================="
    echo "mssql-infra container is running."
    echo "To stop: docker-compose down"
    echo "=========================================="
else
    echo ""
    echo "✗ Failed to start mssql-infra container"
    echo "Check logs with: docker-compose logs mssql"
    exit 1
fi
