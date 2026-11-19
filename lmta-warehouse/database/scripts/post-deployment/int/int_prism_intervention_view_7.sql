CREATE OR ALTER VIEW int.prism_intervention
AS

/*==============================================================================
  PRISM INTERVENTIONS WITH SYNTHETIC ACTION PLANS

  Grain:
      One row per PRISM intervention.

  Effective intervention end:
      1. Invalid source end before start:
             Do not use invalid end.
             Use 60-month maximum only when that threshold has passed.

      2. Actual end later than start + 60 months:
             Cap effective end at start + 60 months.

      3. Actual end within 60 months:
             Use actual end.

      4. Carryover:
             Consider intervention CLOSED.
             Do NOT invent an effective closure date.
             effective_intervention_end_date remains NULL.

      5. No actual end and 60 months have passed:
             Use start + 60 months.

      6. Otherwise:
             Intervention remains open.

  Synthetic Action Plan:
      1. First intervention starts Action Plan 1.

      2. A genuinely open prior intervention blocks creation of a new
         Action Plan when it overlaps the current intervention.

      3. Carryover is closed and therefore does NOT count as an open
         prior intervention.

      4. Carryover has no effective end date and therefore does NOT
         independently start a six-month inactivity clock.

      5. When no prior intervention overlaps the current intervention,
         a new Action Plan starts when the current intervention begins
         more than six months after the latest PRIOR DATED effective
         intervention end.

  Action Plan closure:
      Action Plan end =
          latest dated effective intervention end + 6 months

      provided:
          - no intervention in the Action Plan remains genuinely open;
          - a dated effective end exists;
          - the six-month threshold has passed.

==============================================================================*/

WITH choice_labels AS
(
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
      PRISM Client Action Plans
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
      PRISM Contract Service Plans
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

/*==============================================================================
  Effective intervention end

  Carryover is intentionally checked before the generic 60-month NULL-end rule.

  Therefore:
      Carryover + NULL source end
          -> effective end remains NULL
          -> even when the record itself is older than 60 months.

  This preserves the meaning that Carryover is administratively closed but
  does not have a defensible service-ending date.
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
        )                                              AS maximum_intervention_end_date,


        CASE
            /* Invalid source end before start */
            WHEN i.intervention_end_date < i.intervention_start_date
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

            WHEN i.intervention_end_date < i.intervention_start_date
                THEN NULL


            /* Actual closure exceeds 60-month maximum */
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


            /* Actual valid closure within 60 months */
            WHEN i.intervention_end_date IS NOT NULL
                THEN i.intervention_end_date


            /* Carryover is closed but has NO effective end date */
            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003
                THEN NULL


            /* Normal undated intervention reaches the 60-month maximum */
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
            WHEN i.intervention_end_date < i.intervention_start_date
                THEN 1
            ELSE 0
        END                                            AS has_invalid_date_range

    FROM intervention_source AS i
),

/*==============================================================================
  Calculated intervention status

  IMPORTANT:
      Carryover is always CLOSED for this transformation even though its
      effective_intervention_end_date is NULL.

      Therefore is_intervention_closed cannot be derived simply from whether
      effective_intervention_end_date is NULL.
==============================================================================*/
intervention_status AS
(
    SELECT
        i.*,

        CASE
            /* Carryover is administratively closed */
            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003
                THEN 1

            /* Any dated effective end that has occurred is closed */
            WHEN i.effective_intervention_end_date IS NOT NULL
             AND i.effective_intervention_end_date <= CAST(GETDATE() AS date)
                THEN 1

            ELSE 0
        END                                            AS is_intervention_closed,


        CASE
            /* Carryover takes precedence */
            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003
                THEN CAST('Closed - Carryover' AS varchar(50))


            WHEN i.has_invalid_date_range = 1
             AND i.maximum_intervention_end_date > CAST(GETDATE() AS date)
                THEN CAST('Open - Invalid Date Range' AS varchar(50))


            WHEN i.has_invalid_date_range = 1
             AND i.maximum_intervention_end_date <= CAST(GETDATE() AS date)
                THEN CAST('Closed - 60 Month Maximum' AS varchar(50))


            WHEN i.intervention_end_date >
                 i.maximum_intervention_end_date
             AND i.maximum_intervention_end_date <= CAST(GETDATE() AS date)
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


            WHEN i.maximum_intervention_end_date <= CAST(GETDATE() AS date)
                THEN CAST('Closed - 60 Month Maximum' AS varchar(50))


            ELSE CAST('Open' AS varchar(50))

        END                                            AS calculated_intervention_status,


        CASE
            /* Carryover has intentionally no effective date */
            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003
                THEN CAST('Carryover - no closure date' AS varchar(60))


            WHEN i.has_invalid_date_range = 1
             AND i.maximum_intervention_end_date <= CAST(GETDATE() AS date)
                THEN CAST
                     (
                         '60-month maximum after invalid source end'
                         AS varchar(60)
                     )


            WHEN i.has_invalid_date_range = 1
                THEN CAST('Invalid source end date' AS varchar(60))


            WHEN i.intervention_end_date >
                 i.maximum_intervention_end_date
                THEN CAST('60-month maximum' AS varchar(60))


            WHEN i.intervention_end_date IS NOT NULL
                THEN CAST('PRISM closure date' AS varchar(60))


            WHEN i.maximum_intervention_end_date <= CAST(GETDATE() AS date)
                THEN CAST('60-month maximum' AS varchar(60))


            ELSE NULL

        END                                            AS effective_end_date_basis

    FROM interventions AS i
),

/*==============================================================================
  Establish deterministic chronological order for each client.
==============================================================================*/
sequenced_interventions AS
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
        )                                              AS intervention_sequence

    FROM intervention_status AS i
),

/*==============================================================================
  Evaluate client history relative to the current intervention.

  active_prior_intervention_count:
      Only genuinely OPEN prior interventions count.

      Carryover does not count because:
          is_intervention_closed = 1

      For a dated intervention, it blocks the new Action Plan only while its
      effective end is on or after the current intervention start.

      For a genuinely open intervention with no effective end:
          it blocks the new Action Plan.

  latest_prior_effective_end_date:
      Only DATED effective ends participate.

      Carryover is ignored because its effective end is NULL.
==============================================================================*/
prior_history AS
(
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

                 AND prior_i.is_intervention_closed = 0

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

/*==============================================================================
  Determine Action Plan boundaries.

  A new Action Plan begins when:

      1. This is the client's first intervention.

      OR

      2. No genuinely open prior intervention overlaps the current one,
         AND
         the current start is more than six months after the latest prior
         DATED effective intervention end.

  Undated Carryovers neither block a new Action Plan nor establish a
  six-month boundary.
==============================================================================*/
episode_boundaries AS
(
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

/*==============================================================================
  Assign Action Plan episode number.
==============================================================================*/
episode_assignments AS
(
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

/*==============================================================================
  Calculate Action Plan-level values.

  open_intervention_count uses is_intervention_closed.

  This is essential because Carryover is closed even though its effective
  end date is NULL.
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
                WHEN e.is_intervention_closed = 0
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

/*==============================================================================
  Generate synthetic Action Plan identifier.
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
            AS varchar(120)
        )                                              AS action_plan_id,

        a.*

    FROM action_plan_calculations AS a
)

/*==============================================================================
  FINAL INTERVENTION-GRAIN RESULT
==============================================================================*/
SELECT
    f.client_id,

    f.action_plan_id,

    f.action_plan_start_date,


    /*--------------------------------------------------------------------------
      Action Plan closure requires a DATED effective intervention end.

      An Action Plan containing only undated Carryovers therefore cannot
      acquire an artificial Action Plan end date merely from Carryover.
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


    /* Original PRISM closure date */
    f.intervention_end_date,


    /* Calculated closure date used for Action Plan logic */
    f.effective_intervention_end_date,


    f.effective_end_date_basis,

    f.calculated_intervention_status,


    /* Original PRISM labels */
    f.intervention_status_label,

    f.intervention_closure_reason_label,


    f.intervention_guid

FROM identified_action_plans AS f;