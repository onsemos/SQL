SELECT		supplier_name
			, rfp_bid_id
			, lot_name
			, lot_number
			, department_1
			, department_2
			, department_3
			, department_4
			, department_5
			, department_6
			, department_nbr
			, department_name
			, volume_category_a_e
			, volume_category_b
			, volume_category_c_d
			, RIGHT(ae,1) AS contract_id
			, price_category_a_e
			, price_category_b
			, price_category_c_d
	FROM		(
			SELECT		supplier_name
					, rfp_bid_id
					, lot_name
					, lot_number
					, department_1
					, department_2
					, department_3
					, department_4
					, department_5
					, department_6
					, department_nbr
					, department_name
					, volume_category_a_e
					, volume_category_b
					, volume_category_c_d
					, ISNULL(price_category_a_e,0) price_category_a_e_1, ISNULL(price_category_a_e_2,0) price_category_a_e_2
					, ISNULL(price_category_b,0) price_category_b_1, ISNULL(price_category_b_2,0) price_category_b_2
					, ISNULL(price_category_c_d,0) price_category_c_d_1, ISNULL(price_category_c_d_2,0) price_category_c_d_2

			FROM		optRaw_collection_bids_GD
			) src
		UNPIVOT	(
			price_category_a_e FOR ae IN (price_category_a_e_1, price_category_a_e_2)
			) p_a_e
		UNPIVOT	(
			price_category_b FOR b IN (price_category_b_1, price_category_b_2)
			) p_b
		UNPIVOT	(
			price_category_c_d FOR cd IN (price_category_c_d_1, price_category_c_d_2)
			) p_cd
	WHERE		RIGHT(ae,1) = RIGHT(b,1) 
		AND	RIGHT(ae,1) = RIGHT(cd,1)