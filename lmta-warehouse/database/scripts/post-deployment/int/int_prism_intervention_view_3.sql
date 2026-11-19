CREATE OR ALTER VIEW int.prism_intervention
AS

/*==============================================================================
    PRISM INTERVENTIONS WITH SYNTHETIC ACTION PLANS
    STATUS-LED, NO CONTRACT-DATE VERSION

    PURPOSE
    -------
    Combine PRISM Client Action Plans and Contract Service Plans as
    interventions and assign them to synthetic federal Action Plans.

    GRAIN
    -----
    One row per PRISM intervention.

    IMPORTANT DESIGN CHOICE
    -----------------------
    Contract start dates and Contract end dates are not used.

    Raw PRISM intervention closure dates are also not used to determine:

      - whether an intervention is open or closed;
      - whether a new Action Plan should begin;
      - when the synthetic Action Plan ends.

    This prevents an arbitrary or incorrect closure date from stretching or
    breaking the synthetic Action Plan history.

    INTERVENTION OPEN/CLOSED RULE
    -----------------------------
    PRISM business status determines whether the intervention is closed.

    Closed status labels:

        Complete
        Incomplete
        Carryover
        Closed

    All other statuses, including In Progress, are treated as open.

    Status labels are used instead of numeric values because Client Action Plan
    and Contract Service Plan picklists may use different numeric codes.

    TRUSTED GROUPING DATES
    ----------------------
    Grouping start:

        PRISM intervention start date.

    Grouping end for a closed intervention:

        March 31 at the end of the fiscal year containing the intervention
        start date.

    Examples:

        Start 2022-07-01 -> grouping end 2023-03-31
        Start 2023-02-15 -> grouping end 2023-03-31
        Start 2024-04-01 -> grouping end 2025-03-31

    Grouping end for an open intervention:

        NULL

    Raw PRISM intervention_start_date and intervention_end_date remain in the
    output. The derived grouping end is used only to build synthetic Action
    Plans.

    ACTION PLAN EPISODE RULE
    ------------------------
    1. The first intervention for a client starts Action Plan 1.

    2. If any earlier intervention remains open by status, later interventions
       remain in the current Action Plan.

    3. Once all earlier interventions are closed, a new Action Plan starts when
       the current intervention begins more than six months after the latest
       prior grouping end.

    ACTION PLAN STATUS RULE
    -----------------------
    An Action Plan is Open when any assigned intervention is open.

    An Action Plan is Closed when:

      - every assigned intervention is closed; and
      - six months have elapsed after the latest grouping end.

    action_plan_end_date is the latest grouping end, not the six-month
    inactivity threshold.

    ACTION PLAN IDENTIFIER
    ----------------------
    Format:

        <trimmed client_id>-<action_plan_number>

    Examples:

        ICT-CLT-033743-1
        ICT-CLT-033743-2

    DATA QUALITY
    ------------
    Raw PRISM dates are retained and classified, but invalid dates do not
    control Action Plan grouping.

    LIMITATION
    ----------
    This solution still requires intervention_start_date to establish
    chronology. If the start date is wrong, the view cannot determine the
    correct historical order from status alone.

    Historical status or start-date corrections may change calculated Action
    Plan membership and subsequent sequence numbers.
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

        Contract descriptive attributes are retained, but Contract dates are
        not selected or used.
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

    Closure-date presence is not used.
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
        END AS is_intervention_closed

    FROM intervention_source AS i
),

/*==============================================================================
    ASSIGN THE TRUSTED GROUPING END DATE

    A closed intervention ends, for grouping purposes, on March 31 at the end
    of the fiscal year containing its intervention start date.

    An open intervention receives no grouping end.
==============================================================================*/
trusted_grouping_dates AS
(
    SELECT
        i.*,

        CASE
            WHEN i.is_intervention_closed = 1
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

            ELSE NULL
        END AS action_plan_grouping_end_date,

        /*----------------------------------------------------------------------
            RAW PRISM DATE QUALITY

            This does not remove rows or affect grouping.
        ----------------------------------------------------------------------*/
        CASE
            WHEN i.intervention_end_date IS NULL
             AND i.is_intervention_closed = 1
                THEN CAST
                     (
                         'CLOSED_STATUS_MISSING_END_DATE'
                         AS varchar(50)
                     )

            WHEN i.intervention_end_date IS NOT NULL
             AND i.is_intervention_closed = 0
                THEN CAST
                     (
                         'OPEN_STATUS_HAS_END_DATE'
                         AS varchar(50)
                     )

            WHEN i.intervention_end_date <
                 i.intervention_start_date
                THEN CAST
                     (
                         'END_BEFORE_START'
                         AS varchar(50)
                     )

            WHEN i.intervention_end_date >
                 DATEADD
                 (
                     month,
                     60,
                     i.intervention_start_date
                 )
                THEN CAST
                     (
                         'DURATION_OVER_60_MONTHS'
                         AS varchar(50)
                     )

            ELSE CAST('VALID' AS varchar(50))
        END AS intervention_date_quality_status

    FROM intervention_status AS i
),

/*==============================================================================
    ORDER INTERVENTIONS BY THEIR PRISM START DATE
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

        MAX(i.action_plan_grouping_end_date) OVER
        (
            PARTITION BY i.client_id
            ORDER BY
                i.intervention_start_date,
                i.intervention_type,
                i.intervention_guid
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS latest_prior_grouping_end_date,

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
        ) AS prior_open_intervention_count

    FROM trusted_grouping_dates AS i
),

/*==============================================================================
    IDENTIFY THE START OF EACH SYNTHETIC ACTION PLAN
==============================================================================*/
episode_boundaries AS
(
    SELECT
        h.*,

        CASE
            /*
                The first intervention always begins Action Plan 1.
            */
            WHEN h.intervention_sequence = 1
                THEN 1

            /*
                Any earlier intervention still open by status prevents a new
                Action Plan.
            */
            WHEN COALESCE
                 (
                     h.prior_open_intervention_count,
                     0
                 ) > 0
                THEN 0

            /*
                All earlier interventions are closed.

                Start a new Action Plan only when the current intervention
                begins more than six months after the latest prior fiscal-year
                grouping end.
            */
            WHEN h.latest_prior_grouping_end_date IS NOT NULL
             AND h.intervention_start_date >
                 DATEADD
                 (
                     month,
                     6,
                     h.latest_prior_grouping_end_date
                 )
                THEN 1

            ELSE 0
        END AS starts_new_action_plan

    FROM intervention_history AS h
),

/*==============================================================================
    NUMBER ACTION PLANS WITHIN EACH CLIENT
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
    CALCULATE ACTION PLAN-LEVEL DATES AND OPEN/CLOSED STATE
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

        MAX(e.action_plan_grouping_end_date) OVER
        (
            PARTITION BY
                e.client_id,
                e.action_plan_number
        ) AS action_plan_last_grouping_end_date,

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
        ) AS open_intervention_count

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

    Every row under the same action_plan_id receives the same Action Plan
    start date, end date, and status.
==============================================================================*/
SELECT
    f.source_system,

    f.action_plan_id,

    CAST(f.action_plan_number AS bigint)
        AS action_plan_number,

    f.client_id,

    f.action_plan_start_date,

    /*
        Return the trusted fiscal-year grouping end only when the Action Plan
        is confirmed closed after six months of inactivity.
    */
    CASE
        WHEN f.open_intervention_count = 0
         AND f.action_plan_last_grouping_end_date IS NOT NULL
         AND DATEADD
             (
                 month,
                 6,
                 f.action_plan_last_grouping_end_date
             ) <= CAST(GETDATE() AS date)
            THEN f.action_plan_last_grouping_end_date

        ELSE NULL
    END AS action_plan_end_date,

    /*
        Parent status is calculated at Action Plan grain.
    */
    CASE
        WHEN f.open_intervention_count = 0
         AND f.action_plan_last_grouping_end_date IS NOT NULL
         AND DATEADD
             (
                 month,
                 6,
                 f.action_plan_last_grouping_end_date
             ) <= CAST(GETDATE() AS date)
            THEN CAST('Closed' AS varchar(20))

        ELSE CAST('Open' AS varchar(20))
    END AS action_plan_status,

    /*
        Diagnostic field showing when six months of inactivity are reached.
    */
    DATEADD
    (
        month,
        6,
        f.action_plan_last_grouping_end_date
    ) AS action_plan_inactivity_threshold_date,

    f.intervention_type,
    f.intervention_id,
    f.intervention_title,
    f.contract_number,
    f.contract,
    f.subprogram,

    /*
        Original PRISM intervention dates.
    */
    f.intervention_start_date,
    f.intervention_end_date,

    f.intervention_status_code,
    f.intervention_status_label,
    f.intervention_closure_reason_code,
    f.intervention_closure_reason_label,

    /*
        Derived from business status, not closure-date presence.
    */
    f.is_intervention_closed,

    /*
        Internal episode date derived only from intervention start and status.
    */
    f.action_plan_grouping_end_date,

    /*
        Indicates inconsistency in the raw PRISM date/status combination.
    */
    f.intervention_date_quality_status,

    f.intervention_guid

FROM identified_action_plans AS f;