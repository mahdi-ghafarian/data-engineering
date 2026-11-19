CREATE OR ALTER VIEW int.prism_intervention
AS

/*==============================================================================
  PRISM INTERVENTIONS WITH SYNTHETIC ACTION PLANS

  GRAIN
      One row per PRISM intervention.

  INTERVENTION EFFECTIVE END

      Normal closure:
          effective end = actual PRISM closure date.

      60-month maximum:
          effective end = intervention start + 60 months.

      Carryover:
          Carryover is administratively closed.

          If another intervention starts within 18 months:
              effective end = next intervention start date.

          Otherwise:
              effective end = NULL.

  SYNTHETIC ACTION PLAN

      First intervention starts Action Plan 1.

      A new Action Plan starts when:
          - no prior intervention is genuinely open; and
          - current intervention starts more than 6 months after
            the latest prior effective intervention end.

      Carryover continuity:
          A Carryover followed by another intervention within 18 months
          keeps the interventions in the same Action Plan.

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


/*==============================================================================
  Combine PRISM Client and Contract interventions
==============================================================================*/
intervention_source AS
(
    /* PRISM Client Action Plans */
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

        aps.choice_name
            AS intervention_status_label,

        ap.ict_closurereason
            AS intervention_closure_reason_code,

        apr.choice_name
            AS intervention_closure_reason_label,

        LEFT(ap.ict_actionplanid, 100)
            AS intervention_guid

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


    /* PRISM Contract Service Plans */
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

        sps.choice_name
            AS intervention_status_label,

        sp.ict_closurereason
            AS intervention_closure_reason_code,

        spr.choice_name
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
  Identify Carryover and determine next intervention start.

  Carryover is sorted first when multiple interventions begin on the same date.
==============================================================================*/
intervention_sequence AS
(
    SELECT
        i.*,

        CASE
            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003
                THEN 1
            ELSE 0
        END                                            AS is_carryover,


        LEAD(i.intervention_start_date) OVER
        (
            PARTITION BY i.client_id

            ORDER BY
                i.intervention_start_date,

                CASE
                    WHEN i.intervention_type = 'ict_serviceplan'
                     AND i.intervention_status_code = 802500003
                        THEN 0
                    ELSE 1
                END,

                i.intervention_type,
                i.intervention_guid
        )                                              AS next_intervention_start_date

    FROM intervention_source AS i
),


/*==============================================================================
  Calculate effective intervention end.

  Carryover:
      next start <= carryover start + 18 months
          -> use next start.

      otherwise
          -> NULL.
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
            /* Invalid actual end before start */
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


            /* Actual end exceeds 60-month maximum */
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


            /* Valid actual closure */
            WHEN i.intervention_end_date IS NOT NULL
                THEN i.intervention_end_date


            /* Carryover with plausible continuation */
            WHEN i.is_carryover = 1

             AND i.next_intervention_start_date IS NOT NULL

             AND i.next_intervention_start_date
                    <= DATEADD
                       (
                           month,
                           18,
                           i.intervention_start_date
                       )

                THEN i.next_intervention_start_date


            /* Carryover without plausible continuation */
            WHEN i.is_carryover = 1
                THEN NULL


            /* Normal undated intervention reaches 60 months */
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

    FROM intervention_sequence AS i
),


/*==============================================================================
  Calculated intervention status
==============================================================================*/
intervention_status AS
(
    SELECT
        i.*,


        /* Carryover is always administratively closed */
        CASE
            WHEN i.is_carryover = 1
                THEN 1

            WHEN i.effective_intervention_end_date IS NOT NULL
             AND i.effective_intervention_end_date
                    <= CAST(GETDATE() AS date)
                THEN 1

            ELSE 0
        END                                            AS is_intervention_closed,


        CASE
            WHEN i.is_carryover = 1
                THEN CAST('Closed - Carryover' AS varchar(50))


            WHEN i.has_invalid_date_range = 1
             AND i.maximum_intervention_end_date
                    > CAST(GETDATE() AS date)

                THEN CAST('Open - Invalid Date Range' AS varchar(50))


            WHEN i.has_invalid_date_range = 1
             AND i.maximum_intervention_end_date
                    <= CAST(GETDATE() AS date)

                THEN CAST
                     (
                         'Closed - 60 Month Maximum'
                         AS varchar(50)
                     )


            WHEN i.intervention_end_date >
                 i.maximum_intervention_end_date

             AND i.maximum_intervention_end_date
                    <= CAST(GETDATE() AS date)

                THEN CAST
                     (
                         'Closed - 60 Month Maximum'
                         AS varchar(50)
                     )


            WHEN i.intervention_end_date >
                 i.maximum_intervention_end_date

                THEN CAST
                     (
                         'Open - Future Effective End'
                         AS varchar(50)
                     )


            WHEN i.intervention_end_date IS NOT NULL
             AND i.intervention_end_date
                    <= CAST(GETDATE() AS date)

                THEN CAST('Closed' AS varchar(50))


            WHEN i.intervention_end_date IS NOT NULL
             AND i.intervention_end_date
                    > CAST(GETDATE() AS date)

                THEN CAST
                     (
                         'Open - Future End Date'
                         AS varchar(50)
                     )


            WHEN i.maximum_intervention_end_date
                    <= CAST(GETDATE() AS date)

                THEN CAST
                     (
                         'Closed - 60 Month Maximum'
                         AS varchar(50)
                     )


            ELSE CAST('Open' AS varchar(50))

        END                                            AS calculated_intervention_status,


        CASE
            /* Carryover connected to next intervention */
            WHEN i.is_carryover = 1
             AND i.next_intervention_start_date IS NOT NULL
             AND i.next_intervention_start_date
                    <= DATEADD
                       (
                           month,
                           18,
                           i.intervention_start_date
                       )

                THEN CAST
                     (
                         'Carryover - next intervention start'
                         AS varchar(60)
                     )


            /* Carryover without a defensible continuation date */
            WHEN i.is_carryover = 1

                THEN CAST
                     (
                         'Carryover - no subsequent intervention'
                         AS varchar(60)
                     )


            WHEN i.has_invalid_date_range = 1
             AND i.maximum_intervention_end_date
                    <= CAST(GETDATE() AS date)

                THEN CAST
                     (
                         '60-month maximum after invalid source end'
                         AS varchar(60)
                     )


            WHEN i.has_invalid_date_range = 1

                THEN CAST
                     (
                         'Invalid source end date'
                         AS varchar(60)
                     )


            WHEN i.intervention_end_date >
                 i.maximum_intervention_end_date

                THEN CAST
                     (
                         '60-month maximum'
                         AS varchar(60)
                     )


            WHEN i.intervention_end_date IS NOT NULL

                THEN CAST
                     (
                         'PRISM closure date'
                         AS varchar(60)
                     )


            WHEN i.maximum_intervention_end_date
                    <= CAST(GETDATE() AS date)

                THEN CAST
                     (
                         '60-month maximum'
                         AS varchar(60)
                     )


            ELSE NULL

        END                                            AS effective_end_date_basis

    FROM interventions AS i
),


/*==============================================================================
  Establish final chronological sequence.

  Carryover remains first on matching start dates.
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

                CASE
                    WHEN i.is_carryover = 1
                        THEN 0
                    ELSE 1
                END,

                i.intervention_type,
                i.intervention_guid
        )                                              AS intervention_sequence,


        LAG(i.is_carryover) OVER
        (
            PARTITION BY i.client_id

            ORDER BY
                i.intervention_start_date,

                CASE
                    WHEN i.is_carryover = 1
                        THEN 0
                    ELSE 1
                END,

                i.intervention_type,
                i.intervention_guid
        )                                              AS prior_intervention_is_carryover,


        LAG(i.intervention_start_date) OVER
        (
            PARTITION BY i.client_id

            ORDER BY
                i.intervention_start_date,

                CASE
                    WHEN i.is_carryover = 1
                        THEN 0
                    ELSE 1
                END,

                i.intervention_type,
                i.intervention_guid
        )                                              AS prior_intervention_start_date

    FROM intervention_status AS i
),


/*==============================================================================
  Evaluate prior history relative to the current intervention.
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

        current_i.is_carryover,
        current_i.intervention_sequence,

        current_i.prior_intervention_is_carryover,
        current_i.prior_intervention_start_date,


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

        current_i.is_carryover,
        current_i.intervention_sequence,

        current_i.prior_intervention_is_carryover,
        current_i.prior_intervention_start_date
),


/*==============================================================================
  Determine Action Plan boundaries.

  Carryover continuation is accepted only when the current intervention begins
  within 18 months of the preceding Carryover's start.

  This prevents an old Carryover from keeping an Action Plan alive indefinitely.
==============================================================================*/
episode_boundaries AS
(
    SELECT
        h.*,

        CASE
            /* First intervention */
            WHEN h.intervention_sequence = 1
                THEN 1


            /* Genuinely open previous intervention overlaps current row */
            WHEN h.active_prior_intervention_count > 0
                THEN 0


            /* Plausible Carryover continuation */
            WHEN COALESCE
                 (
                     h.prior_intervention_is_carryover,
                     0
                 ) = 1

             AND h.prior_intervention_start_date IS NOT NULL

             AND h.intervention_start_date
                    <= DATEADD
                       (
                           month,
                           18,
                           h.prior_intervention_start_date
                       )

                THEN 0


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


            ELSE 0

        END                                            AS starts_new_action_plan

    FROM prior_history AS h
),


/*==============================================================================
  Assign interventions to synthetic Action Plan episodes.
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
  Calculate Action Plan values.
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
  Generate synthetic Action Plan ID.
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
  FINAL RESULT
==============================================================================*/
SELECT
    f.client_id,

    f.action_plan_id,

    f.action_plan_start_date,


    /* Action Plan closes six months after latest effective intervention end */
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


    /* Actual PRISM closure */
    f.intervention_end_date,


    /* Calculated analytical closure */
    f.effective_intervention_end_date,

    f.effective_end_date_basis,

    f.calculated_intervention_status,


    /* Original PRISM labels */
    f.intervention_status_label,

    f.intervention_closure_reason_label,


    f.intervention_guid

FROM identified_action_plans AS f;