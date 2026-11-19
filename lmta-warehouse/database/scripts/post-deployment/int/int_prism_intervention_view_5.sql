CREATE OR ALTER VIEW int.prism_intervention
AS

/*==============================================================================
  PRISM INTERVENTIONS WITH SYNTHETIC ACTION PLANS

  Core rules:

  1. Preserve the original PRISM intervention end date.

  2. Calculate effective_intervention_end_date:
       - Actual end <= start + 60 months:
             use actual end.
       - Actual end > start + 60 months:
             cap at start + 60 months.
       - No actual end and 60 months have elapsed:
             infer end at start + 60 months.
       - Carryover service plan without an end date:
             use Saskatchewan fiscal year-end.
       - Otherwise:
             intervention remains open.

  3. Synthetic Action Plan:
       - First intervention starts Action Plan 1.
       - Look at latest PRIOR effective intervention end date.
       - If current intervention starts more than 6 months after that date,
         start a new Action Plan.
       - Otherwise continue the existing Action Plan.

  4. Action Plan end:
       - latest effective intervention end + 6 months
       - only when the 6-month threshold has passed.

==============================================================================*/

WITH intervention_source AS
(
    /*==========================================================================
      PRISM Client Action Plans
    ==========================================================================*/
    SELECT
        CAST('ict_actionplan' AS varchar(100))
            AS intervention_type,

        LEFT(TRIM(c.ict_clientid), 100)
            AS client_id,

        LEFT(ap.ict_name, 100)
            AS intervention_id,

        CAST('Career Counselling' AS varchar(500))
            AS intervention_title,

        CAST(NULL AS varchar(100))
            AS contract_number,

        CAST(NULL AS varchar(500))
            AS contract,

        CAST(NULL AS varchar(500))
            AS subprogram,

        CAST(ap.ict_actionplanstartdate AS date)
            AS intervention_start_date,

        CAST(ap.ict_closuredate AS date)
            AS intervention_end_date,

        ap.ict_actionplanstatus
            AS intervention_status_code,

        LEFT(aps.CHOICE_NAME, 500)
            AS intervention_status_label,

        ap.ict_closurereason
            AS intervention_closure_reason_code,

        LEFT(apr.CHOICE_NAME, 500)
            AS intervention_closure_reason_label,

        LEFT(ap.ict_actionplanid, 100)
            AS intervention_guid

    FROM stg.prism_clt_ict_actionplan AS ap

    INNER JOIN stg.prism_clt_contact AS c
        ON c.contactid = ap.ict_client

    LEFT JOIN stg.prism_choice AS aps
        ON LOWER(TRIM(aps.MODULE_NAME)) = 'client'
       AND LOWER(TRIM(aps.TABLE_NAME)) = 'ict_actionplan'
       AND LOWER(TRIM(aps.COLUMN_NAME)) = 'ict_actionplanstatus'
       AND aps.CHOICE_VALUE = ap.ict_actionplanstatus

    LEFT JOIN stg.prism_choice AS apr
        ON LOWER(TRIM(apr.MODULE_NAME)) = 'client'
       AND LOWER(TRIM(apr.TABLE_NAME)) = 'ict_actionplan'
       AND LOWER(TRIM(apr.COLUMN_NAME)) = 'ict_closurereason'
       AND apr.CHOICE_VALUE = ap.ict_closurereason

    WHERE c.ict_clientid IS NOT NULL
      AND c.statecode = 0
      AND ap.ict_actionplanid IS NOT NULL
      AND ap.ict_actionplanstartdate IS NOT NULL


    UNION ALL


    /*==========================================================================
      PRISM Contract Service Plans
    ==========================================================================*/
    SELECT
        CAST('ict_serviceplan' AS varchar(100))
            AS intervention_type,

        LEFT(TRIM(cc.ict_clientidid), 100)
            AS client_id,

        LEFT(sp.ict_name, 100)
            AS intervention_id,

        LEFT
        (
            COALESCE
            (
                NULLIF(TRIM(ct.pcm_name), ''),
                NULLIF(TRIM(sub.ict_name), ''),
                NULLIF(TRIM(sp.ict_name), '')
            ),
            500
        )
            AS intervention_title,

        LEFT(ct.pcm_contractnum, 100)
            AS contract_number,

        LEFT(ct.pcm_name, 500)
            AS contract,

        LEFT(sub.ict_name, 500)
            AS subprogram,

        CAST(sp.ict_startdate AS date)
            AS intervention_start_date,

        CAST(sp.ict_closuredate AS date)
            AS intervention_end_date,

        sp.ict_serviceplanstatus
            AS intervention_status_code,

        LEFT(sps.CHOICE_NAME, 500)
            AS intervention_status_label,

        sp.ict_closurereason
            AS intervention_closure_reason_code,

        LEFT(spr.CHOICE_NAME, 500)
            AS intervention_closure_reason_label,

        LEFT(sp.ict_serviceplanid, 100)
            AS intervention_guid

    FROM stg.prism_ctr_ict_serviceplan AS sp

    INNER JOIN stg.prism_ctr_ict_client AS cc
        ON cc.ict_clientid = sp.ict_client

    LEFT JOIN stg.prism_ctr_pcm_contract AS ct
        ON ct.pcm_contractid = sp.ict_contractid

    LEFT JOIN stg.prism_ctr_ict_subprogram AS sub
        ON sub.ict_subprogramid = ct.ict_subprogramtype

    LEFT JOIN stg.prism_choice AS sps
        ON LOWER(TRIM(sps.MODULE_NAME)) = 'contract'
       AND LOWER(TRIM(sps.TABLE_NAME)) = 'ict_serviceplan'
       AND LOWER(TRIM(sps.COLUMN_NAME)) = 'ict_serviceplanstatus'
       AND sps.CHOICE_VALUE = sp.ict_serviceplanstatus

    LEFT JOIN stg.prism_choice AS spr
        ON LOWER(TRIM(spr.MODULE_NAME)) = 'contract'
       AND LOWER(TRIM(spr.TABLE_NAME)) = 'ict_serviceplan'
       AND LOWER(TRIM(spr.COLUMN_NAME)) = 'ict_closurereason'
       AND spr.CHOICE_VALUE = sp.ict_closurereason

    WHERE cc.ict_clientidid IS NOT NULL
      AND cc.statecode = 0
      AND sp.ict_serviceplanid IS NOT NULL
      AND sp.ict_startdate IS NOT NULL
),

/*==============================================================================
  Calculate effective intervention end date
==============================================================================*/
interventions AS
(
    SELECT
        i.*,

        DATEADD
        (
            month,
            60,
            i.intervention_start_date
        ) AS maximum_intervention_end_date,

        CASE

            /* Actual closure exceeds 60 months */
            WHEN i.intervention_end_date >
                 DATEADD
                 (
                     month,
                     60,
                     i.intervention_start_date
                 )
                THEN DATEADD
                     (
                         month,
                         60,
                         i.intervention_start_date
                     )


            /* Actual closure within 60 months */
            WHEN i.intervention_end_date IS NOT NULL
                THEN i.intervention_end_date


            /* Carryover without an actual closure date */
            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003
                THEN DATEFROMPARTS
                     (
                         CASE
                             WHEN MONTH(i.intervention_start_date) >= 4
                                 THEN YEAR(i.intervention_start_date) + 1
                             ELSE YEAR(i.intervention_start_date)
                         END,
                         3,
                         31
                     )


            /* No closure but the intervention has exceeded 60 months */
            WHEN DATEADD
                 (
                     month,
                     60,
                     i.intervention_start_date
                 ) <= CAST(GETDATE() AS date)
                THEN DATEADD
                     (
                         month,
                         60,
                         i.intervention_start_date
                     )


            /* Otherwise still open */
            ELSE NULL

        END AS effective_intervention_end_date

    FROM intervention_source AS i
),

/*==============================================================================
  Calculate intervention status
==============================================================================*/
intervention_status AS
(
    SELECT
        i.*,

        CASE
            WHEN i.effective_intervention_end_date IS NOT NULL
                THEN 1
            ELSE 0
        END AS is_intervention_closed,


        CASE

            WHEN i.intervention_end_date >
                 i.maximum_intervention_end_date
                THEN CAST(
                         'Closed - 60 Month Maximum'
                         AS varchar(40)
                     )

            WHEN i.intervention_end_date IS NULL
             AND i.maximum_intervention_end_date
                    <= CAST(GETDATE() AS date)
                THEN CAST(
                         'Closed - 60 Month Maximum'
                         AS varchar(40)
                     )

            WHEN i.intervention_end_date IS NOT NULL
                THEN CAST(
                         'Closed'
                         AS varchar(40)
                     )

            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003
                THEN CAST(
                         'Closed - Carryover'
                         AS varchar(40)
                     )

            ELSE CAST(
                     'Open'
                     AS varchar(40)
                 )

        END AS calculated_intervention_status

    FROM interventions AS i
),

/*==============================================================================
  Determine chronological intervention history per client

  IMPORTANT:
      Uses effective_intervention_end_date.

      The original PRISM intervention_end_date does not determine synthetic
      Action Plan boundaries.
==============================================================================*/
intervention_history AS
(
    SELECT
        i.*,

        ROW_NUMBER() OVER
        (
            PARTITION BY i.client_id
            ORDER BY
                i.intervention_start_date,
                i.intervention_type,
                i.intervention_guid
        ) AS intervention_sequence,


        MAX(i.effective_intervention_end_date) OVER
        (
            PARTITION BY i.client_id

            ORDER BY
                i.intervention_start_date,
                i.intervention_type,
                i.intervention_guid

            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND 1 PRECEDING
        ) AS latest_prior_effective_end_date

    FROM intervention_status AS i
),

/*==============================================================================
  Identify synthetic Action Plan boundaries

  NEW Action Plan when:

      - first intervention for client

      OR

      - current intervention start date is MORE THAN six months after
        the latest prior effective intervention end date.

  There is deliberately NO prior_open_count here.
==============================================================================*/
episode_boundaries AS
(
    SELECT
        h.*,

        CASE

            /* First intervention */
            WHEN h.intervention_sequence = 1
                THEN 1


            /* Return after six-month inactivity threshold */
            WHEN h.latest_prior_effective_end_date IS NOT NULL
             AND h.intervention_start_date >
                 DATEADD
                 (
                     month,
                     6,
                     h.latest_prior_effective_end_date
                 )
                THEN 1


            /* Otherwise continue current Action Plan */
            ELSE 0

        END AS starts_new_action_plan

    FROM intervention_history AS h
),

/*==============================================================================
  Assign each intervention to an Action Plan episode
==============================================================================*/
episode_assignments AS
(
    SELECT
        e.*,

        SUM(e.starts_new_action_plan) OVER
        (
            PARTITION BY e.client_id

            ORDER BY
                e.intervention_start_date,
                e.intervention_type,
                e.intervention_guid

            ROWS UNBOUNDED PRECEDING
        ) AS action_plan_number

    FROM episode_boundaries AS e
),

/*==============================================================================
  Calculate Action Plan values

  Everything is based on effective intervention end dates.
==============================================================================*/
action_plan_calculations AS
(
    SELECT
        e.*,

        MIN(e.intervention_start_date) OVER
        (
            PARTITION BY
                e.client_id,
                e.action_plan_number
        ) AS action_plan_start_date,


        MAX(e.effective_intervention_end_date) OVER
        (
            PARTITION BY
                e.client_id,
                e.action_plan_number
        ) AS last_effective_intervention_end_date,


        SUM
        (
            CASE
                WHEN e.effective_intervention_end_date IS NULL
                    THEN 1
                ELSE 0
            END
        ) OVER
        (
            PARTITION BY
                e.client_id,
                e.action_plan_number
        ) AS open_intervention_count

    FROM episode_assignments AS e
),

/*==============================================================================
  Generate synthetic Action Plan ID

  Example:
      ICT-CLT-033743-1
      ICT-CLT-033743-2
==============================================================================*/
identified_action_plans AS
(
    SELECT
        CAST
        (
            CONCAT
            (
                TRIM(a.client_id),
                '-',
                CAST(a.action_plan_number AS varchar(10))
            )
            AS varchar(30)
        ) AS action_plan_id,

        a.*

    FROM action_plan_calculations AS a
)

/*==============================================================================
  Final result
==============================================================================*/
SELECT
    f.client_id,

    f.action_plan_id,

    f.action_plan_start_date,


    /*--------------------------------------------------------------------------
      Synthetic Action Plan closes 6 months after the latest EFFECTIVE
      intervention end date.

      It remains NULL until:
          - no intervention in that Action Plan remains effectively open;
          - the six-month threshold has actually passed.
    --------------------------------------------------------------------------*/
    CASE
        WHEN f.open_intervention_count = 0
         AND f.last_effective_intervention_end_date IS NOT NULL
         AND DATEADD
             (
                 month,
                 6,
                 f.last_effective_intervention_end_date
             ) <= CAST(GETDATE() AS date)

            THEN DATEADD
                 (
                     month,
                     6,
                     f.last_effective_intervention_end_date
                 )

        ELSE NULL
    END AS action_plan_end_date,


    CASE
        WHEN f.open_intervention_count = 0
         AND f.last_effective_intervention_end_date IS NOT NULL
         AND DATEADD
             (
                 month,
                 6,
                 f.last_effective_intervention_end_date
             ) <= CAST(GETDATE() AS date)

            THEN CAST('Closed' AS varchar(20))

        ELSE CAST('Open' AS varchar(20))
    END AS action_plan_status,


    /*--------------------------------------------------------------------------
      Intervention
    --------------------------------------------------------------------------*/
    f.intervention_type,

    f.intervention_id,

    f.intervention_title,

    f.contract_number,

    f.contract,

    f.subprogram,

    f.intervention_start_date,


    /* Actual PRISM closure date */
    f.intervention_end_date,


    /* 60-month/carryover adjusted date used by Action Plan logic */
    f.effective_intervention_end_date,


    /* Original PRISM status */
    -- f.intervention_status_code,

    f.intervention_status_label,

    -- f.intervention_closure_reason_code,

    f.calculated_intervention_status,


    f.intervention_closure_reason_label,


    -- f.is_intervention_closed,

    f.intervention_guid

FROM identified_action_plans AS f;