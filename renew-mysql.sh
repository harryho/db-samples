#!/bin/bash

# Script to renew the MySQL container with fresh Northwind database
# This will remove all existing data and reinitialize the database

set -e  # Exit on error

echo "=========================================="
echo "Recreating MySQL Container"
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
docker-compose down mysql

# Remove the volume to ensure fresh data
echo ""
echo "2. Removing data volume for fresh installation..."
docker volume rm db-samples_mysql_data 2>/dev/null || echo "   (No existing volume to remove)"

# Start the service
echo ""
echo "3. Starting MySQL container..."
docker-compose up -d mysql

# Wait for MySQL to be healthy
echo ""
echo "4. Waiting for MySQL to be ready..."
echo "   (This may take 10-30 seconds...)"

MAX_WAIT=60
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
    if docker-compose ps mysql | grep -q "healthy"; then
        echo "   ✓ MySQL is ready!"
        break
    fi
    sleep 5
    COUNTER=$((COUNTER + 5))
    echo "   Waiting... (${COUNTER}s/${MAX_WAIT}s)"
done

if [ $COUNTER -ge $MAX_WAIT ]; then
    echo "   ✗ MySQL failed to become healthy within ${MAX_WAIT} seconds"
    echo "   Check logs with: docker-compose logs mysql"
    exit 1
fi

# Run the initialization script
echo ""
echo "5. Creating and populating Northwind database..."
cd mysql
./renew-northwind.sh
EXIT_CODE=$?
cd ..

# Check if initialization was successful
if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Success!"
    echo "=========================================="
    echo ""
    echo "MySQL is running with Northwind database"
    echo ""
    echo "Connection details:"
    echo "  Host:     localhost"
    echo "  Port:     3306"
    echo "  Database: Northwind"
    echo "  Username: root"
    echo "  Password: YourStrong@Passw0rd"
    echo ""
    echo "Connect using:"
    echo "  docker exec -it northwind-mysql mysql -u root -pYourStrong@Passw0rd -D Northwind"
    echo ""
    echo "Sample query:"
    echo "  SELECT * FROM Customer LIMIT 5;"
    echo ""
    echo "To stop: docker-compose down"
    echo "=========================================="
else
    echo ""
    echo "✗ Database initialization failed"
    echo "Check logs with: docker-compose logs mysql"
    exit 1
fi
