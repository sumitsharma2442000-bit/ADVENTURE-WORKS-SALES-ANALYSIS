use excelrprojects;

# creating master table sales
CREATE TABLE Master_sales (
    ProductKey INT,
    OrderDateKey DATE,
    DueDateKey DATE,
    ShipDateKey DATE,
    CustomerKey INT,
    PromotionKey INT,
    CurrencyKey INT,
    SalesTerritoryKey INT,
    SalesOrderNumber VARCHAR(25),
    SalesOrderLineNumber INT,
    RevisionNumber TINYINT,
    OrderQuantity INT,
    UnitPrice DECIMAL(10,2),
    ExtendedAmount DECIMAL(12,2),
    UnitPriceDiscountPct DECIMAL(5,4), 
    DiscountAmount DECIMAL(10,2),
    ProductStandardCost DECIMAL(10,2),
    TaxAmt DECIMAL(10,2),
    Freight DECIMAL(10,2),
    CarrierTrackingNumber VARCHAR(25),
    CustomerPONumber VARCHAR(25),
    OrderDate DATE,
    DueDate DATE,
    ShipDate DATE
);



insert into master_sales 
select * from excelrprojects.factinternetsales
union all 
select * from excelrprojects.fact_internet_sales_news;

# Merge Products, ProductCategory and ProductSubCategory Tables
CREATE TABLE master_product (
    ProductKey INT PRIMARY KEY,
    ProductAlternateKey VARCHAR(50),
    ProductCategoryKey INT,
    ProductSubcategoryKey INT,
    EnglishProductName VARCHAR(200),
    EnglishProductSubcategoryName VARCHAR(100),
    EnglishProductCategoryName VARCHAR(100),
    StandardCost DECIMAL(10,2),
    FinishedGoodsFlag BOOLEAN,
    Color VARCHAR(30),
    SafetyStockLevel INT,
    ReorderPoint INT,
    ListPrice DECIMAL(10,2),
    Size VARCHAR(20),
    Weight DECIMAL(10,2),
    DaysToManufacture INT,
    ProductLine VARCHAR(10),
    DealerPrice DECIMAL(10,2),
    Class VARCHAR(10),
    Style VARCHAR(10),
    ModelName VARCHAR(100),
    StartDate DATE,
    EndDate DATE,
    Status VARCHAR(20)
);



INSERT INTO master_Product
SELECT 
    p.ProductKey,
    p.ProductAlternateKey,
    c.ProductCategoryKey,
    p.ProductSubcategoryKey,
	p.EnglishProductName,
    sc.EnglishProductSubcategoryName,
    c.EnglishProductCategoryName,
    p.StandardCost,
    p.FinishedGoodsFlag,
    p.Color,
    p.SafetyStockLevel,
    p.ReorderPoint,
    p.ListPrice,
    p.Size,
    p.Weight,
    p.DaysToManufacture,
    p.ProductLine,
    p.DealerPrice,
    p.Class,
    p.Style,
    p.ModelName,
    p.StartDate,
    p.EndDate,
    p.Status

FROM DimProduct p
LEFT JOIN DimProductSubcategory sc 
    ON p.ProductSubcategoryKey = sc.ProductSubcategoryKey
LEFT JOIN DimProductCategory c 
    ON sc.ProductCategoryKey = c.ProductCategoryKey;
    
    # Lookup the Productname from the Product sheet to Sales sheet.
    
select 
    s.*,p.EnglishProductName as product_name from master_sales as s 
    left join master_product as p 
    on s.ProductKey = p.ProductKey;
    
    #Lookup the Customerfullname from the Customer Table and Unit Price 
    #from Product Table to Sales sheet.
 SELECT 
    s.*, 
    CONCAT(c.FirstName, ' ', c.MiddleName, ' ', c.LastName) AS CustomerFullName,
    p.ListPrice AS ListPrice
FROM master_sales AS s
LEFT JOIN master_product AS p 
    ON s.ProductKey = p.ProductKey
LEFT JOIN dimcustomer AS c  
    ON s.CustomerKey = c.CustomerKey;

# CONVERTING COLUMN DIMDATE STRING TO DATE FORMAT
SET SQL_SAFE_UPDATES = 0;
update dimdate
set datekey = str_to_date(DateKey , '%Y%m%d');

ALTER TABLE DIMDTAE
MODIFY COLUMN DATEKEY DATE;

# UPDATING ALTERNATE DATE COLUMN TO DATE AND HANDLING INACCURICIES

UPDATE DimDate
SET FullDateAlternateKey = '2014-12-31'
WHERE FullDateAlternateKey = '42004';

ALTER TABLE DimDate
MODIFY COLUMN FullDateAlternateKey DATETIME;

# DROPPED NULL ROWS IN ALL COLUMNS OF TERRITORY COLUMN
DELETE FROM dimsalesterritory
WHERE SalesTerritoryRegion IS NULL 
  AND SalesTerritoryCountry IS NULL 
  AND SalesTerritoryGroup IS NULL 
  AND SalesTerritoryAlternateKey = 0;

# HANDLING MISSING VALUES FOR PRODUCT TABLE
UPDATE MASTER_PRODUCT
SET 
    STANDARDCOST = 868.63,
    LISTPRICE = 1431.5,
    DEALERPRICE = 858.90
WHERE 
    PRODUCTKEY = 210 AND ProductAlternateKey = 'FR-R92B-58';


UPDATE MASTER_PRODUCT
SET 
    STANDARDCOST = 957.37,
    LISTPRICE = 1515.0,
    DEALERPRICE = 924.75
WHERE 
    PRODUCTKEY = 211 AND ProductAlternateKey = 'FR-R92R-58';



#  CALCULATIONS 
SELECT 
YEAR(OrderDate) AS `YEAR`,
MONTH(OrderDate) AS Monthno,
monthname(OrderDate) as Monthfullname,
quarter(OrderDate) as Qtr,
date_format(OrderDate,'%Y-%b') as YearMonth,
weekday(OrderDate) as WeekdayNumber,
dayname(orderdate) as weekdayname,
 CASE 
        WHEN MONTH(OrderDate) >= 4 THEN MONTH(OrderDate) - 3
        ELSE MONTH(OrderDate) + 9
    END AS FinancialMonth,

CASE 
        WHEN MONTH(OrderDate) BETWEEN 4 AND 6 THEN 'Q1'
        WHEN MONTH(OrderDate) BETWEEN 7 AND 9 THEN 'Q2'
        WHEN MONTH(OrderDate) BETWEEN 10 AND 12 THEN 'Q3'
        ELSE 'Q4'
    END AS FinancialQuarter
from master_sales; 

#  Calculate the Sales amount using the columns (Unit price, Order quantity, Unit discount)
#Calculate the Productioncost using the columns (Unit cost, Order quantity)
#Calculate the Profit. (Sales - ProductionCost)

ALTER TABLE MASTER_SALES 
ADD COLUMN SALES DECIMAL(11,2),
ADD COLUMN PRODUCTIONCOST DECIMAL(11,2),
ADD COLUMN PROFIT DECIMAL(11,2);

SET SQL_SAFE_UPDATES = 0 ;
UPDATE MASTER_SALES
SET 
    SALES = (UnitPrice * OrderQuantity) * (1 - UnitPriceDiscountPct),
    PRODUCTIONCOST = ProductStandardCost * OrderQuantity,
    PROFIT = ((UnitPrice * OrderQuantity) * (1 - UnitPriceDiscountPct)) - (ProductStandardCost * OrderQuantity);
 
# SALES,PROFIT,PRODUCTIONCOST BY MONTH 
SELECT 
  MONTHNAME(ORDERDATE) AS MonthName,
  SUM(SALES) AS TotalSales,
  SUM(PROFIT) AS PROFIT,
  SUM(PRODUCTIONCOST) AS PRODUCTIONCOST
FROM MASTER_SALES
GROUP BY MONTH(ORDERDATE), MONTHNAME(ORDERDATE)
ORDER BY MONTH(ORDERDATE);


# SALES BY QUARTER
SELECT 
concat("QTR -",QUARTER(ORDERDATE)),
  SUM(SALES) AS SALES
FROM MASTER_SALES 
GROUP BY QUARTER(ORDERDATE),concat("QTR -",QUARTER(ORDERDATE))
ORDER BY QUARTER(ORDERDATE) ASC;

# Salesamount and Productioncost , Profit by year 
SELECT
YEAR(ORDERDATE) ,
  SUM(SALES) AS SALES,
  SUM(PROFIT) AS PROFIT,
  SUM(PRODUCTIONCOST) AS PRODUCTION_COST
FROM MASTER_SALES 
GROUP BY YEAR(ORDERDATE)
order BY YEAR(ORDERDATE) asc ;

  
  # SALES, PROFIT AND PRODUCTION COST BY GENDER OF CUSTOMERS
  SELECT 
  ifnull(C.GENDER,'GrandTotal') AS GENDER,
  SUM(S.PROFIT) AS PROFIT ,
  SUM(S.SALES) AS SALES 
  FROM MASTER_SALES AS S LEFT JOIN 
  DIMCUSTOMER AS C 
  ON S.CustomerKey = C.CustomerKey
  GROUP BY C.GENDER with rollup
  ;

# SALES AND PROFIT BY MARITAL STATUS OF CUSTOMER 
  SELECT 
  ifnull(C.MaritalStatus, 'GrandTotal') AS MARITAL_STATUS,
  SUM(S.PROFIT) AS PROFIT ,
  SUM(S.SALES) AS SALES 
  FROM MASTER_SALES AS S LEFT JOIN 
  DIMCUSTOMER AS C 
  ON S.CustomerKey = C.CustomerKey
  GROUP BY C.MaritalStatus with rollup
  ;

# TOP 5 PRODUCT (by Order SALES)  with PROFIT AND PRODUCTION cost 
WITH cal1 AS (
  SELECT 
    C.EnglishProductName AS PRODUCT,
    SUM(S.PROFIT) AS PROFIT,
    SUM(S.SALES) AS SALES,
    SUM(S.PRODUCTIONCOST) AS PRODUCTION_COST
  FROM MASTER_SALES AS S
  LEFT JOIN master_product AS C 
    ON S.ProductKey = C.ProductKey
  GROUP BY C.EnglishProductName
  ORDER BY SALES DESC
  LIMIT 5
)
SELECT 
  IFNULL(PRODUCT, 'Grand_Total') AS PRODUCT,
  SUM(PROFIT) AS PROFIT,
  SUM(SALES) AS SALES,
  SUM(PRODUCTION_COST) AS PRODUCTION_COST
FROM cal1
GROUP BY PRODUCT WITH ROLLUP
ORDER BY 
  CASE WHEN PRODUCT IS NULL THEN 1 ELSE 0 END,
  SALES DESC;

# TOP 5 PRODUCTCATEGORY (by Order SALES)  with PROFIT AND PRODUCTION cost  
WITH cal1 AS (
  SELECT 
    C.EnglishProductCategoryName AS PRODUCTCATEGORY,
    SUM(S.PROFIT) AS PROFIT,
    SUM(S.SALES) AS SALES,
    SUM(S.PRODUCTIONCOST) AS PRODUCTION_COST
  FROM MASTER_SALES AS S
  LEFT JOIN master_product AS C 
    ON S.ProductKey = C.ProductKey
  GROUP BY C.EnglishProductCategoryName
)
SELECT 
  IFNULL(PRODUCTCATEGORY, 'Grand_Total') AS PRODUCTCATEGORY,
  SUM(SALES) AS SALES,
  SUM(PROFIT) AS PROFIT,
  SUM(PRODUCTION_COST) AS PRODUCTION_COST
FROM cal1
GROUP BY PRODUCTCATEGORY WITH ROLLUP
ORDER BY 
  CASE WHEN PRODUCTCATEGORY IS NULL THEN 1 ELSE 0 END,
  SALES DESC;

# TOP 5 COUNTRY BY SUM OF SALES,PROFIT 
WITH CAL1 AS (
SELECT 
 D.SalesTerritoryCountry AS COUNTRY,
 SUM(S.PROFIT) AS PROFIT ,
 SUM(S.SALES) AS SALES 
 FROM MASTER_SALES AS S LEFT JOIN dimsalesterritory AS D
 ON S.SalesTerritoryKey = D.SalesTerritoryKey
 GROUP BY D.SalesTerritoryCountry
 ORDER BY SALES DESC
 LIMIT 5)
 SELECT IFNULL(COUNTRY,'Grand_Total') as COUNTRY,SUM(SALES) AS SALES,SUM(PROFIT) AS PROFIT
 FROM CAL1 
 GROUP BY COUNTRY WITH ROLLUP
 ORDER BY CASE WHEN COUNTRY IS NULL THEN 1 ELSE 0 END , SALES DESC;
 