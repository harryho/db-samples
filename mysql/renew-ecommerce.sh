#!/bin/bash

# Script to renew the ecommerce database in MySQL
# Loads mysql/ecommerce.sql (the file includes DROP/CREATE DATABASE)

set -e  # Exit on error

# Default connection parameters
HOST="${MYSQL_HOST:-localhost}"
PORT="${MYSQL_PORT:-3306}"
USERNAME="${MYSQL_USER:-root}"
PASSWORD="${MYSQL_PASSWORD:-YourStrong!Passw0rd}"
DATABASE="ecommerce"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="${SCRIPT_DIR}/ecommerce.sql"

echo "=========================================="
echo "Renewing Ecommerce Database (MySQL)"
echo "=========================================="
echo ""
echo "Server: ${HOST}:${PORT}"
echo "Database: ${DATABASE}"
echo ""

if [ ! -f "$SQL_FILE" ]; then
    echo "Error: SQL file not found: $SQL_FILE"
    exit 1
fi

USE_DOCKER=false

check_mysql() {
    if command -v mysql &> /dev/null; then
        echo "Using local mysql"
        USE_DOCKER=false
    elif docker ps --format '{{.Names}}' | grep -q "mysql-infra"; then
        echo "Using mysql from Docker container"
        USE_DOCKER=true
    else
        echo "Error: mysql not found and Docker container 'mysql-infra' is not running"
        echo ""
        echo "Options:"
        echo "1. Install MySQL client tools"
        echo "2. Run the Docker container: docker-compose up -d mysql"
        exit 1
    fi
}

run_mysql() {
    if [ "$USE_DOCKER" = true ]; then
        docker exec -i mysql-infra mysql -u root -p"$PASSWORD" "$@"
    else
        mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" "$@"
    fi
}

check_mysql

echo "1. Testing connection to MySQL..."
run_mysql -e "SELECT VERSION();" > /dev/null 2>&1
echo "   ✓ Connected successfully"

echo ""
echo "2. Loading ecommerce.sql (includes DROP/CREATE DATABASE)..."
if [ "$USE_DOCKER" = true ]; then
    docker cp "$SQL_FILE" mysql-infra:/tmp/ecommerce.sql
    LOAD_OUTPUT=$(docker exec -i mysql-infra bash -c "mysql -u root -p'$PASSWORD' < /tmp/ecommerce.sql" 2>&1); LOAD_STATUS=$?
    docker exec mysql-infra rm -f /tmp/ecommerce.sql
else
    LOAD_OUTPUT=$(mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" < "$SQL_FILE" 2>&1); LOAD_STATUS=$?
fi
if [ $LOAD_STATUS -ne 0 ]; then
    echo "   ✗ Load failed:"
    echo "$LOAD_OUTPUT" | grep -v "Using a password"
    exit 1
fi
echo "   ✓ Loaded successfully"

echo ""
echo "3. Verifying database..."
TABLE_COUNT=$(run_mysql -D "$DATABASE" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${DATABASE}' AND table_type = 'BASE TABLE';" 2>/dev/null | tr -d ' ')
echo "   ✓ Database contains ${TABLE_COUNT} tables (expected 16)"
if [ "$TABLE_COUNT" != "16" ]; then
    echo "   ✗ Unexpected table count - run the file manually to see errors:"
    echo "     docker exec -i mysql-infra mysql -u root -p'...' < $SQL_FILE"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ Success!"
echo "=========================================="
echo ""
echo "Connect using:"
if [ "$USE_DOCKER" = true ]; then
    echo "  docker exec -it mysql-infra mysql -u root -p'${PASSWORD}' -D ${DATABASE}"
else
    echo "  mysql -h ${HOST} -P ${PORT} -u ${USERNAME} -p -D ${DATABASE}"
fi
echo ""
echo "Sample query:"
echo "  SELECT * FROM products LIMIT 5;"
echo "=========================================="
