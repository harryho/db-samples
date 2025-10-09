# Northwind Database with MS SQL Server

This Docker Compose setup launches a Microsoft SQL Server container and automatically creates the Northwind database with sample data.

## Prerequisites

- Docker and Docker Compose installed on your system
- At least 2GB of available RAM for the SQL Server container

## Usage

### 1. Start the database

```bash
docker-compose up -d
```

This will:
- Start an MS SQL Server 2022 Express container
- Create a database named `northwind`
- Load all the sample data from `mssql/northwind.sql`

### 2. Connect to the database

**Connection details:**
- Server: `localhost,1433`
- Database: `northwind`
- Username: `sa`
- Password: `YourStrong@Passw0rd`

**Using sqlcmd (if you have SQL Server tools installed):**
```bash
sqlcmd -S localhost,1433 -U sa -P YourStrong@Passw0rd -d northwind
```

**Using Docker to connect:**
```bash
docker exec -it northwind-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -d northwind
```

### 3. Verify the installation

Once connected, you can run a simple query to verify the data was loaded:

```sql
SELECT COUNT(*) as TableCount 
FROM information_schema.tables 
WHERE table_type = 'BASE TABLE';
```

```sql
SELECT TOP 5 * FROM Customers;
```

### 4. Stop the database

```bash
docker-compose down
```

To also remove the data volume:
```bash
docker-compose down -v
```

## Database Schema

The Northwind database contains the following main tables:
- Categories
- Customers
- Employees
- Order Details
- Orders
- Products
- Shippers
- Suppliers
- Region
- Territories

## Security Notes

- The default SA password is `YourStrong@Passw0rd` - change this for production use
- The database is exposed on port 1433 - ensure your firewall is configured appropriately
- For production environments, consider using environment variables or Docker secrets for passwords

## Troubleshooting

### Container fails to start
- Ensure you have enough memory available (minimum 2GB)
- Check if port 1433 is already in use: `lsof -i :1433`

### Database initialization fails
- Check the logs: `docker-compose logs mssql-init`
- Verify the SQL file syntax in `mssql/northwind.sql`

### Connection issues
- Wait for the health check to pass: `docker-compose ps`
- Verify the container is running: `docker ps`