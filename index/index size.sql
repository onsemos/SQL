SELECT i.[name] AS IndexName
      ,SUM(s.[used_page_count]) * 8  AS IndexSizeKB 
      ,SUM(s.[used_page_count]) * 8 /1024  AS IndexSizeMB
FROM sys.dm_db_partition_stats AS s 
JOIN sys.indexes AS i 
ON s.[object_id] = i.[object_id] 
AND s.[index_id] = i.[index_id] 
GROUP BY i.[name] 
ORDER BY i.[name] 