# Northwind Database with MS SQL Server

Docker setup for the Northwind sample database with MS SQL Server 2022.

> **Note:** This version uses **singular** table names (e.g., `Customer`, `SalesOrder`, `Product`).

## Quick Start

### 1. Start the database

```bash
docker-compose up -d
```

This starts MS SQL Server and automatically creates the `northwind` database with sample data.

### 2. Connect to the database

**Connection string:**
```
Server=localhost,1433;Database=northwind;User Id=sa;Password=YourStrong@Passw0rd;
```

**Using Docker:**
```bash
docker exec -it northwind-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P YourStrong@Passw0rd -d northwind
```

### 3. Query the database

```sql
-- List customers
SELECT TOP 5 CustomerID, CompanyName, Country FROM Customer;

-- Get orders
SELECT TOP 5 OrderID, CustomerID, OrderDate FROM SalesOrder;

-- Join customers with orders
SELECT c.CompanyName, COUNT(o.OrderID) as TotalOrders
FROM Customer c
LEFT JOIN SalesOrder o ON c.CustomerID = o.CustomerID
GROUP BY c.CompanyName;
```

### 4. Stop the database

```bash
docker-compose down
```

To remove data volume as well:
```bash
docker-compose down -v
```

## Main Tables

- **Customer** - Customer information
- **SalesOrder** - Customer orders
- **Order Details** - Order line items
- **Product** - Product catalog
- **Category** - Product categories
- **Employee** - Employee records
- **Supplier** - Product suppliers

For complete documentation, see `mssql/README.md`.

## Requirements

- Docker and Docker Compose
- 2GB+ available RAM

## Recreate Database

To reset the database with fresh data:

```bash
cd mssql
./renew-northwind.sh
```

## Security Note

⚠️ Default password is `YourStrong@Passw0rd` - change this for production use.