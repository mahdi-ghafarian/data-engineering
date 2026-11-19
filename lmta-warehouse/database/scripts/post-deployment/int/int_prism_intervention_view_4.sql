CREATE OR ALTER VIEW int.prism_intervention
AS

/*==============================================================================
    PRISM INTERVENTIONS WITH SYNTHETIC ACTION PLANS

    VERSION
    -------
    Status-led implementation with no Contract-date dependency.

    GRAIN
    -----
    One row per PRISM intervention.

    SOURCE INTERVENTIONS
    --------------------
    The view combines:

        1. PRISM Client Action Plans
        2. PRISM Contract Service Plans

    Both are treated as interventions under a synthetic federal Action Plan.

    INTERVENTION OPEN/CLOSED RULE
    -----------------------------
    PRISM business status determines whether an intervention is closed.

    Closed status labels:

        Complete
        Incomplete
        Carryover
        Closed

    Every other status, including In Progress, is treated as open.

    The presence or absence of intervention_end_date does not determine whether
    the intervention is open or closed.

    EFFECTIVE END-DATE RULE
    -----------------------
    1. Closed intervention with a recorded closure date:

           effective end = recorded intervention_end_date

    2. Carryover intervention with no recorded closure date:

           effective end = March 31 at the end of the fiscal year containing
                           the intervention start date

       Examples:

           Start 2022-07-01 -> effective end 2023-03-31
           Start 2023-02-15 -> effective end 2023-03-31
           Start 2024-04-01 -> effective end 2025-03-31

    3. Closed non-Carryover intervention with no closure date:

           effective end = NULL
           unresolved end-date indicator = 1

    4. Open intervention:

           effective end = NULL

    March 31 is therefore used only for Carryover with a missing closure date.
    It is not used as the universal end date for closed interventions.

    ACTION PLAN EPISODE RULE
    ------------------------
    1. The first intervention for a client starts Action Plan 1.

    2. A new Action Plan cannot start while an earlier intervention remains
       open by status.

    3. A new Action Plan cannot start when an earlier closed intervention has
       no usable effective end date.

    4. When all earlier interventions are closed and have usable effective end
       dates, a new Action Plan starts when the current intervention begins more
       than six months after the latest prior effective intervention end date.

    ACTION PLAN STATUS RULE
    -----------------------
    An Action Plan is Open when:

        - at least one assigned intervention is open; or
        - a closed intervention has no usable effective end date; or
        - six months have not elapsed after the latest effective end date.

    An Action Plan is Closed when:

        - all assigned interventions are closed;
        - all closed interventions have usable effective end dates; and
        - six months have elapsed after the latest effective end date.

    ACTION PLAN DATES
    -----------------
    action_plan_start_date:

        Earliest intervention start date assigned to the Action Plan.

    action_plan_end_date:

        Latest effective intervention end date, returned only when the Action
        Plan meets the complete closure rule.

    action_plan_inactivity_threshold_date:

        Six months after the latest effective intervention end date.

    The inactivity threshold confirms closure. It is not itself the Action Plan
    end date.

    RAW DATE QUALITY
    ----------------
    Original PRISM start and closure dates remain in the output.

    Date-quality issues are identified but do not automatically remove records.

    ACTION PLAN IDENTIFIER
    ----------------------
    Format:

        <trimmed client_id>-<action plan sequence>

    Examples:

        ICT-CLT-004375-1
        ICT-CLT-004375-2

    LIMITATIONS
    -----------
    intervention_start_date remains necessary for historical ordering.

    If a start date is incorrect, status alone cannot determine the correct
    chronological position of the intervention.

    Historical source corrections can change episode membership and later
    Action Plan sequence numbers.
==============================================================================*/

WITH intervention_source AS
(
    /*==========================================================================
        PRISM CLIENT ACTION PLANS TREATED AS INTERVENTIONS
    ==========================================================================*/
    SELECT
        CAST('PRISM' AS varchar(50))
            AS source_system,

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
        PRISM CONTRACT SERVICE PLANS TREATED AS INTERVENTIONS

        Contract descriptive values are retained.

        Contract start and end dates are not selected and are not used.
    ==========================================================================*/
    SELECT
        CAST('PRISM' AS varchar(50))
            AS source_system,

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
        ) AS intervention_title,

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
    DETERMINE INTERVENTION OPEN/CLOSED STATE

    Status is authoritative.

    Closure-date presence is not used to determine intervention state.
==============================================================================*/
intervention_status AS
(
    SELECT
        i.*,

        CASE
            WHEN LOWER(TRIM(i.intervention_status_label)) IN
                 (
                     'complete',
                     'incomplete',
                     'carryover',
                     'closed'
                 )
                THEN 1

            ELSE 0
        END AS is_intervention_closed,

        CASE
            WHEN LOWER(TRIM(i.intervention_status_label)) = 'carryover'
                THEN 1

            ELSE 0
        END AS is_carryover

    FROM intervention_source AS i
),

/*==============================================================================
    CALCULATE EFFECTIVE INTERVENTION END DATE

    March 31 is used only for Carryover with no recorded closure date.
==============================================================================*/
effective_dates AS
(
    SELECT
        i.*,

        CASE
            /*
                Closed intervention with a recorded closure date:
                use the actual source closure date.
            */
            WHEN i.is_intervention_closed = 1
             AND i.intervention_end_date IS NOT NULL
                THEN i.intervention_end_date

            /*
                Carryover with no closure date:
                use March 31 at the end of the fiscal year containing the
                intervention start date.
            */
            WHEN i.is_carryover = 1
             AND i.intervention_end_date IS NULL
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

            /*
                Open intervention, or closed non-Carryover intervention with
                no closure date.
            */
            ELSE NULL
        END AS effective_intervention_end_date,

        CASE
            /*
                Closed non-Carryover records require a source closure date.
            */
            WHEN i.is_intervention_closed = 1
             AND i.is_carryover = 0
             AND i.intervention_end_date IS NULL
                THEN 1

            ELSE 0
        END AS has_unresolved_end_date

    FROM intervention_status AS i
),

/*==============================================================================
    CLASSIFY RAW DATE QUALITY

    The classification is diagnostic only.

    It does not remove interventions or change their open/closed status.
==============================================================================*/
date_quality AS
(
    SELECT
        i.*,

        CASE
            WHEN i.intervention_end_date IS NOT NULL
             AND i.intervention_end_date < i.intervention_start_date
                THEN CAST('END_BEFORE_START' AS varchar(50))

            WHEN i.intervention_end_date IS NOT NULL
             AND i.intervention_end_date >
                 DATEADD
                 (
                     month,
                     60,
                     i.intervention_start_date
                 )
                THEN CAST('DURATION_OVER_60_MONTHS' AS varchar(50))

            WHEN i.is_intervention_closed = 1
             AND i.is_carryover = 0
             AND i.intervention_end_date IS NULL
                THEN CAST
                     (
                         'CLOSED_STATUS_MISSING_END_DATE'
                         AS varchar(50)
                     )

            WHEN i.is_intervention_closed = 0
             AND i.intervention_end_date IS NOT NULL
                THEN CAST
                     (
                         'OPEN_STATUS_HAS_END_DATE'
                         AS varchar(50)
                     )

            WHEN i.is_carryover = 1
             AND i.intervention_end_date IS NULL
                THEN CAST
                     (
                         'CARRYOVER_FISCAL_YEAR_END_DERIVED'
                         AS varchar(50)
                     )

            ELSE CAST('VALID' AS varchar(50))
        END AS intervention_date_quality_status

    FROM effective_dates AS i
),

/*==============================================================================
    ORDER INTERVENTIONS WITHIN EACH CLIENT

    Original intervention start date establishes chronology.

    Effective end date is used only for episode-boundary calculations.
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
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS latest_prior_effective_end_date,

        SUM
        (
            CASE
                WHEN i.is_intervention_closed = 0
                    THEN 1

                ELSE 0
            END
        ) OVER
        (
            PARTITION BY i.client_id
            ORDER BY
                i.intervention_start_date,
                i.intervention_type,
                i.intervention_guid
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS prior_open_intervention_count,

        SUM(i.has_unresolved_end_date) OVER
        (
            PARTITION BY i.client_id
            ORDER BY
                i.intervention_start_date,
                i.intervention_type,
                i.intervention_guid
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS prior_unresolved_end_date_count

    FROM date_quality AS i
),

/*==============================================================================
    IDENTIFY SYNTHETIC ACTION PLAN BOUNDARIES
==============================================================================*/
episode_boundaries AS
(
    SELECT
        h.*,

        CASE
            /*
                The first intervention always starts Action Plan 1.
            */
            WHEN h.intervention_sequence = 1
                THEN 1

            /*
                An earlier intervention is still open by status.
            */
            WHEN COALESCE
                 (
                     h.prior_open_intervention_count,
                     0
                 ) > 0
                THEN 0

            /*
                An earlier closed intervention has no usable end date.
                Do not guess a new Action Plan boundary.
            */
            WHEN COALESCE
                 (
                     h.prior_unresolved_end_date_count,
                     0
                 ) > 0
                THEN 0

            /*
                All earlier interventions are closed and have usable effective
                end dates.

                Start a new Action Plan only when the current intervention
                starts more than six months after the latest prior effective
                end date.
            */
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
        END AS starts_new_action_plan

    FROM intervention_history AS h
),

/*==============================================================================
    ASSIGN ACTION PLAN SEQUENCE NUMBERS
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
    CALCULATE ACTION PLAN-LEVEL VALUES
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
        ) AS action_plan_last_effective_end_date,

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
        ) AS open_intervention_count,

        SUM(e.has_unresolved_end_date) OVER
        (
            PARTITION BY
                e.client_id,
                e.action_plan_number
        ) AS unresolved_end_date_count

    FROM episode_assignments AS e
),

/*==============================================================================
    GENERATE THE ACTION PLAN BUSINESS IDENTIFIER
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
    FINAL INTERVENTION-GRAIN RESULT

    All rows belonging to the same action_plan_id receive the same:

        action_plan_start_date
        action_plan_end_date
        action_plan_status
        action_plan_inactivity_threshold_date
==============================================================================*/
SELECT
    f.source_system,

    f.action_plan_id,

    CAST(f.action_plan_number AS bigint)
        AS action_plan_number,

    f.client_id,

    f.action_plan_start_date,

    /*
        The Action Plan end is the latest effective intervention end.

        Return it only after:
          - every intervention is closed;
          - no closed intervention has an unresolved end date; and
          - six months have elapsed.
    */
    CASE
        WHEN f.open_intervention_count = 0
         AND f.unresolved_end_date_count = 0
         AND f.action_plan_last_effective_end_date IS NOT NULL
         AND DATEADD
             (
                 month,
                 6,
                 f.action_plan_last_effective_end_date
             ) <= CAST(GETDATE() AS date)
            THEN f.action_plan_last_effective_end_date

        ELSE NULL
    END AS action_plan_end_date,

    /*
        Action Plan status is calculated at the parent Action Plan grain.
    */
    CASE
        WHEN f.open_intervention_count = 0
         AND f.unresolved_end_date_count = 0
         AND f.action_plan_last_effective_end_date IS NOT NULL
         AND DATEADD
             (
                 month,
                 6,
                 f.action_plan_last_effective_end_date
             ) <= CAST(GETDATE() AS date)
            THEN CAST('Closed' AS varchar(20))

        ELSE CAST('Open' AS varchar(20))
    END AS action_plan_status,

    /*
        Diagnostic date showing when six months of inactivity are reached.
    */
    DATEADD
    (
        month,
        6,
        f.action_plan_last_effective_end_date
    ) AS action_plan_inactivity_threshold_date,

    f.intervention_type,
    f.intervention_id,
    f.intervention_title,
    f.contract_number,
    f.contract,
    f.subprogram,

    /*
        Original PRISM dates.
    */
    f.intervention_start_date,
    f.intervention_end_date,

    /*
        Actual closure date where available.
        March 31 only for Carryover with no closure date.
    */
    f.effective_intervention_end_date,

    f.intervention_status_code,
    f.intervention_status_label,
    f.intervention_closure_reason_code,
    f.intervention_closure_reason_label,

    /*
        Derived from business status.
    */
    f.is_intervention_closed,
    f.is_carryover,

    /*
        Indicates whether a closed non-Carryover intervention has no usable
        end date.
    */
    f.has_unresolved_end_date,

    /*
        Diagnostic classification of the original PRISM dates.
    */
    f.intervention_date_quality_status,

    f.intervention_guid

FROM identified_action_plans AS f;