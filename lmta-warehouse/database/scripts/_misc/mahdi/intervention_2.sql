/*==============================================================================
  PRISM interventions with synthetic action plans

  Combines:
    1. PRISM Client action plans
    2. PRISM Contract service plans

  Important:
    - action_plan_id is generated at the ACTION-PLAN grain.
    - Every intervention belonging to the same synthetic action plan receives
      the same action_plan_id.
    - PRISM values remain unmapped.
==============================================================================*/

WITH intervention_source AS
(
    /*==========================================================================
      PRISM Client action plans treated as interventions
    ==========================================================================*/

    SELECT
        CAST('ict_actionplan' AS varchar(100))         AS source_table,

        LEFT(c.ict_clientid, 100)                      AS client_id,
        LEFT(ap.ict_name, 100)                         AS intervention_id,
        CAST('Career Counselling' AS varchar(500))     AS intervention_title,

        CAST(NULL AS varchar(100))                     AS contract_number,
        CAST(NULL AS varchar(500))                     AS contract,
        CAST(NULL AS varchar(500))                     AS subprogram,

        CAST(ap.ict_actionplanstartdate AS date)       AS intervention_start_date,
        CAST(ap.ict_closuredate AS date)               AS intervention_end_date,

        ap.ict_actionplanstatus                        AS intervention_status_code,
        ap.ict_closurereason                           AS closure_reason_code,

        LEFT(ap.ict_actionplanid, 100)                 AS source_intervention_guid

    FROM stg.prism_clt_ict_actionplan AS ap

    INNER JOIN stg.prism_clt_contact AS c
        ON c.contactid = ap.ict_client

    WHERE c.ict_clientid IS NOT NULL
      AND c.statecode = 0
      AND ap.ict_actionplanid IS NOT NULL
      AND ap.ict_actionplanstartdate IS NOT NULL


    UNION ALL


    /*==========================================================================
      PRISM Contract service plans treated as interventions
    ==========================================================================*/

    SELECT
        CAST('ict_serviceplan' AS varchar(100))        AS source_table,

        LEFT(cc.ict_clientidid, 100)                   AS client_id,
        LEFT(sp.ict_name, 100)                         AS intervention_id,

        LEFT(
            COALESCE(
                NULLIF(TRIM(ct.pcm_name), ''),
                NULLIF(TRIM(sub.ict_name), ''),
                NULLIF(TRIM(sp.ict_name), '')
            ),
            500
        )                                              AS intervention_title,

        LEFT(ct.pcm_contractnum, 100)                  AS contract_number,
        LEFT(ct.pcm_name, 500)                         AS contract,
        LEFT(sub.ict_name, 500)                        AS subprogram,

        CAST(sp.ict_startdate AS date)                 AS intervention_start_date,
        CAST(sp.ict_closuredate AS date)               AS intervention_end_date,

        sp.ict_serviceplanstatus                       AS intervention_status_code,
        sp.ict_closurereason                           AS closure_reason_code,

        LEFT(sp.ict_serviceplanid, 100)                AS source_intervention_guid

    FROM stg.prism_ctr_ict_serviceplan AS sp

    INNER JOIN stg.prism_ctr_ict_client AS cc
        ON cc.ict_clientid = sp.ict_client

    LEFT JOIN stg.prism_ctr_pcm_contract AS ct
        ON ct.pcm_contractid = sp.ict_contractid

    LEFT JOIN stg.prism_ctr_ict_subprogram AS sub
        ON sub.ict_subprogramid = ct.ict_subprogramtype

    WHERE cc.ict_clientidid IS NOT NULL
      AND cc.statecode = 0
      AND sp.ict_serviceplanid IS NOT NULL
      AND sp.ict_startdate IS NOT NULL
),

/*==============================================================================
  Remove duplicate intervention records
==============================================================================*/

interventions_raw AS
(
    SELECT DISTINCT
        source_table,
        client_id,
        intervention_id,
        intervention_title,
        contract_number,
        contract,
        subprogram,
        intervention_start_date,
        intervention_end_date,
        intervention_status_code,
        closure_reason_code,
        source_intervention_guid

    FROM intervention_source
),

/*==============================================================================
  Calculate effective intervention end

  If no recorded end date exists:
    - infer the intervention ended one year after its start date,
      but only when that inferred date has already passed.
==============================================================================*/

interventions AS
(
    SELECT
        i.*,

        CASE
            WHEN i.intervention_end_date IS NOT NULL
                THEN i.intervention_end_date

            WHEN DATEADD(
                    year,
                    1,
                    i.intervention_start_date
                 ) <= CAST(GETDATE() AS date)
                THEN DATEADD(
                    year,
                    1,
                    i.intervention_start_date
                )

            ELSE NULL
        END                                            AS effective_intervention_end,

        CASE
            WHEN i.intervention_end_date IS NOT NULL
                THEN CAST('Closed' AS varchar(20))

            WHEN DATEADD(
                    year,
                    1,
                    i.intervention_start_date
                 ) <= CAST(GETDATE() AS date)
                THEN CAST('Inferred Closed' AS varchar(20))

            ELSE CAST('Open' AS varchar(20))
        END                                            AS calculated_intervention_status

    FROM interventions_raw AS i
),

/*==============================================================================
  Examine all earlier interventions for the same client
==============================================================================*/

prior_state AS
(
    SELECT
        current_i.source_table,
        current_i.client_id,
        current_i.intervention_id,
        current_i.intervention_title,
        current_i.contract_number,
        current_i.contract,
        current_i.subprogram,
        current_i.intervention_start_date,
        current_i.intervention_end_date,
        current_i.effective_intervention_end,
        current_i.calculated_intervention_status,
        current_i.intervention_status_code,
        current_i.closure_reason_code,
        current_i.source_intervention_guid,

        COUNT(
            prior_i.source_intervention_guid
        )                                              AS prior_intervention_count,

        SUM(
            CASE
                WHEN prior_i.source_intervention_guid IS NOT NULL
                 AND prior_i.effective_intervention_end IS NULL
                    THEN 1

                ELSE 0
            END
        )                                              AS prior_open_intervention_count,

        MAX(
            prior_i.effective_intervention_end
        )                                              AS latest_prior_intervention_end

    FROM interventions AS current_i

    LEFT JOIN interventions AS prior_i
        ON prior_i.client_id = current_i.client_id

       AND
       (
            prior_i.intervention_start_date
                < current_i.intervention_start_date

            OR
            (
                prior_i.intervention_start_date
                    = current_i.intervention_start_date

                AND prior_i.source_intervention_guid
                    < current_i.source_intervention_guid
            )
       )

    GROUP BY
        current_i.source_table,
        current_i.client_id,
        current_i.intervention_id,
        current_i.intervention_title,
        current_i.contract_number,
        current_i.contract,
        current_i.subprogram,
        current_i.intervention_start_date,
        current_i.intervention_end_date,
        current_i.effective_intervention_end,
        current_i.calculated_intervention_status,
        current_i.intervention_status_code,
        current_i.closure_reason_code,
        current_i.source_intervention_guid
),

/*==============================================================================
  Identify when a new synthetic action plan begins
==============================================================================*/

episode_boundaries AS
(
    SELECT
        p.*,

        CASE
            /* First intervention for the client */
            WHEN p.prior_intervention_count = 0
                THEN 1

            /* A prior intervention is still open */
            WHEN p.prior_open_intervention_count > 0
                THEN 0

            /* More than six months since all prior interventions ended */
            WHEN p.intervention_start_date
                    > DATEADD(
                        month,
                        6,
                        p.latest_prior_intervention_end
                    )
                THEN 1

            ELSE 0
        END                                            AS starts_new_action_plan

    FROM prior_state AS p
),

/*==============================================================================
  Assign each intervention to an action-plan episode

  action_plan_number is only an internal grouping value.
==============================================================================*/

numbered_interventions AS
(
    SELECT
        e.*,

        SUM(e.starts_new_action_plan) OVER
        (
            PARTITION BY e.client_id

            ORDER BY
                e.intervention_start_date,
                e.source_intervention_guid

            ROWS UNBOUNDED PRECEDING
        )                                              AS action_plan_number

    FROM episode_boundaries AS e
),

/*==============================================================================
  Calculate one summary row for each synthetic action plan
==============================================================================*/

action_plan_summary AS
(
    SELECT
        client_id,
        action_plan_number,

        MIN(
            intervention_start_date
        )                                              AS action_plan_start_date,

        MAX(
            effective_intervention_end
        )                                              AS last_intervention_end_date,

        SUM(
            CASE
                WHEN effective_intervention_end IS NULL
                    THEN 1

                ELSE 0
            END
        )                                              AS open_intervention_count,

        SUM(
            CASE
                WHEN calculated_intervention_status = 'Inferred Closed'
                    THEN 1

                ELSE 0
            END
        )                                              AS inferred_closed_count

    FROM numbered_interventions

    GROUP BY
        client_id,
        action_plan_number
),

/*==============================================================================
  Find the first intervention in each action plan

  This provides a deterministic tie-breaker for assigning the numeric ID.
==============================================================================*/

action_plan_first_intervention AS
(
    SELECT
        client_id,
        action_plan_number,
        source_intervention_guid                       AS first_intervention_guid

    FROM
    (
        SELECT
            client_id,
            action_plan_number,
            source_intervention_guid,

            ROW_NUMBER() OVER
            (
                PARTITION BY
                    client_id,
                    action_plan_number

                ORDER BY
                    intervention_start_date,
                    source_intervention_guid
            )                                          AS intervention_sequence

        FROM numbered_interventions
    ) AS ranked_interventions

    WHERE intervention_sequence = 1
),

/*==============================================================================
  Build exactly one row for each synthetic action plan
==============================================================================*/

action_plan_base AS
(
    SELECT
        s.client_id,
        s.action_plan_number,
        s.action_plan_start_date,
        f.first_intervention_guid,

        CASE
            WHEN s.open_intervention_count = 0
             AND DATEADD(
                    month,
                    6,
                    s.last_intervention_end_date
                 ) <= CAST(GETDATE() AS date)
                THEN s.last_intervention_end_date

            ELSE NULL
        END                                            AS action_plan_end_date,

        CASE
            WHEN s.open_intervention_count = 0
             AND DATEADD(
                    month,
                    6,
                    s.last_intervention_end_date
                 ) <= CAST(GETDATE() AS date)
             AND s.inferred_closed_count > 0
                THEN CAST('Closed (Inferred)' AS varchar(30))

            WHEN s.open_intervention_count = 0
             AND DATEADD(
                    month,
                    6,
                    s.last_intervention_end_date
                 ) <= CAST(GETDATE() AS date)
                THEN CAST('Closed' AS varchar(30))

            ELSE CAST('Open' AS varchar(30))
        END                                            AS action_plan_status

    FROM action_plan_summary AS s

    INNER JOIN action_plan_first_intervention AS f
        ON f.client_id = s.client_id
       AND f.action_plan_number = s.action_plan_number
),

/*==============================================================================
  Assign the BIGINT action_plan_id

  ROW_NUMBER runs over action_plan_base, which contains exactly one row per
  action plan. Therefore, one ID is generated per action plan, not per
  intervention.
==============================================================================*/

synthetic_action_plans AS
(
    SELECT
        CAST(
            ROW_NUMBER() OVER
            (
                ORDER BY
                    client_id,
                    action_plan_start_date,
                    first_intervention_guid
            )
            AS bigint
        )                                              AS action_plan_id,

        client_id,
        action_plan_number,
        action_plan_start_date,
        action_plan_end_date,
        action_plan_status

    FROM action_plan_base
)

/*==============================================================================
  Join the action-plan ID back to the interventions

  All interventions with the same client_id and action_plan_number receive
  the same action_plan_id.
==============================================================================*/

SELECT
    ap.action_plan_id,

    i.client_id,

    ap.action_plan_start_date,
    ap.action_plan_end_date,
    ap.action_plan_status,

    i.intervention_id,
    i.intervention_title,

    i.contract_number,
    i.contract,
    i.subprogram,

    i.intervention_start_date,
    i.intervention_end_date,

    i.intervention_status_code,
    i.closure_reason_code,

    i.source_table,
    i.source_intervention_guid

FROM numbered_interventions AS i

INNER JOIN synthetic_action_plans AS ap
    ON ap.client_id = i.client_id
   AND ap.action_plan_number = i.action_plan_number

ORDER BY
    ap.action_plan_id,
    i.intervention_start_date