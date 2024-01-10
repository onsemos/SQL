DECLARE @d_sql NVARCHAR(MAX) = N''

SELECT	@d_sql = @d_sql + N'DROP TABLE ' + name + N';'+CHAR(10)
FROM		tempdb.sys.objects
WHERE		name like '#[^#]%'
	AND	OBJECT_ID('tempdb..'+name) IS NOT NULL

IF @d_sql <> '' BEGIN
    PRINT @d_sql
    --EXEC( @d_sql )
END