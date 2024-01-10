IF OBJECT_ID('tempdb..#Orders','U') IS NOT NULL
 DROP TABLE #Orders


CREATE TABLE #Orders
    (Orderid int identity, GiftCard int, TShirt int, Shipping int)

INSERT INTO #Orders
SELECT 1, NULL, 3 UNION ALL SELECT 2, 5, 4 UNION ALL SELECT 1, 3, 10

SELECT * FROM #Orders


SELECT OrderID, ProductName, ProductQty
FROM #Orders
 CROSS APPLY (
    VALUES ('GiftCard', GiftCard)
    ,('TShirt', TShirt)
    ,('Shipping', Shipping)) x(ProductName, ProductQty)
WHERE ProductQty IS NOT NULL
DROP TABLE #Orders


-------UNPIVOT Multiple Columns-----------------------------

IF OBJECT_ID('tempdb..#Suppliers','U') IS NOT NULL
  DROP TABLE #Suppliers

-- DDL and sample data for UNPIVOT Example 2
CREATE TABLE #Suppliers
    (ID INT, Product VARCHAR(500)
    ,Supplier1 VARCHAR(500), Supplier2 VARCHAR(500), Supplier3 VARCHAR(500)
    ,City1 VARCHAR(500), City2 VARCHAR(500), City3 VARCHAR(500))

-- Load Sample data
INSERT INTO #Suppliers
SELECT 1, 'Car', 'Honda', 'Toyota', 'Nissan', 'Detroit','Miami','Los Angeles'
UNION ALL SELECT 2, 'Bike', 'Schwinn', 'Roadmaster', 'Fleetwing', 'Cincinatti', 'Chicago', 'Tampa'
UNION ALL SELECT 3, 'Motorcycle', 'Harley', 'Yamaha', 'Kawasaki', 'Omaha', 'Dallas', 'Atlanta' -- NULL

SELECT * FROM #Suppliers

/*  -- traditional unpivot
SELECT Id, Product
    ,SuppID=ROW_NUMBER() OVER (PARTITION BY Id ORDER BY SupplierName)
    ,SupplierName, CityName
 FROM (
    SELECT ID, Product, Supplier1, Supplier2, Supplier3, City1, City2, City3
    FROM #Suppliers) Main
UNPIVOT (
    SupplierName FOR Suppliers IN (Supplier1, Supplier2, Supplier3)) Sup
UNPIVOT (
    CityName For Cities IN (City1, City2, City3)) Ct
 WHERE RIGHT(Suppliers,1) =  RIGHT(Cities,1)
 */
 
 SELECT ID, Product
    ,SuppID=ROW_NUMBER() OVER (PARTITION BY ID ORDER BY SupplierName)
    ,SupplierName, CityName
 FROM #Suppliers
  CROSS APPLY (
    VALUES (Supplier1, City1)
    ,(Supplier2, City2)
    ,(Supplier3, City3)) x(SupplierName, CityName)
 WHERE SupplierName IS NOT NULL OR CityName IS NOT NULL

DROP TABLE #Suppliers