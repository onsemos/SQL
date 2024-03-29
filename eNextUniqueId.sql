USE [erfx_bravo_asc_template_v03]
GO
/****** Object:  UserDefinedFunction [dbo].[eNextUniqueId]    Script Date: 2/7/2017 8:55:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*************************************************************************************
  Author    		: J2
  Date    		: 10/29/2014
  Description   		
  Parameters		: 
 
  Modifications History
 
  Date		Done By		Comments
  --------------------------------------------------------------------------------------
  **************************************************************************************/
ALTER FUNCTION [dbo].[eNextUniqueId]
(
)
RETURNS 	NVARCHAR(10)
AS
BEGIN

	DECLARE	@unique_id NVARCHAR(10), @last_id NVARCHAR(10),  @unique_row_num INT 

	SET	@last_id  = ( 
	 
		SELECT		TOP 1 unique_id 
		FROM		( 
				SELECT	unique_id, LEN(unique_id) AS id_length 
				FROM	Mstr_Attribs  
				WHERE	unique_id IS NOT NULL  
				) a 
		ORDER BY	id_length DESC, unique_id DESC 
	) 
	 
	SET @unique_row_num = 0 
	 
	;WITH tbl AS ( 
		SELECT		@last_id		AS id  
				, LEN(@last_id)		AS char_index 
				, ASCII(SUBSTRING(@last_id, LEN(@last_id),LEN(@last_id)))-64 AS row_num 
			UNION ALL 
		SELECT		id 
				, char_index - 1	AS char_index 
				 
				, (ASCII(SUBSTRING(@last_id, char_index - 1,char_index - 1)) - 64)* POWER(26, (LEN(id)-char_index+1)) AS row_num 
		FROM		tbl a 
		WHERE		char_index > 1 
	) 
	SELECT		@unique_row_num += row_num 
	FROM		tbl 
	 
	SET @unique_row_num = ISNULL(@unique_row_num,0) + 1 
	 
	SET @unique_id = BCS_MASTER.dbo.alphaSequence(@unique_row_num)  

	
	RETURN @unique_id
END




