Northwind sample database for other databases except MS Sql Server
====

This project is inspired by [Microsoft Sample Databases](https://github.com/Microsoft/sql-server-samples), but it only targets other databases. 

This folder contains scripts to create and load the Northwind sample databases.


If you are looking for the script of MS Sql Server, please check out the repository from their github.

This project is created to create a sample CRM-like demo database in a few seconds with tiny test data.

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

### TODO

* Add script for PostgresQL
* Add script for MongoDB




