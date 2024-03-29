USE [erfx_audit]
GO
/****** Object:  StoredProcedure [dbo].[manage_audit_tables_v2]    Script Date: 2/10/2017 3:41:54 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

/************
Arguments: 
	db_name: the name of the database, such as rfx_demo
	action: 
DEFAULT-->	'A' = Activate/Alter audit information -- Keeps data (unless columns are deleted) and recreates triggers. Accepts @table_name and @schema_name args (optional) 
							Also will start new tables as well.
		'Q' = Quit auditing, but keep information
		'R' = Resume (after a Q). It only re-creates the script to create the triggers.
		'T' = Test -- no action taken

Dangerous ones -- DELETES DATA:
		'S' = Setup audit information -- Also restarts any auditing (DROPs all tables first!!!) 
		'D' = Delete audit information
		'U' = Update (refresh) one table (or adds it). Requires extra @table_name arg. Wipes out that table and starts over.
***********/ 
ALTER PROCEDURE [dbo].[manage_audit_tables_v2]
(	@db_name		NVARCHAR(500)
	,@action		NCHAR(1) = 'A'	-- 'A' is the safest option
	,@table_name	NVARCHAR(500) = NULL
	,@schema_name	NVARCHAR(200) = NULL
)
 AS
BEGIN
	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF

	--	DECLARE @db_name NVARCHAR(500) = 'tbc_demo_transp', @action NCHAR(1) = 'T'

	DECLARE @qry nvarchar(max)
	DECLARE @app nvarchar(10) = LEFT(DB_NAME(),CHARINDEX('_',DB_NAME())-1)
	
	IF (@app IN ('XECS')) -- Some Opt DBs start with XECS
		SET @app='opt'
	IF (@app IN ('CBC')) -- Some CBC DBs might start with CBC instead of TBC
		SET @app='tbc'

	DECLARE @app_master nvarchar(50) = CASE @app WHEN 'opt' THEN 'xecs' ELSE @app END + '_master'
	DECLARE @app_audit_tables nvarchar(50) = @app + '_audit_tables'
	DECLARE @app_audit_schema NVARCHAR(50) = 'audit'	
	DECLARE @retCode INT, @db_id INT
	DECLARE @schema_exists TINYINT = 0, @table_exists TINYINT = 0, @old_audit_exists TINYINT = 0, @new_audit_exists TINYINT = 0 
	DECLARE @audit_table_exists TINYINT = 0, @exclusion_table_exists TINYINT = 0
	DECLARE @row_count INT = 0, @excl_row_count INT = 0, @audit_row_count INT = 0, @new_audit_row_count INT = 0
	
	--Check for existence of new audit schema
	SET @qry = N'IF EXISTS(SELECT 1 FROM '+@db_name+'.sys.schemas AS s WHERE s.name = '''+@app_audit_schema+''')
					SET @schema_exists = 1'
	EXEC sp_executesql @qry, N'@schema_exists TINYINT OUT', @schema_exists=@schema_exists OUT

	-- if new audit schema does not exist, create schema, create new (app)_audit_tables, create new audit_table_exclusions
	IF (@schema_exists < 1)
	BEGIN
		SET @qry = N'USE '+@db_name+N' 
			EXEC '+@db_name+'..sp_executesql N''CREATE SCHEMA ['+@app_audit_schema+']''
			CREATE TABLE ['+@app_audit_schema+'].['+@app_audit_tables+']
			(
			[tablename] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
			[schema_name] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
			) ON [PRIMARY]
			ALTER TABLE ['+@app_audit_schema+'].['+@app_audit_tables+'] ADD CONSTRAINT [PK_tablename_schema_name] PRIMARY KEY CLUSTERED ([tablename], [schema_name]) ON [PRIMARY]

			CREATE TABLE ['+@app_audit_schema+'].[audit_table_exclusions]
			(
			[table_name] [sys].[sysname] NOT NULL,
			[schema_name] [sys].[sysname] NOT NULL
			) ON [PRIMARY]
			ALTER TABLE ['+@app_audit_schema+'].[audit_table_exclusions] ADD CONSTRAINT [PK__audit_ta__FC35663B4345DA64] PRIMARY KEY CLUSTERED ([table_name], [schema_name]) ON [PRIMARY]
		'
		EXEC(@qry)
		
		-- check for existence of old (app)_audit_tables
		SET @qry = N'USE '+@db_name+N' 
						IF EXISTS(SELECT 1 FROM sys.tables AS t JOIN sys.schemas AS s ON s.schema_id = t.schema_id WHERE t.name = '''+@app_audit_tables+''' AND s.name = ''dbo'')
						SET @audit_table_exists = 1'
		EXEC sp_executesql @qry, N'@audit_table_exists TINYINT OUT', @audit_table_exists=@audit_table_exists OUT

		-- if old (app)_audit_tables exists, and table has data, insert data into new audit (app)_audit_tables
		IF (@audit_table_exists = 1)
		BEGIN
			-- check that old (app)_audit_tables has data
			SET @qry = 'USE '+@db_name+N' 
						SELECT @row_count = COUNT(*) FROM dbo.'+@app_audit_tables
			EXEC sp_executesql @qry, N'@row_count int OUT', @row_count=@row_count OUT

			IF (@row_count > 0)
			BEGIN
				SET @qry = N'USE '+@db_name+N' 
					INSERT INTO '+@app_audit_schema+'.'+@app_audit_tables+'
							(tablename, schema_name)
					SELECT			eat.tablename, s.name
					FROM			dbo.'+@app_audit_tables+' AS eat
							JOIN	sys.tables AS t ON eat.tablename = t.name
							JOIN	sys.schemas AS s ON t.schema_id = s.schema_id	
				'
				EXEC(@qry)
			END
		END

		-- check for existence of old audit_table_exclusions where database_name = @db_name
		SET @qry = N'IF EXISTS(SELECT 1 FROM sys.tables AS t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE t.name = ''audit_table_exclusions'' AND s.name = ''dbo'')
					SET @exclusion_table_exists = 1'
		EXEC sp_executesql @qry, N'@exclusion_table_exists TINYINT OUT', @exclusion_table_exists=@exclusion_table_exists OUT
		
		-- if old audit_table_exclusions exists, and has data, insert data into new audit_table_exclusions
		IF (@exclusion_table_exists = 1)
		BEGIN
			SET @qry = N'SELECT @excl_row_count = COUNT(*) FROM dbo.audit_table_exclusions AS ate WHERE ate.database_name = '''+@db_name+''''
			EXEC sp_executesql @qry, N'@excl_row_count INT OUT', @excl_row_count=@excl_row_count OUT

			IF (@excl_row_count > 0)
			BEGIN
				SET @qry = N'
					INSERT INTO '+@db_name+'.'+@app_audit_schema+'.audit_table_exclusions
							(table_name, schema_name)
					SELECT			ate.table_name, s.name
					FROM			dbo.audit_table_exclusions AS ate
							JOIN	sys.tables AS t ON ate.table_name = t.name
							JOIN	sys.schemas AS s ON t.schema_id = s.schema_id
					WHERE			ate.database_name = '''+@db_name+'''	
				'
				EXEC(@qry)
			END
		END
	END

	-- get database_id of db_name
	SET @qry = N'SELECT  @db_id = database_id FROM '+@app_master+N'.dbo.TBL_MSTR_DATABASES WHERE database_name = @db_name'
	EXEC sp_executesql @qry, N'@db_id int OUT, @db_name sysname', @db_name=@db_name, @db_id=@db_id OUT
	--	SELECT @db_name, @db_id
	
	IF (@db_id IS NOT Null)
	BEGIN
		-- check that new (app)_audit_tables exists under new audit schema
		SET @qry = N'USE '+@db_name+N' SELECT  @retCode = SIGN(NULLIF(t.object_id,0)) FROM sys.tables AS t JOIN sys.schemas AS s ON s.schema_id = t.schema_id WHERE t.name = @app_audit_tables AND s.name = '''+@app_audit_schema+''''
		EXEC sp_executesql @qry, N'@retCode int OUT,  @app_audit_tables sysname', @retCode=@retCode OUT, @app_audit_tables=@app_audit_tables
		--	SELECT @app_audit_tables, @retCode
	END	
	ELSE 
	BEGIN
		PRINT ''''+@db_name+''' is not a valid database name'
	END

	IF (1=@retCode)
	BEGIN
		IF OBJECT_ID('tempdb..#tableCols') IS NOT NULL DROP TABLE #tableCols
		CREATE TABLE #tableCols (tableId int, colid int, tableName NVARCHAR(500), tableSchema NVARCHAR(200), colName NVARCHAR(400), colType NVARCHAR(100) primary key (tableId, colId))
		SET @qry = 
              'SELECT so.object_id as tableId, sc.column_id, quotename(so.name) as tableName,  quotename(ss.name) as tableSchema, quotename(sc.name) as colName,
                               st.name + CASE sc.system_type_id     '+
                     'WHEN  35 THEN ''(''+convert(char(2),sc.scale)+'')''                 '+--time
                     'WHEN  42 THEN ''(''+convert(char(2),sc.scale)+'')''                 '+-- datetime2
                     'WHEN  43 THEN ''(''+convert(char(2),sc.scale)+'')''                 '+-- datetimeoffset
                     'WHEN 106 THEN ''(''+convert(char(2),sc.precision)+'',''+convert(char(2),sc.scale)+'')''     '+-- decimal
                     'WHEN 108 THEN ''(''+convert(char(2),sc.precision)+'',''+convert(char(2),sc.scale)+'')''     '+-- numeric
                     'WHEN 165 THEN ''(''+(CASE sc.max_length WHEN -1 THEN ''max'' ELSE convert(char(4),sc.max_length) END)+'')''       '+-- varbinary
                     'WHEN 167 THEN ''(''+(CASE sc.max_length WHEN -1 THEN ''max'' ELSE convert(char(4),sc.max_length) END)+'')''       '+-- NVARCHAR
                     'WHEN 173 THEN ''(''+convert(char(4),sc.max_length)+'')''            '+-- binary
                     'WHEN 175 THEN ''(''+convert(char(4),sc.max_length)+'')''            '+-- char
                     'WHEN 231 THEN ''(''+(CASE sc.max_length WHEN -1 THEN ''max'' ELSE convert(char(4),sc.max_length/2) END)+'')''     '+-- nvarchar
                     'WHEN 239 THEN ''(''+convert(char(4),sc.max_length/2)+'')''            '+-- nchar
                     'ELSE '''' END as colType
              FROM          ' + @db_name + '.sys.columns sc
                     JOIN   ' + @db_name + '.sys.tables so ON sc.object_id=so.object_id
                     JOIN   ' + @db_name + '.sys.types st ON sc.system_type_id = st.user_type_id
					 JOIN	' + @db_name + '.sys.schemas ss ON ss.schema_id = so.schema_id
                     JOIN   ' + @db_name + '.'+@app_audit_schema+'.' + @app_audit_tables + ' eat ON eat.tablename = so.name AND eat.schema_name = ss.name
              WHERE so.[type]=''U''
              ORDER BY ss.name, so.name, sc.column_id'

              IF (@action='T')
				EXEC (@qry)	-- Display above info and stop.
              ELSE
              IF (@action<>'T')
              BEGIN
					INSERT INTO #tableCols
					EXEC (@qry) 
		
					IF OBJECT_ID('tempdb..#tableSpecs') IS NOT NULL DROP TABLE #tableSpecs
					CREATE TABLE #tableSpecs (tableId int primary key, tablename NVARCHAR(200), tableschema NVARCHAR(200), colspecs NVARCHAR(max))
					IF OBJECT_ID('tempdb..#tableColumns') IS NOT NULL DROP TABLE #tableColumns
					CREATE TABLE #tableColumns (tableId int primary key, collist NVARCHAR(max))
	
					INSERT INTO #tableSpecs (tableId, tableschema, colspecs)
					SELECT tableId, REPLACE(REPLACE(tableSchema, '[', ''), ']', ''), master.dbo.DelimitedList(colname+' '+coltype,',') FROM #tableCols GROUP BY tableId, tableSchema
	
					INSERT INTO #tableColumns (tableId, collist)
					SELECT tableId, master.dbo.DelimitedList(colname,',') FROM #tableCols GROUP BY tableId
					EXEC ('UPDATE #tableSpecs
							SET tableName = so.name
						FROM		#tableSpecs ts
							JOIN	'+@db_name+'.sys.tables so ON ts.tableId = so.object_id')

					IF (@action IN ('U','A'))
					BEGIN
						DELETE #tableSpecs WHERE tableName <> isNull(@table_name,tablename) 
						DELETE #tableSpecs WHERE tableschema <> ISNULL(@schema_name,tableschema)
					END
	
					DECLARE @to_create tinyint = 0, @is_same tinyint=0, @make_triggers tinyint = 1, @err_msg NVARCHAR(500)
					DECLARE @colspecs NVARCHAR(max), @collist NVARCHAR(max), @renamed NVARCHAR(300), @audit_name NVARCHAR(300), @copy_cols NVARCHAR(max)
					DECLARE @table_schema NVARCHAR(200)
		
					IF OBJECT_ID('tempdb..#same_cols') IS NOT NULL DROP TABLE #same_cols
					CREATE TABLE #same_cols (colName NVARCHAR(100) primary key)
					IF OBJECT_ID('tempdb..#same') IS NOT NULL DROP TABLE #same
					CREATE TABLE #same (same int)
		
				DECLARE @tcrs CURSOR 
				SET @tcrs = CURSOR FAST_FORWARD
					FOR SELECT ts.tableName, ts.tableschema, tc.collist, ts.colspecs FROM #tableSpecs ts JOIN #tableColumns tc ON ts.tableId=tc.tableId 
											--WHERE ts.tablename IN('eAudit_Testing') AND ts.tableschema = 'da' -- TESTING
				OPEN @tcrs
				FETCH NEXT FROM @tcrs INTO @table_name, @table_schema, @collist, @colspecs
				WHILE (@@FETCH_STATUS=0)
				BEGIN
					--SET @audit_name = @db_name + '__'+@table_name 
					SET @audit_name = @table_schema + '_' + @table_name
					SET @make_triggers=1
					-- Regardless of option, always delete tables in audit database and triggers in event DATABASE
					IF (@action IN ('S','D','U')) -- Delete, reStart, Update (but not Alter)
					BEGIN
							EXEC('IF EXISTS (SELECT * FROM '+@db_name+'.sys.tables st JOIN '+@db_name+'.sys.schemas AS ss ON st.schema_id = ss.schema_id 
								WHERE st.name = '''+@audit_name+''' AND ss.name = '''+@app_audit_schema+''') 
								DROP TABLE '+@db_name+'.['+@app_audit_schema+'].' + @audit_name)
					END
			
					-- In all cases, drop existing triggers. Depending on action, recreate them, below.			
					EXEC ('		USE ' + @db_name + ' ' + '
								IF EXISTS (SELECT  1
								FROM    sys.triggers tr
								JOIN	sys.tables AS st ON tr.parent_id = st.object_id
								JOIN	sys.schemas AS ss ON st.schema_id = ss.schema_id
								WHERE   tr.name = ''audit_' + @table_name + '_i'' AND ss.name = ''' + @table_schema + ''')
									EXEC(''DROP TRIGGER '+ @table_schema + '.audit_' + @table_name + '_i'')')

					EXEC ('		USE ' + @db_name + ' ' + '
								IF EXISTS (SELECT  1
								FROM    sys.triggers tr
								JOIN	sys.tables AS st ON tr.parent_id = st.object_id
								JOIN	sys.schemas AS ss ON st.schema_id = ss.schema_id
								WHERE   tr.name = ''audit_' + @table_name + '_d'' AND ss.name = ''' + @table_schema + ''')
									EXEC(''DROP TRIGGER '+ @table_schema + '.audit_' + @table_name + '_d'')')

					EXEC ('		USE ' + @db_name + ' ' + '
								IF EXISTS (SELECT  1
								FROM    sys.triggers tr
								JOIN	sys.tables AS st ON tr.parent_id = st.object_id
								JOIN	sys.schemas AS ss ON st.schema_id = ss.schema_id
								WHERE   tr.name = ''audit_' + @table_name + '_u'' AND ss.name = ''' + @table_schema + ''')
									EXEC(''DROP TRIGGER '+ @table_schema + '.audit_' + @table_name + '_u'')')

					-- If not deleting, then create tables in audit database and script for triggers in event database
					IF (@action IN ('Q','D'))	
					BEGIN
						EXEC('IF NOT EXISTS(SELECT 1 FROM ' + @db_name + '.'+@app_audit_schema+'.audit_table_exclusions ate WHERE ate.table_name = ''' + @table_name + ''' AND ate.schema_name = ''' + @table_schema + ''')
								INSERT INTO ' + @db_name + '.'+@app_audit_schema+'.audit_table_exclusions  ( table_name, schema_name ) VALUES (''' + @table_name + ''', ''' + @table_schema + ''')')
					END
					ELSE
					BEGIN	
						-- REMOVE FROM TABLE EXCLUSIONS HERE
						EXEC('DELETE ' + @db_name + '.'+@app_audit_schema+'.audit_table_exclusions WHERE table_name = ''' + @table_name + ''' AND schema_name = ''' + @table_schema + '''')
							
						SET @is_same=0
						SET @make_triggers=1
						IF (@action IN ('S','U')) SET @to_create = 1 ELSE SET @to_create = 0
				
						IF (@action='A')
						BEGIN 
							SET @is_same = 0
							DECLARE @obj_id INT = NULL
							SET @qry = 'SELECT  @obj_id = st.OBJECT_ID FROM ' + @db_name + '.sys.tables st JOIN 
											' + @db_name + '.sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = ''' + @audit_name + ''' AND ss.name = '''+@app_audit_schema+''''
							EXEC sp_executesql @qry, N'@obj_id int OUT', @obj_id=@obj_id OUT					

							IF @obj_id IS NULL
							BEGIN
								SET @to_create = 1	-- this is the same as 'U' or 'S' at this point
								SET @is_same = 1
							END
							ELSE
							BEGIN	-- check if it's the same table. 
								TRUNCATE TABLE #same_cols
								DECLARE @live_tbl_obj_id int, @audit_tbl_obj_id int, @sameness TINYINT
                        
								SET @qry = 'SELECT @live_tbl_obj_id = st.OBJECT_ID FROM ' + @db_name + '.sys.tables st JOIN 
											' + @db_name + '.sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = ''' + @table_name + ''' AND ss.name = ''' + @table_schema + ''''
								EXEC sp_executesql @qry, N'@live_tbl_obj_id int OUT', @live_tbl_obj_id=@live_tbl_obj_id OUT

								SET @qry = 'SELECT @audit_tbl_obj_id = st.OBJECT_ID FROM ' + @db_name + '.sys.tables st JOIN 
											' + @db_name + '.sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = ''' + @audit_name + ''' AND ss.name = '''+@app_audit_schema+''''
								EXEC sp_executesql @qry, N'@audit_tbl_obj_id int OUT', @audit_tbl_obj_id=@audit_tbl_obj_id OUT

								DECLARE @live_tbl_obj_id_str NVARCHAR(MAX)
								SELECT @live_tbl_obj_id_str = CONVERT(NVARCHAR(MAX), @live_tbl_obj_id)

								DECLARE @audit_tbl_obj_id_str NVARCHAR(MAX) 
								SELECT @audit_tbl_obj_id_str = CONVERT(NVARCHAR(MAX), @audit_tbl_obj_id)

								SET @qry = N';WITH live AS (SELECT sc.*, row_number() OVER (ORDER BY sc.column_id) as col_rank FROM '+@db_name+'.sys.columns sc JOIN '+@db_name+'.sys.tables st ON sc.object_id=st.object_id JOIN '+@db_name+'.sys.schemas ss ON ss.schema_id = st.schema_id WHERE sc.object_id='+@live_tbl_obj_id_str+' AND ss.name = '''+@table_schema+''')
											,audit AS (SELECT *, row_number() OVER (ORDER BY column_id) as col_rank FROM '+@db_name+'.sys.columns WHERE object_id = '+@audit_tbl_obj_id_str+' AND column_id>3)
											,same  AS (SELECT COUNT(*) as diff_cols
												FROM		live s
												FUll OUTER JOIN	audit a ON s.col_rank=a.col_rank AND
															(s.name=a.name and s.system_type_id=a.system_type_id and 
															 s.max_length=a.max_length and s.[precision]=a.[precision] and 
															 s.scale=a.scale)
												WHERE s.col_rank + a.col_rank IS NULL)
										SELECT  @sameness = 1-sign(diff_cols)
										FROM	same'
								EXEC sp_executesql @qry, N'@sameness TINYINT OUT', @sameness=@sameness OUT

								IF (@sameness = 0)
								BEGIN
									EXEC(';WITH	live AS (SELECT sc.* FROM '+@db_name+'.sys.columns sc JOIN '+@db_name+'.sys.tables st ON sc.object_id=st.object_id JOIN '+@db_name+'.sys.schemas ss ON ss.schema_id = st.schema_id WHERE sc.object_id='+@live_tbl_obj_id_str+' AND ss.name = '''+@table_schema+''')
										,audit AS (SELECT * FROM ' + @db_name + '.sys.columns WHERE object_id = '+@audit_tbl_obj_id_str+' AND column_id>3)
										INSERT INTO		#same_cols
										SELECT			s.name
										FROM			live s
												JOIN	audit a ON s.name=a.name
								
										INSERT INTO #same VALUES (0)')
								END

								IF EXISTS(SELECT 1 FROM #same)
								BEGIN
									BEGIN TRY
										SET @is_same = 0
										SET @to_create = 1
										SET @renamed = @audit_name + '__'+replace(replace(replace(replace((SYSUTCDATETIME ( )),'.','_'),'-','_'),':','_'),' ','_')
										/* rename */
										print '/*'
										EXEC('USE '+@db_name+' EXEC sp_rename '''+@app_audit_schema+'.' + @audit_name + ''', ''' + @renamed + '''')
										print '*/'
									END TRY
									BEGIN CATCH
										SET @to_create = 0
										SET @make_triggers=0
										SET @err_msg = 'ERROR ***** (Renaming): ' + @db_name + '.'+@app_audit_schema+'.' + @renamed + '. Auditing must be manually fixed for this table!'
										RAISERROR (@err_msg, 10, 1)
									END CATCH
								END
								ELSE
								BEGIN 
									SET @is_same = 1
								END
							END
						END
						
						IF (@to_create = 1)
						BEGIN
							EXEC ('CREATE TABLE ' + @db_name + '.['+@app_audit_schema+'].'+ @audit_name +
							'(rowId bigint primary key identity(1,1), action char(1), action_time datetime, '+@colspecs+')')
						END
				
						IF (@action = 'A' AND @is_same=0)
						BEGIN TRY -- Attempt to copy data
							SET @copy_cols = ''
							SELECT @copy_cols=@copy_cols+','+colName FROM #same_cols
							SET @qry = '
							SET IDENTITY_INSERT ' + @db_name + '.['+@app_audit_schema+'].'+ @audit_name +' ON
							INSERT INTO ' + @db_name + '.['+@app_audit_schema+'].'+ @audit_name + '(rowId, action, action_time'+@copy_cols+')
							SELECT rowId, action, action_time'+@copy_cols+' FROM ' + @db_name + '.['+@app_audit_schema+'].'+@renamed + '
							SET IDENTITY_INSERT ' + @db_name + '.['+@app_audit_schema+'].'+ @audit_name +' OFF
							DECLARE @max_ident bigint = 0
							SELECT @max_ident=isNull(max(rowId),0) FROM ' + @db_name + '.['+@app_audit_schema+'].'+ @audit_name + '
							print ''/*''
							DBCC CHECKIDENT  (''' + @db_name + '.'+@app_audit_schema+'.'+ @audit_name + ''', RESEED, @max_ident)
							print ''*/'''
							EXEC (@qry)
							SET @qry = 'DROP TABLE ' + @db_name + '.['+@app_audit_schema+'].' + @renamed
							EXEC (@qry) 
						END TRY
						BEGIN CATCH
							SET @make_triggers=0
							SET @err_msg = 'ERROR *****(Copy):' + @db_name + '.['+@app_audit_schema+'].' + @renamed + '. Auditing must be manually fixed for this table!'
							RAISERROR (@err_msg, 10, 2)
						END CATCH

						IF (@make_triggers=1)
						BEGIN
							SET @qry =
								'USE '+@db_name+'
								EXEC (''CREATE TRIGGER audit_' + @table_name + '_i ON ' + @db_name + '.['+@table_schema+'].['+@table_name+'] FOR INSERT AS ' +
								'BEGIN '+
								'SET NOCOUNT ON '+
								'INSERT INTO ' + @db_name + '.['+@app_audit_schema+'].'+@audit_name + '(action, action_time, ' + @collist + ') ' +
								'SELECT ''''I'''',getdate(), ' + @collist + ' FROM inserted ' +
								'END'') '
								+
								'EXEC (''CREATE TRIGGER audit_' + @table_name + '_d ON ' + @db_name + '.['+@table_schema+'].['+@table_name+'] FOR DELETE AS ' +
								'BEGIN ' +
								'SET NOCOUNT ON ' +
								'INSERT INTO ' + @db_name + '.['+@app_audit_schema+'].'+@audit_name + '(action, action_time, ' + @collist + ') '+
								'SELECT ''''D'''',getdate(), ' + @collist + ' FROM deleted ' +
								'END'') '
								+
								'EXEC (''CREATE TRIGGER audit_' + @table_name + '_u ON ' + @db_name + '.['+@table_schema+'].['+@table_name+'] FOR UPDATE AS ' +
								'BEGIN ' +
								'SET NOCOUNT ON ' +
								'INSERT INTO ' + @db_name + '.['+@app_audit_schema+'].'+@audit_name + '(action, action_time, ' + @collist + ') '+
								'SELECT ''''U'''',getdate(), ' + @collist + ' FROM inserted ' +
								'END'') '
							EXEC (@qry)
						END
					END

					FETCH NEXT FROM @tcrs INTO @table_name, @table_schema, @collist, @colspecs
				END
				CLOSE @tcrs
				DEALLOCATE @tcrs

		--		IF (@action NOT IN ('D','Q')) SELECT 'You MUST click Messages, copy the output to a fresh Query Analyzer window, and run the script.' AS [Important Message]
				EXEC('SELECT '''+@app_audit_schema+'.'' + so.name AS [Audit Table] from #tableSpecs ts JOIN '+@db_name+'.dbo.sysobjects so ON ts.tableschema + ''_'' + ts.tableName = so.name ORDER BY ts.tableschema, ts.tableName')
	     END

		/****************************************************
			 
			 COPY OLD AUDIT DATA INTO NEW LOCAL AUDIT TABLES

		*****************************************************/
		-- check for existence of (app)_audit audit tables
		SET @old_audit_exists = 0
		SET @qry = N'IF EXISTS(SELECT 1 FROM sys.tables AS st WHERE st.name LIKE ('''+@db_name+'%''))
					SET @old_audit_exists = 1'
		EXEC sp_executesql @qry, N'@old_audit_exists TINYINT OUT', @old_audit_exists=@old_audit_exists OUT

		IF (@old_audit_exists = 1)
		BEGIN
			IF OBJECT_ID('tempdb..#audit_tables') IS NOT NULL DROP TABLE #audit_tables
			SELECT SUBSTRING(name, CHARINDEX('__', name) + 2, LEN(name)) AS table_name INTO #audit_tables FROM sys.tables AS st WHERE st.name LIKE @db_name+'%'

			DECLARE @audit_table_name NVARCHAR(MAX)
			DECLARE copy_audit CURSOR FAST_FORWARD READ_ONLY FOR 
				SELECT			table_name
				FROM			#audit_tables

			OPEN copy_audit
			FETCH NEXT FROM copy_audit INTO @audit_table_name
			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- check if table being audited exists
				SET @table_exists = 0
				SET @qry = N'USE '+@db_name+N' 
							IF EXISTS(SELECT 1 FROM sys.tables AS t JOIN sys.schemas AS s ON s.schema_id = t.schema_id WHERE t.name = '''+@audit_table_name+''' AND s.name = ''dbo'')
							SET @table_exists = 1'
				EXEC sp_executesql @qry, N'@table_exists TINYINT OUT', @table_exists=@table_exists OUT

				IF (@table_exists = 1)
				BEGIN
					-- check if new audit table exists
					SET @new_audit_exists = 0
					SET @qry = N'USE '+@db_name+N' 
								IF EXISTS(SELECT 1 FROM sys.tables AS t JOIN sys.schemas AS s ON s.schema_id = t.schema_id WHERE t.name = ''dbo_'+@audit_table_name+''' AND s.name = '''+@app_audit_schema+''')
								SET @new_audit_exists = 1'
					EXEC sp_executesql @qry, N'@new_audit_exists TINYINT OUT', @new_audit_exists=@new_audit_exists OUT

					IF (@new_audit_exists = 1)
					BEGIN
						-- check if new audit table has data
						SET @new_audit_row_count = 0
						SET @qry = 'SELECT @new_audit_row_count = COUNT(*) FROM '+@db_name+'.'+@app_audit_schema+'.dbo_'+@audit_table_name
						EXEC sp_executesql @qry, N'@new_audit_row_count int OUT', @new_audit_row_count=@new_audit_row_count OUT

						IF (@new_audit_row_count = 0)
						BEGIN
							BEGIN TRANSACTION
							BEGIN TRY
								-- check if old audit table has data
								SET @audit_row_count = 0
								SET @qry = 'SELECT @audit_row_count = COUNT(*) FROM dbo.'+@db_name+'__'+@audit_table_name+' WITH(TABLOCK, HOLDLOCK)'
								EXEC sp_executesql @qry, N'@audit_row_count int OUT', @audit_row_count=@audit_row_count OUT

								IF (@audit_row_count > 0)
								BEGIN
									DECLARE @max_row_id INT = 0
									SET @qry = 'SELECT @max_row_id = MAX(rowId) + 100 FROM dbo.'+@db_name+'__'+@audit_table_name
									EXEC sp_executesql @qry, N'@max_row_id int OUT', @max_row_id=@max_row_id OUT

									-- copy old audit data into new local audit table
									IF(@max_row_id > 0)
									BEGIN
										DECLARE @cols NVARCHAR(MAX)
										SET @qry = 'SELECT  @cols = master.dbo.DelimitedList(c.name, '','')
											FROM    sys.tables AS t
											JOIN    sys.columns c ON c.object_id = t.object_id
											WHERE   t.name = '''+@db_name+'__'+@audit_table_name+'''
										'
										EXEC sp_executesql @qry, N'@cols NVARCHAR(MAX) OUT', @cols=@cols OUT

										SET @qry = '
											EXEC '+@db_name+'..sp_executesql N''DBCC CHECKIDENT('''''+@app_audit_schema+'.dbo_'+@audit_table_name+''''', RESEED, '+CONVERT(NVARCHAR(MAX), @max_row_id)+')''

											SET IDENTITY_INSERT '+@db_name+'.'+@app_audit_schema+'.dbo_'+@audit_table_name+' ON
											INSERT INTO '+@db_name+'.'+@app_audit_schema+'.dbo_'+@audit_table_name+'
											('+@cols+')
											SELECT			'+@cols+'
											FROM			dbo.'+@db_name+'__'+@audit_table_name+'
											SET IDENTITY_INSERT '+@db_name+'.'+@app_audit_schema+'.dbo_'+@audit_table_name+' OFF
										'
										EXEC(@qry)
									END
								END
							END TRY
							BEGIN CATCH
									PRINT 'Error #: ' + CONVERT(NVARCHAR(MAX), ISNULL(ERROR_NUMBER(), ''))
									PRINT 'Error Severity:' + CONVERT(NVARCHAR(MAX), ISNULL(ERROR_SEVERITY(), ''))
									PRINT 'Error State:' + CONVERT(NVARCHAR(MAX), ISNULL(ERROR_STATE(), ''))
									PRINT 'Error Procedure:' + CONVERT(NVARCHAR(MAX), ISNULL(ERROR_PROCEDURE(), ''))
									PRINT 'Error Line:' + CONVERT(NVARCHAR(MAX), ISNULL(ERROR_LINE(), ''))
									PRINT 'Error Message: ' + CONVERT(NVARCHAR(MAX), ISNULL(ERROR_MESSAGE(), ''))
								
									IF @@TRANCOUNT > 0
										ROLLBACK TRANSACTION  
										PRINT 'Transaction to insert from dbo.'+@db_name+'__'+@audit_table_name+' into '+@db_name+'.'+@app_audit_schema+'.dbo_'+@audit_table_name+' was rolled back'
							END CATCH
							IF @@TRANCOUNT > 0
								COMMIT TRANSACTION
						END
					END
				END
			FETCH NEXT FROM copy_audit INTO @audit_table_name
			END
			CLOSE copy_audit
			DEALLOCATE copy_audit
		END
	END
END




