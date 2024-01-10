USE [BCS_MASTER]
GO

/****** Object:  UserDefinedFunction [dbo].[alphaSequence]    Script Date: 2/6/2017 5:41:39 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[alphaSequence](@row_num INT)
RETURNS NVARCHAR(10) 
AS BEGIN
	DECLARE @col NVARCHAR(10) = ''
	
	;WITH tbl AS (
		SELECT	@row_num		AS row_num
				, (@row_num-1)/26	AS div
				, @row_num%26	AS mod
			UNION ALL
		SELECT	@row_num
				, (div-1)/26
				, div%26
		FROM		tbl a
		WHERE		div > 0
	)
	SELECT		@col+=CHAR( CASE WHEN mod = 0 THEN 26 ELSE mod END+64)
	--SELECT		row_num, div, mod, CHAR( CASE WHEN mod = 0 THEN 26 ELSE mod END+64)
	FROM		tbl
	ORDER BY	div


	RETURN @col

END 



GO


