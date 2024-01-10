

/**************************************************************************
***************************************************************************
	Disables/Enables FK relationships
***************************************************************************
**************************************************************************/
ALTER PROCEDURE [dbo].[fkControl]
(
	@db_id			int
	,@direction		varchar(20)
)
AS
BEGIN
	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF

	DECLARE @action varchar(10)

	IF (@direction = 'enable')
		SET @action = 'check'
	ELSE IF (@direction = 'disable')
		SET @action = 'nocheck'

	DECLARE @fkname varchar(500)
	DECLARE @tablename varchar(8000)
	DECLARE @schema varchar(500)
	DECLARE @dbname varchar(100)
	DECLARE @query nvarchar(1000)

	SELECT	@dbname = database_name
	FROM 	tbl_mstr_databases md
	WHERE	md.database_id = @db_id

	SET @query = '
		DECLARE crs CURSOR FOR 
		SELECT		fk.name fkname, p.name tablename, s.name schemaname
		FROM 		' + @dbname + '.sys.objects fk 
			JOIN	' + @dbname + '.sys.objects p on fk.parent_object_id = p.object_id
			JOIN	' + @dbname + '.sys.schemas s ON p.schema_id = s.schema_id
		WHERE	 fk.type=''f'''
	EXEC sp_executesql  @query

	OPEN crs
	FETCH NEXT FROM crs INTO @fkname, @tablename, @schema
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SET @query = 'alter table [' + @dbname + '].[' + @schema + '].[' + @tablename + '] ' + @action + ' constraint [' + @fkname + ']'
		exec sp_executesql  @query

		FETCH NEXT FROM crs INTO @fkname, @tablename, @schema
	END	

	CLOSE crs
	DEALLOCATE crs

END
GO

