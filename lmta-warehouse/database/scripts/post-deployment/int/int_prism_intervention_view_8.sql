CREATE OR ALTER VIEW int.prism_intervention
AS

/*==============================================================================
  PRISM INTERVENTIONS WITH SYNTHETIC ACTION PLANS

  GRAIN
      One row per PRISM intervention.

  EFFECTIVE INTERVENTION END RULES

      1. Valid PRISM closure date:
             Use the actual closure date.

      2. Intervention longer than 60 months:
             Cap the effective end at start date + 60 months.

      3. No closure date after 60 months:
             Infer the effective end at start date + 60 months.

      4. Carryover:
             Consider the intervention administratively closed.
             Do not create an effective closure date.
             Carryover acts as a continuation marker.

      5. Otherwise:
             The intervention remains open.

  SYNTHETIC ACTION PLAN RULES

      1. The first intervention starts Action Plan 1.

      2. A genuinely open prior intervention prevents a new Action Plan.

      3. The first Carryover after a completed historical episode may start
         a new Action Plan when it occurs more than six months after the
         latest dated effective intervention end.

      4. Once a Carryover starts or joins an Action Plan, the intervention
         immediately following it continues the same Action Plan.

      5. Consecutive Carryover records remain in the same Action Plan.

      6. If Carryover and another intervention have the same start date,
         Carryover is sequenced first so the other intervention continues
         the Carryover Action Plan.

      7. Without a Carryover continuation, a new Action Plan starts when
         the client returns more than six months after the latest prior
         dated effective intervention end.

  ACTION PLAN CLOSURE

      Action Plan end date =
          latest dated effective intervention end + 6 months

      provided:
          - no genuinely open intervention remains;
          - a dated effective intervention end exists;
          - the six-month threshold has passed.

      An Action Plan containing only undated Carryovers remains open because
      Carryover does not provide a defensible service-ending date.

==============================================================================*/


WITH choice_labels AS
(
    /*==========================================================================
      Deduplicate PRISM choice labels before joining.
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


    /*==========================================================================
      PRISM Contract Service Plans treated as interventions
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


interventions AS
(
    /*==========================================================================
      Calculate effective intervention end.

      Carryover is checked before the generic undated 60-month rule.

      Therefore, Carryover remains closed but undated even when the Carryover
      record itself is older than 60 months.
    ==========================================================================*/
    SELECT
        i.*,

        DATEADD
        (
            month,
            60,
            i.intervention_start_date
        )
            AS maximum_intervention_end_date,


        CASE
            /*--------------------------------------------------------------
              Invalid PRISM end date earlier than intervention start.

              Use the 60-month maximum only after it has passed.
            --------------------------------------------------------------*/
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


            /*--------------------------------------------------------------
              Actual end exceeds the 60-month maximum.
            --------------------------------------------------------------*/
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


            /*--------------------------------------------------------------
              Valid actual PRISM closure date.
            --------------------------------------------------------------*/
            WHEN i.intervention_end_date IS NOT NULL
                THEN i.intervention_end_date


            /*--------------------------------------------------------------
              Carryover is administratively closed but undated.
            --------------------------------------------------------------*/
            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003

                THEN NULL


            /*--------------------------------------------------------------
              Normal undated intervention has reached 60 months.
            --------------------------------------------------------------*/
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


            /*--------------------------------------------------------------
              Otherwise intervention remains open.
            --------------------------------------------------------------*/
            ELSE NULL

        END
            AS effective_intervention_end_date,


        CASE
            WHEN i.intervention_end_date
                    < i.intervention_start_date
                THEN 1

            ELSE 0
        END
            AS has_invalid_date_range

    FROM intervention_source AS i
),


intervention_status AS
(
    /*==========================================================================
      Determine calculated closure status.

      Carryover is closed even though its effective end date is NULL.
    ==========================================================================*/
    SELECT
        i.*,


        CASE
            /* Carryover is administratively closed */
            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003

                THEN 1


            /* A dated effective end is closed only after that date occurs */
            WHEN i.effective_intervention_end_date IS NOT NULL
             AND i.effective_intervention_end_date
                    <= CAST(GETDATE() AS date)

                THEN 1


            ELSE 0
        END
            AS is_intervention_closed,


        CASE
            /* Carryover takes precedence over other status classifications */
            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003

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

        END
            AS calculated_intervention_status,


        CASE
            /* Carryover intentionally has no effective closure date */
            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003

                THEN CAST
                     (
                         'Carryover - no closure date'
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

        END
            AS effective_end_date_basis,


        CASE
            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003

                THEN 1

            ELSE 0
        END
            AS is_carryover

    FROM interventions AS i
),


sequenced_interventions AS
(
    /*==========================================================================
      Establish intervention sequence for each client.

      Carryover sorts before other interventions on the same start date.

      This allows an In Progress intervention beginning on the same date as a
      Carryover to inherit the Carryover continuation.
    ==========================================================================*/
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
        )
            AS intervention_sequence,


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
        )
            AS prior_intervention_is_carryover

    FROM intervention_status AS i
),


prior_history AS
(
    /*==========================================================================
      Evaluate prior intervention history relative to the current row.

      latest_prior_effective_end_date:
          Latest dated effective end among all prior interventions.

          Carryover is excluded naturally because its effective end is NULL.

      active_prior_intervention_count:
          Number of genuinely open prior interventions that overlap the
          current intervention.

          Carryover is excluded because is_intervention_closed = 1.

      prior_intervention_is_carryover:
          Indicates that the immediately preceding intervention is Carryover.
          This carries the current intervention into the same Action Plan.
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

        current_i.is_carryover,

        current_i.intervention_sequence,

        current_i.prior_intervention_is_carryover,


        MAX
        (
            prior_i.effective_intervention_end_date
        )
            AS latest_prior_effective_end_date,


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
        )
            AS active_prior_intervention_count

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

        current_i.prior_intervention_is_carryover
),


episode_boundaries AS
(
    /*==========================================================================
      Determine whether the current intervention starts a new Action Plan.

      Evaluation order:

          1. First intervention starts AP 1.

          2. A genuinely open prior intervention keeps the current row in
             the existing Action Plan.

          3. If the immediately preceding intervention is Carryover, continue
             the same Action Plan.

          4. Otherwise, a start more than six months after the latest dated
             prior effective end begins a new Action Plan.

          5. Otherwise continue the current Action Plan.
    ==========================================================================*/
    SELECT
        h.*,

        CASE
            /* First intervention for the client */
            WHEN h.intervention_sequence = 1
                THEN 1


            /* Previous genuinely open intervention overlaps this row */
            WHEN h.active_prior_intervention_count > 0
                THEN 0


            /* Carryover continuation */
            WHEN COALESCE
                 (
                     h.prior_intervention_is_carryover,
                     0
                 ) = 1

                THEN 0


            /* Return after more than six months of inactivity */
            WHEN h.latest_prior_effective_end_date IS NOT NULL

             AND h.intervention_start_date >
                 DATEADD
                 (
                     month,
                     6,
                     h.latest_prior_effective_end_date
                 )

                THEN 1


            /* Otherwise remain in the current Action Plan */
            ELSE 0

        END
            AS starts_new_action_plan

    FROM prior_history AS h
),


episode_assignments AS
(
    /*==========================================================================
      Convert boundary markers to client-specific Action Plan numbers.
    ==========================================================================*/
    SELECT
        e.*,

        SUM(e.starts_new_action_plan) OVER
        (
            PARTITION BY e.client_id

            ORDER BY e.intervention_sequence

            ROWS UNBOUNDED PRECEDING
        )
            AS action_plan_number

    FROM episode_boundaries AS e
),


action_plan_calculations AS
(
    /*==========================================================================
      Calculate Action Plan-level values.

      Carryover is closed and therefore does not increase
      open_intervention_count.

      Carryover has no effective end and therefore does not independently
      determine the last dated intervention end.
    ==========================================================================*/
    SELECT
        e.*,

        MIN(e.intervention_start_date) OVER
        (
            PARTITION BY
                e.client_id,
                e.action_plan_number
        )
            AS action_plan_start_date,


        MAX(e.effective_intervention_end_date) OVER
        (
            PARTITION BY
                e.client_id,
                e.action_plan_number
        )
            AS last_effective_intervention_end_date,


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
        )
            AS open_intervention_count

    FROM episode_assignments AS e
),


identified_action_plans AS
(
    /*==========================================================================
      Generate the synthetic Action Plan identifier.

      Example:
          ICT-CLT-033743-1
          ICT-CLT-033743-2
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
        )
            AS action_plan_id,

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
      Action Plan closes six months after the latest dated effective end.

      It remains open when:
          - any intervention remains genuinely open;
          - there is no dated effective end;
          - the six-month threshold has not passed.

      An Action Plan containing only undated Carryovers remains open.
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

    END
        AS action_plan_end_date,


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

    END
        AS action_plan_status,


    f.intervention_type,

    f.intervention_id,

    f.intervention_title,

    f.contract_number,

    f.contract,

    f.subprogram,

    f.intervention_start_date,

    /* Actual PRISM closure date */
    f.intervention_end_date,
        
    /* Original PRISM labels */
    f.intervention_status_label AS intervention_status,

    f.intervention_closure_reason_label AS intervention_closure_reason,

    /* Calculated closure date used by the synthetic Action Plan logic */
    f.effective_intervention_end_date,

    f.effective_end_date_basis,

    f.calculated_intervention_status,

    /* Source traceability */
    f.intervention_guid

FROM identified_action_plans AS f;