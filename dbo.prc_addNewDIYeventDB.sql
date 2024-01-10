SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

-- =============================================
ALTER PROCEDURE [dbo].[prc_addNewDIYeventDB] (
	@db_name		varchar(100)
)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @data_file varchar(max), @log_file varchar(max)
	
	SET @data_file = 'S:\Program Files\Microsoft SQL Server\MSSQL10.MSSQLSERVER\MSSQL\DATA\'+@db_name+'_data.mdf' 
	SET @log_file =  'S:\Program Files\Microsoft SQL Server\MSSQL10.MSSQLSERVER\MSSQL\DATA\'+@db_name+'_log.ldf' 

	BACKUP DATABASE xecs_opt_template TO bcs_opt_template_backup  WITH INIT ,SKIP
--	RESTORE FILELISTONLY 
--	   FROM bcs_opt_template_backup 
	RESTORE DATABASE @db_name 
	   FROM bcs_opt_template_backup 
	   WITH RECOVERY, 
	   MOVE 'xecs_opt_template_Data' TO @data_file, 
	   MOVE 'xecs_opt_template_Log' TO @log_file
END


GO

