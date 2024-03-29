USE [BCS_MASTER]
GO
/****** Object:  StoredProcedure [vz].[prc_mngDatasourceRefreshJobs]    Script Date: 5/25/2016 11:19:17 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [vz].[prc_mngDatasourceRefreshJobs]
(
	@action			NVARCHAR(100) = NULL	-- not currently used
	,@app			NVARCHAR(10) = NULL 	-- not currently used
	,@db_name		NVARCHAR(100)   
	,@job_name		NVARCHAR(128)			--name of job
	,@job_sql		NVARCHAR(MAX)			--sql to run
	,@servername		NVARCHAR(MAX)		--server name, if local can use @@servername
	,@startdate		INT						--date as YYYYMMDD
	,@starttime		INT						--time as HHMMSS
	,@freq_type		INT						--Once: 1, Daily: 4, Weekly: 8
	,@freq_interval		INT					--default 0; unused when @freq_type = 1
	,@freq_subday_type	INT					--Specified Time: 0x1, Minutes: 0x4, Hours: 0x8
	,@freq_subday_interval	INT				--Number of freq_subday_type periods to occur between each execution of the job
	,@owner			NVARCHAR(100)
)
AS
BEGIN
	IF NOT EXISTS(SELECT * FROM msdb.dbo.sysjobs AS sj WHERE sj.name = @job_name)
	BEGIN
		--Add a job
		EXEC MSDB.dbo.sp_add_job 
			@job_name = @job_name
		    
		--Add a job step named process step. This step runs the stored procedure
		EXEC MSDB.dbo.sp_add_jobstep @job_id = NULL, -- uniqueidentifier		
			@job_name = @job_name,
			@step_name = N'process step',
			@subsystem = N'TSQL',
			@command = @job_sql
		    
		--Schedule the job at a specified date and time
		EXEC MSDB.dbo.sp_add_jobschedule
			@enabled = 1,
			@job_name = @job_name,
			@name = 'MySchedule',
			@freq_type = @freq_type,
			@freq_interval = @freq_interval,
			@freq_subday_type = @freq_subday_type,
			@freq_subday_interval = @freq_subday_interval,
			@active_start_date = @startdate,
			@active_start_time = @starttime

		-- Add the job to the SQL Server Server
		EXEC MSDB.dbo.sp_add_jobserver
			@job_name =  @job_name,
			@server_name = @servername
		
		-- Update job owner	
		EXEC MSDB.dbo.sp_update_job 
			@job_name = @job_name, 
			@owner_login_name = @owner		
	END
	ELSE
	BEGIN
		--update Schedule for existing job at a specified date and time
		EXEC MSDB.dbo.sp_update_schedule		
		        @name = 'MySchedule',
		        @freq_type = @freq_type,
			@freq_interval = @freq_interval,
			@freq_subday_type = @freq_subday_type,
			@freq_subday_interval = @freq_subday_interval,
		        @active_start_date = @startdate,
		        @active_start_time = @starttime
	END	
END



