	DECLARE @PERIOD AS VARCHAR(3)       = 'P3'      --can be P3, P6, P9, P12
	DECLARE @FISCALYEAR AS VARCHAR(9)   = '2026-2027' --Example: 2021-2022

	DECLARE @p_Start_StartDate AS VARCHAR(23) = cast(cast(cast(substring(@FISCALYEAR,1,4)AS INT)-1 AS Varchar(4)) + '-04-01 00:00:00.001' AS DATETIME)
	DECLARE @p_Start_EndDate AS VARCHAR(23) = 
							CASE 
								WHEN @PERIOD = 'P3'  THEN cast((substring(@FISCALYEAR,1,4) + '-06-30 23:59:59') AS DATETIME)
								WHEN @PERIOD = 'P6'  THEN cast((substring(@FISCALYEAR,1,4) + '-09-30 23:59:59') AS DATETIME)
								WHEN @PERIOD = 'P9'  THEN cast((substring(@FISCALYEAR,1,4) + '-12-31 23:59:59') AS DATETIME)
								WHEN @PERIOD = 'P12' THEN cast((substring(@FISCALYEAR,6,4) + '-03-31 23:59:59') AS DATETIME)
								WHEN @PERIOD = 'P14' THEN cast((substring(@FISCALYEAR,6,4) + '-03-31 23:59:59') AS DATETIME)
								ELSE null
							END
							
	DECLARE @p_End_StartDate AS VARCHAR(23) = 
							CASE 
								WHEN @PERIOD = 'P3'  THEN cast((substring(@FISCALYEAR,1,4) + '-04-01 00:00:00.001') AS DATETIME)
								WHEN @PERIOD = 'P6'  THEN cast((substring(@FISCALYEAR,1,4) + '-07-01 00:00:00.001') AS DATETIME)
								WHEN @PERIOD = 'P9'  THEN cast((substring(@FISCALYEAR,1,4) + '-10-01 00:00:00.001') AS DATETIME)
								WHEN @PERIOD = 'P12' THEN cast((substring(@FISCALYEAR,6,4) + '-01-01 00:00:00.001') AS DATETIME)
								WHEN @PERIOD = 'P14' THEN cast((substring(@FISCALYEAR,1,4) + '-04-01 00:00:00.001') AS DATETIME)
								ELSE null
							END

	SELECT DISTINCT
		ict_clientidid,
		ClientID,
		ActionPlanID,	
		ManagingOffice,	
		ActionPlanPrecariousEmployment,
		ActionPlanStartDate,
		ActionPlanEndDate,
		ActionPlanResult,
		ActionPlanResultDate,
		ict_summary
	FROM
	(	
		(
			SELECT DISTINCT            
				CL.ict_clientidid
				, CASE WHEN (substring(CL.ict_clientidid, 0,9) = 'ICT-CLT-') THEN '12304560' ELSE '' END + substring(CL.ict_clientidid, 9,6) AS ClientID	
				, CASE WHEN (substring(SP.ict_name, 0,9) = 'ICT-CSP-') THEN '12309870' ELSE '' END + substring(SP.ict_name, 9,6) AS ActionPlanID			
				,99 AS ManagingOffice			
				,null AS ActionPlanPrecariousEmployment
				, cast(year(SP.ict_startdate)as varchar(4)) +'-'+ case when (month(SP.ict_startdate) < 10) then '0'+ cast(month(SP.ict_startdate) as varchar(1)) else cast(month(SP.ict_startdate) as varchar(2)) end +'-'+ case when (day(SP.ict_startdate) < 10) then '0'+ cast(day(SP.ict_startdate) as varchar(1)) else cast(day(SP.ict_startdate) as varchar(2)) end AS ActionPlanStartDate	
				, CASE 
					WHEN (SP.ict_closuredate is null) OR (SP.ict_startdate > SP.ict_closuredate) OR (SP.ict_closuredate >= @p_Start_EndDate) OR (not(SP.ict_serviceplanstatus in (802500002,802500001,802500003)))
					THEN null
					ELSE cast(year(SP.ict_closuredate)as varchar(4)) +'-'+ case when (month(SP.ict_closuredate) < 10) then '0'+ cast(month(SP.ict_closuredate) as varchar(1)) else cast(month(SP.ict_closuredate) as varchar(2)) end +'-'+ case when (day(SP.ict_closuredate) < 10) then '0'+ cast(day(SP.ict_closuredate) as varchar(1)) else cast(day(SP.ict_closuredate) as varchar(2)) end
				END AS ActionPlanEndDate			
				, CASE 
					WHEN (SP.ict_closuredate is null) OR (SP.ict_startdate > SP.ict_closuredate) OR (SP.ict_closuredate >= @p_Start_EndDate) OR (not(SP.ict_serviceplanstatus in (802500002,802500001,802500003)))
					THEN null
					WHEN QR.msfp_response = 'Unemployed but available for work'
					THEN '1'/*1-Unemployed but available for work*/ 
					WHEN (QR.msfp_response in ('Employed - Full Time', 'Employed - Part Time', 'Returned to seasonal job'))
					THEN '2'/*2-Employed*/
					WHEN (QR.msfp_response in ('Self-Employed', 'Started a new business'))
					THEN '3' /*3-Self-employed*/
					WHEN (QR.msfp_response in ('Started a new employment training program or service', 'Training for new business', 'Enrolled in alternative employment program', 'Enrolled in school'))
					THEN '4' /*4-Returned to School*/				
					WHEN QR.msfp_response = 'Not in labour force'
					THEN '6' /*6-Not in labour force*/
					ELSE 
						CASE 
							WHEN SP.ict_closurereason in (802500009) /*802500009-Job ready*/
							THEN '1'/*1-Unemployed but available for work*/
							WHEN SP.ict_closurereason in (802500000, 802500001)/*802500000-Returning to seasonal job, 802500001-Employed*/
							THEN '2'/*2-Employed*/
							WHEN SP.ict_closurereason in (802500012)/*802500012-Starting a new business*/
							THEN '3' /*3-Self-employed*/
							WHEN SP.ict_closurereason in (802500002, 802500003, 802500014)/*802500002-Enrolled in school, 802500003-Enrolled in alternative employment program, 802500014-Training for new business*/
							THEN '4' /*4-Returned to School*/
							WHEN SP.ict_closurereason in (802500006, 802500007, 802500011, 802500015, 802500016)/*802500006-Moving out of catchment area, 802500007-Moving out of province, 802500011-Unable to contact, 802500015-Other, 802500016-Unknown*/
							THEN '5' /*5-Unspecified – participant could not be reached*/
							WHEN SP.ict_closurereason in (802500004, 802500005, 802500008, 802500010, 802500013)/*802500004-Family responsibilities, 802500005-Health reasons, 802500008-No access to services, 802500010-Personal reasons, 802500013-Disengaged*/
							THEN '6' /*6-Not in labour force*/
							ELSE null
						END
				END AS ActionPlanResult
				, CASE 
					WHEN (SP.ict_closuredate is null) OR (SP.ict_startdate > SP.ict_closuredate) OR (SP.ict_closuredate >= @p_Start_EndDate) OR (not(SP.ict_serviceplanstatus in (802500002,802500001,802500003))) OR (SP.ict_closurereason is null)
					THEN null
					ELSE cast(year(SP.ict_closuredate)as varchar(4)) +'-'+ case when (month(SP.ict_closuredate) < 10) then '0'+ cast(month(SP.ict_closuredate) as varchar(1)) else cast(month(SP.ict_closuredate) as varchar(2)) end +'-'+ case when (day(SP.ict_closuredate) < 10) then '0'+ cast(day(SP.ict_closuredate) as varchar(1)) else cast(day(SP.ict_closuredate) as varchar(2)) end
				END  AS ActionPlanResultDate,
				SP.ict_summary            
			FROM
				ict_client CL 
				INNER JOIN pcm_contract CO ON CL.ict_contract = CO.pcm_contractid
				INNER JOIN ict_serviceplan SP ON CO.pcm_contractid = SP.ict_contractid AND SP.ict_client = CL.ict_clientid			
				LEFT OUTER JOIN (			
					SELECT
						MAX(msfp_submitdate) as msfp_submitdate, 
						regardingobjectid
					FROM
						msfp_surveyresponse                    
					GROUP BY 
						regardingobjectid
					)SR ON SP.ict_serviceplanid = SR.regardingobjectid 
				LEFT OUTER JOIN msfp_surveyresponse SUR ON SR.regardingobjectid = SUR.regardingobjectid AND SR.msfp_submitdate = SUR.msfp_submitdate
				LEFT OUTER JOIN msfp_questionresponse QR ON SUR.activityid = QR.msfp_surveyresponseid				
			WHERE
				CL.ict_clientidid is not null 
				AND (((SP.modifiedon >= @p_End_StartDate AND SP.modifiedon <= @p_Start_EndDate)
								OR (SP.ict_startdate >= @p_Start_StartDate AND SP.ict_startdate <= @p_Start_EndDate)
								OR (SP.ict_closuredate >= @p_End_StartDate AND SP.ict_closuredate <= @p_Start_EndDate)
							) 
				AND SP.ict_startdate <= @p_Start_EndDate)
				AND SP.ict_serviceplanstatus is not null
		)
	)DATA_REPORT