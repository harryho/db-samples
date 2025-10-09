#!/bin/bash

# Script to renew the MS SQL Server container with fresh Northwind database
# This will remove all existing data and reinitialize the database

set -e  # Exit on error

echo "=========================================="
echo "Recreating MS SQL Server Container"
echo "=========================================="
echo ""

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in current directory"
    echo "Please run this script from the db-samples directory"
    exit 1
fi

# Stop and remove containers
echo "1. Stopping and removing existing containers..."
docker-compose down

# Remove the volume to ensure fresh data
echo ""
echo "2. Removing data volume for fresh installation..."
docker volume rm db-samples_mssql_data 2>/dev/null || echo "   (No existing volume to remove)"

# Start the services
echo ""
echo "3. Starting MS SQL Server container..."
docker-compose up -d mssql

# Wait for SQL Server to be healthy
echo ""
echo "4. Waiting for SQL Server to be ready..."
echo "   (This may take 30-60 seconds...)"

MAX_WAIT=120
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
    if docker-compose ps mssql | grep -q "healthy"; then
        echo "   ✓ SQL Server is ready!"
        break
    fi
    sleep 5
    COUNTER=$((COUNTER + 5))
    echo "   Waiting... (${COUNTER}s/${MAX_WAIT}s)"
done

if [ $COUNTER -ge $MAX_WAIT ]; then
    echo "   ✗ SQL Server failed to become healthy within ${MAX_WAIT} seconds"
    echo "   Check logs with: docker-compose logs mssql"
    exit 1
fi

# Run the initialization service
echo ""
echo "5. Creating and populating Northwind database..."
docker-compose up mssql-init

# Check if initialization was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Success!"
    echo "=========================================="
    echo ""
    echo "MS SQL Server is running with Northwind database"
    echo ""
    echo "Connection details:"
    echo "  Server:   localhost,1433"
    echo "  Database: northwind"
    echo "  Username: sa"
    echo "  Password: YourStrong@Passw0rd"
    echo ""
    echo "Connect using:"
    echo "  docker exec -it northwind-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P YourStrong@Passw0rd -d northwind"
    echo ""
    echo "To stop: docker-compose down"
    echo "=========================================="
else
    echo ""
    echo "✗ Database initialization failed"
    echo "Check logs with: docker-compose logs mssql-init"
    exit 1
fi
