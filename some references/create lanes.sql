		DECLARE @data_load_id		int = ?	
		DECLARE @user_id			int = ? 
		DECLARE @file_name			nvarchar(4000) = ? 
		DECLARE @total_records		int = ? 
		DECLARE @error_records		int = ? 
		
		DECLARE @num_records_inserted int	
		DECLARE @total_shipments int	
		
		SET NOCOUNT ON;	   
					
		BEGIN TRY BEGIN TRANSACTION  
			/*====================================================================================   
			=   													 
			=	 Setup Tracking  									 
			=  														 
			====================================================================================*/    
			SET @num_records_inserted = (SELECT COUNT(*) FROM eShipments WHERE data_load_id = @data_load_id)	   
			SET @total_shipments = (SELECT SUM(historical_volume) FROM eShipments WHERE data_load_id = @data_load_id)	   
			  
			INSERT INTO eShipment_Upload_Tracking (data_load_id, data_load_date, tbc_user_id, file_name, total_records, num_records_inserted, num_records_errored, total_shipments)	   
			SELECT	@data_load_id, CAST(GETDATE() as DATETIMEOFFSET(7)), @user_id, @file_name, @total_records, @num_records_inserted, @error_records, @total_shipments	   
			  
			/*====================================================================================    
			=									   
			=	Insert master entries				   
			=										   
			====================================================================================*/   
			/***********	COUNTRIES	***********/	 
			INSERT INTO eMstr_Geography ( geo_level_id, geography_abbrev, geography_name )	 
			SELECT DISTINCT Q1.geo_level_id, Q1.geography_abbrev, Q1.geography_name	 
			FROM		(	 
					SELECT	DISTINCT  1		AS geo_level_id 
						, orig_country		AS geography_abbrev	 
						,CASE WHEN orig_country = 'CA' THEN 'Canada' ELSE 'United States' END AS geography_name  
					FROM	eShipments	 
					UNION	 
					SELECT	DISTINCT  1		AS geo_level_id 
						, dest_country	AS geography_abbrev	 
						,CASE WHEN dest_country = 'CA' THEN 'Canada' ELSE 'United States' END AS geography_name  
					FROM	eShipments	 
					) Q1	 
			LEFT	JOIN	eMstr_Geography mg ON Q1.geo_level_id = mg.geo_level_id AND Q1.geography_name = mg.geography_name	 
			WHERE		Q1.geography_name IS NOT NULL AND mg.geography_name IS NULL	 
			 
			/***********  STATES  ***********/	 
			INSERT INTO eMstr_Geography ( geo_level_id, geography_abbrev, geography_name, parent_id )	 
			SELECT DISTINCT Q2.geo_level_id, Q2.[state], Q2.[state], Q2.geography_id	 
			FROM		(	 
					SELECT		DISTINCT	2	AS geo_level_id 
							, orig_country	AS country_code 
							, orig_state		AS [state] 
							, b.geography_id 	 
					FROM		eShipments a 	 
						JOIN	eMstr_Geography b ON a.orig_country = b.geography_abbrev AND b.geo_level_id = 1	 
					UNION	 
					SELECT		DISTINCT 2 AS geo_level_id 
							, dest_country AS country_code 
							, dest_state AS [state], b.geography_id 	 
					FROM		eShipments a 	 
						JOIN	eMstr_Geography b ON a.dest_country= b.geography_abbrev AND b.geo_level_id = 1	 
					) Q2	 
			LEFT	JOIN	eMstr_Geography mg ON Q2.geo_level_id = mg.geo_level_id AND Q2.state = mg.geography_abbrev AND Q2.geography_id = mg.parent_id	 
			WHERE		Q2.state IS NOT NULL AND mg.geography_abbrev IS NULL	 
			 
			/***********  POINTS  ***********/	 
			INSERT INTO eMstr_Geography (geo_level_id, geography_abbrev, geography_name, parent_id )	 
			SELECT	DISTINCT Q3.geo_level_id, Q3.point, Q3.point, Q3.geography_id	 
			FROM		(	 
					SELECT		DISTINCT 3 AS geo_level_id 
							, a.orig_postal_code AS point 
							, b.geography_id	 
					FROM		eShipments a	 
						JOIN	eMstr_Geography b ON a.orig_state = b.geography_abbrev AND b.geo_level_id = 2	 
						JOIN	eMstr_Geography c ON a.orig_country = c.geography_abbrev AND c.geo_level_id = 1	 
					UNION	 
					SELECT		DISTINCT 3 AS geo_level_id 
							, a.dest_postal_code AS point, b.geography_id	 
					FROM		eShipments a	 
						JOIN	eMstr_Geography b ON a.dest_state = b.geography_abbrev AND b.geo_level_id = 2	 
						JOIN	eMstr_Geography c ON a.dest_country = c.geography_abbrev AND c.geo_level_id = 1	 
					) Q3	 
			LEFT	JOIN	eMstr_Geography mg ON Q3.geo_level_id = mg.geo_level_id AND Q3.point = mg.geography_name AND Q3.geography_id = mg.parent_id	 
			WHERE		Q3.point IS NOT NULL AND mg.geography_name IS NULL	
			
			/***********  Location ID  ***********/ 
			INSERT		eMstr_Location_IDs (location_id_name)	 
			SELECT		a.dest_location_id 
			FROM		eShipments a		 
			LEFT	JOIN	eMstr_Location_IDs b ON b.location_id_name = a.dest_location_id 
			WHERE		a.dest_location_id IS NOT NULL AND b.location_id_name IS NULL 
			GROUP BY	a.dest_location_id 
			
			/***********  RFP_Companies  ***********/ 
			INSERT		eMstr_RFP_Companies (rfp_company_name)	 
			SELECT		a.rfp_company 
			FROM		eShipments a		 
			LEFT	JOIN	eMstr_RFP_Companies b ON b.rfp_company_name = a.rfp_company 
			WHERE		a.rfp_company IS NOT NULL AND b.rfp_company_name IS NULL 
			GROUP BY	a.rfp_company 
			
			/***********  RFP_Divisions  ***********/ 
			INSERT		eMstr_RFP_Divisions (rfp_division_name)	 
			SELECT		a.rfp_division 
			FROM		eShipments a		 
			LEFT	JOIN	eMstr_RFP_Divisions b ON b.rfp_division_name = a.rfp_division 
			WHERE		a.rfp_division IS NOT NULL AND b.rfp_division_name IS NULL 
			GROUP BY	a.rfp_division 
			
			/***********  OPT_Companies  ***********/ 
			INSERT		eMstr_OPT_Companies ( opt_company_name)	 
			SELECT		a.opt_company 
			FROM		eShipments a		 
			LEFT	JOIN	eMstr_OPT_Companies b ON b.opt_company_name = a.opt_company 
			WHERE		a.opt_company IS NOT NULL AND b.opt_company_name IS NULL 
			GROUP BY	a.opt_company 
			
			/***********  OPT_Divisions  ***********/ 
			INSERT		eMstr_OPT_Divisions (opt_division_name)	 
			SELECT		a.opt_division 
			FROM		eShipments a		 
			LEFT	JOIN	eMstr_OPT_Divisions b ON b.opt_division_name = a.opt_division 
			WHERE		a.opt_division IS NOT NULL AND b.opt_division_name IS NULL 
			GROUP BY	a.opt_division 
			
			/***********  eMstr_Equipments  ***********/ 
			INSERT		eMstr_Equipments (equipment_name)	 
			SELECT		a.equipment_type	 
			FROM		eShipments a	 
			WHERE		NOT EXISTS ( SELECT 1 FROM eMstr_Equipments b WHERE a.equipment_type = b.equipment_name)
				AND	a.equipment_type IS NOT NULL
			GROUP BY	a.equipment_type	 
			 
			/***********  TARIFFS  ***********/ 
			INSERT		eMstr_Tariffs (tariff_name, currency_id)	 
			SELECT		a.tariff_type, MIN(a.rfp_currency_id) 
			FROM		eShipments a		 
			WHERE		NOT EXISTS ( SELECT 1 FROM eMstr_Tariffs b WHERE a.tariff_type = b.tariff_name)
				AND	a.tariff_type IS NOT NULL
			GROUP BY	a.tariff_type 
			
			/***********  Rated Class  ***********/ 
			INSERT		eMstr_Rated_Classes (rated_class_name)	 
			SELECT		a.rated_class
			FROM		eShipments a		 
			WHERE		NOT EXISTS ( SELECT 1 FROM eMstr_Rated_Classes b WHERE a.rated_class = b.rated_class_name)
				AND	a.rated_class IS NOT NULL
			GROUP BY	a.rated_class 
			
			/***********  Customer Type  ***********/ 
			INSERT		eMstr_Customer_Types (customer_type_name)	 
			SELECT		a.customer_type
			FROM		eShipments a		 
			WHERE		NOT EXISTS ( SELECT 1 FROM eMstr_Customer_Types b WHERE a.customer_type = b.customer_type_name)
				AND	a.customer_type IS NOT NULL
			GROUP BY	a.customer_type 
			
			/******** Historic Suppliers ********/   
			MERGE	eMstr_Historic_Suppliers t   
			USING	(   
				SELECT		carrier_id historic_supplier_id, MAX(b.organization_name) historic_supplier_name    
				FROM		eShipments a 
					JOIN	<<TBC_DB_NAME>>.dbo.Adm_Organizations b ON a.carrier_id = b.organization_id 
				GROUP BY	carrier_id
				) s ON t.historic_supplier_id = s.historic_supplier_id   
			WHEN	MATCHED    
				THEN	UPDATE	SET historic_supplier_name = s.historic_supplier_name   
			WHEN	NOT MATCHED   
				THEN	INSERT	(historic_supplier_id, historic_supplier_name)   
					VALUES	(historic_supplier_id, historic_supplier_name);  
			
			/*====================================================================================   
			=									  
			=	Update	IDs in eShipments				  
			=										  
			====================================================================================*/  
			/********  Update Currency ID   ********/  
			UPDATE		eShipments  
			SET		rfp_currency_id = ISNULL(b.currency_id, 1)  
					, baseline_currency_id = ISNULL(c.currency_id, 1)  
			FROM		eShipments a  
			LEFT	JOIN	eMstr_Currencies b ON b.currency_code = a.rfp_currency  
			LEFT	JOIN	eMstr_Currencies c ON c.currency_code = a.baseline_currency  
			
			/********  Update Country ID   ********/ 
			UPDATE		eShipments  
			SET		orig_country_id = b.geography_id
					, dest_country_id = c.geography_id
			FROM		eShipments a  
			LEFT	JOIN	eMstr_Geography b	ON b.geo_level_id = 1 
								AND b.geography_abbrev = a.orig_country 
			LEFT	JOIN	eMstr_Geography c	ON c.geo_level_id = 1 
								AND c.geography_abbrev = a.dest_country
			
			/********  Update State ID   ********/ 
			UPDATE		eShipments  
			SET		orig_state_id = b.geography_id
					, dest_state_id = c.geography_id
			FROM		eShipments a  					
			LEFT	JOIN	eMstr_Geography b	ON b.geo_level_id = 2 
								AND b.geography_abbrev = a.orig_state 
								AND b.parent_id = a.orig_country_id
			LEFT	JOIN	eMstr_Geography c	ON c.geo_level_id = 2 
								AND c.geography_abbrev = a.dest_state 
								AND c.parent_id = a.dest_country_id
								
			/********  Update Postal(Point) ID   ********/ 
			UPDATE		eShipments  
			SET		orig_postal_id = b.geography_id
					, dest_postal_id = c.geography_id
			FROM		eShipments a  
			LEFT	JOIN	eMstr_Geography b	ON b.geo_level_id = 3 
								AND b.geography_abbrev = a.orig_postal_code 
								AND b.parent_id = a.orig_state_id
			LEFT	JOIN	eMstr_Geography c	ON c.geo_level_id = 3 
								AND c.geography_abbrev = a.dest_postal_code
								AND c.parent_id = a.dest_state_id
			
			/********  Update Location ID ID   ********/  
			UPDATE		eShipments  
			SET		dest_location_id_id = b.location_id_id
			FROM		eShipments a  
				JOIN	eMstr_Location_IDs b ON b.location_id_name = a.dest_location_id  
			
			/********  Update RFP Company ID   ********/  
			UPDATE		eShipments  
			SET		rfp_company_id = b.rfp_company_id
			FROM		eShipments a  
				JOIN	eMstr_RFP_Companies b ON b.rfp_company_name = a.rfp_company  
				
			/********  Update RFP Division ID   ********/  
			UPDATE		eShipments  
			SET		rfp_division_id = b.rfp_division_id
			FROM		eShipments a  
				JOIN	eMstr_RFP_Divisions b ON b.rfp_division_name = a.rfp_division  
			
			/********  Update OPT Company ID   ********/  
			UPDATE		eShipments  
			SET		opt_company_id = b.opt_company_id
			FROM		eShipments a  
				JOIN	eMstr_OPT_Companies b ON b.opt_company_name = a.opt_company  
				
			/********  Update OPT Division ID   ********/  
			UPDATE		eShipments  
			SET		opt_division_id = b.opt_division_id
			FROM		eShipments a  
				JOIN	eMstr_OPT_Divisions b ON b.opt_division_name = a.opt_division 
			
			/********  Update Equipment ID   ********/  
			UPDATE		eShipments  
			SET		equipment_id = b.equipment_id
			FROM		eShipments a  
				JOIN	eMstr_Equipments b ON b.equipment_name = a.equipment_type  
			
			/********  Update Tariff ID   ********/  
			UPDATE		eShipments  
			SET		tariff_id = b.tariff_id
			FROM		eShipments a  
				JOIN	eMstr_Tariffs b ON b.tariff_name = a.tariff_type  
				
			/********  Update Rated Class ID   ********/  
			UPDATE		eShipments  
			SET		rated_class_id = b.rated_class_id
			FROM		eShipments a  
				JOIN	eMstr_Rated_Classes b ON b.rated_class_name = a.rated_class  
				
			/********  Update Customer Type ID   ********/  
			UPDATE		eShipments  
			SET		customer_type_id = b.customer_type_id
			FROM		eShipments a  
				JOIN	eMstr_Customer_Types b ON b.customer_type_name = a.customer_type  
			
			/********  Update Carrier IDs   ********/  
			UPDATE		eShipments  
			SET		carrier_id = b.organization_id  
			FROM		eShipments a  
				JOIN	<<TBC_DB_NAME>>.dbo.Adm_Organizations b ON b.organization_name = a.carrier_name  

			/*====================================================================================   
			=   													 
			=	 Update Lane IDs in eShipments     					 
			=   													 
			====================================================================================*/ 	   
			UPDATE	eShipments	  
			SET	lane_id = NULL	  
			 
			UPDATE	eShipments	   
			SET	lane_id = b.lane_id	   
			FROM	eShipments a	   
			JOIN	eMstr_Lanes b	ON a.orig_postal_id = b.orig_id   
						AND a.dest_postal_id = b.dest_id	  
						AND a.rfp_company_id = b.rfp_company_id
						AND a.rfp_division_id = b.rfp_division_id
						AND a.tariff_id = b.tariff_id	   
						AND a.equipment_id = b.equipment_id
						AND a.rfp_currency_id = b.rfp_currency_id 
						AND a.rated_class = b.rated_class 
						AND a.extra_lane_defining_text_1 = b.extra_lane_defining_text_1 
						AND a.extra_lane_defining_text_2 = b.extra_lane_defining_text_2
						AND ISNULL(a.extra_lane_defining_number_1,0) = ISNULL(b.extra_lane_defining_number_1,0)	  
						AND ISNULL(a.extra_lane_defining_number_2,0) = ISNULL(b.extra_lane_defining_number_2,0)  
						AND ISNULL(a.extra_lane_defining_yesno_1,0) = ISNULL(b.extra_lane_defining_yesno_1,0)	  
						AND ISNULL(a.extra_lane_defining_yesno_2,0) = ISNULL(b.extra_lane_defining_yesno_2,0)  
						AND ISNULL(a.extra_lane_defining_percent_1,0) = ISNULL(b.extra_lane_defining_percent_1,0)	  
						AND ISNULL(a.extra_lane_defining_percent_2,0) = ISNULL(b.extra_lane_defining_percent_2,0) 
			


			/*====================================================================================     
			=    														  
			=	 Update/Insert eMstr_Lanes (ROLL UP LANES)				  
			=															  
			====================================================================================*/ 	     
			DECLARE @tbl_rowcounts TABLE ( mergeAction nvarchar(10) )     
			DECLARE @insert_count int, @update_count int, @delete_count int;	  
			  
			MERGE	eMstr_Lanes t   
			USING	(   
				SELECT		lane_id  
						, 1			AS lane_type_id
						, orig_postal_id	AS orig_id   
						, dest_postal_id	AS dest_id	  
						, rfp_company_id
						, rfp_division_id 
						, tariff_id 	   
						, equipment_id  
						, rfp_currency_id 
						, rated_class	
						, MAX(extra_text_1)		AS extra_text_1	 
						, MAX(extra_text_2)		AS extra_text_2		 
						, MAX(extra_text_3)		AS extra_text_3		 
						, MAX(extra_text_4)		AS extra_text_4 
						, extra_lane_defining_text_1	 	 
						, extra_lane_defining_text_2	  
						, MAX(extra_number_1)		AS extra_number_1		 
						, MAX(extra_number_2)		AS extra_number_2		 
						, MAX(extra_number_3)		AS extra_number_3	 
						, MAX(extra_number_4)		AS extra_number_4 
						, extra_lane_defining_number_1	 	 
						, extra_lane_defining_number_2	  
						, MAX(extra_yesno_1)		AS extra_yesno_1 
						, MAX(extra_yesno_2)		AS extra_yesno_2			 
						, MAX(extra_yesno_3)		AS extra_yesno_3		 
						, MAX(extra_yesno_4)		AS extra_yesno_4 
						, extra_lane_defining_yesno_1	 
						, extra_lane_defining_yesno_2 
						, MAX(extra_percent_1)		AS extra_percent_1		 
						, MAX(extra_percent_2)		AS extra_percent_2		 
						, MAX(extra_percent_3)		AS extra_percent_3	 
						, MAX(extra_percent_4)		AS extra_percent_4 
						, extra_lane_defining_percent_1	 
						, extra_lane_defining_percent_2	 

						, SUM(historical_volume * weight) 	AS total_weight
						, SUM(full_tariff_spend)	AS tariff_amount
						, 1				AS is_active	  
						  
				FROM		eShipments 	   
				GROUP BY	lane_id  
						, orig_postal_id    
						, dest_postal_id  
						, rfp_company_id 
						, rfp_division_id
						, tariff_id    
						, equipment_id 
						, rfp_currency_id 
						, rated_class 
						, extra_lane_defining_text_1
						, extra_lane_defining_text_2
						, ISNULL(extra_lane_defining_number_1,0)	
						, ISNULL(extra_lane_defining_number_2,0)
						, ISNULL(extra_lane_defining_yesno_1,0)	 
						, ISNULL(extra_lane_defining_yesno_2,0) 
						, ISNULL(extra_lane_defining_percent_1,0)	 
						, ISNULL(extra_lane_defining_percent_2,0)  
				) s ON t.lane_id = s.lane_id   
			WHEN	MATCHED	THEN   
				UPDATE	SET	total_weight = s.total_weight   
						, tariff_amount = s.tariff_amount   
						, is_active = s.is_active
						
						, extra_text_1 = s.extra_text_1 
						, extra_text_2 = s.extra_text_2 
						, extra_text_3 = s.extra_text_3 
						, extra_text_4 = s.extra_text_4 
						, extra_number_1 = s.extra_number_1 
						, extra_number_2 = s.extra_number_2 
						, extra_number_3 = s.extra_number_3 
						, extra_number_4 = s.extra_number_4 
						, extra_yesno_1 = s.extra_yesno_1 
						, extra_yesno_2 = s.extra_yesno_2 
						, extra_yesno_3 = s.extra_yesno_3 
						, extra_yesno_4 = s.extra_yesno_4 
						, extra_percent_1 = s.extra_percent_1 
						, extra_percent_2 = s.extra_percent_2 
						, extra_percent_3 = s.extra_percent_3 
						, extra_percent_4 = s.extra_percent_4    
			WHEN	NOT MATCHED	   
				THEN	INSERT	(lane_type_id
						, orig_id   
						, dest_id	  
						, rfp_company_id
						, rfp_division_id 
						, tariff_id 	   
						, equipment_id  
						, rfp_currency_id 
						, rated_class	
						, extra_text_1	 
						, extra_text_2	 
						, extra_text_3	 
						, extra_text_4 
						, extra_lane_defining_text_1	 
						, extra_lane_defining_text_2 
						, extra_number_1	 
						, extra_number_2	 
						, extra_number_3	 
						, extra_number_4 
						, extra_lane_defining_number_1	 
						, extra_lane_defining_number_2 
						, extra_yesno_1	 
						, extra_yesno_2	 
						, extra_yesno_3		 
						, extra_yesno_4 
						, extra_lane_defining_yesno_1	 
						, extra_lane_defining_yesno_2 
						, extra_percent_1	 
						, extra_percent_2	 
						, extra_percent_3	 
						, extra_percent_4 
						, extra_lane_defining_percent_1	 
						, extra_lane_defining_percent_2 
						, total_weight
						, tariff_amount
						, is_active)	   
					VALUES	(lane_type_id
						, orig_id   
						, dest_id	  
						, rfp_company_id
						, rfp_division_id 
						, tariff_id 	   
						, equipment_id  
						, rfp_currency_id 
						, rated_class	
						, extra_text_1	 
						, extra_text_2	 
						, extra_text_3	 
						, extra_text_4 
						, extra_lane_defining_text_1	 
						, extra_lane_defining_text_2 
						, extra_number_1	 
						, extra_number_2	 
						, extra_number_3	 
						, extra_number_4 
						, extra_lane_defining_number_1	 
						, extra_lane_defining_number_2 
						, extra_yesno_1	 
						, extra_yesno_2	 
						, extra_yesno_3		 
						, extra_yesno_4 
						, extra_lane_defining_yesno_1	 
						, extra_lane_defining_yesno_2 
						, extra_percent_1	 
						, extra_percent_2	 
						, extra_percent_3	 
						, extra_percent_4 
						, extra_lane_defining_percent_1	 
						, extra_lane_defining_percent_2 
						, total_weight
						, tariff_amount
						, is_active)
			WHEN	NOT MATCHED BY SOURCE		/****  DEACTIVATE LANES  ****/   
				THEN	UPDATE	SET	is_active = 0 	   
			OUTPUT        
				$action into @tbl_rowcounts;    
				  
			/*====================================================================================    
			=   											  
			=	 TRACKING  									  
			=  												  
			====================================================================================*/      
			SELECT		@insert_count=[INSERT]              
					, @update_count=[UPDATE]              
					, @delete_count=[DELETE]			      
			FROM 		(              
					SELECT  mergeAction,	1 rows              
					FROM	@tbl_rowcounts              
					)p	      
					pivot	      
					(        
					count(rows) FOR mergeAction IN ([INSERT], [UPDATE], [DELETE])	      
					) AS pvt;     
					    
			/********  Tracking - # of lanes that have been inserted or updated from current data load  ********/     
			UPDATE	eShipment_Upload_Tracking	      
			SET	num_lanes_inserted = @insert_count	      
				,num_lanes_updated = @update_count	      
			WHERE	data_load_id = @data_load_id    
 			 	
			
			/*====================================================================================   
			=    
			=	 Update Lane IDs in eShipments   
			=   
			====================================================================================*/     
			UPDATE	eShipments	   
			SET	lane_id = b.lane_id	   
			FROM	eShipments a	   
			JOIN	eMstr_Lanes b	ON a.orig_postal_id = b.orig_id   
						AND a.dest_postal_id = b.dest_id	  
						AND a.rfp_company_id = b.rfp_company_id
						AND a.rfp_division_id = b.rfp_division_id
						AND a.tariff_id = b.tariff_id	   
						AND a.equipment_id = b.equipment_id
						AND a.rfp_currency_id = b.rfp_currency_id 
						AND a.rated_class = b.rated_class 
						AND a.extra_lane_defining_text_1 = b.extra_lane_defining_text_1 
						AND a.extra_lane_defining_text_2 = b.extra_lane_defining_text_2
						AND ISNULL(a.extra_lane_defining_number_1,0) = ISNULL(b.extra_lane_defining_number_1,0)	  
						AND ISNULL(a.extra_lane_defining_number_2,0) = ISNULL(b.extra_lane_defining_number_2,0)  
						AND ISNULL(a.extra_lane_defining_yesno_1,0) = ISNULL(b.extra_lane_defining_yesno_1,0)	  
						AND ISNULL(a.extra_lane_defining_yesno_2,0) = ISNULL(b.extra_lane_defining_yesno_2,0)  
						AND ISNULL(a.extra_lane_defining_percent_1,0) = ISNULL(b.extra_lane_defining_percent_1,0)	  
						AND ISNULL(a.extra_lane_defining_percent_2,0) = ISNULL(b.extra_lane_defining_percent_2,0)  
 			 
			/*====================================================================================    
			=     
			=	 Update/Insert various tables    
			=	(eLane_Incumbents in convertPrices)   
			=    
			====================================================================================*/     
 			  
			 
			/*====================================================================================    
			=						  
			=	 TRACKING				  
			=						  
			====================================================================================*/     
			/********  Tracking - total # of lanes in the current data load  ********/	    
			UPDATE	eShipment_Upload_Tracking	    
			SET	total_lanes_load = (SELECT COUNT(DISTINCT lane_id) FROM eShipments WHERE data_load_id = @data_load_id)	    
			WHERE	data_load_id = @data_load_id	    
			    
			/********  Tracking - total # of lanes in the RFP  ********/	    
			UPDATE eShipment_Upload_Tracking	    
			SET	total_lanes_rfp = (SELECT COUNT(lane_id) FROM eMstr_Lanes WHERE is_active = 1)	    
			WHERE data_load_id = @data_load_id    
			    
			/********  Tracking - determine if there are any shipment records without a lane id for this shipment upload  ********/	    
			DECLARE @null_lane_count int = (SELECT COUNT(*) FROM eShipments WHERE data_load_id = @data_load_id AND lane_id IS NULL)	    
				    
			UPDATE eShipment_Upload_Tracking	    
			SET	has_null_lane_ids = CASE WHEN @null_lane_count = 0 THEN 0 WHEN @null_lane_count > 0 THEN 1 END	    
			WHERE	data_load_id = @data_load_id	    
			    
			/********  Tracking - Sum() of total spend for this data load  ********/	    
			UPDATE	eShipment_Upload_Tracking	    
			SET	shipments_total_spend =	(SELECT	SUM(shipment_cost*historical_volume) FROM eShipments )    
			WHERE	data_load_id = @data_load_id		   
			 
			/*====================================================================================   
			=    
			=	 prc_convertPrices   
			=   
			====================================================================================*/    
			EXEC prc_convertPrices 'Lanes'  
			
		COMMIT TRAN	END TRY	  
		  
		BEGIN CATCH	  
		  
			IF @@TRANCOUNT > 0	  
				ROLLBACK TRAN	  
			  
				DECLARE @ErrorMessage NVARCHAR(4000);	  
				DECLARE @ErrorSeverity INT;	  
				DECLARE @ErrorState INT;	  
				  
				SELECT	@ErrorMessage	= ERROR_MESSAGE()	  
						,@ErrorSeverity	= ERROR_SEVERITY()	  
						,@ErrorState	= ERROR_STATE();	  
				RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);		  
		END CATCH