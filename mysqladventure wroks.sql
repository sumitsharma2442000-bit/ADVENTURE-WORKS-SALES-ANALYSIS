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

#______________________________________________________________
select * from master_sales;


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
    
    
#________________________________________________________________
    select * from master_product;

#________________________________________________________________

# DATA CLEANING & HANDLING MISSING VALUES & CHANGING DATA TYPES

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



# Lookup the Productname from the Product sheet to Sales sheet.
   
#________________________________________________________________   
select 
    s.*,p.EnglishProductName as product_name from master_sales as s 
    left join master_product as p 
    on s.ProductKey = p.ProductKey;
    
#________________________________________________________________
#Lookup the Customerfullname from the Customer Table and List Price 
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


#_____________________________________________________________________
# CALCULATIONS 
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

#Calculate the Sales amount using the columns (Unit price, Order quantity, Unit discount)
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
 
 
# EXPLORING THE DATA 
#______________________________________________________________________
# Overall Sales, Profit, Production Cost, and Profit Margin (%) – KPI Summary
SELECT 
    SUM(Sales) AS SALES,
    SUM(Profit) AS PROFIT,
    SUM(ProductionCost) AS PRODUCTION_COST,
    CONCAT(ROUND((SUM(Profit) / NULLIF(SUM(Sales), 0)) * 100, 2),"%") AS PROFIT_MARGIN_PERCENT
FROM Master_Sales;

#______________________________________________________________________
#Monthly Sales, Profit, Production Cost, and Profit Margin (%) 
SELECT 
    MONTHNAME(OrderDate) AS MONTH_NAME,
    SUM(Sales) AS SALES,
    SUM(Profit) AS PROFIT,
    SUM(ProductionCost) AS PRODUCTION_COST,
    CONCAT(ROUND((SUM(Profit) / NULLIF(SUM(Sales), 0)) * 100, 2),"%") AS PROFIT_MARGIN_PERCENT
FROM Master_Sales
GROUP BY MONTH(OrderDate), MONTHNAME(OrderDate)
ORDER BY MONTH(OrderDate);


#______________________________________________________________________
#Quarterly Sales, Profit, Production Cost, and Profit Margin (%)
SELECT
    CONCAT('QTR-', QUARTER(OrderDate)) AS QUARTER,
    SUM(Sales) AS SALES,
    SUM(Profit) AS PROFIT,
    SUM(ProductionCost) AS PRODUCTION_COST,
    CONCAT(ROUND((SUM(Profit) / NULLIF(SUM(Sales), 0)) * 100, 2),"%") AS PROFIT_MARGIN_PERCENT
FROM Master_Sales
GROUP BY QUARTER(OrderDate), CONCAT('QTR-', QUARTER(OrderDate))
ORDER BY QUARTER(OrderDate);


#______________________________________________________________________
#Yearly Sales, Profit, Production Cost, and Profit Margin (%)
SELECT
    YEAR(OrderDate) AS YEAR,
    SUM(Sales) AS SALES,
    SUM(Profit) AS PROFIT,
    SUM(ProductionCost) AS PRODUCTION_COST,
    CONCAT(ROUND((SUM(Profit) / NULLIF(SUM(Sales), 0)) * 100, 2),"%") AS PROFIT_MARGIN_PERCENT
FROM Master_Sales
GROUP BY YEAR(OrderDate)
ORDER BY YEAR(OrderDate) ASC;

#______________________________________________________________________  
  # Gender-wise Sales, Profit, and Profit Margin (%)
SELECT 
    C.Gender AS GENDER,
    SUM(S.Sales) AS SALES,
    SUM(S.Profit) AS PROFIT,
    CONCAT(ROUND((SUM(S.Profit) / NULLIF(SUM(S.Sales), 0)) * 100, 2),"%") AS PROFIT_MARGIN_PERCENT
FROM Master_Sales AS S
LEFT JOIN DimCustomer AS C 
    ON S.CustomerKey = C.CustomerKey
GROUP BY C.Gender;

#______________________________________________________________________
# Marital Status-wise Sales, Profit, and Profit Margin (%)
SELECT 
    C.MaritalStatus AS MARITAL_STATUS,
    SUM(S.Sales) AS SALES,
    SUM(S.Profit) AS PROFIT,
    CONCAT(ROUND((SUM(S.Profit) / NULLIF(SUM(S.Sales), 0)) * 100, 2),"%") AS PROFIT_MARGIN_PERCENT
FROM Master_Sales AS S
LEFT JOIN DimCustomer AS C 
    ON S.CustomerKey = C.CustomerKey
GROUP BY C.MaritalStatus;

#______________________________________________________________________
# Top 5 Products by Sales with Profit, Production Cost, and Profit Margin (%)
 SELECT 
    C.EnglishProductName AS PRODUCT,
    SUM(S.SALES) AS SALES,
    SUM(S.PROFIT) AS PROFIT,
    SUM(S.PRODUCTIONCOST) AS PRODUCTION_COST,
    CONCAT(ROUND((SUM(S.PROFIT) / NULLIF(SUM(S.SALES), 0)) * 100, 2),"%") AS PROFIT_MARGIN_PERCENT
FROM MASTER_SALES AS S
LEFT JOIN master_product AS C 
    ON S.ProductKey = C.ProductKey
GROUP BY C.EnglishProductName
ORDER BY SALES DESC
LIMIT 5;

#________________________________________________________________________________________________________
# Product Category Sales, Profit, Production Cost, and Profit Margin (%)
SELECT 
    C.EnglishProductCategoryName AS PRODUCT_CATEGORY,
    SUM(S.SALES) AS SALES,
    SUM(S.PROFIT) AS PROFIT,
    SUM(S.PRODUCTIONCOST) AS PRODUCTION_COST,
    CONCAT(ROUND((SUM(S.PROFIT) / NULLIF(SUM(S.SALES), 0)) * 100, 2),"%") AS PROFIT_MARGIN_PERCENT
FROM MASTER_SALES AS S
LEFT JOIN master_product AS C 
    ON S.ProductKey = C.ProductKey
GROUP BY C.EnglishProductCategoryName
ORDER BY SALES DESC;

#________________________________________________________________________________________________________
# Country-wise Sales, Profit, Production Cost, and Profit Margin (%)
    SELECT
    D.SalesTerritoryCountry AS COUNTRY,
    SUM(S.Sales) AS SALES,
    SUM(S.Profit) AS PROFIT,
    SUM(S.ProductionCost) AS PRODUCTION_COST,
    CONCAT(ROUND((SUM(S.Profit) / NULLIF(SUM(S.Sales), 0)) * 100, 2),"%") AS PROFIT_MARGIN_PERCENT
FROM Master_Sales AS S
LEFT JOIN dimSalesTerritory AS D
    ON S.SalesTerritoryKey = D.SalesTerritoryKey
GROUP BY D.SalesTerritoryCountry
ORDER BY SALES DESC;


