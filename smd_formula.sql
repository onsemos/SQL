USE [erfx_bravo_flex_template_v2]
GO
/****** Object:  StoredProcedure [dbo].[smd_formula]    Script Date: 5/17/2016 5:05:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER procedure [dbo].[smd_formula] 
	 
	   @attrib_id			INT = null

AS
BEGIN
		--	DECLARE @attrib_id INT = 304
		-- Get length of formula
		
		DECLARE @formula nvarchar(MAX) = (SELECT REPLACE(formula, ' ', '') FROM Mstr_Attribs WHERE attrib_id = @attrib_id)
		
		--SET @formula = REPLACE(@formula, ' ', '')   
		DECLARE @formula_length INT = LEN(@formula)   
		  
		DECLARE @start INT = 1   
		DECLARE @length INT = 1   
		DECLARE @id INT = 1   
		DECLARE @string_length INT = 1   
		DECLARE @count INT = 1   
		DECLARE @tbl_count INT = 0   
		DECLARE @position INT = 1   
		DECLARE @num_ifs INT = 0   
		DECLARE @start_point INT = 1   
		DECLARE @xml_formula_start NVARCHAR(MAX) = ''   
		DECLARE @xml_formula nvarchar(MAX) = ''   
		DECLARE @ui_formula nvarchar(MAX) = ''   
		DECLARE @ui_formula_default NVARCHAR(MAX) = ''   
		DECLARE @sql_formula nvarchar(MAX) = ''   
		DECLARE @sql_formula_default NVARCHAR(MAX) = ''
		
		/* Create table of visible attributes used in formulas */   
		IF OBJECT_ID('tempdb..#id_attrib_tbl') IS NOT NULL DROP TABLE #id_attrib_tbl   
		CREATE TABLE #id_attrib_tbl (attrib_id INT , unique_id nvarchar(5), is_percent tinyint, decimals int)   
		   
		INSERT		#id_attrib_tbl   
		SELECT		ma.attrib_id, ma.unique_id, CASE WHEN validation_type LIKE '%PERCENT%' THEN 1 ELSE 0 END  
				, CASE WHEN cell_type = 'NUMERIC' THEN ISNULL(decimals,0) ELSE decimals END	AS decimals
		FROM		Mstr_Attribs ma   
		WHERE		ma.unique_id IS NOT NULL   
			
		   
		/*Create table to hold dropdown type unique IDs */   
		IF OBJECT_ID('tempdb..#dd_attrib_tbl') IS NOT NULL DROP TABLE #dd_attrib_tbl   
		CREATE TABLE #dd_attrib_tbl (attrib_id INT, list_option_id INT , list_option_value nvarchar(100))   
		   
		INSERT 		#dd_attrib_tbl   
		SELECT		ma.attrib_id, mlo.list_option_id, mlo.list_option_value   
		FROM		Mstr_Attribs ma   
			JOIN	Mstr_List_Options mlo ON ma.list_id = mlo.list_id   
		WHERE		ma.cell_type = 'DROPDOWN'   
		   
		/* Table will hold each unique id and operator used in formula */   
		IF OBJECT_ID('tempdb..#parsed_formula') IS NOT NULL DROP TABLE #parsed_formula   
		CREATE TABLE #parsed_formula (id INT, letter nvarchar(30))   
	   
		   
		/* loop through to parse formula into pieces */   
		WHILE(@count <= @formula_length) BEGIN   
			SET @string_length = 1   
			SET @start = @count   
			WHILE (SUBSTRING(@formula, @start, @length) NOT IN ('(',')','+','-','*','/','<','>','=','')) BEGIN   
				SET @start += 1   
				SET @string_length += 1   
			END   
			IF(SUBSTRING(@formula, @start+1, @length) NOT IN ('(',')','<','>','=','')) BEGIN 			  
				INSERT INTO #parsed_formula( id, letter )   
				VALUES  ( @id, SUBSTRING(@formula, @count, @string_length - 1)), (@id + 1, SUBSTRING(@formula, @start, 1))   
				SET @id += 2   
				SET @count += @string_length   
				   
			END   
			ELSE IF(SUBSTRING(@formula, @start, 2) IN ('<>','<=','>=','()')) BEGIN 	  
				INSERT INTO #parsed_formula( id, letter )   
				VALUES  ( @id, SUBSTRING(@formula, @count, @string_length - 1)), (@id + 1, SUBSTRING(@formula, @start, 2))   
				SET @id += 2   
				SET @count += @string_length   
				SET @count += 1   
			END   
			ELSE BEGIN 			  
				INSERT INTO #parsed_formula( id, letter )   
				VALUES  ( @id, SUBSTRING(@formula, @count, @string_length - 1)), (@id + 1, SUBSTRING(@formula, @start, 1)), (@id + 2, SUBSTRING(@formula, @start + 1, 1))   
				SET @id += 3   
				SET @count += @string_length   
				SET @count += 1   
			END   
			
			
		END   
		
		UPDATE		a  
		SET		id = b.new_id  
		FROM		#parsed_formula	a  
			JOIN	(  
				SELECT		id, ROW_NUMBER() OVER (ORDER BY id)  new_id  
				FROM		#parsed_formula  
				WHERE		LEN(letter)> 0  
				) b ON a.id  = b.id  
		 
		DELETE #parsed_formula WHERE LEN(letter) = 0
		
		IF OBJECT_ID('tempdb..#xml_formula') IS NOT NULL DROP TABLE #xml_formula   
		CREATE TABLE #xml_formula (id INT, xml_text nvarchar(100), is_percent tinyint, raw_col_name nvarchar(100))   
		IF OBJECT_ID('tempdb..#ui_formula') IS NOT NULL DROP TABLE #ui_formula   
		CREATE TABLE #ui_formula (id INT, ui_text nvarchar(100), is_percent tinyint)   
		IF OBJECT_ID('tempdb..#sql_formula') IS NOT NULL DROP TABLE #sql_formula
		CREATE TABLE #sql_formula (id INT, sql_text nvarchar(100), is_percent tinyint, decimals int)
		
		/* for XML syntax */   
		INSERT 		#xml_formula(id, xml_text, is_percent, raw_col_name)   
		SELECT		id   
				, CASE	WHEN b.unique_id IS not NULL 
					THEN	CASE WHEN decimals IS NOT NULL THEN 'ROUND(' ELSE '' END 
						+ '{attrib' + CAST(attrib_id AS nvarchar(100)) + '}[ROWNUM]' 
						+ CASE WHEN decimals IS NOT NULL THEN ','+CONVERT(NVARCHAR(10),decimals)+')' ELSE '' END  
						
					WHEN letter = '<>' THEN '<>' --Excel can easily use <>, so the crazy NOT logic below isn't needed, and it didn't even work properly
					WHEN letter = 'IF' THEN 'IF('   
					WHEN letter = 'THEN' OR letter = 'ELSE' THEN ' ,'    
					WHEN letter = '()' THEN '""'   
					ELSE letter END AS xml_text   
				, is_percent  
				, CASE	WHEN b.unique_id IS not NULL	THEN '{attrib' + CAST(attrib_id AS nvarchar(100)) + '}[ROWNUM]' 
					ELSE NULL
					END raw_col_name
		FROM		#parsed_formula a   
		LEFT	JOIN	#id_attrib_tbl b ON a.letter = b.unique_id    
		ORDER BY	id   
		   
	   
		   
		   
		/* check #xml_formula for dropdown types and replace key value with text */   
		SET @count = 1   
		SET @tbl_count = (SELECT COUNT(*) FROM #xml_formula)   
		WHILE(@count <= @tbl_count) BEGIN   
			IF((SELECT xml_text FROM #xml_formula WHERE id = @count AND NOT xml_text like '%[^0-9]%' ) IN (SELECT list_option_id FROM #dd_attrib_tbl)) AND (SELECT xml_text FROM #xml_formula WHERE id = (@count-1)) = '=' 
			BEGIN   
				IF((SELECT xml_text FROM #xml_formula WHERE id = @count -2) LIKE '%' + (SELECT CAST(attrib_id AS NVARCHAR(10)) FROM #dd_attrib_tbl WHERE list_option_id = (SELECT xml_text FROM #xml_formula WHERE id = @count))+'%')   
				BEGIN   
					UPDATE #xml_formula SET xml_text = '"' + (SELECT list_option_value FROM #dd_attrib_tbl WHERE list_option_id = (SELECT xml_text FROM #xml_formula WHERE id = @count)) + '"' WHERE id = @count   
				END   
			END   
			SET @count +=1   
		END   
	   
		/*for UI syntax */   
		INSERT INTO #ui_formula( id, ui_text, is_percent )   
		SELECT		id  
				, CASE	WHEN b.unique_id IS not NULL THEN '[attrib' + CAST(attrib_id AS nvarchar(5)) + ']'   
					WHEN letter = '<>' THEN '!='   
					WHEN letter = '=' THEN '=='   
					WHEN letter = 'OR' THEN '||'   
					WHEN letter = 'AND' THEN '&&'    
					WHEN letter = '()' THEN '[attrib' + CAST(@attrib_id AS NVARCHAR(5)) + '].setValue('''')'   
					ELSE letter END AS ui_text  
				, is_percent   
		FROM		#parsed_formula a   
		LEFT	JOIN	#id_attrib_tbl b ON a.letter = b.unique_id    
		ORDER BY	id
		
		/*for SQL syntax */   
		INSERT INTO #sql_formula( id, sql_text, is_percent, decimals )   
		SELECT		id  
				, CASE	WHEN b.unique_id IS not NULL THEN 'attrib' + CAST(attrib_id AS nvarchar(5))
					WHEN letter = '<>' THEN '<>'   
					WHEN letter = '=' THEN '='   
					WHEN letter = 'OR' THEN 'OR'   
					WHEN letter = 'AND' THEN ' AND '
					WHEN letter = 'IF' THEN 'CASE WHEN'
					WHEN letter = '()' THEN 'NULL'  
					ELSE letter END AS sql_text  
				, is_percent 
				, b.decimals  
		FROM		#parsed_formula a   
		LEFT	JOIN	#id_attrib_tbl b ON a.letter = b.unique_id    
		ORDER BY	id
		
		/* for xml formula, need to move AND/OR to appropriate location for xml formula generation */   
		SET @length = (SELECT COUNT(*) FROM #xml_formula)   
		SET @id = 1   
		SET @start_point = 1   
		DECLARE @op NVARCHAR(50) 
		
		WHILE @length >= 0 BEGIN	   
			SET @op = (SELECT xml_text FROM #xml_formula WHERE id = @id) 
			
			IF @op IN( 'AND','OR')  BEGIN    
				/* move AND/OR to beginning of its group and replace it with comma */   
				  
				
				/* @position is the new location where the AND/OR will sit */
				;WITH cte_xml AS (
				SELECT		id, CASE xml_text WHEN  ')' THEN -1 WHEN '(' THEN 1 else 0 END bal
				FROM		#xml_formula	
				WHERE		id = @id -1
					UNION ALL
				SELECT		a.id, b.bal + CASE a.xml_text WHEN  ')' THEN -1 WHEN '(' THEN 1 else 0 END bal 
				FROM		#xml_formula a
					JOIN	cte_xml b ON a.id = b.id-1
				)
				SELECT		@position = MAX(id) 
				FROM		cte_xml
				WHERE		bal = 1
				
				
				SET @start_point = @id + 1   
				UPDATE #xml_formula SET id = id + 1 WHERE id >= @position    
				INSERT INTO #xml_formula( id, xml_text )   
				VALUES  ( @position, @op )   
				UPDATE #xml_formula SET xml_text = ',' WHERE id = @id + 1   
			   
			END   
			SET @length -= 1   
			SET @id += 1   
		END   
		
		
		
		
		



	   
		/* reset length value to # of fields in table */   
		SET @length = (SELECT COUNT(*) FROM #xml_formula)   
		/* count #of IFs in formula */   
		SET @num_ifs = (SELECT COUNT(*) FROM #xml_formula WHERE xml_text LIKE '%if%')   
		   
				   
		/* concatenate  xml formula start string to determine all fields that should be checked for values before formula results display in field */   
		SET @count = 1   
		DECLARE @counter INT = 1, @in_if_zone TINYINT = 0, @if_count_down INT = 0, @xml_text NVARCHAR(100), @raw_col_name NVARCHAR(100)  
		WHILE @length > 0 BEGIN   
		  
			SELECT	@xml_text = xml_text  
			FROM	#xml_formula   
			WHERE	id = @count  
			  
			SET	@in_if_zone = CASE WHEN @xml_text LIKE 'IF(%' OR @in_if_zone = 1 THEN 1 ELSE 0 END  
			  
			IF @in_if_zone = 1 AND @xml_text = '(' BEGIN  
				SET @if_count_down += 1  
			END  
			ELSE IF @in_if_zone = 1 AND @xml_text = ')' BEGIN  
				SET @if_count_down -= 1  
			END  
			  
			IF @if_count_down = 0 and @xml_text = ')' BEGIN  
				SET @in_if_zone = 0   
			END  
			  
			  
			/* use [CASE WHEN is_percent = 1 AND @if_count_down = 0] if only want to do /100 in THEN&ELSE zones */  
			SET @xml_formula += (  
				SELECT	xml_text + CASE WHEN is_percent = 1  THEN '/100' ELSE '' END    
				FROM	#xml_formula   
				WHERE	id = @count  
			)   
			  
			  
			/* code to check field is not empty before calculatoin */  
			SET @raw_col_name = (SELECT TOP 1 raw_col_name FROM #xml_formula WHERE id = @count)
			 
			IF @raw_col_name IS NOT NULL BEGIN   
				IF(CHARINDEX ( @raw_col_name ,@xml_formula_start) = 0 ) BEGIN   
					IF(@counter > 1) BEGIN   
						SET @xml_formula_start += ','   
					END   
					  
					SET @xml_formula_start += @raw_col_name + '=""'   
					   
					SET @counter += 1   
				END   
			END   
			  
			SET @length -= 1   
			SET @count += 1   
			   
		END   
		   
		/* Need an AND if there are multiple fields to check */   
		IF(@counter > 2) BEGIN   
			SET @xml_formula_start = 'IF(OR(' + @xml_formula_start + '),"",'	   
		END   
		ELSE BEGIN   
			SET @xml_formula_start = 'IF('+ @xml_formula_start + ',"",'   
		END   
			   
		SET @xml_formula = @xml_formula_start + REPLACE(@xml_formula, '(IF', 'IF')   
	   
	   
		/* need to add parentheses to close out IFs */   
		SET @num_ifs = (SELECT COUNT(*) FROM #xml_formula WHERE xml_text LIKE '%if%')   
		IF (@num_ifs > 1) BEGIN   
			SET @xml_formula +=  '))'   
		END   
		ELSE IF (@num_ifs = 1) BEGIN   
			SET @xml_formula = @xml_formula + '))'   
		END   
		ELSE BEGIN   
			SET @xml_formula = @xml_formula + ')'   
		END   




	   
		/* keep track of # of IFs, THENs and ELSEs */   
		DECLARE @if_num INT = 0   
		DECLARE @then_num INT = 0   
		DECLARE @else_num INT = 0   
		/* used to determine where the else that begins the last rowAction parameter begins	*/   
		DECLARE @last_if_flag INT = 0   
		   
		DECLARE @begin INT = 0   
		DECLARE @end INT = 0   
		DECLARE @need_to_close INT = 0  
		SET @length = (SELECT MAX(id) FROM #ui_formula)   
		SET @id = 1   
		  
		  
		/* if need to find out attribute integer id  
		DECLARE @xID INT = NULL  
		  
		  
				SET @xID = (  
					SELECT	CONVERT(INT, SUBSTRING(ui_text, CHARINDEX('[attrib',ui_text)+7, CHARINDEX(']',ui_text) - (CHARINDEX('[attrib',ui_text)+7) ))   
					FROM	#ui_formula   
					WHERE	id = @begin AND ui_text LIKE '%attrib%'  
				)  
		*/  
		  
			  
		/* sets the if part of the rowAction with all attributes used in formula to check if attributes are empty */    
		SELECT	@ui_formula += CASE WHEN LEN(@ui_formula)>0 THEN ' && ' ELSE '' END + ui_text + CASE WHEN b.cell_type='DROPDOWN' THEN '.getValue().toString()!=''0''' ELSE '.getValue().toString().length>0' END    
		FROM		#ui_formula a   
		LEFT	JOIN	Mstr_Attribs b ON a.ui_text = '[attrib'+CONVERT(NVARCHAR(10),b.attrib_id)+']'
		WHERE		ui_text LIKE '%attrib%' AND ui_text NOT LIKE '%attrib' + CAST(@attrib_id AS NVARCHAR(5)) + '%'   
		GROUP BY	ui_text, b.cell_type 
		  
		SET @ui_formula += ','  
	   
		/* for formulas with no if..then..else */   
		IF(CHARINDEX('IF', @formula) = 0) BEGIN   
			/* for then (true) part of rowAction, which is the formula */   
			SET @ui_formula += '[attrib' + CAST(@attrib_id AS nvarchar(5)) + '].setValue('   
			  
			   
			SELECT	@ui_formula += CASE	WHEN ui_text LIKE '%attrib%' THEN ui_text + '.getNumber()' + CASE WHEN is_percent = 1 THEN '/100' ELSE '' END  
							WHEN ui_text = '()' THEN ''''''  
							ELSE LOWER(ui_text)  
							END  
			FROM	#ui_formula   
			   
		   
			SET @ui_formula += ')'   
			 			   
		END    


		  
	   
		/* for formulas with if..then..else */   
		ELSE BEGIN   
			WHILE @length >= 0 BEGIN   
					  
				/* IFs */   
				IF((SELECT ui_text FROM #ui_formula WHERE id = @id) = 'IF' ) BEGIN   
					SET @if_num += 1   
					SET @begin = @id   
					SET @end = (SELECT MIN(id)-1 FROM #ui_formula WHERE ui_text = 'THEN' AND id > @id)   
					  
					SELECT	@ui_formula += CASE	WHEN ui_text LIKE '%attrib%' THEN ui_text + '.getNumber()' + CASE WHEN is_percent = 1 THEN '/100' ELSE '' END  
									ELSE   
									LOWER(ui_text)  
									END  
					FROM	#ui_formula   
					WHERE	id BETWEEN @begin AND @end  
				   
				END	   
				   
				/* THENs that are not followed by IF	*/			   
				ELSE IF((SELECT ui_text FROM #ui_formula WHERE id = @id) = 'THEN' AND (SELECT ui_text FROM #ui_formula WHERE id = @id + 2) <> 'IF') BEGIN   
					  
					SET @then_num += 1   
					SET @ui_formula += '{'  
										   
					SET @begin = @id + 1   
					SET @end = (SELECT MIN(id)-1 FROM #ui_formula WHERE ui_text = 'ELSE' AND id > @id)   
					  
							   
					IF((SELECT ui_text FROM #ui_formula WHERE id = @id+1) NOT LIKE N'%setVAlue%') BEGIN   
						SET @ui_formula += '[attrib' + CAST(@attrib_id AS NVARCHAR(5)) + '].setValue('   
						   
						SELECT	@ui_formula += CASE	WHEN ui_text LIKE '%attrib%' THEN ui_text + '.getNumber()' + CASE WHEN is_percent = 1 THEN '/100' ELSE '' END  
										ELSE LOWER(ui_text)  
										END  
						FROM	#ui_formula   
						WHERE	id BETWEEN @begin AND @end  
						  
						  
						SET @ui_formula += ')'   
						  
					END   
					ELSE BEGIN   
					  
						SET @ui_formula += (SELECT ui_text FROM #ui_formula WHERE id = @id+1)   
					END   
										   
				END   

			   
				/* THENs followed by IF */   
				ELSE IF((SELECT ui_text FROM #ui_formula WHERE id = @id) = 'THEN' AND (SELECT ui_text FROM #ui_formula WHERE id = @id + 2) = 'IF') BEGIN   
					SET @ui_formula += '{'   
					SET @then_num += 1   
				END   
				   
				/* ELSEs followed by IF */   
				ELSE IF((SELECT ui_text FROM #ui_formula WHERE id = @id) = 'ELSE' AND (SELECT ui_text FROM #ui_formula WHERE id = @id + 2) = 'IF') BEGIN   
					  
					SET @else_num += 1   
					  
					SET @need_to_close = 1  
					  
					SET @ui_formula += '} else {'  
					   
					IF(@if_num = @else_num AND @last_if_flag = 0) BEGIN   
						SET @last_if_flag = 1   
					END   
					   
				END   
				   
				/* ELSEs not followed by IF but have a value to set column to */			   
				ELSE IF((SELECT ui_text FROM #ui_formula WHERE id = @id) = 'ELSE' AND (SELECT ui_text FROM #ui_formula WHERE id = @id + 2) <> 'IF') BEGIN   
					SET @ui_formula += '} else {'  
					  
					SET @else_num += 1   
					IF(@if_num = @else_num AND @last_if_flag = 0) BEGIN   
						  
						SET @last_if_flag = 1   
					END   
					  
			  
					SET @begin = @id + 1   
					  
					/* find out @end*/  
					IF OBJECT_ID('tempdb..#balance') IS NOT NULL DROP TABLE #balance  
					  
					SELECT		id, CASE WHEN ui_text = '(' THEN 1 ELSE -1 END AS point, ROW_NUMBER() OVER ( ORDER BY id) row_num  
					INTO		#balance  
					FROM		#ui_formula   
					WHERE		id >= @begin AND ui_text IN ('(',')')   
			  
					;WITH balance_cte AS (  
						SELECT		*   
						FROM		#balance a  
						WHERE		row_num = 1  
							UNION ALL  
						SELECT		b.id, b.point+c.point, b.row_num   
						FROM		#balance b   
							JOIN	balance_cte c ON b.row_num = c.row_num+1  
					)		  
					SELECT		@end = MIN(id)   
					FROM		balance_cte  
					WHERE		point = 0  
					/* end of find out @end*/  
				  
					  
					IF((SELECT ui_text FROM #ui_formula WHERE id = @id+1) NOT LIKE N'%setVAlue%') BEGIN   
					  
						IF(@if_num = @else_num AND @last_if_flag = 0) BEGIN   
						  
							IF(@if_num > 1) BEGIN   
								SET @ui_formula += '}'   
							END   
							   
							SET @ui_formula +=',if(' + @ui_formula_default + '){[attrib' + CAST(@attrib_id AS NVARCHAR(5)) + '].setValue('''')}else{[attrib' + CAST(@attrib_id AS NVARCHAR(5)) + '].setValue('   
							SET @last_if_flag = 1   
						END   
						ELSE BEGIN    
							SET @ui_formula +='[attrib' + CAST(@attrib_id AS NVARCHAR(5)) + '].setValue('   
						END   
						  
						  
						SELECT	@ui_formula += CASE	WHEN ui_text LIKE '%attrib%' THEN ui_text + '.getNumber()' + CASE WHEN is_percent = 1 THEN '/100' ELSE '' END  
										ELSE LOWER(ui_text)  
										END  
						FROM	#ui_formula   
						WHERE	id BETWEEN @begin AND @end  
						  
						  
						  
						SET @ui_formula += ')}'   
						  
			  
					END   
					   
					ELSE BEGIN   
						IF(@if_num = @else_num AND @last_if_flag = 0) BEGIN   
							SET @ui_formula +=',{[attrib' + CAST(@attrib_id AS NVARCHAR(5)) + '].setValue('   
							SET @last_if_flag = 1   
						END   
						ELSE BEGIN   
							SET @ui_formula += 'else{' + (SELECT ui_text FROM #ui_formula WHERE id = @id+1)   
							SET @ui_formula += '}'   
						END   
						  
						  
						   
					END   
		  
					IF @need_to_close = 1 BEGIN   
						SET @ui_formula += '}'   
						SET @need_to_close = 0  
					END   
					  
					  
				END   
				   
				/* ELSEs that have no value ( else() ), set column blank */   
				ELSE IF((SELECT ui_text FROM #ui_formula WHERE id = @id) = 'ELSE') BEGIN   
					SET @ui_formula += '} else {'  
					  
					SET @else_num += 1   
					IF(@if_num = @else_num AND @last_if_flag = 0) BEGIN   
						  
						SET @last_if_flag = 1   
					END   
				   
					SET @begin = @id + 1   
					SET @end = (SELECT MIN(id)-1 FROM #ui_formula WHERE ui_text = 'ELSE' AND id > @id)   
					  
		  
		  
					IF((SELECT ui_text FROM #ui_formula WHERE id = @id+1) NOT LIKE N'%setVAlue%') BEGIN   
				  
						SET @ui_formula +='[attrib' + CAST(@attrib_id AS NVARCHAR(5)) + '].setValue('   
						   
						SELECT	@ui_formula += CASE	WHEN ui_text LIKE '%attrib%' THEN ui_text + '.getNumber()' + CASE WHEN is_percent = 1 THEN '/100' ELSE '' END  
										ELSE LOWER(ui_text)  
										END  
						FROM	#ui_formula   
						WHERE	id BETWEEN @begin AND @end  
						  
						  
						SET @ui_formula += ')'   
						  
					END   
					   
					ELSE BEGIN   
						SET @ui_formula += (SELECT ui_text FROM #ui_formula WHERE id = @id+1)   
						  
					END   
					  
					SET @ui_formula += '}'   
					  
					IF @need_to_close = 1 BEGIN   
						SET @ui_formula += '}'   
						SET @need_to_close = 0  
					END   
					   
				END   
				   
				SET @length -= 1   
				SET @id += 1   
				   
				   
				   
			END
		END
		
		
		/* for else (false) part of rowAction, set to blank */   
		SET @ui_formula += ',[attrib' + CAST(@attrib_id AS nvarchar(5)) + '].setValue('''')'   
		   
		SET @ui_formula = REPLACE(@ui_formula, '.getNumber().isDefault()', '.isDefault()')
		
		
		SET @sql_formula += ' CASE WHEN '  
		/* sets the if part of the rowAction with all attributes used in formula to check if attributes are empty */    
		SELECT	@sql_formula += CASE WHEN LEN(@sql_formula)>0 AND @sql_formula <> ' CASE WHEN ' THEN ' AND ' ELSE ' ' END + sql_text + ' IS NOT NULL '    
		FROM		#sql_formula   
		WHERE		sql_text LIKE '%attrib%' AND sql_text NOT LIKE '%attrib' + CAST(@attrib_id AS NVARCHAR(5)) + '%'   
		GROUP BY	sql_text  
		  
		SET @sql_formula += ' THEN '  
		
		/* SQL Code */
		/* keep track of # of IFs, THENs and ELSEs */   
		SET @if_num = 0
		SET @then_num = 0
		SET @else_num = 0
		/* used to determine where the else that begins the last rowAction parameter begins	*/   
		SET @last_if_flag = 0
		
		SET @begin = 0
		SET @end = 0
		SET @need_to_close = 0
		SET @length = (SELECT MAX(id) FROM #sql_formula)
		SET @id = 1
		
		/* for formulas with no if..then..else */   
		IF(CHARINDEX('IF', @formula) = 0) BEGIN   
			/* for then (true) part of rowAction, which is the formula */   
			
			SELECT	@sql_formula += CASE	WHEN sql_text LIKE '%attrib%' THEN ISNULL(N'ROUND('+ sql_text + N', '+CONVERT(NVARCHAR(10),decimals)+ N') ', sql_text) + CASE WHEN is_percent = 1 THEN N'/100' ELSE N'' END  
							WHEN sql_text = '()' THEN N'NULL' 
							ELSE UPPER(sql_text)  
							END  
			FROM	#sql_formula
		END
		
		/* for formulas with if..then..else */   
		ELSE BEGIN   
			WHILE @length >= 0 BEGIN   
				
				/* IFs */   
				IF((SELECT sql_text FROM #sql_formula WHERE id = @id) = 'CASE WHEN' ) BEGIN   
					SET @if_num += 1   
					SET @begin = @id   
					SET @end = (SELECT MIN(id)-1 FROM #sql_formula WHERE sql_text = 'THEN' AND id > @id)   
					
					SELECT	@sql_formula += CASE	WHEN sql_text LIKE '%attrib%' THEN ISNULL(N'ROUND('+ sql_text + N', '+CONVERT(NVARCHAR(10),decimals)+ N') ', sql_text) + CASE WHEN is_percent = 1 THEN N'/100' ELSE N'' END  
									ELSE   
									UPPER(sql_text)  
									END  
					FROM	#sql_formula   
					WHERE	id BETWEEN @begin AND @end
				END	   
				
				/* THENs that are not followed by IF	*/			   
				ELSE IF((SELECT sql_text FROM #sql_formula WHERE id = @id) = 'THEN' AND (SELECT sql_text FROM #sql_formula WHERE id = @id + 2) <> 'CASE WHEN') BEGIN   
					  
					SET @then_num += 1   
					SET @sql_formula += ' THEN '  
										   
					SET @begin = @id + 1   
					SET @end = (SELECT MIN(id)-1 FROM #sql_formula WHERE sql_text = 'ELSE' AND id > @id)   
					
					
					IF((SELECT sql_text FROM #sql_formula WHERE id = @id+1) NOT LIKE N'%NULL%') BEGIN   
						
						SELECT	@sql_formula += CASE	WHEN sql_text LIKE '%attrib%' THEN ISNULL(N'ROUND('+ sql_text + N', '+CONVERT(NVARCHAR(10),decimals)+ N') ', sql_text) + CASE WHEN is_percent = 1 THEN N'/100' ELSE N'' END    
										ELSE ' ' + LOWER(sql_text) + ' '
										END  
						FROM	#sql_formula   
						WHERE	id BETWEEN @begin AND @end  
						
						--SET @sql_formula += ')'   
						  
					END   
					ELSE BEGIN   
					  
						SET @sql_formula += (SELECT sql_text FROM #sql_formula WHERE id = @id+1)   
					END   
										   
				END   

			   
				/* THENs followed by IF */   
				ELSE IF((SELECT sql_text FROM #sql_formula WHERE id = @id) = 'THEN' AND (SELECT sql_text FROM #sql_formula WHERE id = @id + 2) = 'CASE WHEN') BEGIN   
					SET @sql_formula += ' THEN '   
					SET @then_num += 1   
				END   
				   
				/* ELSEs followed by IF */   
				ELSE IF((SELECT sql_text FROM #sql_formula WHERE id = @id) = 'ELSE' AND (SELECT sql_text FROM #sql_formula WHERE id = @id + 2) = 'CASE WHEN') BEGIN   
					  
					SET @else_num += 1   
					  
					SET @need_to_close = 1  
					  
					SET @sql_formula += ' ELSE '  
					   
					IF(@if_num = @else_num AND @last_if_flag = 0) BEGIN   
						SET @last_if_flag = 1   
					END   
					   
				END   
				   
				/* ELSEs not followed by IF but have a value to set column to */			   
				ELSE IF((SELECT sql_text FROM #sql_formula WHERE id = @id) = 'ELSE' AND (SELECT sql_text FROM #sql_formula WHERE id = @id + 2) <> 'CASE WHEN') BEGIN   
					SET @sql_formula += ' ELSE '  
					  
					SET @else_num += 1   
					IF(@if_num = @else_num AND @last_if_flag = 0) BEGIN   
						  
						SET @last_if_flag = 1   
					END   
					  
			  
					SET @begin = @id + 1   
					  
					/* find out @end*/  
					IF OBJECT_ID('tempdb..#balance_sql') IS NOT NULL DROP TABLE #balance_sql  
					  
					SELECT		id, CASE WHEN sql_text = '(' THEN 1 ELSE -1 END AS point, ROW_NUMBER() OVER ( ORDER BY id) row_num  
					INTO		#balance_sql  
					FROM		#sql_formula   
					WHERE		id >= @begin AND sql_text IN ('(',')')   
					
					;WITH balance_cte AS (  
						SELECT		*   
						FROM		#balance_sql a  
						WHERE		row_num = 1  
							UNION ALL  
						SELECT		b.id, b.point+c.point, b.row_num   
						FROM		#balance_sql b   
							JOIN	balance_cte c ON b.row_num = c.row_num+1  
					)		  
					SELECT		@end = MIN(id)   
					FROM		balance_cte  
					WHERE		point = 0  
					/* end of find out @end*/  
				  
					  
					IF((SELECT sql_text FROM #sql_formula WHERE id = @id+1) NOT LIKE N'% = %') BEGIN   
					  
						IF(@if_num = @else_num AND @last_if_flag = 0) BEGIN   
						  
							IF(@if_num > 1) BEGIN   
								SET @sql_formula += ' END '   
							END   
							   
							SET @sql_formula +=N' CASE WHEN ' + @sql_formula_default + N' attrib' + CAST(@attrib_id AS NVARCHAR(5)) + N' IS NULL THEN NULL  ELSE  '--attrib' + CAST(@attrib_id AS NVARCHAR(5)) + ' = '   
							SET @last_if_flag = 1   
						END   
						ELSE BEGIN    
							SET @sql_formula += ''--attrib' + CAST(@attrib_id AS NVARCHAR(5)) + ' = '
						END   
						  
						  
						SELECT	@sql_formula += CASE	WHEN sql_text LIKE '%attrib%' THEN ISNULL(N'ROUND('+ sql_text + N', '+CONVERT(NVARCHAR(10),decimals)+ N') ', sql_text) + CASE WHEN is_percent = 1 THEN N'/100' ELSE N'' END  
										ELSE LOWER(sql_text)  
										END  
						FROM	#sql_formula   
						WHERE	id BETWEEN @begin AND @end  
						  
						  
						  
						SET @sql_formula += ' END '   
						  
			  
					END   
					   
					ELSE BEGIN   
						IF(@if_num = @else_num AND @last_if_flag = 0) BEGIN   
							--SET @sql_formula +=',BEGIN attrib' + CAST(@attrib_id AS NVARCHAR(5)) + ' = '   
							SET @last_if_flag = 1   
						END   
						ELSE BEGIN   
							SET @sql_formula += 'ELSE ' + (SELECT sql_text FROM #sql_formula WHERE id = @id+1)   
							SET @sql_formula += ' END '   
						END   
						  
						  
						   
					END   
		  
					IF @need_to_close = 1 BEGIN   
						SET @sql_formula += ' END '--}'   
						SET @need_to_close = 0  
					END   
					  
					  
				END   
				   
				/* ELSEs that have no value ( else() ), set column blank */   
				ELSE IF((SELECT sql_text FROM #sql_formula WHERE id = @id) = 'ELSE') BEGIN   
					SET @sql_formula += ' ELSE '  
					  
					SET @else_num += 1   
					IF(@if_num = @else_num AND @last_if_flag = 0) BEGIN   
						  
						SET @last_if_flag = 1   
					END   
				   
					SET @begin = @id + 1   
					SET @end = (SELECT MIN(id)-1 FROM #sql_formula WHERE sql_text = 'ELSE' AND id > @id)   
					  
		  
		  
					IF((SELECT sql_text FROM #sql_formula WHERE id = @id+1) NOT LIKE N'% = %') BEGIN   
						SET @sql_formula += ' NULL '
						  
					END   
					   
					ELSE BEGIN   
						SET @sql_formula += (SELECT sql_text FROM #sql_formula WHERE id = @id+1)   
						  
					END   
					  
					SET @sql_formula += ' END '   
					
				END   
				
				SET @length -= 1   
				SET @id += 1   
				
			END
		END
		
		/* to close off outer check on null data */
		SET @sql_formula += N' ELSE NULL END '
		
		--SELECT @xml_formula
		--UNION ALL
		--SELECT @ui_formula
		--UNION ALL
		--SELECT @sql_formula
		
		UPDATE		t 
		SET		xml_formula = @xml_formula
				, ui_formula = @ui_formula 
				, sql_formula = N'ROUND('+ @sql_formula +N', '+CONVERT(NVARCHAR(10),decimals)+ N')'
		FROM		Mstr_Attribs t
		WHERE		attrib_id = @attrib_id
END