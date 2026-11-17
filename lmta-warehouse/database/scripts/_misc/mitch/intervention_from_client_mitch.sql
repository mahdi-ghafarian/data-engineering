SELECT
    /* KEYS */
    C.ict_clientid                          AS clientID,
    AP.ict_actionplanid                     AS ActionPlanGUID,
    AP.ict_name                             AS actionPlanID,
 
    /* LMTA INTERVENTION */
    AP.ict_name                             AS interventionID,
    CAST('Career Counselling' AS varchar(100)) AS interventionTitle,
    112                                     AS interventionCode,        -- Counselling / Case Management
    AP.ict_actionplanstartdate              AS interventionStartDate,
 
    CASE WHEN AP.ict_closuredate IS NULL
           OR AP.ict_actionplanstartdate > AP.ict_closuredate
           OR AP.ict_actionplanstatus NOT IN (802500002, 802500001)
         THEN NULL ELSE AP.ict_closuredate END AS interventionEndDate,
 
    /* Outcome: 1 Complete, 3 Incomplete, 4 Failed to report, 5 Cancelled, 6 Rescheduled
       Required when the intervention is closed (end date present) */
    CASE
      WHEN AP.ict_closuredate IS NULL
        OR AP.ict_actionplanstartdate > AP.ict_closuredate
        OR AP.ict_actionplanstatus NOT IN (802500002, 802500001) THEN NULL
      WHEN AP.ict_actionplanstatusname = 'Complete'   THEN 1
      WHEN AP.ict_actionplanstatusname = 'Incomplete' THEN 3
    END                                     AS interventionOutcome,
 
    /* Not required for code 112, so left out of the output:
       interventionRelatedNOC / Version (required only for 211, or tariff-funded 212/214/215/221-224/311)
       interventionEssentialSkills (required only for code 213) */
 
    CAST(NULL AS int)                       AS interventionLanguageOfService,  -- MANDATORY: 2 English, 3 French, 9 Not official; source column needed
 
    /* Credential: required when an end date is provided; 8 = Not Applicable */
    CASE
      WHEN AP.ict_closuredate IS NULL
        OR AP.ict_actionplanstartdate > AP.ict_closuredate
        OR AP.ict_actionplanstatus NOT IN (802500002, 802500001) THEN NULL
      ELSE 8
    END                                     AS interventionCredential,
 
    /* Source values kept for validation */
    AP.ict_actionplanstatus, AP.ict_actionplanstatusname,
    AP.ict_closurereason,    AP.ict_closurereasonname
 
FROM dbo.ict_actionplan AP
JOIN dbo.contact C ON C.contactid = AP.ict_client
WHERE C.ict_sin IS NOT NULL
  AND C.ict_sin <> '000000000'
  AND C.ict_clientid IS NOT NULL;