#!/bin/bash

# Script to renew the Northwind database from northwind.sql
# This script drops and renews the database with fresh data

set -e  # Exit on error

# Default connection parameters
SERVER="${MSSQL_SERVER:-localhost}"
PORT="${MSSQL_PORT:-1433}"
USERNAME="${MSSQL_USER:-sa}"
PASSWORD="${MSSQL_PASSWORD:-YourStrong@Passw0rd}"
DATABASE="northwind"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="${SCRIPT_DIR}/northwind.sql"

echo "=========================================="
echo "Recreating Northwind Database"
echo "=========================================="
echo ""
echo "Server: ${SERVER}:${PORT}"
echo "Database: ${DATABASE}"
echo ""

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "Error: SQL file not found: $SQL_FILE"
    exit 1
fi

# Function to check if sqlcmd is available
check_sqlcmd() {
    if command -v sqlcmd &> /dev/null; then
        echo "Using local sqlcmd"
        SQLCMD="sqlcmd"
        return 0
    elif docker ps --format '{{.Names}}' | grep -q "northwind-mssql"; then
        echo "Using sqlcmd from Docker container"
        SQLCMD="docker exec -i northwind-mssql /opt/mssql-tools/bin/sqlcmd"
        return 0
    else
        echo "Error: sqlcmd not found and Docker container 'northwind-mssql' is not running"
        echo ""
        echo "Options:"
        echo "1. Install SQL Server command-line tools"
        echo "2. Run the Docker container: docker-compose up -d mssql"
        exit 1
    fi
}

# Check for sqlcmd availability
check_sqlcmd

# Test connection
echo "1. Testing connection to SQL Server..."
$SQLCMD -S ${SERVER},${PORT} -U ${USERNAME} -P ${PASSWORD} -Q "SELECT @@VERSION" -h -1 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "   ✗ Failed to connect to SQL Server"
    echo "   Please check your connection parameters"
    exit 1
fi
echo "   ✓ Connected successfully"

# Drop database if it exists
echo ""
echo "2. Dropping existing database (if exists)..."
$SQLCMD -S ${SERVER},${PORT} -U ${USERNAME} -P ${PASSWORD} -Q "
IF EXISTS (SELECT name FROM sys.databases WHERE name = '${DATABASE}')
BEGIN
    ALTER DATABASE [${DATABASE}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [${DATABASE}];
    PRINT 'Database ${DATABASE} dropped successfully';
END
ELSE
BEGIN
    PRINT 'Database ${DATABASE} does not exist';
END
" -h -1

# Create new database
echo ""
echo "3. Creating new database..."
$SQLCMD -S ${SERVER},${PORT} -U ${USERNAME} -P ${PASSWORD} -Q "
CREATE DATABASE [${DATABASE}];
PRINT 'Database ${DATABASE} created successfully';
" -h -1

if [ $? -ne 0 ]; then
    echo "   ✗ Failed to create database"
    exit 1
fi
echo "   ✓ Database created"

# Load data from SQL file
echo ""
echo "4. Loading data from northwind.sql..."
echo "   (This may take a minute...)"

$SQLCMD -S ${SERVER},${PORT} -U ${USERNAME} -P ${PASSWORD} -d ${DATABASE} -i "$SQL_FILE" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "   ✗ Failed to load data from SQL file"
    echo "   Run manually to see errors:"
    echo "   $SQLCMD -S ${SERVER},${PORT} -U ${USERNAME} -P ${PASSWORD} -d ${DATABASE} -i $SQL_FILE"
    exit 1
fi
echo "   ✓ Data loaded successfully"

# Verify the database
echo ""
echo "5. Verifying database..."
TABLE_COUNT=$($SQLCMD -S ${SERVER},${PORT} -U ${USERNAME} -P ${PASSWORD} -d ${DATABASE} -Q "
SET NOCOUNT ON;
SELECT COUNT(*) FROM information_schema.tables WHERE table_type = 'BASE TABLE';
" -h -1 | tr -d ' ')

echo "   ✓ Database contains ${TABLE_COUNT} tables"

echo ""
echo "=========================================="
echo "✓ Success!"
echo "=========================================="
echo ""
echo "Database '${DATABASE}' has been renewd successfully"
echo ""
echo "Connect using:"
echo "  $SQLCMD -S ${SERVER},${PORT} -U ${USERNAME} -P ${PASSWORD} -d ${DATABASE}"
echo ""
echo "Sample query:"
echo "  SELECT TOP 5 * FROM Customers;"
echo "=========================================="
