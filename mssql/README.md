# Northwind Database for MS SQL Server

This folder contains the Northwind database SQL script and utilities for MS SQL Server.

## Files

- **northwind.sql** - Complete database schema and data for the Northwind sample database
- **renew-northwind.sh** - Script to renew the Northwind database from scratch

## Quick Start

### Option 1: Using the renew script (Recommended)

Simply run the script from the mssql directory:

```bash
cd mssql
./renew-northwind.sh
```

The script will:
1. Drop the existing `northwind` database (if it exists)
2. Create a fresh `northwind` database
3. Load all schema and data from `northwind.sql`
4. Verify the installation

### Option 2: Manual setup

If you prefer to run the SQL manually:

```bash
# Create the database
sqlcmd -S localhost,1433 -U sa -P YourStrong@Passw0rd -Q "CREATE DATABASE northwind;"

# Load the data
sqlcmd -S localhost,1433 -U sa -P YourStrong@Passw0rd -d northwind -i northwind.sql
```

## Configuration

The `renew-northwind.sh` script uses environment variables for connection parameters:

```bash
# Set custom connection parameters (optional)
export MSSQL_SERVER=localhost      # Default: localhost
export MSSQL_PORT=1433             # Default: 1433
export MSSQL_USER=sa               # Default: sa
export MSSQL_PASSWORD=YourStrong@Passw0rd  # Default: YourStrong@Passw0rd

# Run the script
./renew-northwind.sh
```

## Requirements

The script will automatically detect and use:
1. **sqlcmd** installed locally, OR
2. **Docker container** named `northwind-mssql` (if running)

If neither is available, the script will provide instructions.

## Usage Examples

### Example 1: Default connection (localhost)
```bash
./renew-northwind.sh
```

### Example 2: Remote server
```bash
MSSQL_SERVER=192.168.1.100 MSSQL_PASSWORD=MyPassword ./renew-northwind.sh
```

### Example 3: Using Docker container
```bash
# First, start the Docker container
docker-compose up -d mssql

# Then run the script (it will auto-detect the container)
./renew-northwind.sh
```

## Database Schema

The Northwind database includes:

### Tables
- Categories
- Customers
- Employees
- EmployeeTerritories
- Order Details
- Orders
- Products
- Region
- Shippers
- Suppliers
- Territories

### Views
- Alphabetical list of products
- Category Sales for 1997
- Current Product List
- Customer and Suppliers by City
- Invoices
- Order Details Extended
- Order Subtotals
- Orders Qry
- Product Sales for 1997
- Products Above Average Price
- Products by Category
- Quarterly Orders
- Sales by Category
- Sales Totals by Amount
- Summary of Sales by Quarter
- Summary of Sales by Year

### Stored Procedures
- CustOrderHist
- CustOrdersDetail
- CustOrdersOrders
- Employee Sales by Country
- Sales by Year
- SalesByCategory
- Ten Most Expensive Products

## Troubleshooting

### Connection failed
- Verify SQL Server is running: `docker ps` or check service status
- Check server address and port
- Verify username and password
- Ensure network connectivity to the server

### Script fails to find sqlcmd
- Install SQL Server command-line tools for your platform
- OR run SQL Server in Docker and ensure container is named `northwind-mssql`

### Database already in use
The script automatically handles this by forcing all connections to close before dropping the database.

## Notes

- The script uses `SET SINGLE_USER WITH ROLLBACK IMMEDIATE` to forcefully close existing connections before dropping the database
- All data will be lost when recreating the database
- The SQL file does not include database creation - it only creates objects within an existing database
