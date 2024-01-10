IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[Employee]') AND type IN (N'U')) 
BEGIN 
   DROP TABLE [Employee] 
END 
GO 
IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[Department]') AND type IN (N'U')) 
BEGIN 
   DROP TABLE [Department] 
END 
CREATE TABLE [Department]( 
   [DepartmentID] [int] NOT NULL PRIMARY KEY, 
   [Name] VARCHAR(250) NOT NULL, 
) ON [PRIMARY] 
INSERT [Department] ([DepartmentID], [Name])  
VALUES (1, N'Engineering') 
INSERT [Department] ([DepartmentID], [Name])  
VALUES (2, N'Administration') 
INSERT [Department] ([DepartmentID], [Name])  
VALUES (3, N'Sales') 
INSERT [Department] ([DepartmentID], [Name])  
VALUES (4, N'Marketing') 
INSERT [Department] ([DepartmentID], [Name])  
VALUES (5, N'Finance') 
GO 
CREATE TABLE [Employee]( 
   [EmployeeID] [int] NOT NULL PRIMARY KEY, 
   [FirstName] VARCHAR(250) NOT NULL, 
   [LastName] VARCHAR(250) NOT NULL, 
   [DepartmentID] [int] NOT NULL REFERENCES [Department](DepartmentID), 
) ON [PRIMARY] 
GO 
INSERT [Employee] ([EmployeeID], [FirstName], [LastName], [DepartmentID]) 
VALUES (1, N'Orlando', N'Gee', 1 ) 
INSERT [Employee] ([EmployeeID], [FirstName], [LastName], [DepartmentID]) 
VALUES (2, N'Keith', N'Harris', 2 ) 
INSERT [Employee] ([EmployeeID], [FirstName], [LastName], [DepartmentID]) 
VALUES (3, N'Donna', N'Carreras', 3 ) 
INSERT [Employee] ([EmployeeID], [FirstName], [LastName], [DepartmentID]) 
VALUES (4, N'Janet', N'Gates', 3 )


select	*
from		Department a
cross	apply	(
		select	*
		from		Employee x
		where		x.DepartmentID = a.DepartmentID
		) b
GO
select	*
from		Department a
	join	Employee b on a.DepartmentID= b.DepartmentID
GO

select	*
from		Department a
outer	apply	(
		select	*
		from		Employee x
		where		x.DepartmentID = a.DepartmentID
		) b
GO
select	*
from		Department a
left	join	Employee b on a.DepartmentID= b.DepartmentID
GO

if OBJECT_ID('ufn_GetAllEmployeeOfADepartment',N'TF') is not null
	drop function ufn_GetAllEmployeeOfADepartment
GO



create function ufn_GetAllEmployeeOfADepartment(@deptID int)
returns @results table
(
	[EmployeeID] [int] NOT NULL PRIMARY KEY, 
	[FirstName] VARCHAR(250) NOT NULL, 
	[LastName] VARCHAR(250) NOT NULL, 
	[DepartmentID] [int] NOT NULL 
)
as
begin
	insert	@results
	select	[EmployeeID],[FirstName],[LastName],[DepartmentID]
	from		Employee
	where		DepartmentID = @deptID
	return;
end

with emp as(
	select	EmployeeID, DepartmentID, LastName
	from		Employee
)
select	*
from		Department a
	join	emp b on a.DepartmentID = b.DepartmentID


select	*
from		Department a
cross	apply	ufn_GetAllEmployeeOfADepartment(a.DepartmentID)

select	*
from		Department a
	join	Employee b on a.DepartmentID= b.DepartmentID


;with emp as(
	select	EmployeeID, DepartmentID, LastName
	from		Employee
)
select	*
from		Department a
	join	emp b on a.DepartmentID = b.DepartmentID




select	*
from		Department a
outer	apply	ufn_GetAllEmployeeOfADepartment(a.DepartmentID)
go
select	*
from		Department a
left	join	Employee b on a.DepartmentID= b.DepartmentID