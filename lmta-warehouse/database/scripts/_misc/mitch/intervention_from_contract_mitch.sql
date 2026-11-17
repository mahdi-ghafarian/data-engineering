SELECT
    cc.ict_clientidid                       AS clientID,
    cc.ict_clientcontactid                  AS ClientContactGUID,
    sp.ict_serviceplanid                    AS ServicePlanGUID,
    ct.pcm_contractnumber                   AS ContractNumber,
 
    /* <intervention> */
    sp.ict_name                             AS interventionID,
    COALESCE(NULLIF(LTRIM(RTRIM(ct.ict_projectname)), ''), sub.ict_name) AS interventionTitle,
 
    CASE
      WHEN sub.ict_name IN ('Career and Employment Services',
                            'Gateway and Settlement Supports',
                            'Settlement Advisor',
                            'Newcomer Employability Supports',
                            'Employability Assistance for Persons with Disabilities') THEN 112
      WHEN sub.ict_name IN ('Language Programs',
                            'Stage 1 and 2 English',
                            'English for Employment',
                            'Conversation Circles')                                   THEN 213
      WHEN sub.ict_name = 'Self-Employment'                                            THEN 223
      WHEN sub.ict_name = 'Northern Skills Training'                                   THEN 211
      WHEN sub.ict_name IN ('Credential Recognition Grant', 'CES CRG')                 THEN 311
      ELSE NULL    -- CES ECB / TIOW / TVP, FQR Provincial/Federal Projects, RPEP, Tariff Support: not mapped yet
    END                                     AS interventionCode,
 
    CONVERT(char(10), sp.ict_startdate, 23) AS interventionStartDate,
 
    CASE WHEN sp.ict_serviceplanstatusname IN ('Complete', 'Incomplete')
          AND sp.ict_closuredate IS NOT NULL
          AND sp.ict_startdate <= sp.ict_closuredate
         THEN CONVERT(char(10), sp.ict_closuredate, 23)
    END                                     AS interventionEndDate,
 
    CASE
      WHEN sp.ict_serviceplanstatusname NOT IN ('Complete', 'Incomplete')
        OR sp.ict_serviceplanstatusname IS NULL
        OR sp.ict_closuredate IS NULL
        OR sp.ict_startdate > sp.ict_closuredate                       THEN NULL
      WHEN sp.ict_serviceplanstatusname = 'Complete'                   THEN 1   -- Complete
      WHEN sp.ict_closurereasonname = 'Unable to contact'              THEN 4   -- Failed to report
      ELSE 3                                                                    -- Incomplete
    END                                     AS interventionOutcome,
 
    CAST(NULL AS int)                       AS interventionRelatedNOC,
    CAST(NULL AS int)                       AS interventionRelatedNOCVersion,
    CAST(NULL AS int)                       AS interventionLanguageOfService,
    CAST(NULL AS int)                       AS interventionEssentialSkills,
    CAST(NULL AS int)                       AS interventionCredential,
 
    /* validation columns (drop before export) */
    sub.ict_name                            AS _SubProgramType,
    sp.ict_serviceplanstatusname            AS _PlanStatus,
    sp.ict_closurereasonname                AS _ClosureReason
 
FROM ict_serviceplan AS sp
JOIN ict_client      AS cc  ON cc.ict_clientid   = sp.ict_client
JOIN pcm_contract    AS ct  ON ct.pcm_contractid = sp.ict_contractid
LEFT JOIN ict_subprogram AS sub ON sub.ict_subprogramid = ct.ict_subprogramtype
WHERE cc.ict_clientidid IS NOT NULL;