CREATE OR ALTER VIEW int.prism_intervention
AS

/*==============================================================================
  PRISM INTERVENTIONS WITH SYNTHETIC ACTION PLANS

  Grain:
      One row per PRISM intervention.

  Effective intervention end:
      1. Invalid source end before start:
             Do not use the invalid end. Treat as open unless the 60-month
             maximum has passed.
      2. Actual end later than start + 60 months:
             Cap effective end at start + 60 months.
      3. Actual end within 60 months:
             Use actual end.
      4. Carryover service plan without an actual end:
             Use Saskatchewan fiscal year-end.
      5. No actual end and 60 months have passed:
             Use start + 60 months.
      6. Otherwise:
             Effective end remains NULL.

  Synthetic Action Plan:
      1. The client's first intervention starts Action Plan 1.
      2. A previous intervention blocks a new Action Plan only when it is
         still active at the current intervention's start date.
      3. When no previous intervention overlaps the current intervention,
         start a new Action Plan if the current intervention begins more than
         six months after the latest prior effective intervention end.
      4. All Action Plan calculations use effective intervention end dates.

  Action Plan closure:
      Action Plan end = latest effective intervention end + 6 months,
      provided no intervention in the Action Plan remains open as of today
      and the inactivity threshold has passed.
==============================================================================*/

WITH choice_labels AS
(
    /*==========================================================================
      Ensure each choice value produces no more than one joined row.
    ==========================================================================*/
    SELECT
        LOWER(TRIM(MODULE_NAME))                       AS module_name,
        LOWER(TRIM(TABLE_NAME))                        AS table_name,
        LOWER(TRIM(COLUMN_NAME))                       AS column_name,
        CHOICE_VALUE                                   AS choice_value,
        MAX(LEFT(CHOICE_NAME, 500))                    AS choice_name

    FROM stg.prism_choice

    GROUP BY
        LOWER(TRIM(MODULE_NAME)),
        LOWER(TRIM(TABLE_NAME)),
        LOWER(TRIM(COLUMN_NAME)),
        CHOICE_VALUE
),

intervention_source AS
(
    /*==========================================================================
      PRISM Client Action Plans treated as interventions
    ==========================================================================*/
    SELECT
        CAST('ict_actionplan' AS varchar(100))         AS intervention_type,

        LEFT(TRIM(c.ict_clientid), 100)                AS client_id,
        LEFT(ap.ict_name, 100)                         AS intervention_id,
        CAST('Career Counselling' AS varchar(500))     AS intervention_title,

        CAST(NULL AS varchar(100))                     AS contract_number,
        CAST(NULL AS varchar(500))                     AS contract,
        CAST(NULL AS varchar(500))                     AS subprogram,

        CAST(ap.ict_actionplanstartdate AS date)       AS intervention_start_date,
        CAST(ap.ict_closuredate AS date)               AS intervention_end_date,

        ap.ict_actionplanstatus                        AS intervention_status_code,
        aps.choice_name                                AS intervention_status_label,

        ap.ict_closurereason                           AS intervention_closure_reason_code,
        apr.choice_name                                AS intervention_closure_reason_label,

        LEFT(ap.ict_actionplanid, 100)                 AS intervention_guid

    FROM stg.prism_clt_ict_actionplan AS ap

    INNER JOIN stg.prism_clt_contact AS c
        ON c.contactid = ap.ict_client

    LEFT JOIN choice_labels AS aps
        ON aps.module_name = 'client'
       AND aps.table_name = 'ict_actionplan'
       AND aps.column_name = 'ict_actionplanstatus'
       AND aps.choice_value = ap.ict_actionplanstatus

    LEFT JOIN choice_labels AS apr
        ON apr.module_name = 'client'
       AND apr.table_name = 'ict_actionplan'
       AND apr.column_name = 'ict_closurereason'
       AND apr.choice_value = ap.ict_closurereason

    WHERE NULLIF(TRIM(c.ict_clientid), '') IS NOT NULL
      AND c.statecode = 0
      AND ap.ict_actionplanid IS NOT NULL
      AND ap.ict_actionplanstartdate IS NOT NULL


    UNION ALL


    /*==========================================================================
      PRISM Contract Service Plans treated as interventions
    ==========================================================================*/
    SELECT
        CAST('ict_serviceplan' AS varchar(100))        AS intervention_type,

        LEFT(TRIM(cc.ict_clientidid), 100)             AS client_id,
        LEFT(sp.ict_name, 100)                         AS intervention_id,

        LEFT
        (
            COALESCE
            (
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
        sps.choice_name                                AS intervention_status_label,

        sp.ict_closurereason                           AS intervention_closure_reason_code,
        spr.choice_name                                AS intervention_closure_reason_label,

        LEFT(sp.ict_serviceplanid, 100)                AS intervention_guid

    FROM stg.prism_ctr_ict_serviceplan AS sp

    INNER JOIN stg.prism_ctr_ict_client AS cc
        ON cc.ict_clientid = sp.ict_client

    LEFT JOIN stg.prism_ctr_pcm_contract AS ct
        ON ct.pcm_contractid = sp.ict_contractid

    LEFT JOIN stg.prism_ctr_ict_subprogram AS sub
        ON sub.ict_subprogramid = ct.ict_subprogramtype

    LEFT JOIN choice_labels AS sps
        ON sps.module_name = 'contract'
       AND sps.table_name = 'ict_serviceplan'
       AND sps.column_name = 'ict_serviceplanstatus'
       AND sps.choice_value = sp.ict_serviceplanstatus

    LEFT JOIN choice_labels AS spr
        ON spr.module_name = 'contract'
       AND spr.table_name = 'ict_serviceplan'
       AND spr.column_name = 'ict_closurereason'
       AND spr.choice_value = sp.ict_closurereason

    WHERE NULLIF(TRIM(cc.ict_clientidid), '') IS NOT NULL
      AND cc.statecode = 0
      AND sp.ict_serviceplanid IS NOT NULL
      AND sp.ict_startdate IS NOT NULL
),

interventions AS
(
    /*==========================================================================
      Calculate the effective intervention end date.

      The original PRISM intervention_end_date is preserved unchanged.
    ==========================================================================*/
    SELECT
        i.*,

        DATEADD
        (
            month,
            60,
            i.intervention_start_date
        )                                              AS maximum_intervention_end_date,

        CASE
            /* Invalid source end date: earlier than start */
            WHEN i.intervention_end_date
                    < i.intervention_start_date
             AND DATEADD
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

            WHEN i.intervention_end_date
                    < i.intervention_start_date
                THEN NULL

            /* Actual closure exceeds the 60-month maximum */
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

            /* Actual closure is valid and within 60 months */
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

            /* No actual closure and 60 months have elapsed */
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

            ELSE NULL
        END                                            AS effective_intervention_end_date,

        CASE
            WHEN i.intervention_end_date
                    < i.intervention_start_date
                THEN 1
            ELSE 0
        END                                            AS has_invalid_date_range

    FROM intervention_source AS i
),

intervention_status AS
(
    /*==========================================================================
      Determine calculated status and effective end-date basis.

      An intervention with a future effective end date remains open today.
    ==========================================================================*/
    SELECT
        i.*,

        CASE
            WHEN i.effective_intervention_end_date IS NOT NULL
             AND i.effective_intervention_end_date <= CAST(GETDATE() AS date)
                THEN 1
            ELSE 0
        END                                            AS is_intervention_closed,

        CASE
            WHEN i.has_invalid_date_range = 1
             AND i.maximum_intervention_end_date
                    > CAST(GETDATE() AS date)
                THEN CAST('Open - Invalid Date Range' AS varchar(50))

            WHEN i.has_invalid_date_range = 1
             AND i.maximum_intervention_end_date
                    <= CAST(GETDATE() AS date)
                THEN CAST('Closed - 60 Month Maximum' AS varchar(50))

            WHEN i.intervention_end_date >
                 i.maximum_intervention_end_date
             AND i.maximum_intervention_end_date
                    <= CAST(GETDATE() AS date)
                THEN CAST('Closed - 60 Month Maximum' AS varchar(50))

            WHEN i.intervention_end_date >
                 i.maximum_intervention_end_date
                THEN CAST('Open - Future Effective End' AS varchar(50))

            WHEN i.intervention_end_date IS NOT NULL
             AND i.intervention_end_date <= CAST(GETDATE() AS date)
                THEN CAST('Closed' AS varchar(50))

            WHEN i.intervention_end_date IS NOT NULL
             AND i.intervention_end_date > CAST(GETDATE() AS date)
                THEN CAST('Open - Future End Date' AS varchar(50))

            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003
             AND i.effective_intervention_end_date <= CAST(GETDATE() AS date)
                THEN CAST('Closed - Carryover' AS varchar(50))

            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003
                THEN CAST('Open - Carryover End Pending' AS varchar(50))

            WHEN i.maximum_intervention_end_date
                    <= CAST(GETDATE() AS date)
                THEN CAST('Closed - 60 Month Maximum' AS varchar(50))

            ELSE CAST('Open' AS varchar(50))
        END                                            AS calculated_intervention_status,

        CASE
            WHEN i.has_invalid_date_range = 1
             AND i.maximum_intervention_end_date
                    <= CAST(GETDATE() AS date)
                THEN CAST('60-month maximum after invalid source end'
                          AS varchar(60))

            WHEN i.has_invalid_date_range = 1
                THEN CAST('Invalid source end date' AS varchar(60))

            WHEN i.intervention_end_date >
                 i.maximum_intervention_end_date
                THEN CAST('60-month maximum' AS varchar(60))

            WHEN i.intervention_end_date IS NOT NULL
                THEN CAST('PRISM closure date' AS varchar(60))

            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003
                THEN CAST('Carryover fiscal year-end' AS varchar(60))

            WHEN i.maximum_intervention_end_date
                    <= CAST(GETDATE() AS date)
                THEN CAST('60-month maximum' AS varchar(60))

            ELSE NULL
        END                                            AS effective_end_date_basis

    FROM interventions AS i
),

sequenced_interventions AS
(
    /*==========================================================================
      Establish deterministic chronological order for each client.
    ==========================================================================*/
    SELECT
        i.*,

        ROW_NUMBER() OVER
        (
            PARTITION BY i.client_id
            ORDER BY
                i.intervention_start_date,
                i.intervention_type,
                i.intervention_guid
        )                                              AS intervention_sequence

    FROM intervention_status AS i
),

prior_history AS
(
    /*==========================================================================
      Evaluate previous interventions relative to the CURRENT intervention.

      active_prior_intervention_count:
          Prior intervention has no effective end, or its effective end is
          on/after the current intervention start date.

      latest_prior_effective_end_date:
          Latest effective end among all chronologically prior interventions.

      The self-join is intentional because the "active" test depends on the
      current row's intervention_start_date.
    ==========================================================================*/
    SELECT
        current_i.intervention_type,
        current_i.client_id,
        current_i.intervention_id,
        current_i.intervention_title,
        current_i.contract_number,
        current_i.contract,
        current_i.subprogram,
        current_i.intervention_start_date,
        current_i.intervention_end_date,
        current_i.intervention_status_code,
        current_i.intervention_status_label,
        current_i.intervention_closure_reason_code,
        current_i.intervention_closure_reason_label,
        current_i.intervention_guid,
        current_i.maximum_intervention_end_date,
        current_i.effective_intervention_end_date,
        current_i.has_invalid_date_range,
        current_i.is_intervention_closed,
        current_i.calculated_intervention_status,
        current_i.effective_end_date_basis,
        current_i.intervention_sequence,

        MAX
        (
            prior_i.effective_intervention_end_date
        )                                              AS latest_prior_effective_end_date,

        SUM
        (
            CASE
                WHEN prior_i.intervention_guid IS NOT NULL
                 AND
                 (
                     prior_i.effective_intervention_end_date IS NULL
                     OR prior_i.effective_intervention_end_date
                            >= current_i.intervention_start_date
                 )
                    THEN 1
                ELSE 0
            END
        )                                              AS active_prior_intervention_count

    FROM sequenced_interventions AS current_i

    LEFT JOIN sequenced_interventions AS prior_i
        ON prior_i.client_id = current_i.client_id
       AND prior_i.intervention_sequence
                < current_i.intervention_sequence

    GROUP BY
        current_i.intervention_type,
        current_i.client_id,
        current_i.intervention_id,
        current_i.intervention_title,
        current_i.contract_number,
        current_i.contract,
        current_i.subprogram,
        current_i.intervention_start_date,
        current_i.intervention_end_date,
        current_i.intervention_status_code,
        current_i.intervention_status_label,
        current_i.intervention_closure_reason_code,
        current_i.intervention_closure_reason_label,
        current_i.intervention_guid,
        current_i.maximum_intervention_end_date,
        current_i.effective_intervention_end_date,
        current_i.has_invalid_date_range,
        current_i.is_intervention_closed,
        current_i.calculated_intervention_status,
        current_i.effective_end_date_basis,
        current_i.intervention_sequence
),

episode_boundaries AS
(
    /*==========================================================================
      Start a new Action Plan when:

          1. This is the client's first intervention.

          OR

          2. No prior intervention overlaps the current intervention,
             and the current intervention begins more than six months after
             the latest prior effective intervention end.
    ==========================================================================*/
    SELECT
        h.*,

        CASE
            WHEN h.intervention_sequence = 1
                THEN 1

            WHEN h.active_prior_intervention_count > 0
                THEN 0

            WHEN h.latest_prior_effective_end_date IS NOT NULL
             AND h.intervention_start_date >
                 DATEADD
                 (
                     month,
                     6,
                     h.latest_prior_effective_end_date
                 )
                THEN 1

            ELSE 0
        END                                            AS starts_new_action_plan

    FROM prior_history AS h
),

episode_assignments AS
(
    /*==========================================================================
      Convert Action Plan boundary markers into client-specific episode numbers.
    ==========================================================================*/
    SELECT
        e.*,

        SUM(e.starts_new_action_plan) OVER
        (
            PARTITION BY e.client_id
            ORDER BY e.intervention_sequence
            ROWS UNBOUNDED PRECEDING
        )                                              AS action_plan_number

    FROM episode_boundaries AS e
),

action_plan_calculations AS
(
    /*==========================================================================
      Calculate Action Plan values using effective intervention dates.
    ==========================================================================*/
    SELECT
        e.*,

        MIN(e.intervention_start_date) OVER
        (
            PARTITION BY
                e.client_id,
                e.action_plan_number
        )                                              AS action_plan_start_date,

        MAX(e.effective_intervention_end_date) OVER
        (
            PARTITION BY
                e.client_id,
                e.action_plan_number
        )                                              AS last_effective_intervention_end_date,

        SUM
        (
            CASE
                WHEN e.effective_intervention_end_date IS NULL
                  OR e.effective_intervention_end_date
                        > CAST(GETDATE() AS date)
                    THEN 1
                ELSE 0
            END
        ) OVER
        (
            PARTITION BY
                e.client_id,
                e.action_plan_number
        )                                              AS open_intervention_count

    FROM episode_assignments AS e
),

identified_action_plans AS
(
    /*==========================================================================
      Generate the synthetic Action Plan business identifier.

      Length is increased to avoid truncating longer client identifiers.
    ==========================================================================*/
    SELECT
        CAST
        (
            CONCAT
            (
                TRIM(a.client_id),
                '-',
                CAST(a.action_plan_number AS varchar(10))
            )
            AS varchar(120)
        )                                              AS action_plan_id,

        a.*

    FROM action_plan_calculations AS a
)

/*==============================================================================
  Final intervention-grain result
==============================================================================*/
SELECT
    f.client_id,
    f.action_plan_id,

    f.action_plan_start_date,

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
    END                                                AS action_plan_end_date,

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
    END                                                AS action_plan_status,

    f.intervention_type,
    f.intervention_id,
    f.intervention_title,

    f.contract_number,
    f.contract,
    f.subprogram,

    f.intervention_start_date,

    /* Actual PRISM closure date */
    f.intervention_end_date,

    /* Calculated date used for synthetic Action Plan processing */
    f.effective_intervention_end_date,
    f.effective_end_date_basis,
    f.calculated_intervention_status,

    /* Original PRISM status and closure information */
    -- f.intervention_status_code,
    f.intervention_status_label,
    -- f.intervention_closure_reason_code,
    f.intervention_closure_reason_label,

    -- f.has_invalid_date_range,
    f.intervention_guid

FROM identified_action_plans AS f;