

/* 
check log size
https://technet.microsoft.com/en-us/library/ms189768(v=sql.105).aspx 
*/
DBCC SQLPERF (LOGSPACE)

/*
shrink file size
https://technet.microsoft.com/en-us/library/ms189493(v=sql.105).aspx
*/
SELECT	name 
	, size/128	AS sizeInMB
	, CAST(FILEPROPERTY(name, 'SpaceUsed') AS int)/128.0	AS usedSpaceInMB
	, size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS int)/128.0 AS AvailableSpaceInMB
	, physical_name
FROM	sys.database_files;


DECLARE @log_name  NVARCHAR(200) = (SELECT name FROM sys.database_files WHERE type_desc = 'log')
--	select @log_name
DBCC SHRINKFILE (@log_name, 1) -- if second parameter is not specified, it will use the default number when the db was set up
