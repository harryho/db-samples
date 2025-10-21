# Northwind Database for MS SQL Server

This folder contains the Northwind database SQL script and utilities for MS SQL Server.

> **Note:** This version uses **singular** table names (e.g., `Customer`, `SalesOrder`, `Product`) instead of plural names. This differs from the official Microsoft Northwind database which uses plural table names (e.g., `Customers`, `Orders`, `Products`).

## Files

- **northwind.sql** - Complete database schema and data with singular table names
- **renew-northwind.sh** - Script to recreate the Northwind database from scratch
- **northwind.sql.backup** - Original version with plural table names (backup)
- **northwind_order.sql.backup** - Version with `Order` table name (before SalesOrder rename)

## Quick Start

### Using the renew script (Recommended)

```bash
cd mssql
./renew-northwind.sh
```

The script will automatically:
1. Drop the existing `northwind` database (if it exists)
2. Create a fresh `northwind` database
3. Load all schema and data from `northwind.sql`
4. Verify the installation

### Manual setup

```bash
# Create the database
sqlcmd -S localhost,1433 -U sa -P YourStrong@Passw0rd -Q "CREATE DATABASE northwind;"

# Load the data
sqlcmd -S localhost,1433 -U sa -P YourStrong@Passw0rd -d northwind -i northwind.sql
```

## Database Schema

### Tables (Singular Names)
- **Category** - Product categories
- **Customer** - Customer information
- **Employee** - Employee records
- **EmployeeTerritory** - Employee-territory assignments
- **SalesOrder** - Customer orders
- **OrderDetails** - Order line items
- **Product** - Product catalog
- **Region** - Sales regions
- **Shipper** - Shipping companies
- **Supplier** - Product suppliers
- **Territory** - Sales territories

### Sample Queries

```sql
-- Get customers
SELECT TOP 5 CustomerID, CompanyName, Country FROM Customer;

-- Get products
SELECT ProductID, ProductName, UnitPrice FROM Product WHERE UnitPrice > 20;

-- Get orders with customer info
SELECT o.OrderID, c.CompanyName, o.OrderDate 
FROM SalesOrder o 
JOIN Customer c ON o.CustomerID = c.CustomerID;
```

## Configuration

The `renew-northwind.sh` script uses environment variables for custom connection parameters:

```bash
export MSSQL_SERVER=localhost                  # Default: localhost
export MSSQL_PORT=1433                         # Default: 1433
export MSSQL_USER=sa                           # Default: sa
export MSSQL_PASSWORD=YourStrong@Passw0rd      # Default: YourStrong@Passw0rd

./renew-northwind.sh
```

## Requirements

The script automatically detects and uses:
- **sqlcmd** installed locally, OR
- **Docker container** named `mssql-infra`

## Differences from Microsoft Version

This version has been modified from the official Microsoft Northwind database:

| Microsoft Version | This Version |
|-------------------|--------------|
| Customers | **Customer** |
| Orders | **SalesOrder** |
| Products | **Product** |
| Employees | **Employee** |
| Categories | **Category** |
| Suppliers | **Supplier** |
| Shippers | **Shipper** |
| Territories | **Territory** |
| EmployeeTerritories | **EmployeeTerritory** |

All references, foreign keys, views, and stored procedures have been updated accordingly.
