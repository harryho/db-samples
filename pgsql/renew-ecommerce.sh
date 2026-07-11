#!/bin/bash

# Script to renew the ecommerce database in PostgreSQL
# Drops and recreates the database, then loads pgsql/ecommerce.sql

set -e  # Exit on error

# Default connection parameters
HOST="${POSTGRES_HOST:-localhost}"
PORT="${POSTGRES_PORT:-5432}"
USERNAME="${POSTGRES_USER:-postgres}"
PASSWORD="${POSTGRES_PASSWORD:-YourStrong!Passw0rd}"
DATABASE="ecommerce"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="${SCRIPT_DIR}/ecommerce.sql"

echo "=========================================="
echo "Renewing Ecommerce Database (PostgreSQL)"
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

check_psql() {
    if command -v psql &> /dev/null; then
        echo "Using local psql"
        USE_DOCKER=false
    elif docker ps --format '{{.Names}}' | grep -q "pgsql-infra"; then
        echo "Using psql from Docker container"
        USE_DOCKER=true
    else
        echo "Error: psql not found and Docker container 'pgsql-infra' is not running"
        echo ""
        echo "Options:"
        echo "1. Install PostgreSQL client tools"
        echo "2. Run the Docker container: docker-compose up -d postgres"
        exit 1
    fi
}

run_psql() {
    if [ "$USE_DOCKER" = true ]; then
        docker exec -i pgsql-infra psql -U postgres "$@"
    else
        PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USERNAME" "$@"
    fi
}

check_psql

echo "1. Testing connection to PostgreSQL..."
run_psql -c "SELECT version();" > /dev/null
echo "   ✓ Connected successfully"

echo ""
echo "2. Dropping existing database (if exists)..."
run_psql -c "
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = '${DATABASE}'
  AND pid <> pg_backend_pid();
" > /dev/null
run_psql -c "DROP DATABASE IF EXISTS ${DATABASE};" > /dev/null
echo "   ✓ Database dropped (if existed)"

echo ""
echo "3. Creating new database..."
run_psql -c "CREATE DATABASE ${DATABASE} WITH ENCODING='UTF8' TEMPLATE=template0;" > /dev/null
echo "   ✓ Database created"

echo ""
echo "4. Loading schema and data from ecommerce.sql..."
if [ "$USE_DOCKER" = true ]; then
    docker cp "$SQL_FILE" pgsql-infra:/tmp/ecommerce.sql
    docker exec -i pgsql-infra psql -U postgres -d "${DATABASE}" -v ON_ERROR_STOP=1 -q -f /tmp/ecommerce.sql
    docker exec -i pgsql-infra rm -f /tmp/ecommerce.sql
else
    PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "${DATABASE}" -v ON_ERROR_STOP=1 -q -f "$SQL_FILE"
fi
echo "   ✓ Loaded successfully"

echo ""
echo "5. Verifying database..."
TABLE_COUNT=$(run_psql -d "$DATABASE" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" | tr -d ' ')
echo "   ✓ Database contains ${TABLE_COUNT} tables (expected 16)"

echo ""
echo "=========================================="
echo "✓ Success!"
echo "=========================================="
echo ""
echo "Connect using:"
if [ "$USE_DOCKER" = true ]; then
    echo "  docker exec -it pgsql-infra psql -U postgres -d ${DATABASE}"
else
    echo "  psql -h ${HOST} -p ${PORT} -U ${USERNAME} -d ${DATABASE}"
fi
echo ""
echo "Sample query:"
echo "  SELECT * FROM products LIMIT 5;"
echo "=========================================="
