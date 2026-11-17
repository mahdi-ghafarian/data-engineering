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
	InterventionID,
	SocialInsuranceNumber,
	ProgramSessionID,
	InterventionTitle,
	InterventionLocation,
	InterventionStartDate,
	InterventionEndDate,
	EnrollmentStatus,
	InterventionOutcome,
	InterventionOutcomeDetail,
	InterventionRelatedNOC,
	NOCVersion,
	InterventionLanguageOfService,
	InterventionEssentialSkills,
	InterventionCredential,
	InterventionCode,
	Intervention_Program_Category,
	Intervention_Service_Provider,
	Intervention_Program_Name
FROM
(
	(
		SELECT DISTINCT
			  CASE WHEN (substring(C.ict_clientid,0,9) = 'ICT-CLT-') THEN '12304560' ELSE '' END + substring(C.ict_clientid,9,6) AS ClientID		
			, CASE WHEN  (substring(AP.ict_name, 0, 9) = 'ICT-ACP-') THEN '12307890' ELSE '' END +  substring(AP.ict_name, 9, 6) AS ActionPlanID
			, CASE WHEN  (substring(AP.ict_name, 0, 9) = 'ICT-ACP-') THEN '12307890' ELSE '' END +  substring(AP.ict_name, 9, 6) AS InterventionID
			, C.ict_sin AS SocialInsuranceNumber
			, AP.ict_name AS ProgramSessionID
			, 'Job Search and Career Planning' AS InterventionTitle
			--externalOfficeCode
			, null AS InterventionLocation
			, cast(year(AP.ict_actionplanstartdate)as varchar(4)) +'-'+ case when (month(AP.ict_actionplanstartdate) < 10) then '0'+ cast(month(AP.ict_actionplanstartdate) as varchar(1)) else cast(month(AP.ict_actionplanstartdate) as varchar(2)) end +'-'+ case when (day(AP.ict_actionplanstartdate) < 10) then '0'+ cast(day(AP.ict_actionplanstartdate) as varchar(1)) else cast(day(AP.ict_actionplanstartdate) as varchar(2)) end AS InterventionStartDate
			, CASE 
                WHEN (AP.ict_closuredate is null) OR (AP.ict_actionplanstartdate > AP.ict_closuredate) OR (AP.ict_closuredate >= @p_Start_EndDate) OR (not(AP.ict_actionplanstatus in (802500002,802500001)))
                THEN null
                ELSE cast(year(AP.ict_closuredate)as varchar(4)) +'-'+ case when (month(AP.ict_closuredate) < 10) then '0'+ cast(month(AP.ict_closuredate) as varchar(1)) else cast(month(AP.ict_closuredate) as varchar(2)) end +'-'+ case when (day(AP.ict_closuredate) < 10) then '0'+ cast(day(AP.ict_closuredate) as varchar(1)) else cast(day(AP.ict_closuredate) as varchar(2)) end
             END AS InterventionEndDate	
			, null AS EnrollmentStatus			
			, CASE
				WHEN (AP.ict_closuredate is null) OR (AP.ict_actionplanstartdate > AP.ict_closuredate) OR (AP.ict_closuredate >= @p_Start_EndDate) 
				THEN null
				WHEN AP.ict_actionplanstatus = 802500002 /*802500002 - Completed*/
				THEN '1' /*1 - Complete*/
				WHEN AP.ict_actionplanstatus = 802500001 /*802500001 - Incomplete*/
				THEN '3' /*3 - Incomplete*/     
				ELSE null /*802500000 - In Progress, 802500003 - Pending Follow-up*/
			 END AS InterventionOutcome
			, null AS InterventionOutcomeDetail
			, null AS InterventionRelatedNOC
			, null AS NOCVersion
			, 2 AS InterventionLanguageOfService
			, null AS InterventionEssentialSkills /*Always NULL for Client Data*/
			, 8 AS InterventionCredential
			, 112 AS InterventionCode
			, 'Career and Employment Services' AS Intervention_Program_Category
			, 'ICT Career Services' AS Intervention_Service_Provider
			, 'Job Search and Career Planning' AS Intervention_Program_Name
		FROM
			contact C
			INNER JOIN ict_actionplan AP ON C.contactid = AP.ict_client
		WHERE
			C.ict_sin is not null AND C.ict_sin <> '000000000' AND C.ict_clientid is not null  AND AP.ict_actionplanstartdate is not null AND C.statecode = 0
			AND (((AP.modifiedon >= @p_End_StartDate AND AP.modifiedon <= @p_Start_EndDate)
				OR (AP.ict_actionplanstartdate >= @p_Start_StartDate AND AP.ict_actionplanstartdate <= @p_Start_EndDate)
				OR (AP.ict_closuredate >= @p_End_StartDate AND AP.ict_closuredate <= @p_Start_EndDate)
			)
			AND AP.ict_actionplanstartdate <= @p_Start_EndDate)
			AND AP.ict_actionplanstatus is not null
	)
) DATA_REPORT
