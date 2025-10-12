#!/bin/bash

# Script to renew the Northwind database in MySQL
# This script drops and recreates the database with fresh data

set -e  # Exit on error

# Default connection parameters
HOST="${MYSQL_HOST:-localhost}"
PORT="${MYSQL_PORT:-3306}"
USERNAME="${MYSQL_USER:-root}"
PASSWORD="${MYSQL_PASSWORD:-YourStrong@Passw0rd}"
DATABASE="northwind"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="${SCRIPT_DIR}/northwind.sql"

echo "=========================================="
echo "Recreating northwind Database (MySQL)"
echo "=========================================="
echo ""
echo "Server: ${HOST}:${PORT}"
echo "Database: ${DATABASE}"
echo ""

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "Error: SQL file not found: $SQL_FILE"
    exit 1
fi

# Function to check if mysql is available
USE_DOCKER=false

check_mysql() {
    if command -v mysql &> /dev/null; then
        echo "Using local mysql"
        USE_DOCKER=false
        return 0
    elif docker ps --format '{{.Names}}' | grep -q "mysql-infra"; then
        echo "Using mysql from Docker container"
        USE_DOCKER=true
        return 0
    else
        echo "Error: mysql not found and Docker container 'mysql-infra' is not running"
        echo ""
        echo "Options:"
        echo "1. Install MySQL client tools"
        echo "2. Run the Docker container: docker-compose up -d mysql"
        exit 1
    fi
}

# Function to execute mysql
run_mysql() {
    if [ "$USE_DOCKER" = true ]; then
        docker exec -i mysql-infra mysql -u root -p"$PASSWORD" "$@"
    else
        mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" "$@"
    fi
}

# Check for mysql availability
check_mysql

# Test connection
echo "1. Testing connection to MySQL..."
run_mysql -e "SELECT VERSION();" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "   ✗ Failed to connect to MySQL"
    echo "   Please check your connection parameters"
    exit 1
fi
echo "   ✓ Connected successfully"

# The northwind.sql file includes DROP and CREATE DATABASE commands
# So we just need to execute the file
echo ""
echo "2. Loading northwind.sql (includes DROP/CREATE DATABASE)..."
echo "   (This may take a minute...)"

if [ "$USE_DOCKER" = true ]; then
    # Copy SQL file to container and execute it (without specifying database)
    docker cp "$SQL_FILE" mysql-infra:/tmp/northwind.sql
    docker exec -i mysql-infra bash -c "mysql -u root -p'$PASSWORD' < /tmp/northwind.sql" 2>/dev/null
    docker exec mysql-infra rm -f /tmp/northwind.sql
else
    # Connect without specifying database since SQL file includes CREATE DATABASE
    mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" < "$SQL_FILE" 2>/dev/null
fi

if [ $? -ne 0 ]; then
    echo "   ✗ Failed to load data from SQL file"
    echo "   Run manually to see errors:"
    if [ "$USE_DOCKER" = true ]; then
        echo "   docker exec -i mysql-infra mysql -u root -pYourStrong@Passw0rd < $SQL_FILE"
    else
        echo "   mysql -h $HOST -P $PORT -u $USERNAME -p$PASSWORD < $SQL_FILE"
    fi
    exit 1
fi
echo "   ✓ Database recreated successfully"

# Verify the database
echo ""
echo "3. Verifying database..."
TABLE_COUNT=$(run_mysql -D "$DATABASE" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${DATABASE}' AND table_type = 'BASE TABLE';" 2>/dev/null | tr -d ' ')

echo "   ✓ Database contains ${TABLE_COUNT} tables"

echo ""
echo "=========================================="
echo "✓ Success!"
echo "=========================================="
echo ""
echo "Database '${DATABASE}' has been renewed successfully"
echo ""
if [ "$USE_DOCKER" = true ]; then
    echo "Connect using:"
    echo "  docker exec -it mysql-infra mysql -u root -p${PASSWORD} -D ${DATABASE}"
else
    echo "Connect using:"
    echo "  mysql -h ${HOST} -P ${PORT} -u ${USERNAME} -p${PASSWORD} -D ${DATABASE}"
fi
echo ""
echo "Sample query:"
echo "  SELECT * FROM Customer LIMIT 5;"
echo "=========================================="
