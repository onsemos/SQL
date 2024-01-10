SET NOCOUNT ON;
IF OBJECT_ID('tempdb..#tbl') IS NOT NULL 
 drop table #tbl
 
CREATE TABLE #tbl (id int PRIMARY key, fill int, id2 int)
/*


CREATE INDEX ix_tbl_fill ON #tbl (fill) INCLUDE (id2)
*/

INSERT		#tbl
SELECT 		ROW_NUMBER() OVER(ORDER BY id) AS id2, id AS fill, ROW_NUMBER() OVER(ORDER BY id)+1 AS id2
--INTO		#tbl
FROM 		master.dbo.SysColumns 

/*
Table '#tbl'. Scan count 1, logical reads 36, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

ix_tbl_fill
Scan count 1, logical reads 4, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.

*/


SELECT  fill, id2
FROM #tbl
WHERE fill > 5000




