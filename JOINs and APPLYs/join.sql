
drop table #Emp
drop table #Dept
drop table #EmpDeptHist

create table #Emp (EmpId int primary key, DeptId int, FirstName nvarchar(500))
create table #Dept (DeptId int primary key, DeptName nvarchar(500))
create table #EmpDeptHist (EmpId int, DeptId int, StartDate datetime, EndDate datetime)


insert #Emp
values (1,1,'John'), (2,2,'Smith'), (3, 3, 'Brian'),(4,4,'Anthony')
insert #Dept
values (1,'HR'),(2,'FI'),(5,'IT')
insert #EmpDeptHist
values (1,1,getdate(),GETDATE()), (10,1,getdate(),GETDATE()), (1,20,getdate(),GETDATE())

select	*
from		#Emp a
	join	#Dept b on a.DeptId = b.DeptId

select	*
from		#Emp a
full 	join	#Dept b on a.DeptId = b.DeptId


select	*
from		#Emp a
cross	join	#Dept b 

select	*
from		#Emp a
left	join	#Dept b on a.DeptId = b.DeptId
left	join	#EmpDeptHist c on b.DeptId = c.DeptId



drop table TestTable

create table TestTable (a int not null, b int not null, c int, d int)


alter table TestTable add constraint PK_TestTable primary key clustered (a)


create index IX_TestTable_a on TestTable(a) 

create nonclustered index IX_TestTable_b on TestTable(b desc,c asc) include (d)
