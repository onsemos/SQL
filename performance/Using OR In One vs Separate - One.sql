USE erfx_test

SET STATISTICS IO ON
SET STATISTICS TIME ON


DBCC DROPCLEANBUFFERS

	--SELECT 		co.geography_id AS country_id, co.geography_name AS country_name, co.geography_abbrev AS country_abbrev, 
	--		c.geography_id AS city_id, c.geography_name AS city_name, c.geography_abbrev AS city_abbrev,  
	--		z.geography_id AS zip_id, z.geography_name AS zip_name, z.geography_abbrev AS zip_abbrev,
	--		z2.geography_id AS zip2_id, z2.geography_name AS zip2_name, z2.geography_abbrev AS zip2_abbrev
		SELECT COUNT(co.geography_id)
	FROM 		eMstr_Geographies co 
		JOIN	eMstr_Geographies c ON c.parent_id = co.geography_id AND c.geo_level_id = 20
		JOIN	eMstr_Geographies z ON z.parent_id = c.geography_id AND z.geo_level_id = 1
		JOIN	eMstr_Geographies z2 ON z.zip2_id = z2.geography_id AND z2.geo_level_id = 33
	WHERE		co.geo_level_id = 60

		AND	EXISTS (
				SELECT 		1
				FROM 		eMstr_Lanes_OrigDest l 
				WHERE		l.is_active = 1
					AND	(z.geography_id = l.orig_id  OR z.geography_id = l.dest_id )
			)
	


	
-- http://stackoverflow.com/questions/81278/ways-to-avoid-eager-spool-operations-on-sql-server
