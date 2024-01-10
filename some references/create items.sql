		DECLARE @data_load_id int = ? 
		
		SET NOCOUNT ON;
		 
		BEGIN TRY BEGIN TRANSACTION  
			/*====================================================================================      
			=       
			=	 Update/Insert optItems (ROLL UP ITEMS)     
			=      
			====================================================================================*/          
			DECLARE @tbl_rowcounts TABLE ( mergeAction nvarchar(10) )   
			DECLARE @insert_count int, @update_count int, @delete_count int; 
			   
			/*	--this is my merge statement, which inserts, updates, and invalidates all in one shot	*/		    
			MERGE	optItems  t	    
			USING	(   
				SELECT		a.lane_id
						, b.orig_id
						, b.dest_id 
						, a.rfp_company_id
						, a.rfp_division_id
						, a.opt_company_id
						, a.opt_division_id
						, a.dest_location_id_id
						, a.tariff_id
						, a.equipment_id
						, a.company_controlled
						, a.rfp_currency_id
						, a.rated_class_id
						, a.customer_type_id
						, SUM(historical_volume * weight)	AS total_weight
						, SUM(full_tariff_spend)		AS tariff_amount
						, SUM(CASE WHEN weight > 0 THEN historical_volume ELSE 0 END) AS shipments_with_weight_info
						, 1					AS is_valid  
				FROM		eShipments a	    
				LEFT	JOIN	eMstr_Lanes b ON b.lane_id = a.lane_id 
				GROUP BY	a.lane_id
						, b.orig_id, b.dest_id 
						, a.rfp_company_id, a.rfp_division_id
						, a.opt_company_id, a.opt_division_id
						, a.dest_location_id_id
						, a.tariff_id
						, a.equipment_id
						, a.company_controlled
						, a.rfp_currency_id
						, a.rated_class_id
						, a.customer_type_id
				) s ON	t.lane_id = s.lane_id 
					AND t.orig_id = s.orig_id	    
					AND t.dest_id = s.dest_id 
					AND t.rfp_company_id = s.rfp_company_id 
					AND t.rfp_division_id = s.rfp_division_id 
					AND t.opt_company_id = s.opt_company_id 
					AND t.opt_division_id = s.opt_division_id 
					AND t.dest_location_id_id = s.dest_location_id_id 
					AND t.tariff_id = s.tariff_id 
					AND t.equipment_id = s.equipment_id 
					AND t.company_controlled = s.company_controlled 
					AND t.rfp_currency_id = s.rfp_currency_id 
					AND t.rated_class_id = s.rated_class_id 
					AND t.customer_type_id = s.customer_type_id 		    
			WHEN	MATCHED THEN	    
					UPDATE SET	total_weight = s.total_weight   
							, tariff_amount = s.tariff_amount   
							, shipments_with_weight_info = s.shipments_with_weight_info
							, is_valid = s.is_valid   
			WHEN	NOT MATCHED THEN	    
				INSERT	(lane_id
					, orig_id
					, dest_id 
					, rfp_company_id
					, rfp_division_id
					, opt_company_id
					, opt_division_id
					, dest_location_id_id
					, tariff_id
					, equipment_id
					, company_controlled
					, rfp_currency_id
					, rated_class_id
					, customer_type_id
					, total_weight
					, tariff_amount
					, shipments_with_weight_info
					, is_valid  )	    
				VALUES	(lane_id
					, orig_id
					, dest_id 
					, rfp_company_id
					, rfp_division_id
					, opt_company_id
					, opt_division_id
					, dest_location_id_id
					, tariff_id
					, equipment_id
					, company_controlled
					, rfp_currency_id
					, rated_class_id
					, customer_type_id
					, total_weight
					, tariff_amount
					, shipments_with_weight_info
					, is_valid  ) 
			WHEN	NOT MATCHED BY SOURCE THEN	    
				UPDATE SET	is_valid = NULL	    
			OUTPUT        
				$action into @tbl_rowcounts;     
			   
			/*====================================================================================      
			=       
			=	 TRACKING      
			=      
			====================================================================================*/     
			SELECT		@insert_count=INSERT             
					, @update_count=UPDATE            
					, @delete_count=DELETE			      
			FROM		(              
				SELECT  mergeAction,	1 rows              
				FROM	@tbl_rowcounts              
				)p	      
				pivot	      
				(     
				COUNT(rows) FOR mergeAction IN (    INSERT, UPDATE, DELETE)	      
				) AS pvt;     
		     
			/********  Tracking - # of items (new) that have been inserted from current data load  ********/	      
			UPDATE	eShipment_Upload_Tracking	      
			SET	num_items_inserted	= @insert_count	      
				, num_items_updated	= @update_count	      
			WHERE	data_load_id = @data_load_id	   	    
			   
			/*====================================================================================      
			=       
			=	 Update Item IDs (otr_item_id/itml_item_id) in eShipments      
			=      
			====================================================================================*/     
			UPDATE eShipments SET item_id = NULL     
			   
			UPDATE		a	    
			SET		item_id = c.item_id	    
			FROM		eShipments a	       
			LEFT	JOIN	eMstr_Lanes b ON b.lane_id = a.lane_id   
				JOIN	optItems c ON	a.lane_id = c.lane_id 
							AND b.orig_id = c.orig_id	    
							AND b.dest_id = c.dest_id 
							AND a.rfp_company_id = c.rfp_company_id 
							AND a.rfp_division_id = c.rfp_division_id 
							AND a.opt_company_id = c.opt_company_id 
							AND a.opt_division_id = c.opt_division_id 
							AND a.dest_location_id_id = c.dest_location_id_id 
							AND a.tariff_id = c.tariff_id 
							AND a.equipment_id = c.equipment_id 
							AND a.company_controlled = c.company_controlled 
							AND a.rfp_currency_id = c.rfp_currency_id 
							AND a.rated_class_id = c.rated_class_id 
							AND a.customer_type_id = c.customer_type_id 
			WHERE	c.is_valid IN (1,2)	    
			
			/*====================================================================================  
			=   															
			=	 Create Master Tables for OPT (Extra Lane Fields)  							
			=  																
			====================================================================================*/   
			EXEC opt_normColumn 'eMstr_Lanes','xd_extra_lane_defining_text_1','extra_lane_defining_text_1','extra_lane_defining_text_1','nvarchar(400)' 
			EXEC opt_normColumn 'eMstr_Lanes','xd_extra_lane_defining_text_2','extra_lane_defining_text_2','extra_lane_defining_text_2','nvarchar(400)' 
			EXEC opt_normColumn 'eMstr_Lanes','xd_extra_lane_defining_number_1','extra_lane_defining_number_1','extra_lane_defining_number_1','float' 
			EXEC opt_normColumn 'eMstr_Lanes','xd_extra_lane_defining_number_2','extra_lane_defining_number_2','extra_lane_defining_number_2','float' 
			EXEC opt_normColumn 'eMstr_Lanes','xd_extra_lane_defining_yesno_1','extra_lane_defining_yesno_1','extra_lane_defining_yesno_1','float' 
			EXEC opt_normColumn 'eMstr_Lanes','xd_extra_lane_defining_yesno_2','extra_lane_defining_yesno_2','extra_lane_defining_yesno_2','float' 
			EXEC opt_normColumn 'eMstr_Lanes','xd_extra_lane_defining_percent_1','extra_lane_defining_percent_1','extra_lane_defining_percent_1','float' 
			EXEC opt_normColumn 'eMstr_Lanes','xd_extra_lane_defining_percent_2','extra_lane_defining_percent_2','extra_lane_defining_percent_2','float' 
			 
			UPDATE xd_extra_lane_defining_yesno_1 SET id_name = 'Yes' WHERE extra_lane_defining_yesno_1 = 1 
			UPDATE xd_extra_lane_defining_yesno_1 SET id_name = 'No' WHERE extra_lane_defining_yesno_1 = 0 
			UPDATE xd_extra_lane_defining_yesno_2 SET id_name = 'Yes' WHERE extra_lane_defining_yesno_2 = 1 
			UPDATE xd_extra_lane_defining_yesno_2 SET id_name = 'No' WHERE extra_lane_defining_yesno_2 = 0 
			   
			/*====================================================================================     
			=   															   
			=	 Generate the Extra Fields list   							   
			=  																   
			====================================================================================*/      
			 EXEC prc_extra_lane_attrib_show_hide	  
			   
			/*====================================================================================     
			=    															   
			=	 Price Conversions   										   
			=   															   
			====================================================================================*/      
			EXEC prc_convertPrices 'Items'   
			  
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