


-- EXEC sp_whoisactive @get_locks  =1
--	drop proc sp_whoisactive


SELECT	* 
FROM		person.Person a
WHERE		BusinessEntityID > 100

--UPDATE	person.Person
--SET		FirstName = 'Ken'
--WHERE		BusinessEntityID = 1

SELECT	a.BusinessEntityID, a.FirstName, a.ModifiedDate
FROM		person.Person a
ORDER BY	2

SELECT	a.BusinessEntityID, a.FirstName, a.ModifiedDate
FROM		person.Person a
ORDER BY	3

SELECT	a.BusinessEntityID, a.LastName, a.ModifiedDate
FROM		person.Person a
ORDER BY	3





CREATE INDEX IX_Person_ModifiedDate ON Person.Person (ModifiedDate) INCLUDE (FirstName)

CREATE INDEX IX_Person_M ON Person.Person (FirstName, ModifiedDate) 


DROP INDEX Person.Person.IX_Person_ModifiedDate
DROP INDEX Person.Person.IX_Person_M


UPDATE STATISTICS Person.Person

DROP STATISTICS Person.Person.IX_Person_ModifiedDate
DROP STATISTICS Person.Person.IX_Person_M



CREATE TABLE #tmp (FirstName NVARCHAR(200))

INSERT	#tmp(FirstName)
VALUES	('Aaron'),('Abigail')



SELECT	b.BusinessEntityID, b.FirstName, b.ModifiedDate
FROM		#tmp a 
INNER JOIN	person.Person b ON a.FirstName = b.FirstName

SELECT	a.BusinessEntityID , b.BusinessEntityID
FROM		Person.Person a
	JOIN	Person.BusinessEntity b ON a.BusinessEntityID = b.BusinessEntityID
ORDER BY	a.BusinessEntityID

SELECT	a.BusinessEntityID , b.BusinessEntityID
FROM		Person.Person a
INNER MERGE	JOIN	Person.BusinessEntity b ON a.BusinessEntityID = b.BusinessEntityID
ORDER BY	a.BusinessEntityID


SELECT	COUNT(*)
FROM		Person.BusinessEntity

DECLARE @name1 NVARCHAR(max)=N'', @name2 NVARCHAR(max)=N''
SELECT	@name1=@name1 +TSQL, @name1 = @name1 + Event, @name1=@name1+tsql
		, @name2+=TSQL, @name2+=Event, @name2+=TSQL
FROM		DatabaseLog

SELECT LEN(@name1), LEN(@name2)

442934, 885868
SELECT	OBJECT_NAME(a.object_id), c.*
FROM		sys.columns a
	JOIN	sys.tables b ON a.object_id = b.object_id
	JOIN	sys.schemas c ON b.schema_id = c.schema_id
	
WHERE		a.max_length=-1 AND a.system_type_id IN (167,231)

SELECT	* 
FROM		INFORMATION_SCHEMA.TABLES
WHERE name LIKE '%varchar%'