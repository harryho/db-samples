Northwind sample database for MySql, PostgresQL, and more
====

This project is inspired by [Microsoft Sample Databases](https://github.com/Microsoft/sql-server-samples), but it only targets other databases, such as MySql, PostgresQL, etc. 

This folder contains scripts to create and load the Northwind sample databases.


If you are looking for the script of MS Sql Server, please check out the repository from their github.

This project is created to create a sample CRM-like demo database in a few seconds with tiny test data.

## Quick Start with Docker (Recommended)

The easiest way to get started is using Docker Compose, which provides pre-configured containers for MySQL, PostgreSQL, and MS SQL Server.

### Prerequisites

- [Docker](https://www.docker.com/get-started) installed and running
- [Docker Compose](https://docs.docker.com/compose/install/) (included with Docker Desktop)

### Starting Database Servers

**Start all database servers:**
```bash
docker-compose up -d
```

**Start specific database server:**
```bash
# MySQL only
docker-compose up -d mysql

# PostgreSQL only
docker-compose up -d postgres

# MS SQL Server only
docker-compose up -d mssql
```

### Creating and Refreshing Databases (Recommended)

Use the provided renewal scripts to quickly create or refresh databases with sample data:

**MySQL:**
```bash
./renew-mysql.sh
```
- Recreates the MySQL container with fresh data
- Database: `northwind` (lowercase, case-insensitive)
- Port: 3306
- Username: `root`
- Password: `YourStrong@Passw0rd`

**PostgreSQL:**
```bash
./renew-postgres.sh
```
- Recreates the PostgreSQL container with fresh data
- Database: `northwind`
- Port: 5432
- Username: `postgres`
- Password: `YourStrong@Passw0rd`

**MS SQL Server:**
```bash
./renew-mssql.sh
```
- Recreates the MS SQL Server container with fresh data
- Database: `northwind`
- Port: 1433
- Username: `sa`
- Password: `YourStrong@Passw0rd`

### Connection Examples

**MySQL:**
```bash
# Using Docker
docker exec -it mysql-infra mysql -u root -pYourStrong@Passw0rd -D northwind

# Using local MySQL client
mysql -h localhost -P 3306 -u root -pYourStrong@Passw0rd -D northwind
```

**PostgreSQL:**
```bash
# Using Docker
docker exec -it postgres-infra psql -U postgres -d northwind

# Using local psql client
psql -h localhost -p 5432 -U postgres -d northwind
```

**MS SQL Server:**
```bash
# Using Docker
docker exec -it northwind-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -d northwind -C

# Using local sqlcmd (if installed)
sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -d northwind
```

### Database Features

**MySQL Configuration:**
- **Case-insensitive table names**: Query using `customer`, `Customer`, or `CUSTOMER`
- **Collation**: `utf8mb4_0900_ai_ci` (accent and case insensitive)
- All 13 tables with sample data

**PostgreSQL Configuration:**
- Full Northwind schema with constraints
- Sample data included

**MS SQL Server Configuration:**
- Northwind database with singular table names
- Compatible with SQL Server 2022

### Stopping and Removing Containers

```bash
# Stop all containers
docker-compose down

# Stop and remove all data volumes (WARNING: deletes all data)
docker-compose down -v
```

## Manual Database Installation (Without Docker)

If you prefer to install databases manually without Docker, you can use the SQL scripts directly with your local database installations.

### Caveat

The sample databases in the project are customized. Some tables' and columns' names have been changed on purpose. 

### Difference from the sample of MS Sql Server

* Additional columns on some tables, e.g. email, mobile. 
* All photo sample data has been removed, and additional photoPath is added for flexible implementation.
* NorthwindCore is designed for Entity Framework

### ER Diagram

* The ER diagram only contains PK and FKs
* The ER file is created by MySQl Workbrench. You can open the file with the same tool.

#### Northwind 


![northwind_er_diagram](mysql/northwind_er_diagram.png)

####  NorthwindCore


* Every table in NorthwindCore contains column EntityId.  

![northwindcore_er_diagram](mysql/northwindcore_er_diagram.png)



### Restore the database from SQL script

> **Note:** For easier setup, consider using the [Docker method](#quick-start-with-docker-recommended) with the `./renew-mysql.sh` or other renewal scripts.

#### MySql

**Using the renewal script (recommended):**
```bash
cd mysql
./renew-northwind.sh
```

**Manual import:**
```bash
mysql -u user_id -p northwind < mysql/northwind.sql
```


#### PostgresQL

**Using the renewal script (recommended):**
```bash
cd pgsql
./renew-northwind.sh
```

**Manual import:**
```bash
sudo su - postgres
psql -d postgres -U postgres -f pgsql/northwind.sql
```

#### MongoDB

* Firstly, install MongoDB community server, shell and tools
* Launch the mongoDB server

```
# Launch mongodb in Linux 
systemctl start mongod

```

* Create the db northwind and import the data

```
sh mongo_import.sh

echo "db.getCollectionNames()" > getColNames.js

mongo mongodb://localhost/northwind < getColNames.js

# You may see some output as follow:
# .......
# ......
# MongoDB server version: x.x.x
# [
# 	"category",
# 	"customer",
# 	"employee",
# 	"employeeTerritory",
# 	"orderDetail",
# 	"product",
# 	"region",
# 	"salesOrder",
# 	"shipper",
# 	"supplier",
# 	"territory"
# ]

```

#### Sqlite

* Install [sqlite3](https://www.sqlite.org/)
* Create northwind db

```
cd db-samples/sqlite3
sqlite3 northwind.db < northwind_core.sql
sqlite3 northwind.db
>.tables
```

#### Json Flat file

* Json flat file is great for intergation test or demostraction
* Folder json contains a few json flat files
* json_data.min.json is the original data set
* json_tiny.json is version with only a small data set

# MS SQL Server

This folder `mssql` contains the Northwind database SQL script and utilities for MS SQL Server.

> **Note:** This version uses **singular** table names (e.g., `Customer`, `SalesOrder`, `Product`) instead of plural names. This differs from the official Microsoft Northwind database which uses plural table names (e.g., `Customers`, `Orders`, `Products`).

**Using the renewal script (recommended):**
```bash
cd mssql
./renew-northwind.sh
```

**Manual import:**
```bash
sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -i mssql/northwind.sql
```

## Docker Compose Configuration

The `docker-compose.yml` file includes optimized configurations for all three database servers:

- **MySQL**: Case-insensitive table names (`lower_case_table_names=1`), utf8mb4 collation
- **PostgreSQL**: Alpine-based lightweight image, health checks enabled
- **MS SQL Server**: Express edition, automatic initialization support

To view container logs:
```bash
docker-compose logs mysql
docker-compose logs postgres
docker-compose logs mssql
```

## Troubleshooting

**Container won't start:**
```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs <service-name>

# Restart a specific service
docker-compose restart <service-name>
```

**Database connection refused:**
- Wait 10-30 seconds after starting containers for databases to initialize
- Check if the container is healthy: `docker-compose ps`
- Verify port is not already in use: `lsof -i :3306` (MySQL), `lsof -i :5432` (PostgreSQL), `lsof -i :1433` (MSSQL)

**Reset everything:**
```bash
# Stop containers and remove volumes (deletes all data)
docker-compose down -v

# Restart fresh
./renew-mysql.sh    # or renew-postgres.sh, or renew-mssql.sh
```



### TODO

* ~~Add script for MongoDB~~
* ~~Add script for Sqlite~~
* Add Mongo container



