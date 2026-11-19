CREATE OR ALTER VIEW int.prism_intervention
AS

/*==============================================================================
    PRISM INTERVENTIONS WITH SYNTHETIC ACTION PLANS

    PURPOSE
    -------
    Combine PRISM Client Action Plans and Contract Service Plans into one
    intervention-level view and assign each intervention to a synthetic
    federal Action Plan.

    GRAIN
    -----
    One row per PRISM intervention.

    ACTION PLAN IDENTIFIER
    ----------------------
    <trimmed client_id>-<action plan sequence>

    Examples:
        ICT-CLT-033743-1
        ICT-CLT-033743-2

    INTERVENTION CLOSURE RULE
    -------------------------
    An intervention is considered closed when:

      1. PRISM provides an intervention closure date; or
      2. The intervention is a Contract Service Plan with Carryover status
         802500003.

    CARRYOVER EFFECTIVE END DATE
    ----------------------------
    When a Carryover Service Plan has no PRISM closure date, its effective
    intervention end date is the last day of the fiscal year containing its
    intervention start date.

    Saskatchewan fiscal year:
        April 1 through March 31

    Examples:
        Start 2022-07-01 -> effective end 2023-03-31
        Start 2023-02-15 -> effective end 2023-03-31
        Start 2024-04-01 -> effective end 2025-03-31

    The original PRISM intervention_end_date remains unchanged. The derived
    effective_intervention_end_date is used only for episode calculation and
    Action Plan closure calculation.

    ACTION PLAN EPISODE RULE
    ------------------------
    1. The client's first intervention starts Action Plan 1.

    2. A new intervention remains in the current Action Plan when any earlier
       intervention remains open.

    3. When all earlier interventions are closed, a new Action Plan starts only
       when the current intervention begins more than six months after the
       latest prior effective intervention end date.

    ACTION PLAN CLOSURE RULE
    ------------------------
    An Action Plan is Closed only when:

      1. All interventions assigned to the Action Plan are closed; and
      2. Six months have elapsed after the latest effective intervention end.

    action_plan_end_date is the six-month inactivity threshold date.

    IMPORTANT
    ---------
    action_plan_status is calculated at the Action Plan level. Carryover closes
    the intervention, but it does not independently set the parent Action Plan
    to Closed.

    The Action Plan identifier is reconstructed from the currently available
    intervention history. Historical deletions or date corrections can change
    later Action Plan sequence numbers.
==============================================================================*/

WITH intervention_source AS
(
    /*==========================================================================
        PRISM CLIENT ACTION PLANS TREATED AS INTERVENTIONS
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
        ON LOWER(LTRIM(RTRIM(aps.MODULE_NAME))) = 'client'
       AND LOWER(LTRIM(RTRIM(aps.TABLE_NAME))) = 'ict_actionplan'
       AND LOWER(LTRIM(RTRIM(aps.COLUMN_NAME))) = 'ict_actionplanstatus'
       AND aps.CHOICE_VALUE = ap.ict_actionplanstatus

    LEFT JOIN stg.prism_choice AS apr
        ON LOWER(LTRIM(RTRIM(apr.MODULE_NAME))) = 'client'
       AND LOWER(LTRIM(RTRIM(apr.TABLE_NAME))) = 'ict_actionplan'
       AND LOWER(LTRIM(RTRIM(apr.COLUMN_NAME))) = 'ict_closurereason'
       AND apr.CHOICE_VALUE = ap.ict_closurereason

    WHERE c.ict_clientid IS NOT NULL
      AND c.statecode = 0
      AND ap.ict_actionplanid IS NOT NULL
      AND ap.ict_actionplanstartdate IS NOT NULL

    UNION ALL

    /*==========================================================================
        PRISM CONTRACT SERVICE PLANS TREATED AS INTERVENTIONS
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
        ON LOWER(LTRIM(RTRIM(sps.MODULE_NAME))) = 'contract'
       AND LOWER(LTRIM(RTRIM(sps.TABLE_NAME))) = 'ict_serviceplan'
       AND LOWER(LTRIM(RTRIM(sps.COLUMN_NAME))) = 'ict_serviceplanstatus'
       AND sps.CHOICE_VALUE = sp.ict_serviceplanstatus

    LEFT JOIN stg.prism_choice AS spr
        ON LOWER(LTRIM(RTRIM(spr.MODULE_NAME))) = 'contract'
       AND LOWER(LTRIM(RTRIM(spr.TABLE_NAME))) = 'ict_serviceplan'
       AND LOWER(LTRIM(RTRIM(spr.COLUMN_NAME))) = 'ict_closurereason'
       AND spr.CHOICE_VALUE = sp.ict_closurereason

    WHERE cc.ict_clientidid IS NOT NULL
      AND cc.statecode = 0
      AND sp.ict_serviceplanid IS NOT NULL
      AND sp.ict_startdate IS NOT NULL
),

/*==============================================================================
    DETERMINE INTERVENTION CLOSURE AND EFFECTIVE END DATE

    Carryover status:
        ict_serviceplanstatus = 802500003

    A populated PRISM closure date always takes precedence.

    If Carryover has no closure date:
        - April through December start -> March 31 of the next calendar year
        - January through March start  -> March 31 of the same calendar year
==============================================================================*/
interventions AS
(
    SELECT
        i.*,

        CASE
            WHEN i.intervention_end_date IS NOT NULL
                THEN 1

            WHEN i.intervention_type = 'ict_serviceplan'
             AND i.intervention_status_code = 802500003
                THEN 1

            ELSE 0
        END AS is_intervention_closed,

        CASE
            /*
                Use the actual PRISM closure date whenever it exists.
            */
            WHEN i.intervention_end_date IS NOT NULL
                THEN i.intervention_end_date

            /*
                Carryover without a closure date ends on the final day of the
                fiscal year containing the intervention start date.
            */
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

            /*
                An open intervention has no effective end date.
            */
            ELSE NULL
        END AS effective_intervention_end_date

    FROM intervention_source AS i
),

/*==============================================================================
    EXAMINE PRIOR INTERVENTION HISTORY

    The latest prior end uses effective_intervention_end_date, so Carryover
    Service Plans participate in episode calculations even when the PRISM
    closure date is null.

    prior_open_count means that an earlier intervention has no actual or
    derived closure under the approved rules.
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
        ) AS prior_open_count

    FROM interventions AS i
),

/*==============================================================================
    IDENTIFY THE START OF EACH SYNTHETIC ACTION PLAN

    Start a new Action Plan when:

      - this is the client's first intervention; or
      - every earlier intervention is closed and the current intervention begins
        more than six months after the latest prior effective end date.
==============================================================================*/
episode_boundaries AS
(
    SELECT
        h.*,

        CASE
            WHEN h.intervention_sequence = 1
                THEN 1

            WHEN COALESCE(h.prior_open_count, 0) > 0
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
        END AS starts_new_action_plan

    FROM intervention_history AS h
),

/*==============================================================================
    NUMBER ACTION PLANS SEPARATELY FOR EACH CLIENT
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
    CALCULATE ACTION PLAN DATES AND OPEN/CLOSED STATE

    All values in this CTE are calculated at:
        client_id + action_plan_number
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

    Do not silently truncate the completed identifier. client_id is trimmed
    before concatenation.
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

    All rows belonging to one Action Plan receive the same:
        action_plan_start_date
        action_plan_end_date
        action_plan_status
==============================================================================*/
SELECT
    f.action_plan_id,

    CAST(f.action_plan_number AS bigint)
        AS action_plan_number,

    f.client_id,

    f.action_plan_start_date,

    /*
        The Action Plan closes after six months of inactivity, provided all
        assigned interventions are closed.
    */
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

    /*
        This is calculated only from Action Plan-level values.
        There is no per-row Carryover override.
    */
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

    f.intervention_type,
    f.intervention_id,
    f.intervention_title,
    f.contract_number,
    f.contract,
    f.subprogram,
    f.intervention_start_date,
    f.intervention_end_date,
    f.intervention_status_code,
    f.intervention_status_label,
    f.intervention_closure_reason_code,
    f.intervention_closure_reason_label,
    f.is_intervention_closed,
    f.intervention_guid

FROM identified_action_plans AS f;