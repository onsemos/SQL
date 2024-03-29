USE [xecs_master]
GO
/****** Object:  Trigger [dbo].[trgr_opt_report_log_insert]    Script Date: 12/13/2016 5:27:55 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER TRIGGER [dbo].[trgr_opt_report_log_insert]
	ON  [dbo].[opt_report_log_details]
	AFTER INSERT
AS 
BEGIN
	SET NOCOUNT ON
	
	IF OBJECT_ID('tempdb..#trgr_orli_output') IS NOT NULL DROP TABLE #trgr_orli_output
	CREATE TABLE #trgr_orli_output(log_id INT PRIMARY KEY, opt_db_id INT, opt_db_name NVARCHAR(250)
							,report_id INT, report_name NVARCHAR(250)
							,report_type_id INT, report_type_name NVARCHAR(50), report_type_limit INT
							,total_time_seconds INT, user_name NVARCHAR(50)
							)
	
	-- POPULATE OUTPUT TABLE FOR EMAIL
	INSERT INTO #trgr_orli_output
	        (
	         log_id
	        ,opt_db_id
	        ,opt_db_name
	        ,report_id
	        ,report_name
	        ,report_type_id
	        ,report_type_name
	        ,report_type_limit
	        ,total_time_seconds
			,user_name
	        )
	SELECT			d.log_id
					,d.opt_db_id
					,tmd.database_name
					,d.report_id
					,NULL AS report_name
					,d.report_type_id
					,mlrt.report_type_name
					,mlrt.run_threshold_sec
					,d.total_time_seconds
					,d.user_name
	FROM			inserted AS d
			JOIN	TBL_MSTR_DATABASES AS tmd ON tmd.database_id = d.opt_db_id
			JOIN	Mstr_Log_Report_Types AS mlrt ON mlrt.report_type_id = d.report_type_id
	WHERE			d.opt_db_id <> 1 -- Default parameter run
				AND	d.total_time_seconds > mlrt.run_threshold_sec
	
	-- UPDATE REPORT NAME
	DECLARE @sql NVARCHAR(MAX) = ''
	SELECT			@sql += 'UPDATE a SET a.report_name = b.report_name FROM #trgr_orli_output AS a JOIN ' 
						+ o.opt_db_name + CASE o.report_type_id WHEN 1 THEN '.vz.Vlang_Reports' ELSE '.dbo.ELang_Reports' END
						+ ' AS b ON a.report_id = b.report_id '
						+ CASE o.report_type_id WHEN 1 THEN '' ELSE 'WHERE b.language_id = 1' END
	FROM			#trgr_orli_output AS o
	EXEC(@sql)	

	
	
	
	-- EMAIL SLOW REPORT INFO TO OPT TEAM
	IF(SELECT COUNT(*) FROM #trgr_orli_output AS o) > 0
	BEGIN
		SET NOCOUNT ON
		DECLARE @query nvarchar(MAX),
				@orderBy nvarchar(MAX) = NULL,
				@html nvarchar(MAX) = NULL
		
		IF @orderBy IS NULL BEGIN
			SET @orderBy = 'ORDER BY [OPT Database Name], [Total Time (Seconds)]'  -- If your query has an Order By, copy/paste it here without the table alias
		END
		
		SET @orderBy = REPLACE(@orderBy, '''', '''''');
		
		SET @query = 'SELECT			o.log_id AS [Log ID]
									,o.opt_db_name AS [OPT Database Name]
									,o.report_name AS [Report Name]
									,o.report_type_name AS [Report Type]
									,o.user_name AS [User Name]
									,o.report_type_limit AS [Run Threshold (Seconds)]
									,o.total_time_seconds AS [Total Time (Seconds)]
									, CONVERT(DECIMAL(10,2), CASE WHEN o.total_time_seconds < o.report_type_limit THEN 0 
										ELSE ((o.total_time_seconds - o.report_type_limit) / (o.report_type_limit * 1.00)) * 100
										END) AS [% Slowness]
					FROM			#trgr_orli_output AS o'
		
		DECLARE @realQuery nvarchar(MAX) = '
			DECLARE @headerRow nvarchar(MAX);
			DECLARE @cols nvarchar(MAX);    
		
			SELECT * INTO #temp FROM (' + @query + ') a;
		
			SELECT @cols = COALESCE(@cols + '', '''''''', '', '''') + ''['' + name + ''] AS ''''td''''''
			FROM tempdb.sys.columns 
			WHERE object_id = object_id(''tempdb..#temp'')
			ORDER BY column_id;
		
			SET @cols = ''SET @html = CAST(( SELECT '' + @cols + '' FROM #temp ' + @orderBy + ' FOR XML PATH(''''tr''''), ELEMENTS XSINIL) AS nvarchar(max))''    
		
			EXEC sys.sp_executesql @cols, N''@html nvarchar(MAX) OUTPUT'', @html=@html OUTPUT
		
			SELECT @headerRow = COALESCE(@headerRow + '''', '''') + ''<th>'' + name + ''</th>'' 
			FROM tempdb.sys.columns 
			WHERE object_id = object_id(''tempdb..#temp'')
			ORDER BY column_id;
		
			SET @headerRow = ''<tr>'' + @headerRow + ''</tr>'';
		
			SET @html = ''<table border="1">'' + @headerRow + @html + ''</table>'';    
		'
		
		EXEC sys.sp_executesql @realQuery, N'@html nvarchar(MAX) OUTPUT', @html=@html OUTPUT
		
		--SELECT @html
		
		EXEC msdb.dbo.sp_send_dbmail 
			@profile_name = 'SQLMail',
		    @recipients = 'a.ditusa@bravosolution.com;p.jang@bravosolution.com; j.tu@bravosolution.com; a.guglielmelli@bravosolution.com',  
		    @subject = '* (PROD) Slow Opt Report *',
		    @from_address = 'opt-support@bravosolution.com',
			@reply_to = 'opt-support@bravosolution.com',
			@body_format = 'HTML',
		    @query_no_truncate = 1,
		    @attach_query_result_as_file = 0,
			@body = @html
		
	END
END
