USE [erfx_adm_flex_004]
GO
/****** Object:  StoredProcedure [dbo].[smd_itemPricing]    Script Date: 12/1/2016 9:03:17 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [dbo].[smd_itemPricing] 
	-- Add the parameters for the stored procedure here
	@action			NVARCHAR(100)			
	, @language_id		INT = NULL
	, @supplier_id		INT = NULL  
	, @user_id		INT = NULL			
	, @item_id		INT = NULL
	, @bid_type_id		INT = NULL				
	, @filter_query		nvarchar(max) = NULL		
	, @qry_flex		nvarchar(MAX) = NULL		
	, @param_flex		nvarchar(MAX) = NULL		
	
	
	
	
AS
BEGIN
	/*	
	SELECT		* FROM		eMstr_RFP_Settings
	SELECT		* FROM		Mstr_Attribs
	*/
	IF @action IN ('S-Upload','S') BEGIN
		--	DECLARE @supplier_id INT = 2, @language_id INT = 1, @user_id INT = NULL, @filter_query nvarchar(max) = NULL, @action nvarchar(100)= 'S'	
		
		EXEC	prc_supplierItemScope @supplier_id, @user_id
		-- find items in scope
		
		
		
		--	DECLARE @filter_query nvarchar(max)= 'SELECT item_id FROM eMstr_Items WHERE is_active = 1', @supplier_id INT = 2, @action nvarchar(100)= 'S-Upload'
		-- Filter items based on entry in filter table
		IF OBJECT_ID('tempdb..#filter_pricing') IS NOT NULL DROP TABLE #filter_pricing
		
		DECLARE @filter_join NVARCHAR(200) = N''
		IF LEN(@filter_query) > 0 BEGIN
			CREATE TABLE #filter_pricing(item_id INT PRIMARY KEY)
			INSERT INTO #filter_pricing
			EXEC (@filter_query)
			
			SET @filter_join = N'JOIN	#filter_pricing ft	ON mi.item_id = ft.item_id'
		END

		
		
			
		/****    Pivot Flex Fields    ****/
		IF OBJECT_ID('tempdb..#tblPricingFlex') IS NOT NULL DROP TABLE #tblPricingFlex
		CREATE TABLE #tblPricingFlex
		(
			item_id			INT
			, bid_type_id		INT
			, item_pricing_id	INT 
			, COL_NAME	nvarchar(18)
			, value		nvarchar(max)
			, PRIMARY KEY (item_id, bid_type_id, item_pricing_id, col_name)
		)
		
		--DECLARE @supplier_id INT = -17
		INSERT INTO	#tblPricingFlex
		--	DECLARE @supplier_id INT = 2, @action nvarchar(10)='S'
		SELECT		ip.item_id
				, ip.bid_type_id
				, ip.item_pricing_id
				,'attrib'+ CONVERT(nvarchar(10), ma.attrib_id)	AS col_name
				, ipa.value							AS VALUE 
		FROM 		eItem_Pricing ip
			JOIN	eItem_Pricing_Attribs ipa	ON ip.item_pricing_id = ipa.item_pricing_id
			JOIN	Mstr_Attribs ma			ON ipa.attrib_id = ma.attrib_id 
								AND ma.is_bid_attrib = 1	
		WHERE		ip.supplier_id = @supplier_id
			AND	(@action = 'S' OR ma.cell_type <> 'DROPDOWN')
		
		
		INSERT INTO	#tblPricingFlex
		--	DECLARE @supplier_id INT = 2, @action nvarchar(10)='S'
		SELECT		ip.item_id
				, ip.bid_type_id
				, ip.item_pricing_id
				,'attrib'+ CONVERT(nvarchar(10), ma.attrib_id)	AS col_name
				, mlo.list_option_value					AS VALUE 
		FROM 		eItem_Pricing ip
			JOIN	eItem_Pricing_Attribs ipa	ON ip.item_pricing_id = ipa.item_pricing_id
			JOIN	Mstr_Attribs ma			ON ipa.attrib_id = ma.attrib_id 
								AND ma.is_bid_attrib = 1
		LEFT    JOIN	Mstr_List_Options mlo		ON ma.list_id = mlo.list_id AND ipa.value = CONVERT(nvarchar(5), mlo.list_option_id)	
		WHERE		ip.supplier_id = @supplier_id
			AND	(@action = 'S-Upload' AND ma.cell_type = 'DROPDOWN')
		
		
		
		
		
		
			
			
		INSERT INTO	#tblPricingFlex
		SELECT		-1						AS item_id
				, -1						AS bid_type_id
				, -1						AS item_pricing_id
				, 'attrib'+ CONVERT(nvarchar(10), ma.attrib_id)	AS col_name 
				, NULL						AS VALUE
		FROM		Mstr_Attribs ma
		WHERE		ma.is_bid_attrib = 1
					
		


		
		-- 2) create your crosstab table with only those fields that will be the fields that you would group-on
		IF OBJECT_ID('tempdb..#ctPricingFlex') IS NOT NULL DROP TABLE #ctPricingFlex
		CREATE TABLE #ctPricingFlex (
			 ct_item_id		INT
			 , ct_bid_type_id	INT
			 , item_pricing_id	INT 
			 , PRIMARY KEY (ct_item_id, ct_bid_type_id, item_pricing_id)
		)
		-- generate the Pivot table 
		EXEC erfx_master.dbo.util_crossTab '#tblPricingFlex', 'item_id, bid_type_id, item_pricing_id', 'col_name', 'value', '#ctPricingFlex', 'item_id, bid_type_id, item_pricing_id'
		
		
		
		
		/****    get Order By columns    ****/
		DECLARE @order_by_rank NVARCHAR(2000) = N''
		SELECT		@order_by_rank += CASE WHEN LEN(@order_by_rank)>0 THEN N', ' ELSE N'' END + N'mi.'+ attrib_code
		FROM		Mstr_Attribs
		WHERE		order_by_rank IS NOT NULL
		ORDER BY	order_by_rank
		
		SET @order_by_rank = ISNULL(NULLIF(@order_by_rank,''),N'mi.item_id')

		
		/***************************************************** BID FEEDBACK *************************************************/
		
		--Get parameters from RFP Settings
		DECLARE @is_bid_feedback_enabled float = (SELECT ISNULL(value,0) FROM eMstr_RFP_Settings WHERE setting_id = 2002)
		DECLARE @is_outliers_enabled tinyint = (SELECT ISNULL(value,0) FROM eMstr_RFP_Settings WHERE setting_id = 2000)
		DECLARE @outlier_technique int = (SELECT ISNULL(value,0) FROM eMstr_RFP_Settings WHERE setting_id = 2004)
		DECLARE @feedback_tecnhique int = (SELECT ISNULL(value,0) FROM eMstr_RFP_Settings WHERE setting_id = 2008)
		
		DECLARE @min_num_bid int = (SELECT ISNULL(value,5) FROM eMstr_RFP_Settings WHERE setting_id = 2003)
		DECLARE @std_factor float = (SELECT ISNULL(value,2) FROM eMstr_RFP_Settings emrs WHERE setting_id = 2001)
		DECLARE	@baseline_feedback_attrib_id int = (SELECT ISNULL(value,0) FROM eMstr_RFP_Settings WHERE setting_id = 2005)
		DECLARE	@rfp_feedback_attrib_id int = (SELECT ISNULL(value,0) FROM eMstr_RFP_Settings WHERE setting_id = 2006)
		DECLARE @outlier_percentage_difference int = (SELECT ISNULL(value,0) FROM eMstr_RFP_Settings WHERE setting_id = 2007)
	

		SET @is_bid_feedback_enabled = CASE WHEN @action = 'S-Upload' THEN 0 ELSE @is_bid_feedback_enabled END
		
		IF OBJECT_ID('tempdb..#allBidAttributes') IS NOT NULL DROP TABLE #allBidAttributes
		CREATE TABLE	#allBidAttributes(supplier_id int
						, item_id int
						, item_pricing_id int
						, attrib_id int
						, attrib_name nvarchar(20)
						, attrib_band nvarchar(20)
						, attrib_color nvarchar(20)
						, attrib_min_band nvarchar(20)
						, attrib_value float
						, is_outlier tinyint DEFAULT 0
						, perc_distance_from_best float
						, bid_rank int
						, feedback_color_code nvarchar(50)
						, feedback_band_name nvarchar(50)
						, feedback_band_min float
						, PRIMARY KEY (supplier_id,item_id,item_pricing_id,attrib_id))
		
		/* Insert dummy records to make sure that crosstab creates columns for each attrib otherwise UI will error when no bids */
		INSERT INTO	#allBidAttributes
						( supplier_id
						, item_id
						, item_pricing_id
						, attrib_id
						, attrib_name
						, attrib_band 
						, attrib_color
						, attrib_min_band 
						, attrib_value
						 )
		SELECT		-1						AS item_id
				, -1						AS bid_type_id
				, -1						AS item_pricing_id
				, ma.attrib_id
				, 'attrib'+ CONVERT(nvarchar(5), ma.attrib_id) AS attrib_name
				, 'band'+ CONVERT(nvarchar(5), ma.attrib_id) AS attrib_band
				, 'color'+ CONVERT(nvarchar(5), ma.attrib_id) AS attrib_color
				, 'min'+ CONVERT(nvarchar(5), ma.attrib_id) AS attrib_color
				, NULL						AS VALUE
		FROM		Mstr_Attribs ma
		WHERE		ma.include_feedback = 1
				
		IF(@is_bid_feedback_enabled = 1)BEGIN
			/* Get all attributes that are flagged for Bid Feedback with their values for all suppliers */
			/* Assumptions: feedback is provided only for numeric column */
			
			SELECT 		ip.supplier_id
					, item_id
					, ip.item_pricing_id
					, ma.attrib_id
					, ipa.value
			INTO	#values_table	
			FROM 		eItem_Pricing ip 
				JOIN	SUPPLIERS s ON ip.supplier_id = s.SUPPLIER_ID AND s.SUPPLIER_TYPE_ID = 3
				JOIN	eItem_Pricing_Attribs ipa	ON ip.item_pricing_id = ipa.item_pricing_id
				JOIN	Mstr_Attribs ma			ON ipa.attrib_id = ma.attrib_id
			WHERE		ma.include_feedback = 1
				AND	value IS NOT NULL
				AND	ma.attrib_id = CASE WHEN @outlier_technique = 1 THEN @rfp_feedback_attrib_id ELSE ma.attrib_id END -- if we use comparison to baseline we only show feedback on the chosen RFP attribute
			
			
			INSERT INTO	#allBidAttributes
						( supplier_id
						, item_id
						, item_pricing_id
						, attrib_id
						, attrib_name
						, attrib_band 
						, attrib_color
						, attrib_min_band 
						, attrib_value )
			SELECT 		supplier_id
					, item_id
					, item_pricing_id
					, attrib_id
					, 'attrib'+ CONVERT(nvarchar(5), attrib_id) AS attrib_name
					, 'band'+ CONVERT(nvarchar(5), attrib_id) AS attrib_band
					, 'color'+ CONVERT(nvarchar(5), attrib_id) AS attrib_color
					, 'min'+ CONVERT(nvarchar(5), attrib_id) AS attrib_color
					, CONVERT(float, value) AS attrib_value
			FROM 		#values_table
			WHERE		CONVERT(float, ISNULL(value,0)) >0
			
			
			
			/* Calculate for each item and attribute the avg and standard deviation to remove outliers */
			IF OBJECT_ID('tempdb..#allItemStats') IS NOT NULL DROP TABLE #allItemStats
			CREATE TABLE	#allItemStats(item_id int, attrib_id int, attrib_avg float, attrib_std float, attrib_median float, attrib_mad float, num_bids int, baseline_attrib_value float, best_bid float PRIMARY KEY (item_id,attrib_id))
			INSERT INTO	#allItemStats
						( item_id
						, attrib_id
						, attrib_avg
						, attrib_std 
						, num_bids)
			SELECT 		item_id, attrib_id, AVG(attrib_value), STDEV(attrib_value), COUNT(*)
			FROM 		#allBidAttributes aba
			GROUP BY	item_id, attrib_id
			
			/* If Outlier Detection is enabled */
			IF(@is_outliers_enabled = 1)
			BEGIN
				/* If Outlier Technique is MAD - Median Absolute Deviation */
				IF(@outlier_technique = 0)
				BEGIN
					-- Calculate Median
					;WITH cteMedian
					AS (
						SELECT	item_id as item_id,
							attrib_id AS attrib_id,
							item_pricing_id AS ID,
							attrib_value AS value
						FROM	#allBidAttributes
					)
					SELECT		item_id,
							attrib_id,
							MIN(ID) AS minID,
							MAX(ID) AS maxID,
							AVG(value) AS Median
					INTO		#Median
					FROM		(
								SELECT	item_id,
									attrib_id,
									ID,
									value,
									2 * ROW_NUMBER() OVER (PARTITION BY item_id,attrib_id ORDER BY value) - COUNT(*) OVER (PARTITION BY item_id,attrib_id) AS y
								FROM	cteMedian
							) AS d
					WHERE		y BETWEEN 0 AND 2
					GROUP BY	item_id,attrib_id
					
					-- Calculate Median Absolute Deviation
					;WITH cteDeviation
					AS (
						SELECT	item_id as item_id,
							attrib_id AS attrib_id,
							item_pricing_id AS ID,
							attrib_value AS value
						FROM	#allBidAttributes
					)
					SELECT		item_id,
							attrib_id,
							MIN(minID) AS minID,
							MAX(maxID) AS maxID,
							MIN(Median) AS Median,
							AVG(ABS(value - Median)) AS Deviation
					INTO		#MAD_Stats
					FROM		(
								SELECT		d.item_id,
										d.attrib_id,
										d.ID,
										d.value,
										2 * ROW_NUMBER() OVER (PARTITION BY d.item_id,d.attrib_id ORDER BY ABS(d.value - m.Median)) - COUNT(*) OVER (PARTITION BY d.item_id,d.attrib_id) AS y,
										m.Median,
										m.minID,
										m.maxID
								FROM		cteDeviation AS d
								INNER JOIN	#Median AS m ON m.item_id = d.item_id AND m.attrib_id = d.attrib_id
							) AS d
					WHERE		y BETWEEN 0 AND 2
					GROUP BY	item_id,attrib_id
					
					UPDATE		#allItemStats
					SET		attrib_median = ms.Median
							,attrib_mad = ms.Deviation
					FROM		#allItemStats ais
						JOIN	#MAD_Stats ms ON ms.item_id = ais.item_id AND ms.attrib_id = ais.attrib_id
						
						
					/* Flag Records as outliers in all bids table */
					UPDATE		a
					SET		is_outlier = 1
					FROM		#allBidAttributes a
						JOIN	#allItemStats ais ON ais.item_id = a.item_id AND ais.attrib_id = a.attrib_id
					WHERE		ais.num_bids >= @min_num_bid -- do not use outlier logic if there are not enough bids 
						
						AND	(	a.attrib_value > ais.attrib_median + @std_factor * ais.attrib_mad
							OR	a.attrib_value < ais.attrib_median - @std_factor * ais.attrib_mad
							)
				END
				/* If Outlier Technique is % Difference from Baseline */
				ELSE IF (@outlier_technique = 1)
				BEGIN
					DECLARE		@column_name nvarchar(100)
					SELECT 		@column_name = mb.attrib_code
					FROM 		Meta_Baseline mb
					WHERE		mb.attrib_id = @baseline_feedback_attrib_id
					
					EXEC(
						'UPDATE		#allItemStats
						SET		baseline_attrib_value = emi.'+@column_name+'
						FROM		#allItemStats ais
							JOIN	eMstr_Items emi ON ais.item_id = emi.item_id'
					)
					
					/* Flag Records as outliers if they are the RFP value is too different from the baseline value */
					UPDATE		a
					SET		is_outlier = 1
					FROM		#allBidAttributes a
						JOIN	#allItemStats ais ON ais.item_id = a.item_id AND ais.attrib_id = a.attrib_id
					WHERE		a.attrib_id = @rfp_feedback_attrib_id
						AND	(ABS(a.attrib_value - ais.baseline_attrib_value)/ais.baseline_attrib_value)*100 > @outlier_percentage_difference
				END
				/* If Outlier Technique is AVG & Standard Deviation */
				ELSE IF (@outlier_technique = 2)
				BEGIN
					/* Flag Records as outliers in all bids table */
					UPDATE		a
					SET		is_outlier = 1
					FROM		#allBidAttributes a
						JOIN	#allItemStats ais ON ais.item_id = a.item_id AND ais.attrib_id = a.attrib_id
					WHERE		ais.num_bids > @min_num_bid -- do not use outlier logic if there are not enough bids 
						
						AND	(	a.attrib_value > ais.attrib_avg + @std_factor * ais.attrib_std
							OR	a.attrib_value < ais.attrib_avg - @std_factor * ais.attrib_std
							)
				END
				
			END
			
			/*Check which feedback model was chosen */
			IF (@feedback_tecnhique = 0) -- Bands from Best Bid
			BEGIN
				/* Calculate Best bid for each item and attribute and update the item stats table */
				UPDATE		ais
				SET		best_bid = best_attrib_value
				FROM		#allItemStats ais 
					JOIN(
						SELECT 	item_id, attrib_id , MIN(aba.attrib_value) AS best_attrib_value
						FROM 		#allBidAttributes aba
						WHERE		is_outlier = 0
						GROUP BY	item_id, attrib_id
					) a ON a.item_id = ais.item_id AND a.attrib_id = ais.attrib_id
				
				
				CREATE INDEX idx_all_bid_item_attrib_id ON #allBidAttributes (item_id,attrib_id) INCLUDE (attrib_value)
				--DROP INDEX idx_all_bid_item_attrib_id ON #allBidAttributes
				
				/* Calculate distance from the best bid using the item stats and update it into the bids table */
				UPDATE		#allBidAttributes
				SET		perc_distance_from_best =ROUND ((((aba.attrib_value - ais.best_bid)/ais.best_bid) *100),3)
				FROM		#allBidAttributes aba
				JOIN		#allItemStats ais ON ais.item_id = aba.item_id AND ais.attrib_id = aba.attrib_id

				CREATE INDEX idx_all_bid_percentage ON #allBidAttributes (perc_distance_from_best) 
				--DROP INDEX idx_all_bid_percentage ON #allBidAttributes
				
				
				/* Get the max feedback band, make highest band unlimited */
				DECLARE @max_band float = (SELECT MAX(max_percentage) FROM eMstr_Feedback_Bands emfb)			
				
				/* Get the feedback text and the color and update the table */
				UPDATE		#allBidAttributes
				SET		feedback_color_code = emc.color_code
						,feedback_band_name = emfb.band_name
						,feedback_band_min = emfb.min_percentage
				FROM		#allBidAttributes aba
					JOIN	#allItemStats ais ON ais.item_id = aba.item_id AND ais.attrib_id = aba.attrib_id
					JOIN	eMstr_Feedback_Bands emfb ON emfb.feedback_technique = @feedback_tecnhique AND aba.perc_distance_from_best BETWEEN emfb.min_percentage AND CASE WHEN emfb.max_percentage = @max_band THEN aba.perc_distance_from_best ELSE emfb.max_percentage END 
					JOIN	BCS_MASTER.dbo.eMstr_Colors emc ON emc.color_id = emfb.band_color_id
				WHERE		aba.is_outlier = 0
					AND	( (@outlier_technique = 0 AND ais.num_bids >= @min_num_bid)-- if outliers from bids do not show feedback if there are not enough bids for that item
						OR @outlier_technique = 1
						)
			END
			ELSE IF (@feedback_tecnhique = 1) -- Top N from baseline price
			BEGIN
					UPDATE		aba 		
					SET		bid_rank = a.rank 
					FROM 		#allBidAttributes aba
						JOIN	(
								SELECT 		aba.item_pricing_id , RANK() OVER (PARTITION BY aba.item_id,aba.attrib_id ORDER BY aba.attrib_value) AS rank
								FROM 		#allBidAttributes aba
								WHERE		aba.is_outlier = 0
						)a ON a.item_pricing_id = aba.item_pricing_id
					WHERE		is_outlier = 0
					
					/* Get the feedback text and the color and update the table */
					UPDATE		#allBidAttributes
					SET		feedback_color_code = emc.color_code
							,feedback_band_name = emfb.band_name
							,feedback_band_min = emfb.min_percentage
					FROM		#allBidAttributes aba
						JOIN	#allItemStats ais ON ais.item_id = aba.item_id AND ais.attrib_id = aba.attrib_id
						JOIN	eMstr_Feedback_Bands emfb ON emfb.feedback_technique = @feedback_tecnhique AND aba.bid_rank BETWEEN emfb.min_percentage AND CASE WHEN emfb.max_percentage = @max_band THEN aba.bid_rank ELSE emfb.max_percentage END 
						JOIN	BCS_MASTER.dbo.eMstr_Colors emc ON emc.color_id = emfb.band_color_id
					WHERE		aba.is_outlier = 0
						AND	( (@outlier_technique = 0 AND ais.num_bids >= @min_num_bid)-- if outliers from bids do not show feedback if there are not enough bids for that item
							OR @outlier_technique = 1
							)
			END
			
			
			/* Set the message to show for outliers */
			UPDATE		#allBidAttributes
			SET		feedback_color_code = 4
					,feedback_band_name = 'Potential Outlier'
			WHERE		is_outlier = 1
		END
		
	
		-- Pivot all the data so we can join it to pricing tables
		
		IF OBJECT_ID('tempdb..#allBidBandNamePivoted') IS NOT NULL DROP TABLE #allBidBandNamePivoted
		CREATE TABLE #allBidBandNamePivoted (
			item_pricing_id	INT 
			 , PRIMARY KEY (item_pricing_id)
		)
		EXEC erfx_master.dbo.util_crossTab '#allBidAttributes', 'item_pricing_id', 'attrib_band', 'feedback_band_name', '#allBidBandNamePivoted', 'item_id, item_pricing_id'
		--SELECT * FROM #allBidBandNamePivoted abap
		
		IF OBJECT_ID('tempdb..#allBidColorPivoted') IS NOT NULL DROP TABLE #allBidColorPivoted
		CREATE TABLE #allBidColorPivoted (
			item_pricing_id	INT 
			 , PRIMARY KEY (item_pricing_id)
		)
		EXEC erfx_master.dbo.util_crossTab '#allBidAttributes', 'item_pricing_id', 'attrib_color', 'feedback_color_code', '#allBidColorPivoted', 'item_id, item_pricing_id'
		--SELECT * FROM #allBidColorPivoted abap
		
		IF OBJECT_ID('tempdb..#allBidMinBandPivoted') IS NOT NULL DROP TABLE #allBidMinBandPivoted
		CREATE TABLE #allBidMinBandPivoted (
			item_pricing_id	INT 
			 , PRIMARY KEY (item_pricing_id)
		)
		EXEC erfx_master.dbo.util_crossTab '#allBidAttributes', 'item_pricing_id', 'attrib_min_band', 'feedback_band_min', '#allBidMinBandPivoted', 'item_id, item_pricing_id'
		
		

		/**************************************************** END OF BID FEEDBACK ****************************************/	
		IF OBJECT_ID('tempdb..#eLang_Bid_Types') IS NOT NULL DROP TABLE #eLang_Bid_Types
		CREATE TABLE #eLang_Bid_Types (bid_type_id INT PRIMARY KEY, bid_type_name NVARCHAR(150) )

		INSERT		#eLang_Bid_Types(bid_type_id, bid_type_name)
		--	declare @language_id int = 3
		SELECT		bt.bid_type_id
				, ISNULL(bt2.bid_type_name, bt.bid_type_name) AS bid_type_name
		FROM		eLang_Bid_Types bt		
		LEFT	JOIN	eLang_Bid_Types bt2	ON bt.bid_type_id = bt2.bid_type_id AND bt2.language_id = @language_id 
		WHERE		bt.language_id = 1 
		


		/****************************************************************
			temp table for non-dynamic feedback
		****************************************************************/
		IF OBJECT_ID('tempdb..#eTblPricingFeedback') IS NOT NULL DROP TABLE #eTblPricingFeedback
		CREATE TABLE #eTblPricingFeedback  
		(
			pricing_id 	INT NOT NULL PRIMARY KEY, 
			feedback_col_1 nvarchar(2000),
			feedback_col_2 nvarchar(2000),
			feedback_col_3 nvarchar(2000),
			feedback_col_4 nvarchar(2000),
			feedback_col_5 nvarchar(2000),
			feedback_col_6 nvarchar(2000),
			feedback_col_7 nvarchar(2000),
			feedback_col_8 nvarchar(2000),
			feedback_col_9 nvarchar(2000),
			feedback_col_10 nvarchar(2000),
			composite_pricing_id varchar(300)
		)
		
		INSERT	#eTblPricingFeedback 
		SELECT	pricing_id
				, feedback_col_1
				, feedback_col_2
				, feedback_col_3
				, feedback_col_4
				, feedback_col_5 
				, feedback_col_6 
				, feedback_col_7 
				, feedback_col_8 
				, feedback_col_9 
				, feedback_col_10
				, composite_pricing_id
		FROM		eTblPricingFeedback('eItem_Pricing')

			
		--		DECLARE @supplier_id INT = 2
		DECLARE @item_attribs NVARCHAR(max) = N''
		SELECT		@item_attribs += N', mi.'+ attrib_code +N' AS attrib'+ CONVERT(NVARCHAR(10),attrib_id) 
		FROM		Mstr_Attribs
		WHERE		is_bid_attrib = 0
		

		DECLARE @top_constraint NVARCHAR(max) = CASE WHEN @action = 'S' THEN N'TOP 2501' ELSE N'' END

		-- item_id and attrib2 are the same but item_id is returned for internal use 
		
		DECLARE @s_qry NVARCHAR(MAX) = N'
			SELECT 	'+@top_constraint+N'	bt.bid_type_id
					, bt.bid_type_name	AS bid_type
					, mi.item_id		
					@item_attribs 
					, pf.*
					, etpf.*
					, abbnp.*
					, abcp.*
					, abmp.*
			FROM 		eMstr_Items mi
					@filter_join
				JOIN	eSupplier_Item_Scope  ss	ON mi.item_id = ss.item_id AND ss.supplier_id = @supplier_id
			CROSS	JOIN	#eLang_Bid_Types bt		
			LEFT	JOIN	#ctPricingFlex  pf		ON mi.item_id = pf.ct_item_id AND bt.bid_type_id = pf.ct_bid_type_id
			LEFT	JOIN	#eTblPricingFeedback etpf ON pf.item_pricing_id  = etpf.pricing_id
			LEFT	JOIN	#allBidBandNamePivoted abbnp ON abbnp.item_pricing_id = pf.item_pricing_id
			LEFT	JOIN	#allBidColorPivoted abcp ON abcp.item_pricing_id = pf.item_pricing_id
			LEFT	JOIN	#allBidMinBandPivoted abmp ON abmp.item_pricing_id = pf.item_pricing_id 	
			WHERE		mi.is_active = 1
				AND 	NOT EXISTS (
						SELECT		1
						FROM		eClient_Item_Scope bb
						WHERE		ss.supplier_id = bb.supplier_id
							AND	ss.item_id = bb.item_id
							AND	bb.scope_option_id = 1
					)
			ORDER BY	@order_by_rank, bt.bid_type_id
		'
		
		SET @s_qry = REPLACE(@s_qry,'@filter_join',@filter_join) 
		SET @s_qry = REPLACE(@s_qry,'@item_attribs',@item_attribs) 
		SET @s_qry = REPLACE(@s_qry,'@supplier_id',convert(nvarchar(5),@supplier_id)) 
		SET @s_qry = REPLACE(@s_qry,'@order_by_rank',@order_by_rank)
		
		EXEC (@s_qry)
		
		
	
		
		DROP TABLE #tblPricingFlex
		DROP TABLE #ctPricingFlex

	
	END
	
	/* list of attributes that supplier will see*/
	ELSE IF (@action='S-FLEX') BEGIN
		
		SELECT		a.attrib_id
				, 'attrib'+CONVERT(NVARCHAR(10),a.attrib_id) AS col_name 
				, is_bid_attrib 
				, mb.aggregation
				, a.cell_type
				, a.display_name
				, ISNULL(a.element_width,
					ROUND(CEILING(CASE WHEN LEN(a.display_name)< 15 THEN 15 ELSE LEN(a.display_name) END * 0.9) - (LEN(a.display_name) - LEN(REPLACE(a.display_name, ' ', ''))) ,0)
					) AS element_width
				, a.element_height
				, CASE WHEN a.cell_type = 'DATE' THEN 10 ELSE a.max_length END max_length
				, a.is_required
				, a.display_order
				, a.validation_type
				, a.xml_formula
				, a.ui_formula
				, is_alt_only
				, a.decimals	
				, ISNULL(v.ui_validation,'None') AS ui_validation
				, v.ui_validation_js
				, v.ui_validation_msg
				, CASE	WHEN a.cell_type IN ('TEXT', 'DATE','DROPDOWN') THEN '@'      
					WHEN a.cell_type = 'TIME' THEN 'h:mm'      
					WHEN a.cell_type = 'NUMERIC' AND a.validation_type NOT LIKE '%INTEGER%' THEN '0.'+REPLICATE('0',a.decimals) 
					WHEN a.cell_type = 'FORMULA' AND a.decimals > 0 THEN '0.'+REPLICATE('0',a.decimals)      
					ELSE NULL      
					END data_format 
				, CASE	WHEN a.cell_type = 'NUMERIC' AND a.validation_type LIKE 'INTEGER%' THEN 1      
					ELSE 0      
					END AS is_int  
				, CASE	WHEN a.is_bid_attrib = 0 OR a.cell_type = 'FORMULA' THEN 'nonInputData' ELSE 'inputData' END AS data_style
				, CASE	WHEN a.is_bid_attrib = 0 OR a.cell_type = 'FORMULA' THEN 'nonInputHeader' ELSE 'inputHeader' END AS column_style 
				, CASE	WHEN a.is_bid_attrib = 0 OR a.cell_type = 'FORMULA' THEN 0 ELSE 1 END AS is_input 
				, CASE	WHEN a.cell_type = 'NUMERIC' AND a.validation_type LIKE '%_POS' THEN 'GREATER_THAN'      
					WHEN a.cell_type = 'NUMERIC' THEN 'BETWEEN'      
					ELSE NULL      
					END AS operator  
				, CASE	WHEN a.cell_type ='DROPDOWN' THEN c.list_code       
					ELSE b.limit_low      
					END AS validation1         
				, b.limit_high	AS validation2 
				, a.is_optional
				, a.is_semi_hidden
				, a.header_comments
		FROM 		Mstr_Attribs a	
		LEFT	JOIN	erfx_master.dbo.Meta_Validation_Types b ON a.validation_type = b.validation_type
		LEFT	JOIN	Mstr_Lists c				ON a.list_id = c.list_id
		LEFT	JOIN	Meta_Baseline mb			ON a.attrib_id = mb.attrib_id
		LEFT	JOIN	erfx_master.dbo.Meta_Validation_Types v ON a.validation_type = v.validation_type
		WHERE		a.is_hidden = 0
		ORDER BY	display_order, display_name

	END
	
	/* list of bid attributes that need to be saved. formula attributes don't need to be saved. they are calculated and saved later. */
	ELSE IF (@action='S-FLEX2') BEGIN

		SELECT		ma.attrib_id, ma.*
		FROM 		dbo.Mstr_Attribs ma
		WHERE		is_bid_attrib = 1 AND cell_type <> 'FORMULA'
			AND	ma.is_hidden  = 0
		ORDER BY	ma.display_order
		
	END
	
	
	

	
	ELSE IF @action IN ('M-Upload','M') BEGIN	
		
		DECLARE @id_tbl TABLE (id INT)
		
		/* if an item is hidden (scope_option_id = 1) from the supplier, do not do update */
		DECLARE @is_hidden TINYINT = (
			--	declare @supplier_id int = 2, @item_id int = 3
			SELECT		COUNT(*) 
			FROM		eClient_Item_Scope
			WHERE		supplier_id = @supplier_id
				AND	item_id = @item_id
				AND	scope_option_id = 1
		)
		
		IF @is_hidden = 0 BEGIN
			MERGE	eItem_Pricing t 
			USING	(
				SELECT	@supplier_id	AS supplier_id   
					, @item_id	AS item_id
					, @bid_type_id	AS bid_type_id
					, @user_id	AS modified_by_id
			) s	ON	
					t.item_id = s.item_id
				AND	t.supplier_id = s.supplier_id
				AND	t.bid_type_id = s.bid_type_id
			 
			WHEN	MATCHED THEN 
				UPDATE SET	modified_by_id	= s.modified_by_id
			WHEN	NOT MATCHED THEN
				INSERT (supplier_id, item_id, bid_type_id, modified_by_id)  
				VALUES (supplier_id, item_id, bid_type_id, modified_by_id)  
			OUTPUT inserted.item_pricing_id INTO @id_tbl;
			
			DECLARE	@item_pricing_id INT = (SELECT TOP 1 id FROM @id_tbl)
			SET @param_flex = REPLACE(@param_flex, '#item_pricing_id', CONVERT(nvarchar(MAX),@item_pricing_id))
			SET @param_flex = REPLACE(@param_flex, '#supplier_id', CONVERT(nvarchar(MAX),@supplier_id))
			SET @param_flex = REPLACE(@param_flex, '#modified_by_id', CONVERT(nvarchar(MAX),@user_id))
			EXEC sp_executesql @qry_flex, @param_flex
		END
		
		IF @action = 'M'
			SELECT @item_pricing_id AS id
	END
	
END

