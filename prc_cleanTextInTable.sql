SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO
ALTER procedure [dbo].[prc_cleanTextInTable]
(
	@database_name NVARCHAR(MAX)
	,@table_name NVARCHAR(MAX)
	,@exec_sql TINYINT = 0
	,@columns_to_include NVARCHAR(MAX) = NULL
	,@columns_to_exclude NVARCHAR(MAX) = NULL
	,@use_LTRIM TINYINT = 1
	,@use_RTRIM TINYINT = 1
	,@use_ConvertMixedCase TINYINT = 0
	,@use_CleanSpecialChars TINYINT = 1
	,@use_NULLIFBlank TINYINT = 1
	
	-- @database_name - REQUIRED - Database name that contains the table to clean (ie erfx_bcs_training_tlachin)
	--,@table_name - REQUIRED - Table name to clean (ie eShipments)
	--,@exec_sql - OPTIONAL - Defaults 0, will print SQL to be executed instead of exec immediately by default.  Good for spot checks and sanity checks, & use SQLPrompt auto format
	--,@columns_to_include - OPTIONAL - If you only want to clean specific columns, list (CSV) them here.
	--,@columns_to_exclude - OPTIONAL - If you only want to exclude specific columns, list (CSV) them here.
	--,@use_LTRIM - OPTIONAL - Default 1, will apply LTRIM to the fields in the table
	--,@use_RTRIM - OPTIONAL - Default 1, will apply RTRIM to the fields in the table
	--,@use_ConvertMixedCase - OPTIONAL - Default 0, will apply ConvertMixedCase to the fields in the table (ie CHICAGO -> Chicago || st. someplace -> St. Someplace)
		--WARNING: ConvertMixedCase is a function that auto applies LTRIM and RTRIM
	--,@use_CleanSpecialChars - OPTIONAL - Default 1, will apply clean CHAR(9), CHAR(10), CHAR(13)
	--,@use_NULLIFBlank - OPTIONAL - Default 1, will apply NULLIF(column, '') to the fields in the table
)

AS

BEGIN
	--	For testing purposes, good to keep for later
	--DECLARE @database_name NVARCHAR(MAX) =  N'erfx_cb_ocean_028'
	--,@table_name NVARCHAR(MAX) = N'eShipments'
	--,@exec_sql TINYINT = 0
	--,@columns_to_include NVARCHAR(MAX) = NULL
	--,@columns_to_exclude NVARCHAR(MAX) = NULL
	--,@use_LTRIM TINYINT = 1
	--,@use_RTRIM TINYINT = 1
	--,@use_ConvertMixedCase TINYINT = 1
	--,@use_CleanSpecialChars TINYINT = 1
	--,@use_NULLIFBlank TINYINT = 1
	
	DECLARE @sql NVARCHAR(MAX) = N'	
	USE @database_name
	
	DECLARE @qry NVARCHAR(MAX) = N''''
	,@setQry NVARCHAR(MAX) = N''''
	
	SET @qry +=	N''
			UPDATE @table_name 
			SET ''
	
	SELECT 		@setQry += CASE WHEN @setQry = N'''' THEN N'''' ELSE N'','' END + N''
			
			 '' + c.name + '' = @use_NULLIFBlank_start(@use_CleanSpecialChars_start(@use_ConvertMixedCase(@use_LTRIM(@use_RTRIM( '' + c.name + '' )))@use_CleanSpecialChars_end)@use_NULLIFBlank_end)
			
			''
			
	FROM 		sys.columns c
	WHERE		Object_ID = Object_ID(N''@table_name'')
		@columns_to_include
		@columns_to_exclude
	
	SET @qry = @qry + @setQry
	
	IF(@exec_sql = 1)
		EXEC (@qry)
	ELSE
		SELECT (@qry)
	
	'
	
	SET @sql = REPLACE(@sql, N'@database_name', @database_name)
	SET @sql = REPLACE(@sql, N'@table_name', @table_name)
	SET @sql = REPLACE(@sql, N'@exec_sql', ISNULL(CONVERT(NVARCHAR(4000),@exec_sql),N'NULL') )
	
	SET @sql = REPLACE(@sql, N'@columns_to_include', CASE WHEN NULLIF(LTRIM(RTRIM(@columns_to_include)),'') IS NOT NULL THEN N'AND	c.name IN ('''+REPLACE(@columns_to_include,N',',N''',''')+N''') ' ELSE N'' END)
	SET @sql = REPLACE(@sql, N'@columns_to_exclude', CASE WHEN NULLIF(LTRIM(RTRIM(@columns_to_exclude)),'') IS NOT NULL THEN N'AND	c.name NOT IN ('''+REPLACE(@columns_to_exclude,N',',N''',''')+N''') ' ELSE N'' END)
	
	SET @sql = REPLACE(@sql, N'@use_LTRIM', CASE @use_LTRIM WHEN 1 THEN N'LTRIM' ELSE N'' END)
	SET @sql = REPLACE(@sql, N'@use_RTRIM', CASE @use_RTRIM WHEN 1 THEN N'RTRIM' ELSE N'' END)
	
	SET @sql = REPLACE(@sql, N'@use_ConvertMixedCase', CASE @use_ConvertMixedCase WHEN 1 THEN N'erfx_master.dbo.convertToMixedCase' ELSE N'' END)
	
	SET @sql = REPLACE(@sql, N'@use_CleanSpecialChars_start', CASE @use_CleanSpecialChars WHEN 1 THEN N'REPLACE(REPLACE(REPLACE' ELSE N'' END)
	SET @sql = REPLACE(@sql, N'@use_CleanSpecialChars_end', CASE @use_CleanSpecialChars WHEN 1 THEN N',Char(9),''''''''),Char(10),''''''''),Char(13),'''''''' ' ELSE N'' END)
	
	SET @sql = REPLACE(@sql, N'@use_NULLIFBlank_start', CASE @use_NULLIFBlank WHEN 1 THEN N'NULLIF' ELSE N'' END)
	SET @sql = REPLACE(@sql, N'@use_NULLIFBlank_end', CASE @use_NULLIFBlank WHEN 1 THEN N','''''''' ' ELSE N'' END)
	
	--EXEC (@sql)
	EXEC sp_executesql @sql
END

GO

