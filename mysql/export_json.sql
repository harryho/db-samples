
DROP TEMPORARY TABLE IF EXISTS tmp_json_data;

CREATE TEMPORARY TABLE tmp_json_data (
  jsonText TEXT,
  tableName VARCHAR(100)
); 
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'categoryName',  categoryName,
   'description',  description,
   'picture',  picture
 ) as json, 'Category' 
  FROM  Category ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'regiondescription',  regiondescription
 ) as json, 'Region' 
  FROM  Region ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'territoryCode',  territoryCode,
   'territorydescription',  territorydescription,
   'regionId',  regionId
 ) as json, 'Territory' 
  FROM  Territory ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'customerDesc',  customerDesc
 ) as json, 'CustomerDemographics' 
  FROM  CustomerDemographics ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'companyName',  companyName,
   'contactName',  contactName,
   'contactTitle',  contactTitle,
   'address',  address,
   'city',  city,
   'region',  region,
   'postalCode',  postalCode,
   'country',  country,
   'phone',  phone,
   'mobile',  mobile,
   'email',  email,
   'fax',  fax
 ) as json, 'Customer' 
  FROM  Customer ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'customerId',  customerId,
   'customerTypeId',  customerTypeId
 ) as json, 'CustomerCustomerDemographics' 
  FROM  CustomerCustomerDemographics ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'lastname',  lastname,
   'firstname',  firstname,
   'title',  title,
   'titleOfCourtesy',  titleOfCourtesy,
   'birthDate',  birthDate,
   'hireDate',  hireDate,
   'address',  address,
   'city',  city,
   'region',  region,
   'postalCode',  postalCode,
   'country',  country,
   'phone',  phone,
   'extension',  extension,
   'mobile',  mobile,
   'email',  email,
   'photo',  photo,
   'notes',  notes,
   'mgrId',  mgrId,
   'photoPath',  photoPath
 ) as json, 'Employee' 
  FROM  Employee ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'employeeId',  employeeId,
   'territoryCode',  territoryCode
 ) as json, 'EmployeeTerritory' 
  FROM  EmployeeTerritory ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'companyName',  companyName,
   'contactName',  contactName,
   'contactTitle',  contactTitle,
   'address',  address,
   'city',  city,
   'region',  region,
   'postalCode',  postalCode,
   'country',  country,
   'phone',  phone,
   'email',  email,
   'fax',  fax,
   'HomePage',  HomePage
 ) as json, 'Supplier' 
  FROM  Supplier ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'productName',  productName,
   'supplierId',  supplierId,
   'categoryId',  categoryId,
   'quantityPerUnit',  quantityPerUnit,
   'unitPrice',  unitPrice,
   'unitsInStock',  unitsInStock,
   'unitsOnOrder',  unitsOnOrder,
   'reorderLevel',  reorderLevel,
   'discontinued',  discontinued
 ) as json, 'Product' 
  FROM  Product ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'companyName',  companyName,
   'phone',  phone
 ) as json, 'Shipper' 
  FROM  Shipper ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'customerId',  customerId,
   'employeeId',  employeeId,
   'orderDate',  orderDate,
   'requiredDate',  requiredDate,
   'shippedDate',  shippedDate,
   'shipperId',  shipperId,
   'freight',  freight,
   'shipName',  shipName,
   'shipAddress',  shipAddress,
   'shipCity',  shipCity,
   'shipRegion',  shipRegion,
   'shipPostalCode',  shipPostalCode,
   'shipCountry',  shipCountry
 ) as json, 'SalesOrder' 
  FROM  SalesOrder ; 
  
 
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object( 
   'entityId',  entityId,
   'orderId',  orderId,
   'productId',  productId,
   'unitPrice',  unitPrice,
   'quantity',  quantity,
   'discount',  discount
 ) as json, 'OrderDetail' 
  FROM  OrderDetail ; 
   
SET SESSION  group_concat_max_len = 999096;


-- Group the data in table tmp_json_data with table name
-- Use group_concat to concat jsonText, which contains a row of data,
-- into an array. And then wrap the array with square brackets 
SELECT concat('"',j.tableName,'":[', j.jtxt, '],')
INTO OUTFILE '/var/lib/mysql-files/json_data.json'
FROM (
SELECT tableName, group_concat(jsonText) jtxt
FROM tmp_json_data 
GROUP BY tableName ) AS j

