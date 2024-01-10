
SET STATISTICS IO, TIME OFF

BEGIN TRY
	SELECT 1/0
	SELECT 2
	--INSERT	Person.BusinessEntity
	--(
	--    BusinessEntityID
	--)
	--VALUES
	--(   111
	--    )
END TRY


BEGIN CATCH
	DECLARE	@ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT 
	SELECT	@ErrorMessage = ERROR_MESSAGE()
			, @ErrorSeverity = ERROR_SEVERITY()
			, @ErrorState = ERROR_STATE()

	print N'message:'+@ErrorMessage+CHAR(13)+'severity:'+CONVERT(NVARCHAR(10),@ErrorSeverity)+CHAR(13)+'state:'+CONVERT(NVARCHAR(10),@ErrorState)
	RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	/*
	• SEVERITY: Severity levels from 0 through 18 can be specified by any user. Severity levels from 19 through 25 can only be specified 
	by members of the sysadmin fixed server role or users with ALTER TRACE permissions. A RAISERROR severity of 11 to 19 executed in the 
	TRY block of a TRY…CATCH construct causes control to transfer to the associated CATCH block. Specify a severity of 10 or lower to 
	return messages using RAISERROR without invoking a CATCH block. PRINT does not transfer control to a CATCH block. For back-end 
	applications, it doesn’t matter severity is 0 or 11. Level 16 is typically used for user-defined errors.
	
	• STATE: Is an integer from 0 through 255. Negative values default to 1. Values larger than 255 should not be used. If the same 
	user-defined error is raised at multiple locations, using a unique state number for each location can help find which section of code 
	is raising the errors. Usually use 1 as default.
	*/
END CATCH


BEGIN TRY BEGIN TRAN
	SELECT 1/0
	SELECT 2
COMMIT TRAN END TRY


BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK

	DECLARE @ErrMessage NVARCHAR(4000) = ERROR_MESSAGE()
	print N'message:'+@ErrMessage+CHAR(13)+'severity:'+CONVERT(NVARCHAR(10),ERROR_SEVERITY())+CHAR(13)+'state:'+CONVERT(NVARCHAR(10),ERROR_STATE())
	RAISERROR(@ErrMessage, 16, 1)

END CATCH




