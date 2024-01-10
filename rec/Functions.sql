


/*SUBSTRING: first letter is index 1*/
DECLARE @str NVARCHAR(4000) = N'New York, NY'

SELECT	CHARINDEX(',', @str)

SELECT	SUBSTRING(@str,1, CHARINDEX(',', @str) - 1), SUBSTRING(@str, CHARINDEX(',', @str)+1, LEN(@str)) --apply LTRIM/RTRIM afterwards

SELECT	GETDATE(), DATENAME(YEAR, GETDATE()), DATENAME(month, GETDATE()), DATENAME(day, GETDATE()), DATENAME(weekday, GETDATE())

SELECT	GETDATE(), DATEPART(YEAR, GETDATE()), DATEPART(month, GETDATE()), DATEPART(day, GETDATE()), DATEPART(weekday, GETDATE())

SELECT	DATEDIFF(YEAR, '01/01/2017 00:00:00', '01/01/2018 00:00:00')
		, DATEDIFF(month, '01/01/2017 00:00:00', '01/01/2018 00:00:00')
		, DATEDIFF(day, '01/01/2017 00:00:00', '01/01/2018 00:00:00')

RETURN

/*ROW_NUMBER*/
IF OBJECT_ID('tempdb..#MstrItems') IS NOT NULL DROP TABLE #MstrItems
CREATE TABLE #MstrItems (ItemID INT PRIMARY KEY, Attrib1 INT, IsActive TINYINT)

IF OBJECT_ID('tempdb..#Baseline') IS NOT NULL DROP TABLE #Baseline
CREATE TABLE #Baseline (RowID INT PRIMARY KEY, ItemID INT, Attrib1 INT)

INSERT	#Baseline
VALUES	(1, 1, 1), (2, 1, 2), (3, 1, 3), (4, 1, 2), (5, 2, 1), (6, 2, 1), (7, 2, 2), (8, 2, 2), (9, 2, 2), (10, 2, 1)

IF OBJECT_ID('tempdb..#RowCounts') IS NOT NULL DROP TABLE #RowCounts
CREATE TABLE #RowCounts (MergeAction NVARCHAR(200))

MERGE	#MstrItems t
USING	(
	SELECT	ItemID 
			, 1 AS IsActive
	FROM		#Baseline
	GROUP BY	ItemID
	) s ON t.ItemID = s.ItemID
WHEN MATCHED THEN
	UPDATE SET IsActive = s.IsActive
WHEN NOT MATCHED THEN
	INSERT	(ItemID, IsActive)
	VALUES	(ItemID, IsActive)
WHEN NOT MATCHED BY SOURCE THEN
	UPDATE SET	IsActive=0
OUTPUT        
	$action into #RowCounts;

SELECT	* 
FROM		(
		SELECT	MergeAction 
		FROM		#RowCounts
		) s
	PIVOT	(
		COUNT(MergeAction) FOR MergeAction IN ([INSERT], [UPDATE], [DELETE])
		) pvt;

UPDATE	t
SET		Attrib1 = s.Attrib1
FROM		#MstrItems t
	JOIN	(
		SELECT	ItemID 
				, Attrib1
				, ROW_NUMBER() OVER (PARTITION BY ItemID ORDER BY COUNT(*) DESC) AS RowNum
				, COUNT(*)
		FROM		#Baseline
		GROUP BY	ItemID, Attrib1
		) s ON t.ItemID = s.ItemID AND s.RowNum = 1

SELECT	* 
FROM		#MstrItems

/*PIVOT/UNPIVOT*/

IF OBJECT_ID('tempdb..#VendorOrders') IS NOT NULL DROP TABLE #VendorOrders
CREATE TABLE #VendorOrders (VendorID int, Emp1 int, Emp2 int, Emp3 int, Emp4 int, Emp5 int)

INSERT INTO #VendorOrders VALUES (1,4,3,5,4,4);
INSERT INTO #VendorOrders VALUES (2,4,1,5,5,5);
INSERT INTO #VendorOrders VALUES (3,4,3,5,4,4);
INSERT INTO #VendorOrders VALUES (4,4,2,5,5,4);
INSERT INTO #VendorOrders VALUES (5,5,1,5,5,5);

SELECT	unpvt.VendorID, unpvt.Employee, unpvt.Orders 
FROM		(
		SELECT	* 
		FROM		#VendorOrders
		) s
UNPIVOT	(
		Orders FOR Employee IN (Emp1, Emp2, Emp3, Emp4, Emp5)
		) unpvt


/*multiple unpivot*/
IF OBJECT_ID('tempdb..#Suppliers') IS NOT NULL
  DROP TABLE #Suppliers

-- DDL and sample data for UNPIVOT Example 2
CREATE TABLE #Suppliers (
	ID INT, Product VARCHAR(500)
	,Supplier1 VARCHAR(500), Supplier2 VARCHAR(500), Supplier3 VARCHAR(500)
	,City1 VARCHAR(500), City2 VARCHAR(500), City3 VARCHAR(500)
)

-- Load Sample data
INSERT INTO #Suppliers
SELECT 1, 'Car', 'Honda', 'Toyota', 'Nissan', 'Detroit','Miami','Los Angeles'
UNION ALL SELECT 2, 'Bike', 'Schwinn', 'Roadmaster', 'Fleetwing', 'Cincinatti', 'Chicago', 'Tampa'
UNION ALL SELECT 3, 'Motorcycle', 'Harley', 'Yamaha', 'Kawasaki', 'Omaha', 'Dallas', 'Atlanta' -- NULL

SELECT * FROM #Suppliers

SELECT	ID, Product, Supplier, Brand, City, Location 
FROM		(
		SELECT	* 
		FROM		#Suppliers
		) s
UNPIVOT	(
		Brand FOR Supplier IN (Supplier1, Supplier2, Supplier3)
		) sup
UNPIVOT	(
		Location FOR City IN (City1, City2, City3)
		) city
 
SELECT	ID
		, Product
		, ROW_NUMBER() OVER (PARTITION BY ID ORDER BY SupplierName) AS SuppID
		, SupplierName
		, CityName
FROM		#Suppliers
CROSS APPLY	(
		VALUES (Supplier1, City1)
		,(Supplier2, City2)
		,(Supplier3, City3)
		) x(SupplierName, CityName)
 WHERE	SupplierName IS NOT NULL OR CityName IS NOT NULL


/*csv*/

SELECT	STUFF(
			(
			SELECT	',' + s.Name
			FROM		HumanResources.Shift s
			ORDER BY	s.Name
			FOR XML PATH('')  
			)
			, 1
			, 1
			, ''
		) AS csv


--	check out Execution Plan. First method is more efficient. Less rows to process.
SELECT	a.ItemID
		, STUFF(
					(
					SELECT	',' + CONVERT(NVARCHAR(5), Attrib1)
					FROM		#Baseline x
					WHERE		x.ItemID = a.ItemID
					GROUP BY	Attrib1
					ORDER BY	Attrib1
					FOR XML PATH('')
					)
					, 1
					, 1
					, ''
				) AS attrib1s
FROM		#Baseline a 
GROUP BY	a.ItemID


SELECT	a.ItemID, b.*
FROM		#Baseline a 
CROSS APPLY	(
		SELECT	STUFF(
					(
					SELECT	',' + CONVERT(NVARCHAR(5), Attrib1)
					FROM		#Baseline x
					WHERE		x.ItemID = a.ItemID
					GROUP BY	Attrib1
					ORDER BY	Attrib1
					FOR XML PATH('')
					)
					, 1
					, 1
					, ''
				) AS attrib1s
		) b
GROUP BY	a.ItemID, b.attrib1s








/*parse csv. only works in 2016 DB*/
SELECT * FROM OPENJSON('["India", "United Kingdom", "United States", "Mexico", "Singapore"]')


DECLARE @json NVARCHAR(4000) = N'{  
   "StringValue":"John",  
   "IntValue":45,  
   "TrueValue":true,  
   "FalseValue":false,  
   "NullValue":null,  
   "ArrayValue":["a","r","r","a","y"],  
   "ObjectValue":{"obj":"ect"}  
}'

SELECT *
FROM OPENJSON(@json)


/*CTE*/
-- based on Execution plan, all 3 cost the same
;WITH bd AS (
	SELECT	* 
	FROM		Person.BusinessEntity
)
SELECT	*
FROM		Person.Person a
	JOIN	bd b ON a.BusinessEntityID = b.BusinessEntityID


SELECT	* 
FROM		Person.Person a
	JOIN	Person.BusinessEntity b ON a.BusinessEntityID = b.BusinessEntityID


SELECT	* 
FROM		Person.Person a
CROSS APPLY	(
		SELECT	* 
		FROM		Person.BusinessEntity x
		WHERE		x.BusinessEntityID = a.BusinessEntityID
		) b

RETURN

/*CTE recursive*/
;WITH tbl AS (
	SELECT	1 AS num
		UNION all
	SELECT	num+1 
	FROM		tbl
	WHERE		num<50
)
SELECT	* 
FROM		tbl

/*bulk insert, minimal logging
  Bulk Insert is the fastest option. Then Insert-Values > Insert-Select > Insert-Select-Union
  For an example of 10K rows, Bulk Insert took 0 sec, Insert-Value took 1:13,  Insert-Select took 1:43, Insert-Select-Union took forever
*/
CREATE TABLE #tmp (FirstName NVARCHAR(200), LastName NVARCHAR(200), State NVARCHAR(200), City NVARCHAR(200))

BULK INSERT #tmp
FROM 'c:\customers.csv'
WITH (FIELDTERMINATOR = ',', FIRSTROW = 2);
SELECT	* 
FROM		#tmp

/*When columns don't match between source of Bulk Insert and destination table, create a view that matches Bulk Insert or use Format File*/
--View
CREATE VIEW BulkInsertPerson
AS
SELECT	FirstName, LastName, Email, Phone
FROM 		Person

-- Non-XML format file
/*
9.0
4
1 SQLCHAR 0 200 "," 2 FirstName SQL_Latin1_General_CP1_CI_AS
2 SQLCHAR 0 200 "," 3 LastName SQL_Latin1_General_CP1_CI_AS
3 SQLCHAR 0 200 "," 4 Email SQL_Latin1_General_CP1_CI_AS
4 SQLCHAR 0 50 "\r\n" 5 Phone ""
*/
BULK INSERT Person
FROM 'c:\p.csv'
WITH (FIELDTERMINATOR = ',', FIRSTROW = 2, FORMATFILE = 'C:\bulk_format.fmt');





/*temperoal tables*/
CREATE TABLE Temporal
(
	ID		INT IDENTITY(1,1)
	, FirstName	NVARCHAR(200) NOT NULL
	, LastName	NVARCHAR(200) NOT NULL
	, MiddleName	NVARCHAR(200)
	, [ValidFrom] datetime2 (2) GENERATED ALWAYS AS ROW START  
	, [ValidTo] datetime2 (2) GENERATED ALWAYS AS ROW END
	, PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo) 
	, CONSTRAINT PK_Temporal PRIMARY KEY (ID)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.TemporalHistory));

INSERT	Temporal(FirstName, LastName, MiddleName)
VALUES	('John', 'Smith', '1')


SELECT	* 
FROM		Temporal
FOR		SYSTEM_TIME BETWEEN '2018-01-01 00:00:00.0000000' AND '2019-01-01 00:00:00.0000000' 

UPDATE	Temporal
SET		MiddleName = '2'
WHERE		ID = 1

RETURN

/*set system versioning off before dropping a table*/
ALTER TABLE Temporal SET (SYSTEM_VERSIONING = OFF); 
DROP TABLE Temporal

RETURN



/* VIEW
http://www.informit.com/articles/article.aspx?p=130855&seqNum=4
You can insert, update, and delete rows in a view, subject to the following limitations:
	*. If the view contains joins between multiple tables, you can only insert and update one table in the view, and you can't delete rows.
	*. You can't directly modify data in views based on union queries. You can't modify data in views that use GROUP BY or DISTINCT statements.
	*. All columns being modified are subject to the same restrictions as if the statements were being executed directly against the base table.
	*. Text and image columns can't be modified through views.
	*. There is no checking of view criteria. For example, if the view selects all customers who live in Paris, and data is modified to either 
	   add or edit a row that does not have City = 'Paris', the data will be modified in the base table but not shown in the view, unless WITH 
	   CHECK OPTION is used when defining the view.
*/
USE Test;

CREATE TABLE Person (
	PID		INT IDENTITY(1,1) NOT NULL 
	, FirstName	NVARCHAR(200) NOT NULL
      , LastName	NVARCHAR(200) NOT NULL
      , MiddleName	NVARCHAR(200) NULL
	, CONSTRAINT PK_Person PRIMARY KEY(PID)
)

CREATE TABLE Address (
	PID		INT NOT NULL 
	, AddressID	INT IDENTITY(1,1) NOT NULL
      , City	NVARCHAR(200) NOT NULL
	, IsPrimary TINYINT
	, CONSTRAINT PK_Address PRIMARY KEY(PID, AddressID)
)

INSERT	Person(FirstName, LastName, MiddleName)
VALUES	('John', 'Smith', 'M'), ('Anthony', 'Ked', 'A')

INSERT	Address(PID, City, IsPrimary)
VALUES	(1, 'Chicago', 1), (1, 'New York', 0), (2, 'LA', 1)


CREATE VIEW Addreses
AS 
	SELECT	a.PID, a.FirstName, a.LastName, CASE WHEN b.IsPrimary=1 THEN 'Yes' ELSE 'No' END AS 'Primary Location?' 
	FROM		Person a
		JOIN	Address b ON a.PID = b.PID

SELECT	* 
FROM		Addreses

UPDATE	Addreses
SET		LastName = 'Kedd'
WHERE		PID = 2