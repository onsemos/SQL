USE [erfx_bravo_flex_template_v2]
GO
/****** Object:  StoredProcedure [dbo].[prc_applySQLForumla]    Script Date: 5/17/2016 5:02:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [dbo].[prc_applySQLForumla]

AS

BEGIN
	
	UPDATE	t
	SET		sql_formula_final = t.sql_formula
	FROM		Mstr_Attribs t
	WHERE		visible_to_client = 1
	
	IF OBJECT_ID('tempdb..#Mstr_Attribs') IS NOT NULL DROP TABLE #Mstr_Attribs
	CREATE TABLE #Mstr_Attribs (attrib_id NVARCHAR(10) , sql_formula NVARCHAR(max))
	
	INSERT	#Mstr_Attribs (attrib_id, sql_formula )
	SELECT	attrib_id, sql_formula 
	FROM		Mstr_Attribs a
	WHERE		cell_type='FORMULA' AND sql_formula IS NOT NULL
		AND	a.visible_to_client = 1
	
	/* -- Recursive, go through all formulas that reference other formulas */
	;WITH tbl AS (
		SELECT	a.attrib_id		
				, REPLACE(a.sql_formula,'attrib'+b.attrib_id,'('+b.sql_formula+')') AS sql_formula
				, 1 AS row_num
				, ROW_NUMBER() OVER (PARTITION BY a.attrib_id ORDER BY b.attrib_id ) rr
		FROM		#Mstr_Attribs a
			JOIN	#Mstr_Attribs b ON a.sql_formula LIKE '%attrib'+b.attrib_id+'%'
			UNION ALL
		SELECT	a.attrib_id
				, REPLACE(a.sql_formula,'attrib'+b.attrib_id,'('+b.sql_formula+')') AS sql_formula 
				, a.row_num + 1 AS row_num
				, ROW_NUMBER() OVER (PARTITION BY a.attrib_id ORDER BY b.attrib_id ) rr
		FROM		tbl a
			JOIN	#Mstr_Attribs b ON a.sql_formula LIKE '%attrib'+b.attrib_id+'%'	
		WHERE		a.rr = 1  
	)
	/* -- Select for testing purposes. */
	--SELECT		* 
	--FROM		(
	--		SELECT		CONVERT(INT, attrib_id) AS attrib_id
	--				, sql_formula
	--				, rr
	--				, row_num
	--				, ROW_NUMBER() OVER (PARTITION BY a.attrib_id ORDER BY a.row_num DESC ) final_row_num
	--		FROM		tbl a
	--		) s
	--WHERE		s.final_row_num = 1
	
	/* -- Update final sql formula. comment select code above and uncomment code below */
	UPDATE	t
	SET		sql_formula_final = s.sql_formula
	FROM		Mstr_Attribs t
		JOIN	(
			SELECT	CONVERT(INT, attrib_id) AS attrib_id
					, sql_formula
					, rr
					, row_num
					, ROW_NUMBER() OVER (PARTITION BY a.attrib_id ORDER BY a.row_num DESC ) final_row_num
			FROM		tbl a
			) s ON s.final_row_num = 1 AND t.attrib_id = s.attrib_id
	
	
	--EXEC prc_refreshFormulaAttribs @supplier_id = NULL
	
END