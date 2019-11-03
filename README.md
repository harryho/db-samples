Northwind sample database for other databases except MS Sql Server
====

This folder contains scripts to create and load the Northwind sample databases.


If you are looking for the script of MS Sql Server, please check out the repository from their github.

This project is created to create a sample CRM-like demo database in a few seconds with tiny test data.

### Difference from the sample of MS Sql Server

* Additional columns on some tables, e.g. email, mobile. 
* All photo sample data has been removed, and additional photoPath is added for flexible implementation.


### ER Diagram

* The ER diagram only contains PK and FKs
* The ER file is created by MySQl Workbrench. You can open the file with the same tool.

![mysql_er_diagram](mysql/northwind_er_diagram.png)



### TODO

* Add script for PostgresQL
* Add script for MongoDB




