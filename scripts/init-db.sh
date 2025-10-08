#!/bin/bash

# Wait for SQL Server to be ready
echo "Waiting for SQL Server to start..."
sleep 30

# Create the northwind database
echo "Creating northwind database..."
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -Q "CREATE DATABASE northwind;"

# Check if database was created successfully
if [ $? -eq 0 ]; then
    echo "Database 'northwind' created successfully."
    
    # Run the northwind.sql script to populate the database
    echo "Loading northwind.sql data..."
    /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -d northwind -i /docker-entrypoint-initdb.d/northwind.sql
    
    if [ $? -eq 0 ]; then
        echo "Northwind database setup completed successfully!"
    else
        echo "Error: Failed to load northwind.sql data."
        exit 1
    fi
else
    echo "Error: Failed to create northwind database."
    exit 1
fi