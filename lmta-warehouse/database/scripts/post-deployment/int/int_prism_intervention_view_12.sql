CREATE OR ALTER VIEW int.prism_intervention
AS

/*==============================================================================
    PRISM INTERVENTIONS WITH SYNTHETIC ACTION PLANS

    ACTION PLAN RULES
        1. Partition interventions by client.
        2. Sort interventions chronologically by start date.
        3. First intervention starts Action Plan 1.
        4. Gap > 24 months from previous intervention start starts a new plan.
        5. Gap <= 24 months remains in the same plan.
        6. Same-date interventions remain together.
        7. Action Plan ID = client_id + '-' + sequence.
        8. Normal Action Plan end is 24 months after its latest intervention
           start.
        9. If the next Action Plan starts before the normal 24-month end,
           use the next Action Plan start as the effective end.
       10. A future Action Plan is classified as Future, not Open.
       11. An Action Plan is Open only when:
               action_plan_start_date <= today
           AND effective action_plan_end_date > today.
       12. The Action Plan end date remains NULL until the effective end date
           is reached.

    INTERVENTION END-DATE RULES
        1. Preserve the actual PRISM end date.
        2. Effective end cannot be before intervention start.
        3. Effective end cannot exceed 24 months after start.
        4. Missing/invalid end reaches the 24-month maximum once that
           maximum date has passed.
==============================================================================*/

WITH choice_labels AS
(
    SELECT
        LOWER(TRIM(MODULE_NAME))
            AS module_name,

        LOWER(TRIM(TABLE_NAME))
            AS table_name,

        LOWER(TRIM(COLUMN_NAME))
            AS column_name,

        CHOICE_VALUE
            AS choice_value,

        MAX(LEFT(CHOICE_NAME, 500))
            AS choice_name

    FROM stg.prism_choice

    GROUP BY
        LOWER(TRIM(MODULE_NAME)),
        LOWER(TRIM(TABLE_NAME)),
        LOWER(TRIM(COLUMN_NAME)),
        CHOICE_VALUE
),

/*==============================================================================
    Combine PRISM Client Action Plans and Contract Service Plans into a common
    intervention-shaped source.
==============================================================================*/
intervention_source AS
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
    Effective intervention end date.

    Maximum allowed effective end:
        intervention start + 24 months
==============================================================================*/
prepared_interventions AS
(
    SELECT
        i.*,

        CASE
            /* Valid source end date within the 24-month limit. */
            WHEN i.intervention_end_date >= i.intervention_start_date
             AND i.intervention_end_date <=
                 DATEADD
                 (
                     month,
                     24,
                     i.intervention_start_date
                 )
                THEN i.intervention_end_date

            /* Source end exceeds the 24-month limit. */
            WHEN i.intervention_end_date >
                 DATEADD
                 (
                     month,
                     24,
                     i.intervention_start_date
                 )
                THEN DATEADD
                     (
                         month,
                         24,
                         i.intervention_start_date
                     )

            /* Missing or invalid end and 24 months have already passed. */
            WHEN DATEADD
                 (
                     month,
                     24,
                     i.intervention_start_date
                 ) <= CAST(GETDATE() AS date)
                THEN DATEADD
                     (
                         month,
                         24,
                         i.intervention_start_date
                     )

            ELSE NULL
        END
            AS effective_intervention_end_date

    FROM intervention_source AS i
),

/*==============================================================================
    Chronological intervention order.
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
                i.intervention_type
        )
            AS client_intervention_sequence,

        LAG(i.intervention_start_date) OVER
        (
            PARTITION BY i.client_id
            ORDER BY
                i.intervention_start_date,
                i.intervention_type
        )
            AS previous_intervention_start_date

    FROM prepared_interventions AS i
),

/*==============================================================================
    Assign Action Plans.

    A new Action Plan starts when:

        current intervention start
            >
        previous intervention start + 24 months
==============================================================================*/
assigned_interventions AS
(
    SELECT
        i.*,

        SUM
        (
            CASE
                WHEN i.previous_intervention_start_date IS NULL
                    THEN 1

                WHEN i.intervention_start_date >
                     DATEADD
                     (
                         month,
                         24,
                         i.previous_intervention_start_date
                     )
                    THEN 1

                ELSE 0
            END
        ) OVER
        (
            PARTITION BY i.client_id
            ORDER BY i.client_intervention_sequence
            ROWS UNBOUNDED PRECEDING
        )
            AS action_plan_sequence

    FROM sequenced_interventions AS i
),

/*==============================================================================
    One row per synthetic Action Plan.

    Normal Action Plan end:
        latest intervention start + 24 months
==============================================================================*/
action_plan_summary AS
(
    SELECT
        client_id,
        action_plan_sequence,

        MIN(intervention_start_date)
            AS action_plan_start_date,

        MAX(intervention_start_date)
            AS latest_intervention_start_date,

        DATEADD
        (
            month,
            24,
            MAX(intervention_start_date)
        )
            AS normal_action_plan_end_date

    FROM assigned_interventions

    GROUP BY
        client_id,
        action_plan_sequence
),

/*==============================================================================
    Obtain the next Action Plan start date for each client.

    This supports two requirements:
        1. Prevent two Action Plans from being Open at the same time.
        2. Preserve the normal 24-month end unless the next Action Plan starts
           before that normal end.
==============================================================================*/
action_plan_boundaries AS
(
    SELECT
        p.*,

        LEAD(p.action_plan_start_date) OVER
        (
            PARTITION BY p.client_id
            ORDER BY p.action_plan_sequence
        )
            AS next_action_plan_start_date

    FROM action_plan_summary AS p
),

/*==============================================================================
    Effective Action Plan end calculation.

    Use the earlier of:
        1. Normal end: latest intervention start + 24 months.
        2. Next Action Plan start.

    If the next Action Plan begins after the normal end, retain the normal end.

    In the current V11 grouping model, a new Action Plan normally starts after
    the prior plan's 24-month threshold. Therefore, this is mainly a safety
    rule. The Future status below is the primary prevention for multiple open
    Action Plans caused by future-dated records.
==============================================================================*/
action_plan_lifecycle AS
(
    SELECT
        p.*,

        CASE
            WHEN p.next_action_plan_start_date IS NOT NULL
             AND p.next_action_plan_start_date <
                 p.normal_action_plan_end_date
                THEN p.next_action_plan_start_date

            ELSE p.normal_action_plan_end_date
        END
            AS effective_action_plan_end_date

    FROM action_plan_boundaries AS p
)

/*==============================================================================
    Final Intervention View
==============================================================================*/
SELECT
    i.client_id,

    CAST
    (
        CONCAT
        (
            TRIM(i.client_id),
            '-',
            CAST(i.action_plan_sequence AS varchar(10))
        )
        AS varchar(120)
    )
        AS action_plan_id,

    i.action_plan_sequence,

    p.action_plan_start_date,

    /*
        Preserve V11 behavior:
        do not populate the Action Plan end date until that date is reached.
    */
    CASE
        WHEN CAST(GETDATE() AS date) >=
             p.effective_action_plan_end_date
            THEN p.effective_action_plan_end_date

        ELSE NULL
    END
        AS action_plan_end_date,

    /*
        A not-yet-started Action Plan is Future, not Open.

        This prevents future Action Plans from being counted as additional
        open plans for the client.
    */
    CASE
        WHEN p.action_plan_start_date > CAST(GETDATE() AS date)
            THEN CAST('Future' AS varchar(20))

        WHEN CAST(GETDATE() AS date) >=
             p.effective_action_plan_end_date
            THEN CAST('Closed' AS varchar(20))

        ELSE CAST('Open' AS varchar(20))
    END
        AS action_plan_status,

    ROW_NUMBER() OVER
    (
        PARTITION BY
            i.client_id,
            i.action_plan_sequence
        ORDER BY
            i.intervention_start_date,
            i.intervention_type,
            i.intervention_guid
    )
        AS intervention_sequence,

    i.intervention_type,
    i.intervention_id,
    i.intervention_title,
    i.contract_number,
    i.contract,
    i.subprogram,
    i.intervention_start_date,

    /* Actual PRISM closure date. */
    i.intervention_end_date,

    /* Reporting-effective intervention end date. */
    i.effective_intervention_end_date,

    /* Original PRISM status and closure information. */
    -- i.intervention_status_code,
    i.intervention_status_label,

    -- i.intervention_closure_reason_code,
    i.intervention_closure_reason_label,

    i.intervention_guid

FROM assigned_interventions AS i

INNER JOIN action_plan_lifecycle AS p
    ON p.client_id = i.client_id
   AND p.action_plan_sequence = i.action_plan_sequence;