#!/bin/bash

# Script to renew the Northwind database in PostgreSQL
# This script drops and recreates the database with fresh data

set -e  # Exit on error

# Default connection parameters
HOST="${POSTGRES_HOST:-localhost}"
PORT="${POSTGRES_PORT:-5432}"
USERNAME="${POSTGRES_USER:-postgres}"
PASSWORD="${POSTGRES_PASSWORD:-YourStrong@Passw0rd}"
DATABASE="northwind"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="${SCRIPT_DIR}/northwind.sql"

echo "=========================================="
echo "Renewing Northwind Database (PostgreSQL)"
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

# Function to check if psql is available
USE_DOCKER=false

check_psql() {
    if command -v psql &> /dev/null; then
        echo "Using local psql"
        USE_DOCKER=false
        return 0
    elif docker ps --format '{{.Names}}' | grep -q "postgres-infra"; then
        echo "Using psql from Docker container"
        USE_DOCKER=true
        return 0
    else
        echo "Error: psql not found and Docker container 'postgres-infra' is not running"
        echo ""
        echo "Options:"
        echo "1. Install PostgreSQL client tools"
        echo "2. Run the Docker container: docker-compose up -d postgres"
        exit 1
    fi
}

# Function to execute psql
run_psql() {
    if [ "$USE_DOCKER" = true ]; then
        docker exec -i postgres-infra psql -U postgres "$@"
    else
        PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USERNAME" "$@"
    fi
}

# Check for psql availability
check_psql

# Test connection
echo "1. Testing connection to PostgreSQL..."
run_psql -c "SELECT version();" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "   ✗ Failed to connect to PostgreSQL"
    echo "   Please check your connection parameters"
    exit 1
fi
echo "   ✓ Connected successfully"

# Drop database if it exists (must disconnect all users first)
echo ""
echo "2. Dropping existing database (if exists)..."
run_psql -c "
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = '${DATABASE}'
  AND pid <> pg_backend_pid();
" > /dev/null 2>&1

run_psql -c "DROP DATABASE IF EXISTS ${DATABASE};" > /dev/null 2>&1
echo "   ✓ Database dropped (if existed)"

# Create new database
echo ""
echo "3. Creating new database..."
run_psql -c "CREATE DATABASE ${DATABASE} WITH ENCODING='UTF8' TEMPLATE=template0;" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "   ✗ Failed to create database"
    exit 1
fi
echo "   ✓ Database created"

# Load data from SQL file (skip the CREATE/DROP DATABASE commands)
echo ""
echo "4. Loading data from northwind.sql..."
echo "   (This may take a minute...)"

# Extract only the table creation and data insertion parts (skip database creation)
if [ "$USE_DOCKER" = true ]; then
    # Copy SQL file and process it in the container
    docker cp "$SQL_FILE" postgres-infra:/tmp/northwind.sql
    docker exec -i postgres-infra bash -c "
        sed -n '/^DROP TABLE/,\$p' /tmp/northwind.sql | psql -U postgres -d ${DATABASE} > /dev/null 2>&1
        rm -f /tmp/northwind.sql
    "
else
    sed -n '/^DROP TABLE/,$p' "$SQL_FILE" | PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$DATABASE" > /dev/null 2>&1
fi

if [ $? -ne 0 ]; then
    echo "   ✗ Failed to load data from SQL file"
    echo "   Run manually to see errors:"
    if [ "$USE_DOCKER" = true ]; then
        echo "   docker exec -i postgres-infra psql -U postgres -d ${DATABASE} < $SQL_FILE"
    else
        echo "   psql -h $HOST -p $PORT -U $USERNAME -d $DATABASE < $SQL_FILE"
    fi
    exit 1
fi
echo "   ✓ Data loaded successfully"

# Verify the database
echo ""
echo "5. Verifying database..."
TABLE_COUNT=$(run_psql -d "$DATABASE" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" | tr -d ' ')

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
    echo "  docker exec -it postgres-infra psql -U postgres -d ${DATABASE}"
else
    echo "Connect using:"
    echo "  psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE}"
fi
echo ""
echo "Sample query:"
echo "  SELECT * FROM Customer LIMIT 5;"
echo "=========================================="
