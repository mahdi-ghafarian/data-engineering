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
		ClientID,
		ActionPlanID,
		SocialInsuranceNumber,
		EducationLevel,
		EducationLevelComment,
		ManagingOffice,
		ActionPlanPreviousEmployment,
		ActionPlanPrecariousEmployment,
		ActionPlanStartDate,
		ActionPlanEndDate,
		ActionPlanResult,
		ActionPlanResultDate
	FROM
	(
		(
			SELECT DISTINCT
				CASE WHEN (substring(C.ict_clientid, 0,9) = 'ICT-CLT-') THEN '12304560' ELSE '' END + substring(C.ict_clientid, 9,6) AS ClientID
				, CASE WHEN (substring(AP.ict_name, 0,9) = 'ICT-ACP-') THEN '12307890' ELSE '' END + substring(AP.ict_name, 9,6) AS ActionPlanID
				, C.ict_sin AS SocialInsuranceNumber
				, CASE 
					WHEN C.educationcode in (802500000, 802500001)/*802500000-High school diploma, 802500001-High school equivalent*/
					THEN 5 /*Secondary school diploma or GED*/
					WHEN C.educationcode in (802500002)/*802500002-Some post-secondary training*/
					THEN 6 /*Some post-secondary training*/
					WHEN C.educationcode in (802500003, 802500006)/*802500003-College or other non-university certificate or diploma, 802500006-Apprenticeship*/
					THEN 8 /*College, CEGEP, or other non-university certificate or diploma*/
					WHEN C.educationcode in (802500004)/*802500004-University certificate or diploma*/
					THEN 9 /*University certificate or diploma*/
					WHEN C.educationcode in (1)/*1-Less than high school*/
					THEN 13 /*Less than high school*/
					WHEN C.educationcode in (802500005)/*802500005-University Degree*/
					THEN 14 /*University degree*/
					WHEN C.educationcode in (802500007)/*802500007-Other*/
					THEN 15 /*Other*/
					WHEN C.educationcode in (802500008)/*802500008-I choose not to respond*/
					THEN 99 /*Prefer not to report*/
					ELSE 98 /*Unknown*/		
				END AS EducationLevel
				, CASE
					WHEN C.educationcode in (802500007) and C.ict_educationotherspecify is not null
					THEN LEFT(C.ict_educationotherspecify, 150)
					WHEN C.educationcode in (802500007) and C.ict_educationotherspecify is null
					THEN 'Unspecified'
					ELSE null
				END AS EducationLevelComment
				,99 AS ManagingOffice
				, CASE
					WHEN C.ict_employmentstatus = 802500000/*802500000-Unemployed*/
					THEN 1 /*Unemployed*/
					WHEN C.ict_employmentstatus = 802500001/*802500001-Employed*/
					THEN 2 /*Employed*/
					WHEN C.ict_employmentstatus = 802500002/*802500002-Self employed*/
					THEN 3 /*3-Self-employed*/
					WHEN C.ict_employmentstatus = 802500003/*802500003-Not in the labour force*/
					THEN 6 /*6-Not in labour force*/
					ELSE 10 /*Unknown*/
				END AS ActionPlanPreviousEmployment
				,null AS ActionPlanPrecariousEmployment
				, cast(year(AP.ict_actionplanstartdate)as varchar(4)) +'-'+ case when (month(AP.ict_actionplanstartdate) < 10) then '0'+ cast(month(AP.ict_actionplanstartdate) as varchar(1)) else cast(month(AP.ict_actionplanstartdate) as varchar(2)) end +'-'+ case when (day(AP.ict_actionplanstartdate) < 10) then '0'+ cast(day(AP.ict_actionplanstartdate) as varchar(1)) else cast(day(AP.ict_actionplanstartdate) as varchar(2)) end AS ActionPlanStartDate	
				, CASE 
					WHEN (AP.ict_closuredate is null) OR (AP.ict_actionplanstartdate > AP.ict_closuredate) OR (AP.ict_closuredate >= @p_Start_EndDate) OR (not(AP.ict_actionplanstatus in (802500002,802500001)))
					THEN null
					ELSE cast(year(AP.ict_closuredate)as varchar(4)) +'-'+ case when (month(AP.ict_closuredate) < 10) then '0'+ cast(month(AP.ict_closuredate) as varchar(1)) else cast(month(AP.ict_closuredate) as varchar(2)) end +'-'+ case when (day(AP.ict_closuredate) < 10) then '0'+ cast(day(AP.ict_closuredate) as varchar(1)) else cast(day(AP.ict_closuredate) as varchar(2)) end
				END AS ActionPlanEndDate		 			
				, CASE 
					WHEN (AP.ict_closuredate is null) OR (AP.ict_actionplanstartdate > AP.ict_closuredate) OR (AP.ict_closuredate >= @p_Start_EndDate) OR (not(AP.ict_actionplanstatus in (802500002,802500001)))
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
							WHEN AP.ict_closurereason in (802500009)/*802500009-Job ready*/
							THEN '1'/*1-Unemployed but available for work*/
							WHEN AP.ict_closurereason in (802500000, 802500001)/*802500000-Returning to seasonal job, 802500001-Employed*/
							THEN '2'/*2-Employed*/
							WHEN AP.ict_closurereason in (802500012)/*802500012-Starting a new business*/
							THEN '3' /*3-Self-employed*/
							WHEN AP.ict_closurereason in (802500002, 802500003, 802500014)/*802500002-Enrolled in school, 802500003-Enrolled in alternative employment program, 802500014-Training for new business*/
							THEN '4' /*4-Returned to School*/
							WHEN AP.ict_closurereason in (802500006, 802500007, 802500011, 802500015, 802500016)/*802500006-, 802500007-Moving out of province, 802500011-Unable to contact, 802500015-Other, 802500016-Unknown*/
							THEN '5' /*5-Unspecified – participant could not be reached*/
							WHEN AP.ict_closurereason in (802500004, 802500005, 802500008, 802500010, 802500013)/*802500004-Family responsibilities, 802500005-Health reasons, 802500008-No access to services, 802500010-Personal reasons, 802500013-Disengaged*/
							THEN '6' /*6-Not in labour force*/
							ELSE null
						END
				END AS ActionPlanResult		
				, CASE 
					WHEN (AP.ict_closuredate is null) OR (AP.ict_actionplanstartdate > AP.ict_closuredate) OR (AP.ict_closuredate >= @p_Start_EndDate) OR (not(AP.ict_actionplanstatus in (802500002,802500001))) OR (AP.ict_closurereason is null)
					THEN null
					ELSE cast(year(AP.ict_closuredate)as varchar(4)) +'-'+ case when (month(AP.ict_closuredate) < 10) then '0'+ cast(month(AP.ict_closuredate) as varchar(1)) else cast(month(AP.ict_closuredate) as varchar(2)) end +'-'+ case when (day(AP.ict_closuredate) < 10) then '0'+ cast(day(AP.ict_closuredate) as varchar(1)) else cast(day(AP.ict_closuredate) as varchar(2)) end
				END  AS ActionPlanResultDate  		
			FROM
				contact C
				INNER JOIN ict_actionplan AP ON C.contactid = AP.ict_client						
				LEFT OUTER JOIN (			
					SELECT
						MAX(msfp_submitdate) as msfp_submitdate, 
						regardingobjectid
					FROM
						msfp_surveyresponse                    
					GROUP BY 
						regardingobjectid
					)SR ON AP.ict_actionplanid = SR.regardingobjectid 
				LEFT OUTER JOIN msfp_surveyresponse SUR ON SR.regardingobjectid = SUR.regardingobjectid AND SR.msfp_submitdate = SUR.msfp_submitdate
				LEFT OUTER JOIN msfp_questionresponse QR ON SUR.activityid = QR.msfp_surveyresponseid 			          
			WHERE
				C.ict_sin is not null AND C.ict_sin <> '000000000' AND C.ict_clientid is not null  AND AP.ict_actionplanstartdate is not null AND C.statecode = 0
				AND (((AP.modifiedon >= @p_End_StartDate AND AP.modifiedon <= @p_Start_EndDate)
					OR (AP.ict_actionplanstartdate >= @p_Start_StartDate AND AP.ict_actionplanstartdate <= @p_Start_EndDate)
					OR (AP.ict_closuredate >= @p_End_StartDate AND AP.ict_closuredate <= @p_Start_EndDate)
				)
				AND AP.ict_actionplanstartdate <= @p_Start_EndDate)
				AND AP.ict_actionplanstatus is not null
		)
	)DATA_REPORT