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
	InterventionID,	
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
			CL.ict_clientidid,
			CASE WHEN (substring(CL.ict_clientidid, 0,9) = 'ICT-CLT-') THEN '12304560' ELSE '' END + substring(CL.ict_clientidid, 9,6) AS ClientID
			, CASE WHEN (substring(SP.ict_name, 0,9) = 'ICT-CSP-') THEN '12309870' ELSE '' END + substring(SP.ict_name, 9,6) AS ActionPlanID	
			, CASE WHEN (substring(SP.ict_name, 0,9) = 'ICT-CSP-') THEN '12309870' ELSE '' END + substring(SP.ict_name, 9,6) AS InterventionID		
			, SP.ict_name  AS ProgramSessionID
			, CASE 
				WHEN CO.pcm_contracttypeidname = CO.ict_subprogramtypename
				THEN CO.pcm_contracttypeidname
				ELSE CO.pcm_contracttypeidname + ' - ' + CO.ict_subprogramtypename
			END AS InterventionTitle
			, CO.ict_municipalityname AS InterventionLocation
			, cast(year(SP.ict_startdate)as varchar(4)) +'-'+ case when (month(SP.ict_startdate) < 10) then '0'+ cast(month(SP.ict_startdate) as varchar(1)) else cast(month(SP.ict_startdate) as varchar(2)) end +'-'+ case when (day(SP.ict_startdate) < 10) then '0'+ cast(day(SP.ict_startdate) as varchar(1)) else cast(day(SP.ict_startdate) as varchar(2)) end AS InterventionStartDate
			, CASE 
				WHEN (SP.ict_closuredate is null) OR (SP.ict_startdate > SP.ict_closuredate) OR (SP.ict_closuredate >= @p_Start_EndDate) OR (not(SP.ict_serviceplanstatus in (802500002,802500001,802500003)))
				THEN null
				ELSE cast(year(SP.ict_closuredate)as varchar(4)) +'-'+ case when (month(SP.ict_closuredate) < 10) then '0'+ cast(month(SP.ict_closuredate) as varchar(1)) else cast(month(SP.ict_closuredate) as varchar(2)) end +'-'+ case when (day(SP.ict_closuredate) < 10) then '0'+ cast(day(SP.ict_closuredate) as varchar(1)) else cast(day(SP.ict_closuredate) as varchar(2)) end
			 END AS InterventionEndDate			
			, null AS EnrollmentStatus	
			, CASE
				WHEN (SP.ict_closuredate is null) OR (SP.ict_startdate > SP.ict_closuredate) OR (SP.ict_closuredate >= @p_Start_EndDate)
				THEN ''
				WHEN SP.ict_serviceplanstatus = 802500002 /*802500002-Incomplete*/
				THEN '3' /*3-Incomplete*/
				WHEN SP.ict_serviceplanstatus = 802500001 /*802500001- Completed*/
				THEN '1' /*1-Complete*/
				WHEN SP.ict_serviceplanstatus = 802500003 /*802500003-Carryover*/ 
				THEN '6' /*6-Rescheduled*/
				ELSE null
			 END AS InterventionOutcome
			, null AS InterventionOutcomeDetail
			, null AS InterventionRelatedNOC
			, null AS NOCVersion
			, 2 AS InterventionLanguageOfService
			, CASE 
				WHEN (CO.pcm_contracttypeidname = 'Newcomer Settlement' and CO.ict_subprogramtypename in ('Conversation Circles', 'English for Employment','Language Programs','Stage 1 and 2 English') AND SP.ict_serviceplanstatus = 802500001 )
				THEN '1'
				WHEN (CO.pcm_contracttypeidname = 'Newcomer Settlement' and CO.ict_subprogramtypename in ('Conversation Circles', 'English for Employment','Language Programs','Stage 1 and 2 English') AND SP.ict_serviceplanstatus in (802500000,802500002,802500003))
				THEN '2'
				ELSE null
			END AS InterventionEssentialSkills
			, 8 AS InterventionCredential
			, CASE 
				WHEN CO.pcm_contractnum in ('CSA-25-00003659', 'CSA-25-00003660')
				THEN '215'
				WHEN CO.pcm_contractnum in ('CSA-25-00003502')
				THEN '114'
				WHEN CO.pcm_accountname in ('Saskatoon Trades and Skills Centre Inc.', 'Regina Trades and Skills Centre Inc.') 
				THEN '215'				
				WHEN (CO.pcm_contracttypeidname = 'Workforce Development' and CO.ict_subprogramtypename = 'Tariff Support')
				THEN '221'
				WHEN ((CO.pcm_contracttypeidname = 'Employability Assistance for Persons with Disabilities' and CO.ict_subprogramtypename = 'Employability Assistance for Persons with Disabilities' ) or (CO.pcm_contracttypeidname = 'Newcomer Settlement' and CO.ict_subprogramtypename = 'Newcomer Employability Supports') or(CO.pcm_contracttypeidname = 'Workforce Development' and CO.ict_subprogramtypename in ('CES ECB', 'CES TIOW')))
				THEN '111'			
				WHEN CO.pcm_contracttypeidname = 'Newcomer Settlement' and CO.ict_subprogramtypename in ('Conversation Circles', 'English for Employment','Language Programs','Stage 1 and 2 English')
				THEN '213'					
				WHEN ((CO.pcm_contracttypeidname = 'Newcomer Settlement' and CO.ict_subprogramtypename in ('FQR Federal Projects','FQR Provincial Projects')) or (CO.pcm_contracttypeidname = 'Workforce Development' and CO.ict_subprogramtypename = 'CES TVP'))
				THEN '114' 			
				WHEN ((CO.pcm_contracttypeidname = 'Newcomer Settlement' and CO.ict_subprogramtypename in ('Gateway and Settlement Supports', 'Settlement Advisor')) or (CO.pcm_contracttypeidname = 'Workforce Development' and CO.ict_subprogramtypename = 'Career and Employment Services'))
				THEN '112'
				WHEN (CO.pcm_contracttypeidname = 'Workforce Development' and CO.ict_subprogramtypename = 'RPEP')
				THEN '222'
				WHEN (CO.pcm_contracttypeidname = 'Workforce Development' and CO.ict_subprogramtypename = 'Self-Employment')
				THEN '223'
				WHEN ((CO.pcm_contracttypeidname = 'Workforce Development' and CO.ict_subprogramtypename = 'CES CRG') OR (CO.pcm_contracttypeidname = 'Newcomer Settlement' and CO.ict_subprogramtypename = 'Credential Recognition Grant'))
				THEN '112'
				ELSE null
			END AS InterventionCode
			, CASE 
				WHEN CO.pcm_contracttypeidname = CO.ict_subprogramtypename
				THEN CO.pcm_contracttypeidname
				ELSE CO.pcm_contracttypeidname + ' - ' + CO.ict_subprogramtypename
			END AS Intervention_Program_Category
			, CO.pcm_accountname AS Intervention_Service_Provider
			, CO.pcm_contractnum + ' - ' + CO.pcm_name AS Intervention_Program_Name  
		FROM
			ict_client CL
			INNER JOIN pcm_contract CO ON CL.ict_contract = CO.pcm_contractid
			INNER JOIN ict_serviceplan SP ON CO.pcm_contractid = SP.ict_contractid AND SP.ict_client = CL.ict_clientid
		WHERE
			CL.ict_clientidid is not null 
			AND (((SP.modifiedon >= @p_End_StartDate AND SP.modifiedon <= @p_Start_EndDate)
							OR (SP.ict_startdate >= @p_Start_StartDate AND SP.ict_startdate <= @p_Start_EndDate)
							OR (SP.ict_closuredate >= @p_End_StartDate AND SP.ict_closuredate <= @p_Start_EndDate)
						) 
			AND SP.ict_startdate <= @p_Start_EndDate)
			AND SP.ict_serviceplanstatus is not null
			
	)
) DATA_REPORT