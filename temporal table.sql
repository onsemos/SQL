

-- add temporal table to existing table
ALTER TABLE TBL_JUR_FP_CUSTOM ADD
			VALID_FROM DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN CONSTRAINT DF_TBL_JUR_FP_CUSTOM_VALID_FROM DEFAULT SYSUTCDATETIME(),
			VALID_TO DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN CONSTRAINT DF_TBL_JUR_FP_CUSTOM_VALID_TO DEFAULT CONVERT(DATETIME2, '9999-12-31 23:59:59.9999999'),
			PERIOD FOR SYSTEM_TIME(VALID_FROM, VALID_TO);

		ALTER TABLE TBL_JUR_FP_CUSTOM SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.TBL_JUR_FP_CUSTOM_HISTORY));



-- switch off and change primary key , then switch on 
ALTER TABLE TBL_JUR SET   (SYSTEM_VERSIONING = OFF)

DECLARE	@PK_TBL_JUR VARCHAR(200) = (
	SELECT TOP 1 name
	FROM sys.key_constraints  
	WHERE type = 'PK' AND OBJECT_NAME(parent_object_id) = N'TBL_JUR'
)

IF LEN(@PK_TBL_JUR) > 0 BEGIN
	EXEC ('ALTER TABLE TBL_JUR DROP CONSTRAINT '+ @PK_TBL_JUR)
END

ALTER TABLE TBL_JUR ADD CONSTRAINT PK_TBL_JUR PRIMARY KEY CLUSTERED (
	STATE_ABBR ASC,
	COUNTY_NAME ASC,
	CITY_NAME ASC,
	GEOCODE ASC,
	ZIP ASC,
	SD_CODE ASC,
	STJ_NAME ASC,
	EFFECTIVE_MONTH_DATE ASC
)

ALTER TABLE [dbo].TBL_JUR
SET 
    (SYSTEM_VERSIONING = ON (HISTORY_TABLE = [dbo].TBL_JUR_HISTORY , DATA_CONSISTENCY_CHECK = ON ))