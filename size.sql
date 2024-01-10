

SELECT		OBJECT_NAME(id) AS [table_name], [table_size_in_mb] = convert (varchar, dpages * 8 / 1024) + ' MB'
FROM		sysindexes a
WHERE		indid in (0,1) --AND OBJECT_NAME(id) LIKE 'xtrc%'
ORDER BY	dpages DESC

