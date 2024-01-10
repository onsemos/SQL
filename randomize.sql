/* http://blogs.lessthandot.com/index.php/DataMgmt/DataDesign/sql-server-set-based-random-numbers/ */

SELECT ABS(CHECKSUM(NewId())) % 10


/*
Notice that the ‘Random Number’ column is the same for each row, but the GUID column is different. We can use this 
interesting fact to generate random numbers by combining this with another function available in SQL Server. 
The CHECKSUM function will return an integer hash value based on its argument. In this case, we can pass in a GUID, 
and checksum will return an integer.
*/
Select Rand() As RandomNumber, 
       NewId() As GUID, 
       Checksum(NewId()) As RandomInteger
From   (Select 1 As NUM Union All
        Select 2 Union All
        Select 3) As Alias

/*
Before we continue, let’s take a look at the output, because there are some interesting observations that we need to 
consider before continuing. RandomInteger can be positive or negative because it’s limited to the range of an integer, 
so the values must fall between -2,147,483,648 and 2,147,483,647.

Most of the time, we want a random number within a certain range of numbers. In most languages, we simply multiply 
the result of the Rand() function to get this number. Since our RandomInteger is already a whole number, we really 
can’t do this. However, we could use the mod operator to guarantee a range of numbers. Mod is the remainder of a division 
operation, so if we mod a number by 10, we are guaranteed to get a number between -9 and +9. Unfortunately, this is a little 
misleading because there are 19 possible numbers we can get for this. So, to make sure we get a range to 10 numbers, we 
need to take the absolute value of the number, and then mod 10. Like this:
*/
Select Rand() As RandomNumber, 
       NewId() As GUID, 
       Abs(Checksum(NewId())) % 10 As RandomInteger
From   (Select 1 As NUM Union All
        Select 2 Union All
        Select 3) As Alias

/*
%6 vs %11 - 5
%11 -5: will avoid 0 haing double the number of occurrences
*/
Select Checksum(NewId()) % 6 As RandomNumber

Select Abs(Checksum(NewId())) % 11 - 5 As RandomNumber