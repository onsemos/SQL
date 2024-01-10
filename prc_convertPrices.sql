USE [erfx_bravo_flex_template_v2]

 
ALTER procedure [dbo].[prc_convertPrices]
	@action			NVARCHAR(50) = NULL
AS

BEGIN
	/* update supplier_id (incumbent id) */
	DECLARE @sql_incumbents NVARCHAR(MAX) = N'
		UPDATE		a
		SET		supplier_id = b.organization_id
		FROM		eBaseline a
			JOIN	'+ erfx_master.dbo.getTbcDbName(DB_NAME()) +'.dbo.Adm_Organizations b ON a.supplier = b.organization_name
	'
	
	EXEC (@sql_incumbents)
	
	
	/*====================================================================================  
	=  
	=	Incumbent Tables
	=  
	====================================================================================*/
	/* gather columns that are baseline cost components */  
	DECLARE @inc_col_list NVARCHAR(MAX) = N'', @inc_update_list NVARCHAR(MAX) = N''
	
	SELECT		@inc_col_list += N', '+attrib_code
			, @inc_update_list +=  N', SUM(annual_volume * '+attrib_code+N') / NULLIF( SUM(CASE WHEN '+attrib_code+N' IS NULL THEN 0 ELSE annual_volume END),0 ) AS '+attrib_code
	FROM		Meta_Baseline
	WHERE		is_baseline_cost = 1
	
	/* RFP Incumbents */	
	TRUNCATE TABLE eItem_Incumbents
	DECLARE @rfp_inc_qry NVARCHAR(MAX) = N'
		INSERT		eItem_Incumbents (
					item_id, supplier_id, annual_volume 
					@inc_col_list
				)   
		SELECT		rfp_item_id	
				, supplier_id	
				, SUM(annual_volume)	AS annual_volume  
				@inc_update_list
		FROM		eBaseline a 
		WHERE		rfp_item_id IS NOT NULL AND supplier_id IS NOT NULL
		GROUP BY	rfp_item_id, supplier_id
	'
	
	SET @rfp_inc_qry = REPLACE(REPLACE(@rfp_inc_qry, '@inc_col_list',@inc_col_list), '@inc_update_list',@inc_update_list)
	EXEC	(@rfp_inc_qry)
	
	
	/* OPT Incumbents */  
	TRUNCATE TABLE optIncumbents
	
	DECLARE @opt_inc_qry NVARCHAR(MAX) = N'
		INSERT		optIncumbents (
					item_id, supplier_id, annual_volume
					@inc_col_list
				)   
		SELECT		opt_item_id	
				, supplier_id	
				, SUM(annual_volume)	AS annual_volume  
				@inc_update_list
		FROM		eBaseline a 
		WHERE		opt_item_id IS NOT NULL AND supplier_id IS NOT NULL
		GROUP BY	opt_item_id, supplier_id
	'
	
	SET @opt_inc_qry = REPLACE(REPLACE(@opt_inc_qry, '@inc_col_list',@inc_col_list), '@inc_update_list',@inc_update_list)
	EXEC	(@opt_inc_qry)
	
	
	/*====================================================================================  
	=  
	=	OPT Roll up
	=  
	====================================================================================*/  
	
	/************************************************************************************
	*	Numeric (MAX/MIN/SUM/WEIGHTED AVG)
	************************************************************************************/
	DECLARE @opt_num_qry NVARCHAR(MAX) = N'
		MERGE	optItems t    
		USING	(    
			SELECT		opt_item_id	AS item_id
					@opt_num_col_list
			FROM		eBaseline a
			WHERE		opt_item_id IS NOT NULL
			GROUP BY	opt_item_id 
			) s ON t.item_id = s.item_id   
		WHEN	MATCHED THEN	    
			UPDATE	SET	@opt_num_update_list
		WHEN	NOT MATCHED BY SOURCE	THEN 
			UPDATE	SET	is_active = NULL; 
	'
		
	DECLARE @opt_num_col_list NVARCHAR(MAX) = N'', @opt_num_update_list NVARCHAR(MAX) = N''
	
	SELECT		@opt_num_col_list +=	CASE	WHEN aggregation IN ('MAX','MIN','SUM') THEN N', '+ aggregation +N'('+ attrib_code +N')		AS '+ attrib_code +N'_raw'
						WHEN aggregation IN ('WEIGHTED AVG') THEN N', SUM(CONVERT(FLOAT,annual_volume) * '+ attrib_code +N') / NULLIF( SUM(CASE WHEN '+ attrib_code +N' IS NULL THEN 0 ELSE annual_volume END),0 ) AS '+ attrib_code +N'_raw'
						ELSE ''
						END
			, @opt_num_update_list +=	CASE	WHEN LEN(@opt_num_update_list) > 0 THEN N', ' ELSE N'' END
						+ attrib_code +N'_raw = s.'+ attrib_code +N'_raw'
	FROM		Meta_Baseline
	WHERE		is_input = 1 AND is_opt = 1 AND is_opt_def = 0 
		AND	(
				( cell_type = 'NUMERIC' AND aggregation IN ('SUM','WEIGHTED AVG') )
			OR	
				aggregation IN ('MAX','MIN')
			)
	
	SET @opt_num_qry = REPLACE(REPLACE(@opt_num_qry,'@opt_num_col_list',@opt_num_col_list),'@opt_num_update_list',@opt_num_update_list) 
	
	IF LEN(@opt_num_col_list)> 0	EXEC (@opt_num_qry)
	
	
	/************************************************************************************
	*	MOST for all cell types
	************************************************************************************/
	/* use rfp_item_id to update optItems in order to keep "most" fields the same between OPT & RFP */
	DECLARE @opt_most_list NVARCHAR(MAX) = N''
	
	SELECT		@opt_most_list += 
			N'UPDATE		a
			SET		'+ attrib_code +N'_raw = b.'+ attrib_code +N'_raw
			FROM		optItems a
				JOIN	(       
					SELECT		opt_item_id	AS item_id			    
							, '+ attrib_code +N' AS 	'+ attrib_code +N'_raw    
							, ROW_NUMBER() OVER (PARTITION BY opt_item_id ORDER BY COUNT(*) DESC, SUM(annual_volume) DESC) AS row_num 		     
					FROM		eBaseline      
					WHERE		opt_item_id IS NOT NULL     
					GROUP BY	opt_item_id, '+ attrib_code +N'    
					) b ON a.item_id = b.item_id AND b.row_num = 1
			'
	FROM		Meta_Baseline
	WHERE		is_input = 1 AND is_opt = 1 AND is_opt_def = 0 
		AND	aggregation = 'MOST'
		
		
	IF LEN(@opt_most_list)> 0	EXEC (@opt_most_list)
	
	
	/************************************************************************************
	*	CSV for all cell types
	************************************************************************************/
	/* use rfp_item_id to update optItems in order to keep "csv" fields the same between OPT & RFP */
	DECLARE @opt_csv_list NVARCHAR(MAX) = N''
	
	SELECT		@opt_csv_list += 
			N'UPDATE		a
			SET		'+ attrib_code +N'_raw = b.'+ attrib_code +N'_raw
			FROM		optItems a
				JOIN	(       
					SELECT		opt_item_id	AS item_id				   		    
							, NULLIF(master.dbo.orderedDelimitedList(distinct '+ attrib_code +N', '', '', ''ASC''),'''') AS '+ attrib_code +N'_raw		     
					FROM		eBaseline     
					WHERE		opt_item_id IS NOT NULL 
					GROUP BY	opt_item_id     
					) b ON a.item_id = b.item_id
			' 
	FROM		Meta_Baseline
	WHERE		is_input = 1 AND is_opt = 1 AND is_opt_def = 0 
		AND	aggregation = 'CSV'
		
		
	IF LEN(@opt_csv_list)> 0	EXEC (@opt_csv_list)
		
	
		
	/************************************************************************************
	*	Update final column with OVERRIDE or RAW
	************************************************************************************/	
	DECLARE @opt_final_qry NVARCHAR(MAX) = N'	
		UPDATE	optItems
		SET 	@opt_final_update_list
		WHERE	is_active = 1
	'
		
		
	DECLARE @opt_final_update_list NVARCHAR(MAX) = N''
	
	SELECT		@opt_final_update_list	+= CASE	WHEN LEN(@opt_final_update_list) > 0 THEN N', ' ELSE N'' END
						+  attrib_code +N' = COALESCE('+ attrib_code +N'_override, '+ attrib_code +N'_raw)'
	FROM		Meta_Baseline
	WHERE		is_input = 1 AND is_opt = 1 AND is_opt_def = 0 
		
		
	SET @opt_final_qry = REPLACE(@opt_final_qry,'@opt_final_update_list',@opt_final_update_list)
	
	
	IF LEN(@opt_final_update_list)> 0	EXEC (@opt_final_qry)
		
		
	/*====================================================================================  
	=  
	=	RFP Roll up
	=  
	====================================================================================*/ 
	/* update is_active in RFP baesd on OPT */
	MERGE	eMstr_Items t
	USING	(
		SELECT	rfp_item_id		AS item_id
				, MIN(is_active)	AS is_active
		FROM		optItems
		WHERE		is_active IS NOT NULL AND rfp_item_id IS NOT NULL
		GROUP BY	rfp_item_id
		) s ON t.item_id = s.item_id
	WHEN	MATCHED THEN
		UPDATE SET is_active = s.is_active;
		
	
	
	
	
	/************************************************************************************
	*	Numeric (MAX/MIN/SUM/WEIGHTED AVG)
	************************************************************************************/
	DECLARE @rfp_num_qry NVARCHAR(MAX) = N'		
		MERGE	eMstr_Items t   
		USING	(   
			SELECT		rfp_item_id		AS item_id
					@rfp_num_col_list
			FROM		optItems   
			WHERE		is_active = 1 AND rfp_item_id IS NOT NULL 
			GROUP BY	rfp_item_id  
			) s ON t.item_id = s.item_id  
		WHEN	MATCHED THEN	   
			UPDATE	SET	@rfp_num_update_list; 
	'
	
	DECLARE @rfp_num_col_list NVARCHAR(MAX) = N'', @rfp_num_update_list NVARCHAR(MAX) = N''
	
	SELECT		@rfp_num_col_list +=	CASE	WHEN aggregation IN ('MAX','MIN','SUM') THEN N', '+ aggregation +N'('+ attrib_code +N')		AS '+ attrib_code 
							WHEN aggregation IN ('WEIGHTED AVG') THEN N', SUM(CONVERT(FLOAT,annual_volume) * '+ attrib_code +N') / NULLIF( SUM(CASE WHEN '+ attrib_code +N' IS NULL THEN 0 ELSE annual_volume END),0 ) AS '+ attrib_code 
							ELSE N''
							END
			, @rfp_num_update_list += CASE	WHEN LEN(@rfp_num_update_list) > 0 THEN N', ' ELSE N'' END + attrib_code +N' = s.'+ attrib_code 
	FROM		Meta_Baseline
	WHERE		is_input = 1 AND is_rfp = 1 AND is_rfp_def = 0 
		AND	(
				( cell_type = 'NUMERIC' AND aggregation IN ('SUM','WEIGHTED AVG') )
			OR	
				aggregation IN ('MAX','MIN')
			)
	
	
	SET @rfp_num_qry = REPLACE(REPLACE(@rfp_num_qry,'@rfp_num_col_list',@rfp_num_col_list),'@rfp_num_update_list',@rfp_num_update_list) 
	
	IF LEN(@rfp_num_col_list)> 0	EXEC (@rfp_num_qry)
	
	
	/************************************************************************************
	*	MOST for all cell types
	************************************************************************************/
	DECLARE @rfp_most_list NVARCHAR(MAX) = N''
	
	SELECT		@rfp_most_list += 
			N'UPDATE		a
			SET		'+ attrib_code +N' = b.'+ attrib_code +N'
			FROM		eMstr_Items a
				JOIN	(       
					SELECT		rfp_item_id	AS item_id		    
							, '+ attrib_code +N'     
							, ROW_NUMBER() OVER (PARTITION BY rfp_item_id ORDER BY SUM(annual_volume) DESC) AS row_num 		     
					FROM		optItems      
					WHERE		is_active = 1 AND rfp_item_id IS NOT NULL     
					GROUP BY	rfp_item_id, '+ attrib_code +N'    
					) b ON a.item_id = b.item_id AND b.row_num = 1
			'
	FROM		Meta_Baseline
	WHERE		is_input = 1 AND is_rfp = 1 AND is_rfp_def = 0
		AND	aggregation = 'MOST'
	
	
	IF LEN(@rfp_most_list)> 0	EXEC (@rfp_most_list)	
	
	
	
	
	/************************************************************************************
	*	CSV for all cell types
	************************************************************************************/
	DECLARE @rfp_csv_list NVARCHAR(MAX) = N''
	
	SELECT		@rfp_csv_list += 
			N'UPDATE		a
			SET		'+ attrib_code +N' = b.'+ attrib_code +N'
			FROM		eMstr_Items a
				JOIN	(       
					SELECT		x.rfp_item_id	AS item_id			   		    
							, NULLIF(master.dbo.orderedDelimitedList(distinct ISNULL(x.'+ attrib_code +N'_override,y.'+ attrib_code +N'), '', '', ''ASC''),'''') AS '+ attrib_code +N'
					FROM		optItems x
						JOIN	eBaseline y ON x.item_id = y.opt_item_id 
					WHERE		x.is_active = 1 AND x.rfp_item_id IS NOT NULL 
					GROUP BY	x.rfp_item_id     
					) b ON a.item_id = b.item_id
			' 
	FROM		Meta_Baseline
	WHERE		is_input = 1 AND is_rfp = 1 AND is_rfp_def = 0 
		AND	aggregation = 'CSV'


	IF LEN(@rfp_csv_list)> 0	EXEC (@rfp_csv_list)
	
	
	
	/*====================================================================================  
	=  
	=	RFP Roll up for RAW columns
	=  
	====================================================================================*/ 
	/************************************************************************************
	*	MOST for all cell types
	************************************************************************************/
	/* use rfp_item_id to update optItems in order to keep "most" fields the same between OPT & RFP */
	DECLARE @rfp_raw_most_list NVARCHAR(MAX) = N''
	
	SELECT		@rfp_raw_most_list += 
			N'UPDATE		a
			SET		'+ attrib_code +N'_raw = b.'+ attrib_code +N'_raw
			FROM		eMstr_Items a
				JOIN	(       
					SELECT		rfp_item_id	AS item_id			    
							, '+ attrib_code +N' AS 	'+ attrib_code +N'_raw    
							, ROW_NUMBER() OVER (PARTITION BY rfp_item_id ORDER BY COUNT(*) DESC, SUM(annual_volume) DESC) AS row_num 		     
					FROM		eBaseline      
					WHERE		rfp_item_id IS NOT NULL     
					GROUP BY	rfp_item_id, '+ attrib_code +N'    
					) b ON a.item_id = b.item_id AND b.row_num = 1
			' 
	FROM		Meta_Baseline
	WHERE		is_rfp_override=1 
		AND	aggregation='MOST'
		

	IF LEN(@rfp_raw_most_list)> 0	EXEC (@rfp_raw_most_list)
	
	
	/************************************************************************************
	*	CSV for all cell types
	************************************************************************************/
	/* use rfp_item_id to update optItems in order to keep "csv" fields the same between OPT & RFP */
	DECLARE @rfp_raw_csv_list NVARCHAR(MAX) = N''
	
	SELECT		@rfp_raw_csv_list += 
			N'UPDATE		a
			SET		'+ attrib_code +N'_raw = b.'+ attrib_code +N'_raw
			FROM		eMstr_Items a
				JOIN	(       
					SELECT		rfp_item_id	AS item_id				   		    
							, NULLIF(master.dbo.orderedDelimitedList(distinct '+ attrib_code +N', '', '', ''ASC''),'''') AS '+ attrib_code +N'_raw		     
					FROM		eBaseline     
					WHERE		rfp_item_id IS NOT NULL 
					GROUP BY	rfp_item_id     
					) b ON a.item_id = b.item_id
			' 
	FROM		Meta_Baseline
	WHERE		is_rfp_override=1
		AND	aggregation='CSV'

	IF LEN(@rfp_raw_csv_list)> 0	EXEC (@rfp_raw_csv_list)
	
	
	/*====================================================================================  
	=  
	=	Copy override data from optItems to eMstr_Items for RFP override fields
	=  
	====================================================================================*/ 
	DECLARE @rfp_ov_qry NVARCHAR(MAX) = N'
		MERGE	eMstr_Items t   
		USING	(   
			SELECT		rfp_item_id		AS item_id
					@rfp_ov_col_list
			FROM		optItems   
			WHERE		is_active = 1 AND rfp_item_id IS NOT NULL 
			GROUP BY	rfp_item_id  
			) s ON t.item_id = s.item_id  
		WHEN	MATCHED THEN	   
			UPDATE	SET	@rfp_ov_update_list; 
	'	
	
	DECLARE @rfp_ov_col_list NVARCHAR(MAX) = N'', @rfp_ov_update_list NVARCHAR(MAX) = N''
			
	SELECT		@rfp_ov_col_list += N', MAX('+ attrib_code +N'_override)		AS '+ attrib_code +N'_override'
			, @rfp_ov_update_list += CASE	WHEN LEN(@rfp_ov_update_list) > 0 THEN N', ' ELSE N'' END + N''+ attrib_code +N'_override = s.'+ attrib_code +N'_override' 
	FROM		Meta_Baseline
	WHERE		is_rfp_override=1 
	
	
	SET @rfp_ov_qry = REPLACE(REPLACE(@rfp_ov_qry,'@rfp_ov_col_list',@rfp_ov_col_list),'@rfp_ov_update_list',@rfp_ov_update_list) 

	IF LEN(@rfp_ov_col_list)> 0	EXEC (@rfp_ov_qry)
	
	
END
