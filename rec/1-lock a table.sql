

BEGIN TRAN
	--SELECT	* 
	--FROM		person.Person a WITH (TABLOCKX)
	--	JOIN	PERSON.BusinessEntity b ON a.BusinessEntityID = b.BusinessEntityID

	--UPDATE	person.Person WITH (TABLOCKX)
	--SET		FirstName = 'Ken'
	--WHERE		BusinessEntityID = 1

	SELECT	* 
	FROM		Person.Person a WITH (TABLOCKX)
	CROSS	JOIN	Person.BusinessEntity b WITH (TABLOCKX)

	--	WAITFOR DELAY '00:02:00' 
ROLLBACK
-- commit
--WAITFOR DELAY '00:10:02'




