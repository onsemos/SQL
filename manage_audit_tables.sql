USE [erfx_audit]
GO
/****** Object:  StoredProcedure [dbo].[manage_audit_tables]    Script Date: 2/10/2017 3:41:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

/************
Arguments: 
	db_name: the name of the database, such as rfx_demo
	action: 
DEFAULT-->	'A' = Activate/Alter audit information -- Keeps data (unless columns are deleted) and recreates triggers. Accepts @tbl arg (optional)
							Also will start new tables as well.
		'Q' = Quit auditing, but keep information
		'R' = Resume (after a Q). It only re-creates the script to create the triggers.
		'T' = Test -- no action taken

Dangerous ones -- DELETES DATA:
		'S' = Setup audit information -- Also reStarts any auditing (DROPs all tables first!!!) 
		'D' = Delete audit information
		'U' = Update (refresh) one table (or adds it). Requires extra @table_name arg. Wipes out that table and starts oves.
***********/ 
ALTER PROCEDURE [dbo].[manage_audit_tables]
(	@db_name	varchar(500)
	,@action	char(1) = 'A'	-- 'A' is the safest option
	,@table_name	varchar(500) = null
)
 AS
BEGIN
	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF
	DECLARE @db_id int, @qry nvarchar(max), @all_tables tinyint = CASE WHEN @table_name IS NULL THEN 1 ELSE 0 END
	DECLARE @app nvarchar(10) = LEFT(DB_NAME(),CHARINDEX('_',DB_NAME())-1)
	IF (@app IN ('XECS'))
		SET @app='opt'
	IF (@app IN ('CBC'))
		SET @app='tbc'
	DECLARE @app_master nvarchar(50) = CASE @app WHEN 'opt' THEN 'xecs' ELSE @app END + '_master'
	DECLARE @audit_db nvarchar(50) = @app + '_audit'
	DECLARE @app_audit_tables nvarchar(50) = @app + '_audit_tables'
	
	
	SET @qry = 'SELECT  @db_id = database_id FROM '+@app_master+'.dbo.TBL_MSTR_DATABASES WHERE database_name = @db_name'
	EXEC sp_executesql @qry, N'@db_id int OUT, @db_name varchar(500)', @db_name=@db_name, @db_id=@db_id OUT
	
	DECLARE @retCode INT
	
	IF (@db_id IS NOT Null)
	BEGIN
		SET @qry = 'USE '+@db_name+' SELECT  @retCode = SIGN(NULLIF(OBJECT_ID(@app_audit_tables),0))'
		EXEC sp_executesql @qry, N'@retCode int OUT,  @app_audit_tables varchar(500)', @retCode=@retCode OUT, @app_audit_tables=@app_audit_tables
	END	
	ELSE 
	BEGIN
		PRINT 'That is not a valid database name'
	END
	IF (1=@retCode)
	BEGIN
		CREATE TABLE #tableCols (tableId int, colid int, tableName varchar(500), colName varchar(400), colType varchar(100) primary key (tableId, colId))
		SET @qry = 
              'SELECT so.object_id as tableId, sc.column_id, quotename(so.name) as tableName,  quotename(sc.name) as colName,
                               st.name + CASE sc.system_type_id     '+
                     'WHEN  35 THEN ''(''+convert(char(2),sc.scale)+'')''                 '+--time
                     'WHEN  42 THEN ''(''+convert(char(2),sc.scale)+'')''                 '+-- datetime2
                     'WHEN  43 THEN ''(''+convert(char(2),sc.scale)+'')''                 '+-- datetimeoffset
                     'WHEN 106 THEN ''(''+convert(char(2),sc.precision)+'',''+convert(char(2),sc.scale)+'')''     '+-- decimal
                     'WHEN 108 THEN ''(''+convert(char(2),sc.precision)+'',''+convert(char(2),sc.scale)+'')''     '+-- numeric
                     'WHEN 165 THEN ''(''+(CASE sc.max_length WHEN -1 THEN ''max'' ELSE convert(char(4),sc.max_length) END)+'')''       '+-- varbinary
                     'WHEN 167 THEN ''(''+(CASE sc.max_length WHEN -1 THEN ''max'' ELSE convert(char(4),sc.max_length) END)+'')''       '+-- varchar
                     'WHEN 173 THEN ''(''+convert(char(4),sc.max_length)+'')''            '+-- binary
                     'WHEN 175 THEN ''(''+convert(char(4),sc.max_length)+'')''            '+-- char
                     'WHEN 231 THEN ''(''+(CASE sc.max_length WHEN -1 THEN ''max'' ELSE convert(char(4),sc.max_length/2) END)+'')''     '+-- nvarchar
                     'WHEN 239 THEN ''(''+convert(char(4),sc.max_length/2)+'')''            '+-- nchar
                     'ELSE '''' END as colType
              FROM          '+@db_name+'.sys.columns sc
                     JOIN   '+@db_name+'.sys.tables so ON sc.object_id=so.object_id
                     JOIN   '+@db_name+'.sys.types st on sc.system_type_id = st.user_type_id
                     JOIN   '+@db_name+'.dbo.'+@app_audit_tables+' eat ON eat.tablename=so.name
              WHERE so.[type]=''U''
              ORDER BY so.name, sc.column_id'
              IF (@action='T')
		EXEC (@qry)	-- Display above info and stop.
              ELSE
              IF (@action<>'T')
              BEGIN
		INSERT INTO #tableCols
		exec (	@qry) 
		
		CREATE TABLE #tableSpecs (tableId int primary key, tablename varchar(200), colspecs varchar(max))
		CREATE TABLE #tableColumns (tableId int primary key, collist varchar(max))
	
		INSERT INTO #tableSpecs (tableId, colspecs)
		SELECT tableId, master.dbo.DelimitedList(colname+' '+coltype,',') FROM #tableCols GROUP BY tableId
	
		INSERT INTO #tableColumns (tableId, collist)
		SELECT tableId, master.dbo.DelimitedList(colname,',') FROM #tableCols GROUP BY tableId
		EXEC ('UPDATE #tableSpecs
				SET tableName = so.name
			FROM		#tableSpecs ts
				JOIN	'+@db_name+'.sys.tables so ON ts.tableId = so.object_id')
	
		IF (@action IN ('U','A'))
		BEGIN
			DELETE #tableSpecs WHERE tableName <> isNull(@table_name,tablename)
		END
	
	
		-- ADD/REMOVE DB EXCLUSION HERE. NOTE that if only 1 table is refreshed, but the DB is excluded, it stays excluded.
		IF (@all_tables = 1)
		BEGIN
			IF (@action IN ('S','A','U','R'))
				DELETE audit_DB_exclusions WHERE database_name = @db_name
			ELSE IF (@action IN ('Q','D') AND NOT EXISTS(SELECT 1 FROM audit_DB_exclusions WHERE database_name = @db_name))
				INSERT INTO audit_DB_exclusions ( database_name ) VALUES ( @db_name )
		END
	
	
		DECLARE @to_create tinyint = 0, @is_same tinyint=0, @make_triggers tinyint = 1, @err_msg varchar(500)
		DECLARE @colspecs varchar(max), @collist varchar(max), @renamed varchar(300), @audit_name varchar(300), @copy_cols varchar(max)
		CREATE TABLE #same_cols (colName varchar(100) primary key)
		CREATE TABLE #same (same int)
		
		DECLARE @tcrs CURSOR 
		SET @tcrs = CURSOR FAST_FORWARD
			FOR SELECT ts.tableName, tc.collist, ts.colspecs FROM #tableSpecs ts JOIN #tableColumns tc ON ts.tableId=tc.tableId
		OPEN @tcrs
		FETCH NEXT FROM @tcrs INTO @table_name, @collist, @colspecs
	
--			IF (@action NOT IN ('D','Q')) PRINT ('USE ' + @db_name + char(13) + 'GO')

		WHILE (@@FETCH_STATUS=0)
		BEGIN
			SET @audit_name = @db_name + '__'+@table_name 
			SET @make_triggers=1
			-- Regardless of option, always delete tables in audit database and triggers in event DATABASE
			IF (@action IN ('S','D','U')) -- Delete, reStart, Update (but not Alter)
			BEGIN
				IF EXISTS (SELECT * FROM sys.tables WHERE name = @audit_name) 
					EXEC ('DROP TABLE '+@audit_name)
			END
			
			-- In all cases, drop existing triggers. Depending on action, recreate them, below.			
			EXEC ('USE ' + @db_name + '
				 IF EXISTS (SELECT 1 FROM sys.triggers  
						WHERE name = ''audit_' + @table_name + '_i'')
					DROP TRIGGER audit_' + @table_name + '_i')

			EXEC ('USE ' + @db_name + '
				 IF EXISTS (SELECT 1 FROM sys.triggers  
						WHERE name = ''audit_' + @table_name + '_d'')
					DROP TRIGGER audit_' + @table_name + '_d')

			EXEC ('USE ' + @db_name + '
				 IF EXISTS (SELECT 1 FROM sys.triggers  
						WHERE name = ''audit_' + @table_name + '_u'')
					DROP TRIGGER audit_' + @table_name + '_u')

			-- If not deleting, then create tables in audit database and script for triggers in event database
			IF (@action IN ('Q','D'))	
			BEGIN
				IF NOT EXISTS(SELECT 1 FROM audit_table_exclusions ate WHERE ate.database_name = @db_name AND ate.table_name = @table_name)
				INSERT INTO audit_table_exclusions  ( database_name, table_name ) VALUES (@db_name, @table_name) 
			END
			ELSE
			BEGIN	
				-- REMOVE FROM TABLE EXCLUSIONS HERE
				DELETE audit_table_exclusions WHERE database_name = @db_name AND table_name = @table_name						
							
				SET @is_same=0
				SET @make_triggers=1
				IF (@action IN ('S','U')) SET @to_create = 1 ELSE SET @to_create = 0
				
				IF (@action='A')
				BEGIN 
					SET @is_same = 0
					IF OBJECT_ID(@audit_name) IS Null
					BEGIN
						SET @to_create = 1	-- this is the same as 'U' or 'S' at this point
						SET @is_same = 1
					END
					ELSE
					BEGIN	-- check if it's the same table. 
						SET @qry = '
						TRUNCATE TABLE #same_cols
						DECLARE @live_tbl int, @audit_tbl int, @sameness tinyint
						SELECT @live_tbl = OBJECT_ID 
						FROM '+@db_name+'.sys.tables WHERE name = '''+ @table_name+ '''
						SET @audit_tbl = Object_id('''+ @audit_name+''')

						;WITH	live AS (SELECT *, row_number() OVER (ORDER BY column_id) as col_rank FROM '+@db_name+'.sys.columns WHERE object_id=@live_tbl)
							,audit AS (SELECT *, row_number() OVER (ORDER BY column_id) as col_rank FROM sys.columns WHERE object_id = @audit_tbl AND column_id>3)
							,same  AS (SELECT COUNT(*) as diff_cols
								FROM		live s
								FUll OUTER JOIN	audit a  ON s.col_rank=a.col_rank AND
											(s.name=a.name and s.system_type_id=a.system_type_id and 
											 s.max_length=a.max_length and s.[precision]=a.[precision] and 
											 s.scale=a.scale)
								WHERE s.col_rank + a.col_rank IS NULL)
						SELECT  @sameness = 1-sign(diff_cols)
						FROM	same

						IF (@sameness = 0)
						BEGIN
							;WITH	live AS (SELECT * FROM '+ @db_name + '.sys.columns WHERE object_id=@live_tbl)
								,audit AS (SELECT * FROM sys.columns WHERE object_id = @audit_tbl AND column_id>3)
							INSERT INTO #same_cols
							SELECT  s.name
							FROM		live s
								JOIN	audit a ON s.name=a.name
								
							INSERT INTO #same VALUES (0)
						END'
						EXEC (@qry)
						
						IF EXISTS(SELECT 1 FROM #same)
						BEGIN
							BEGIN TRY
								SET @is_same = 0
								SET @to_create = 1
								SET @renamed = @audit_name + '__'+replace(replace(replace(replace((SYSUTCDATETIME ( )),'.','_'),'-','_'),':','_'),' ','_')
								-- rename
								print '/*'
								EXEC sp_rename @audit_name, @renamed
								print '*/'
							END TRY
							BEGIN CATCH
								SET @to_create = 0
								SET @make_triggers=0
								SET @err_msg = 'ERROR ***** (Renaming): ' + @renamed + '. Auditing must be manually fixed for this table!'
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
					EXEC ('CREATE TABLE dbo.'+ @audit_name +
					'(rowId bigint primary key identity(1,1), action char(1), action_time datetime, '+@colspecs+')')
				END
				
				IF (@action = 'A' AND @is_same=0)
				BEGIN TRY -- Attempt to copy data
					SET @copy_cols = ''
					SELECT @copy_cols=@copy_cols+','+colName FROM #same_cols
					SET @qry = '
					SET IDENTITY_INSERT dbo.'+ @audit_name +' ON
					INSERT INTO dbo.'+ @db_name + '__'+@table_name + '(rowId, action, action_time'+@copy_cols+')
					SELECT rowId, action, action_time'+@copy_cols+' FROM '+@renamed + '
					SET IDENTITY_INSERT dbo.'+ @audit_name +' OFF
					DECLARE @max_ident bigint = 0
					SELECT @max_ident=isNull(max(rowId),0) FROM dbo.'+ @audit_name + '
					print ''/*''
					DBCC CHECKIDENT  ('+ @audit_name + ', RESEED, @max_ident)
					print ''*/'''
					EXEC (@qry)
					SET @qry = 'DROP TABLE ' + @renamed
					EXEC (@qry)
				END TRY
				BEGIN CATCH
					SET @make_triggers=0
					SET @err_msg = 'ERROR *****(Copy):' + @renamed + '. Auditing must be manually fixed for this table!'
					RAISERROR (@err_msg, 10, 2)
				END CATCH

				IF (@make_triggers=1)
				BEGIN
				
				SET @qry = 'USE '+@db_name+' ' +
					'EXEC (''CREATE TRIGGER audit_' + @table_name + '_i ON [dbo].['+@table_name+'] FOR INSERT AS ' +
					'BEGIN '+
					'SET NOCOUNT ON '+
					'INSERT INTO '+@audit_db+'.dbo.'+@audit_name + '(action, action_time, ' + @collist + ') ' +
					'SELECT ''''I'''',getdate(), ' + @collist + ' FROM inserted ' +
					'END'') '
					+
					'EXEC (''CREATE TRIGGER audit_' + @table_name + '_d ON [dbo].['+@table_name+'] FOR DELETE AS ' +
					'BEGIN ' +
					'SET NOCOUNT ON ' +
					'INSERT INTO '+@audit_db+'.dbo.'+@audit_name + '(action, action_time, ' + @collist + ') '+
					'SELECT ''''D'''',getdate(), ' + @collist + ' FROM deleted ' +
					'END'') '
					+
					'EXEC (''CREATE TRIGGER audit_' + @table_name + '_u ON [dbo].['+@table_name+'] FOR UPDATE AS ' +
					'BEGIN ' +
					'SET NOCOUNT ON ' +
					'INSERT INTO '+@audit_db+'.dbo.'+@audit_name + '(action, action_time, ' + @collist + ') '+
					'SELECT ''''U'''',getdate(), ' + @collist + ' FROM inserted ' +
					'END'') '
				EXEC (@qry)

/*					
				PRINT ( 'CREATE TRIGGER audit_' + @table_name + '_i ON [dbo].['+@table_name+'] FOR INSERT AS
					BEGIN
					SET NOCOUNT ON
					INSERT INTO erfx_audit.dbo.'+@audit_name + '(action, action_time, ' + @collist + ')
					SELECT ''I'',getdate(), * FROM inserted
					END')
				PRINT ('GO')
				PRINT ('CREATE TRIGGER audit_' + @table_name + '_d ON [dbo].['+@table_name+'] FOR DELETE AS
					BEGIN
					SET NOCOUNT ON
					INSERT INTO erfx_audit.dbo.'+@audit_name + '(action, action_time, ' + @collist + ')
					SELECT ''D'',getdate(), * FROM deleted
					END')
				PRINT ('GO')
				PRINT ('CREATE TRIGGER audit_' + @table_name + '_u ON [dbo].['+@table_name+'] FOR UPDATE AS
					BEGIN
					SET NOCOUNT ON
					INSERT INTO erfx_audit.dbo.'+@audit_name + '(action, action_time, ' + @collist + ')
					SELECT ''U'',getdate(), * FROM inserted
					END')
				PRINT ('GO')
*/					
				END
			END

			FETCH NEXT FROM @tcrs INTO @table_name, @collist, @colspecs
		END
		CLOSE @tcrs
		DEALLOCATE @tcrs

--		IF (@action NOT IN ('D','Q')) SELECT 'You MUST click Messages, copy the output to a fresh Query Analyzer window, and run the script.' AS [Important Message]
		SELECT so.name AS [Audit Tables] from #tableSpecs ts JOIN sysobjects so ON @db_name+'__'+ts.tableName=so.name
	     END
	END
	ELSE IF (@db_id IS NOT Null)
	BEGIN
		PRINT 'You should run the following in an SSMS Query window and then populate '+@audit_db+' with the table names that should be tracked:'
		PRINT 'USE ' + @db_name
		PRINT 'CREATE TABLE ['+@app_audit_tables+'] ([tablename] varchar(200) NOT NULL PRIMARY KEY)'
		PRINT 'GO'
	END
END

