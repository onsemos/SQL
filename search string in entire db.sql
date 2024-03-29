USE erfx_bravo_flex_template_v2
DECLARE
    @search_string      VARCHAR(100),
    @table_name         SYSNAME,
    @table_id           INT,
    @column_name        SYSNAME,
    @sql_string         VARCHAR(2000)

SET @search_string = 'Type string you want to search' -- you can also use %


DECLARE tables_cur CURSOR FOR SELECT b.NAME+'.'+a.name AS name, object_id FROM sys.objects a JOIN sys.schemas b ON a.schema_id = b.schema_id WHERE a.type IN ('U','V')


OPEN tables_cur

FETCH NEXT FROM tables_cur INTO @table_name, @table_id

WHILE (@@FETCH_STATUS = 0)
BEGIN
    DECLARE columns_cur CURSOR FOR SELECT name FROM sys.columns WHERE object_id = @table_id AND system_type_id IN (167, 175, 231, 239)

    OPEN columns_cur

    FETCH NEXT FROM columns_cur INTO @column_name
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @sql_string = 'IF EXISTS (SELECT * FROM ' + @table_name + ' WHERE [' + @column_name + '] LIKE ''%' + @search_string + '%'') PRINT ''' + @table_name + ', ' + @column_name + ''''

        EXECUTE(@sql_string)

        FETCH NEXT FROM columns_cur INTO @column_name
    END

    CLOSE columns_cur

    DEALLOCATE columns_cur

    FETCH NEXT FROM tables_cur INTO @table_name, @table_id
END

CLOSE tables_cur

DEALLOCATE tables_cur


