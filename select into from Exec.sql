

SELECT	*  
INTO	#lastrun  
FROM	OPENQUERY( TBCProd, 'EXEC erfx_global_asc_flex_001.dbo.xtrc_check_results ''lastrun''   ')   

