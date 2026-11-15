--------------------------------------------------------------------------------
/*
    This query returns the list of clients along with their associated action plans.
*/
--------------------------------------------------------------------------------
-- SELECT
--     c.ict_clientid AS client_id,
--     c.firstname,
--     c.lastname,

--     ap.ict_name AS action_plan_id,
--     ap.ict_goalstatement,

--     ap.ict_actionplanstatus AS action_plan_status_code,
--     aps.CHOICE_NAME AS action_plan_status,

--     ap.ict_actionplanstartdate,
--     ap.ict_closuredate,

--     ap.ict_closurereason AS closure_reason_code,
--     cr.CHOICE_NAME AS closure_reason

-- FROM stg.prism_clt_contact AS c

-- LEFT JOIN stg.prism_clt_ict_actionplan AS ap
--     ON c.contactid = ap.ict_client

-- LEFT JOIN stg.prism_choice AS aps
--     ON aps.MODULE_NAME = 'client'
--    AND aps.TABLE_NAME = 'ict_actionplan'
--    AND aps.COLUMN_NAME = 'ict_actionplanstatus'
--    AND aps.CHOICE_VALUE = ap.ict_actionplanstatus

-- LEFT JOIN stg.prism_choice AS cr
--     ON cr.MODULE_NAME = 'client'
--    AND cr.TABLE_NAME = 'ict_actionplan'
--    AND cr.COLUMN_NAME = 'ict_closurereason'
--    AND cr.CHOICE_VALUE = ap.ict_closurereason

-- WHERE c.ict_clientid IS NOT NULL

-- ORDER BY
--     c.ict_clientid,
--     ap.ict_name;

--------------------------------------------------------------------------------
/*
    This query returns the count of action plans for each client.
*/
--------------------------------------------------------------------------------
-- SELECT
--     c.ict_clientid,
--     COUNT(ap.ict_actionplanid) AS action_plan_count
-- FROM stg.prism_clt_contact AS c
-- LEFT JOIN stg.prism_clt_ict_actionplan AS ap
--     ON c.contactid = ap.ict_client
-- WHERE   c.ict_clientid IS NOT NULL
-- GROUP BY
--     c.ict_clientid
-- ORDER BY
--     action_plan_count DESC;

--------------------------------------------------------------------------------
/*
    This query returns the distribution of action plans across clients.
*/
--------------------------------------------------------------------------------
-- WITH ActionPlanCountByClient AS
-- (
--     SELECT
--         c.contactid,
--         COUNT(ap.ict_actionplanid) AS action_plan_count
--     FROM stg.prism_clt_contact AS c
--     LEFT JOIN stg.prism_clt_ict_actionplan AS ap
--         ON ap.ict_client = c.contactid
--     WHERE c.ict_clientid IS NOT NULL
--     GROUP BY
--         c.contactid
-- )
-- SELECT
--     action_plan_count AS number_of_action_plans,
--     COUNT(*) AS number_of_clients
-- FROM ActionPlanCountByClient
-- GROUP BY
--     action_plan_count
-- ORDER BY
--     number_of_action_plans;