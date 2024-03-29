USE master
/****** Object:  UserDefinedFunction [dbo].[eTblParseDelimited]    Script Date: 03/22/2012 10:51:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*j*************************************************************************************************************************************************************************2*/
CREATE FUNCTION [dbo].[parseDelimited]
(
	@src_list	nvarchar(max)
	,@split		nvarchar(4000)
)
RETURNS @tbl TABLE 
(
	value		nvarchar(4000)
)

AS

BEGIN 
	--	DECLARE @src_list nvarchar(max) = '1,2,3,4,5', @split nvarchar(4000) = ','
	DECLARE	@xml xml

	SELECT @xml = CONVERT(xml,'<root><s>' + REPLACE(@src_list,@split,'</s><s>') + '</s></root>')

	INSERT INTO @tbl (value)
	SELECT T.c.value('.','nvarchar(4000)') 
	FROM @xml.nodes('/root/s') T(c)

RETURN 
END
