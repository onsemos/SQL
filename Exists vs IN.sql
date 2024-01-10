USE erfx_partesa_index

SET STATISTICS IO ON
SET STATISTICS TIME ON
/*********************************** Example 1 ***********************************/
DBCC DROPCLEANBUFFERS

-- IN
SELECT 		COUNT(*)
FROM 		eScoping
WHERE		whse_id IN (
			SELECT 		DISTINCT whse_id
			FROM 		eMstr_Whse_Handling_Activities
		)
		
-- EXISTS		
SELECT 		COUNT(*)
FROM 		eScoping s
WHERE		EXISTS (
			SELECT 		1
			FROM 		eMstr_Whse_Handling_Activities w
			WHERE		w.whse_id = s.whse_id
		)
		

/*********************************** Example 2 ***********************************/
IF OBJECT_ID('BigTable','u') IS NOT NULL DROP TABLE BigTable
		
Create Table BigTable (
	id		int identity primary key,
	SomeColumn	char(4),
	Filler		char(100)
)
CREATE INDEX ix_bigTable_someColumn ON BigTable(SomeColumn)

 
IF OBJECT_ID('SmallerTable','u') IS NOT NULL DROP TABLE SmallerTable
Create Table SmallerTable (
	id		int identity primary key,
	LookupColumn	char(4),
	SomeArbDate	Datetime default getdate()
)
CREATE INDEX ix_SmallerTable_LookupColumn ON SmallerTable(LookupColumn)
 
INSERT	BigTable (SomeColumn)
SELECT	top 250000
	char(65+FLOOR(RAND(a.column_id *5645 + b.object_id)*10)) + char(65+FLOOR(RAND(b.column_id *3784 + b.object_id)*12)) +
	char(65+FLOOR(RAND(b.column_id *6841 + a.object_id)*12)) + char(65+FLOOR(RAND(a.column_id *7544 + b.object_id)*8))
from	master.sys.columns a cross join master.sys.columns b
 
INSERT	SmallerTable (LookupColumn)
SELECT	DISTINCT SomeColumn
FROM	BigTable TABLESAMPLE (25 PERCENT)


DBCC DROPCLEANBUFFERS

-- IN
SELECT COUNT(*) FROM BigTable
WHERE SomeColumn IN (SELECT LookupColumn FROM SmallerTable)
 
-- EXISTS
SELECT COUNT(*) FROM BigTable
WHERE EXISTS (SELECT 1 FROM SmallerTable WHERE SmallerTable.LookupColumn = BigTable.SomeColumn)