USE erfx_ul_tl_template
GO
/****** Object:  StoredProcedure [dbo].[rpt_BidCountByLane]    Script Date: 01/18/2012 14:16:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 /*************************************************************************************
Author    		: John Kedrowski
Date    		: 6/21/11
Description:		: Client Admin Bid Count Bid Report
Actions			: 
			  
	Modifications History
Date		Done By		Comments
--------------------------------------------------------------------------------------
01/18/2012	J2		Changed from hardcoded bid ranges to using 
				table eBid_Count_Ranges to store ranges
****************************************************************************************/

ALTER PROCEDURE [dbo].[rpt_BidCountByLane] 
	-- Add the parameters for the stored procedure here
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @tblLaneBids TABLE
	(
		BID_SUPPLIER			nvarchar(100)
		,LANE_ID			int
		,ORIGIN_CITY			nvarchar(100)
		,ORIGIN_STATE			nvarchar(100)
		,ORIGIN_COUNTRY			nvarchar(100)
		,DESTINATION_CITY		nvarchar(100)
		,DESTINATION_STATE		nvarchar(100)
		,DESTINATION_COUNTRY		nvarchar(100)
		,MILEAGE			int
		,ANNUAL_VOLUME			int
		,INCUMBENT_SUPPLIER		nvarchar(100)
		,BASELINE_RATE_PER_SHIPMENT	float
		,TOTAL_ANNUAL_BASELINE_SPEND	float
		,BID_EQUIPMENT			nvarchar(100)
		,BID_PRICE_PER_SHIPMENT		float
		,TRANSIT_TIME			float
		,BID_WEEKLY_CAPACITY		int
		,TOTAL_ANNUAL_BID_SPEND		float
		,RATE_COMPETITIVENESS		nvarchar(100)
		,IS_LOWEST_BID			nvarchar(100)
		,TOTAL_ANNUAL_SAVINGS		float
		,PERCENTAGE_SAVINGS		float
		,BEST_SUPPLIER_NAME		nvarchar(100)
		,BEST_BID			float
		,BEST_ANNUAL_SAVINGS		float
		,AVERAGE_BID			float
		,AVERAGE_BID_PERCENT_DIFF	float
		,ODD_CAPACITY			nvarchar(100)
		,LANE_BID_COUNT			int
	)

	DECLARE	@tblCountDetails TABLE (lane_id int, num_bids int)

	DECLARE	@totalLaneCount	int = 0
	SELECT	@totalLaneCount = COUNT(*) FROM eTblLanes()

	INSERT INTO	@tblLaneBids
	EXEC		rpt_LaneBids


	INSERT INTO	@tblCountDetails
	SELECT		l.lane_id
			,ISNULL(lb.LANE_BID_COUNT, 0)
	FROM		eTblLanes() l
	LEFT	JOIN	@tblLaneBids lb ON l.lane_id = lb.LANE_ID
	GROUP BY	l.LANE_ID,lb.LANE_BID_COUNT

 
	SELECT		CAST(cr.min AS varchar(10)) +	CASE 
								WHEN cr.max IS NULL 
								THEN '+'
								WHEN cr.min = cr.max
								THEN ''
								ELSE ' to '+CAST(cr.max AS varchar(10))
							END + ' Bids'
			AS BID_COUNT_RANGE
			,COUNT(cd.lane_id) AS LANE_COUNT
	FROM		eBid_Count_Ranges cr
	LEFT	JOIN	@tblCountDetails cd ON cd.num_bids >= cr.min and cd.num_bids <= ISNULL(cr.max, 100)
	GROUP BY	cr.min, cr.max
	ORDER BY	cr.min

/*
create table #lb
(
	BID_SUPPLIER nvarchar(100)
	,LANE_ID int
	,ORIGIN_CITY nvarchar(100)
	,ORIGIN_STATE nvarchar(100)
	,ORIGIN_COUNTRY nvarchar(100)
	,DESTINATION_CITY nvarchar(100)
	,DESTINATION_STATE nvarchar(100)
	,DESTINATION_COUNTRY nvarchar(100)
	,MILEAGE int
	,ANNUAL_VOLUME int
	,INCUMBENT_SUPPLIER nvarchar(100)
	,BASELINE_RATE_PER_SHIPMENT float
	,TOTAL_ANNUAL_BASELINE_SPEND float
	,BID_EQUIPMENT nvarchar(100)
	,BID_PRICE_PER_SHIPMENT float
	,TRANSIT_TIME float
	,BID_WEEKLY_CAPACITY int
	,TOTAL_ANNUAL_BID_SPEND float
	,RATE_COMPETITIVENESS nvarchar(100)
	,IS_LOWEST_BID nvarchar(100)
	,TOTAL_ANNUAL_SAVINGS float
	,PERCENTAGE_SAVINGS float
	,BEST_SUPPLIER_NAME nvarchar(100)
	,BEST_BID float
	,BEST_ANNUAL_SAVINGS float
	,AVERAGE_BID float
	,AVERAGE_BID_PERCENT_DIFF float
	,ODD_CAPACITY nvarchar(100)
	,LANE_BID_COUNT int
)

DECLARE	@totalLaneCount	int = 0

insert into #lb
exec rpt_LaneBids

create table #bidCount(num_bids nvarchar(10), num_lanes int)
create table #laneBidCountCombined(lane_id int, num_bids int)

insert into #laneBidCountCombined
select lbc.lane_id
		,lbc.LANE_BID_COUNT
from #lb lbc
group by lane_id,lbc.LANE_BID_COUNT

SELECT		@totalLaneCount = COUNT(*)
FROM		eTblLanes()

insert into #bidCount(num_bids, num_lanes)
select '0 Bid', (@totalLaneCount - COUNT(*)) as num_lanes from #laneBidCountCombined --where num_bids = 0


insert into #bidCount(num_bids, num_lanes)
select '1 Bid', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids = 1

insert into #bidCount(num_bids, num_lanes)
select '2 Bids', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids = 2

insert into #bidCount(num_bids, num_lanes)
select '3 Bids', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids = 3

insert into #bidCount(num_bids, num_lanes)
select '4 Bids', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids = 4

insert into #bidCount(num_bids, num_lanes)
select '5 Bids', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids = 5

insert into #bidCount(num_bids, num_lanes)
select '6 to 10', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids >=6 and num_bids <= 10
insert into #bidCount(num_bids, num_lanes)
select '11 to 15', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids >=11 and num_bids <= 15
insert into #bidCount(num_bids, num_lanes)
select '16 to 20', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids >=16 and num_bids <= 20
insert into #bidCount(num_bids, num_lanes)
select '21 to 25', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids >=21 and num_bids <= 25
insert into #bidCount(num_bids, num_lanes)
select '26 to 30', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids >=26 and num_bids <= 30
insert into #bidCount(num_bids, num_lanes)
select '31 to 35', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids >=31 and num_bids <= 35
insert into #bidCount(num_bids, num_lanes)
select '36 to 40', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids >=36 and num_bids <= 40
insert into #bidCount(num_bids, num_lanes)
select '41 to 45', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids >=41 and num_bids <= 45
insert into #bidCount(num_bids, num_lanes)
select '46 to 50', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids >=46 and num_bids <= 50
insert into #bidCount(num_bids, num_lanes)
select '50+', COUNT(*) as num_lanes from #laneBidCountCombined where num_bids >=51


select bc.num_bids AS BID_COUNT_RANGE
		,bc.num_lanes AS LANE_COUNT
from #bidCount bc

drop table #lb
drop table #laneBidCountCombined
drop table #bidCount
*/
	
	
END
