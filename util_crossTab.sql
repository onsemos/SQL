USE [erfx_master]
GO

/****** Object:  StoredProcedure [dbo].[util_crossTab]    Script Date: 2/6/2017 5:46:11 PM ******/
SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[util_crossTab]
(
	 @table      	AS sysname,        		-- Table to crosstab
 	 @onrows      	AS NVARCHAR(255),  		-- Grouping key values (on rows)
 	 @oncols      	AS NVARCHAR(255),  		-- Destination columns (on columns)
  	 @valcol      	AS sysname = NULL,		-- Data cells
	 @outTable  	AS NVARCHAR(255),		-- Temp table to insert into
   	 @outKeyCol	AS NVARCHAR(255),		-- primary key in temp table
	 @orderCol	AS NVARCHAR(255) = NULL,		-- order by column: NOTE this must not vary within @oncols' values or error will occur!!!
	 @aggregate	AS NVARCHAR(50) = 'MAX',	-- aggregate type
	 @charToMax	AS TINYINT = 0			-- set to 1 to adjust all @outTable columns to (max) length
)
AS
BEGIN
	SET NOCOUNT ON 
	-- Declare all local variables, create all temp tables:
	DECLARE @server nvarchar(255)='', @db_name nvarchar(255)='', @tbl_owner nvarchar(255)=''
	DECLARE @list nvarchar(max)			-- List of columns to display
	DECLARE @qry nvarchar(max)			-- Query to execute
	DECLARE @val_type_name nvarchar(100) = 'int'
	DECLARE	@val_type nvarchar(100) = 'int'
	DECLARE @col_name nvarchar(100)
	DECLARE @col_size int

	DECLARE @tbl_parts TABLE (segment_id int identity(1,1) primary key, segment varchar(255))
	SET @table = REVERSE(@table)	-- reverse it to reverse order of fields
	;WITH rev_table(starting_character, ending_character, occurence)
	AS (	SELECT	starting_character = 1, 
			ending_character = 
			CAST(CHARINDEX('.', @table + '.') AS INT), 
			1 as occurence
		UNION ALL
		SELECT 
			starting_character = ending_character + 1, 
			ending_character = CAST(CHARINDEX('.', @table + '.',ending_character + 1) AS INT),
			occurence + 1
	     FROM	rev_table
	     WHERE	CHARINDEX('.', @table + '.', ending_character + 1) <> 0
	)
	INSERT INTO @tbl_parts (segment)
	SELECT reverse(SUBSTRING(@table, starting_character, ending_character-starting_character))
	FROM rev_table
	
	SELECT @server=segment+'.' FROM @tbl_parts WHERE segment_id=4
	SELECT @db_name=segment+'.' FROM @tbl_parts WHERE segment_id=3
	SELECT @tbl_owner=segment+'.' FROM @tbl_parts WHERE segment_id=2
	SELECT @table=segment FROM @tbl_parts WHERE segment_id=1

	IF (CHARINDEX('#',@table,1) <>0) 
	BEGIN
		SET @db_name = 'tempdb.'
		SET @tbl_owner = 'dbo.'
	END

	SET @qry = N'
	SELECT	TOP 1	t.name,
			t.name + 
			CASE WHEN c.max_length=t.max_length AND c.precision=t.precision AND c.scale=t.scale THEN ''''
			WHEN t.name=''datetimeoffset'' THEN ''('' + ltrim(STR(c.scale)) + '')'' 
			WHEN t.name IN (''numeric'',''decimal'') THEN ''('' + ltrim(STR(c.precision)) + '','' + ltrim(STR(c.scale)) + '')'' 
			WHEN t.name IN (''varchar'',''char'') THEN ''('' + (CASE c.max_length WHEN -1 THEN ''max'' ELSE ltrim(str(c.max_length)) END) + '')''
			WHEN t.name IN (''nvarchar'',''nchar'') THEN ''('' + (CASE c.max_length WHEN -1 THEN ''max'' ELSE ltrim(str(c.max_length/2)) END) + '')''
			END
	FROM	' + @db_name + N'sys.columns c
		JOIN	sys.types t ON  c.system_type_id = t.system_type_id
	WHERE		object_id(''' + @db_name+@tbl_owner+@table+N''') = object_id 
		AND	c.name=''' + @valcol + N''''

	IF (CHARINDEX('#',@table,1) <>0) 
	BEGIN
		SET @db_name = ''
		SET @tbl_owner = ''
	END

	CREATE TABLE #_pivot_col_type (col_type_name NVARCHAR(100), col_type NVARCHAR(100))
	INSERT INTO #_pivot_col_type
	EXEC (@qry)
	SELECT @val_type_name = col_type_name, @val_type = col_type FROM #_pivot_col_type

	-- Get list of columns:
	CREATE TABLE #_pivot_col_list (list NVARCHAR(MAX))
	CREATE TABLE #_pivot_unique_cols (list NVARCHAR(100), colsize INT)
	SET @qry = 'SELECT ' + @oncols + ', ISNULL(MAX(LEN(' +@valcol +')),0)+1 FROM ' + @server+@db_name+@tbl_owner+@table + ' GROUP BY ' + @oncols + ','+ISNULL(@orderCol,@oncols)+ ' ORDER BY ' + ISNULL(@orderCol,@oncols)
	INSERT INTO #_pivot_unique_cols
	EXEC (@qry)
	--SELECT @list = replace(substring((SELECT ( ',[' + list +  ']') FROM #_pivot_unique_cols FOR XML PATH( '' )),2,8000),'&amp;','&')
	SELECT @list = COALESCE(@list+',','') + QUOTENAME(list) FROM #_pivot_unique_cols

	-- Loop over list, create Alter statements, and expand @outTable
	DECLARE @csr CURSOR
	SET @csr = CURSOR FAST_FORWARD FOR SELECT list, colsize FROM #_pivot_unique_cols
	OPEN @csr
	FETCH NEXT FROM @csr INTO @col_name, @col_size
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SET @qry = N'ALTER TABLE '+ @outTable + N' ADD ['+@col_name+'] ' + CASE WHEN @val_type_name IN ('varchar','char','nvarchar','nchar') THEN @val_type_name + N' (' + CASE WHEN LTRIM(STR(@col_size))>4000 OR @charToMax IN (1,2) THEN CASE WHEN @charToMax = 1 THEN N'MAX' WHEN @charToMax = 2 THEN N'4000' ELSE N'4000' END ELSE LTRIM(STR(@col_size)) END + ') ' ELSE @val_type END
		EXEC (@qry)
		FETCH NEXT FROM @csr INTO @col_name, @col_size
	END
	CLOSE @csr
	DEALLOCATE @csr

	SET @qry = 'INSERT INTO '+ @outTable + ' SELECT *  FROM (SELECT ' + @onrows + ',' + @oncols + ',' + @valcol + ' FROM ' + @server+@db_name+@tbl_owner+@table + ') src PIVOT ('+@aggregate+'('+@valcol +') FOR ' + @oncols + ' IN ('+@list+')) pvt'
	EXEC(@qry)
END
GO


