/*==============================================================================
  PRISM interventions with synthetic action plans

  Logic:
    1. Combine Client action plans and Contract service plans as interventions.
    2. If an intervention has no end date and started more than one year ago,
       infer its end date as start date + one year.
    3. Keep interventions in the same synthetic action plan while any earlier
       intervention remains open.
    4. Start a new action plan when the client returns more than six months
       after all earlier interventions have ended.
    5. Close an action plan when all its interventions are closed and six
       months have passed since its last effective intervention end.

  PRISM values remain unmapped.
==============================================================================*/

WITH intervention_source AS
(
    /* PRISM Client action plans treated as interventions */
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
        ap.ict_closurereason                           AS intervention_closure_reason_code,

        LEFT(ap.ict_actionplanid, 100)                 AS source_intervention_guid

    FROM stg.prism_clt_ict_actionplan AS ap

    INNER JOIN stg.prism_clt_contact AS c
        ON c.contactid = ap.ict_client

    WHERE c.ict_clientid IS NOT NULL
      AND c.statecode = 0
      AND ap.ict_actionplanid IS NOT NULL
      AND ap.ict_actionplanstartdate IS NOT NULL


    UNION ALL


    /* PRISM Contract service plans treated as interventions */
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
        sp.ict_closurereason                           AS intervention_closure_reason_code,

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

/* Determine the effective end date of each intervention */
interventions AS
(
    SELECT
        i.*,

        CASE
            WHEN i.intervention_end_date IS NOT NULL
                THEN i.intervention_end_date

            WHEN DATEADD(year, 1, i.intervention_start_date)
                    <= CAST(GETDATE() AS date)
                THEN DATEADD(year, 1, i.intervention_start_date)

            ELSE NULL
        END                                            AS effective_intervention_end

    FROM intervention_source AS i
),

/*
  Examine interventions appearing before the current intervention.

  The GUID provides deterministic ordering when two interventions have the
  same start date.
*/
intervention_history AS
(
    SELECT
        i.*,

        ROW_NUMBER() OVER
        (
            PARTITION BY i.client_id
            ORDER BY
                i.intervention_start_date,
                i.source_intervention_guid
        )                                              AS intervention_sequence,

        MAX(i.effective_intervention_end) OVER
        (
            PARTITION BY i.client_id
            ORDER BY
                i.intervention_start_date,
                i.source_intervention_guid
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        )                                              AS latest_prior_end_date,

        SUM(
            CASE
                WHEN i.effective_intervention_end IS NULL
                    THEN 1
                ELSE 0
            END
        ) OVER
        (
            PARTITION BY i.client_id
            ORDER BY
                i.intervention_start_date,
                i.source_intervention_guid
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        )                                              AS prior_open_count

    FROM interventions AS i
),

/* Identify the first intervention of every synthetic action plan */
episode_boundaries AS
(
    SELECT
        h.*,

        CASE
            WHEN h.intervention_sequence = 1
                THEN 1

            WHEN COALESCE(h.prior_open_count, 0) > 0
                THEN 0

            WHEN h.intervention_start_date
                    > DATEADD(month, 6, h.latest_prior_end_date)
                THEN 1

            ELSE 0
        END                                            AS starts_new_action_plan

    FROM intervention_history AS h
),

/* Assign each intervention to its client's synthetic action-plan episode */
episode_assignments AS
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

/* Calculate action-plan-level dates and open/closed state */
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

        MAX(e.effective_intervention_end) OVER
        (
            PARTITION BY
                e.client_id,
                e.action_plan_number
        )                                              AS last_intervention_end_date,

        SUM(
            CASE
                WHEN e.effective_intervention_end IS NULL
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

/*
  Assign one BIGINT ID to each synthetic action plan.

  DENSE_RANK returns the same ID for every intervention having the same
  client_id and action_plan_number.
*/
final_result AS
(
    SELECT
        CAST(
            DENSE_RANK() OVER
            (
                ORDER BY
                    a.action_plan_start_date,
                    a.client_id,
                    a.action_plan_number
            )
            AS bigint
        )                                              AS action_plan_id,

        a.*

    FROM action_plan_calculations AS a
)

SELECT
    f.action_plan_id,
    f.client_id,

    f.action_plan_start_date,

    CASE
        WHEN f.open_intervention_count = 0
         AND DATEADD(month, 6, f.last_intervention_end_date)
                <= CAST(GETDATE() AS date)
            THEN f.last_intervention_end_date
        ELSE NULL
    END                                                AS action_plan_end_date,

    CASE
        WHEN f.open_intervention_count = 0
         AND DATEADD(month, 6, f.last_intervention_end_date)
                <= CAST(GETDATE() AS date)
            THEN CAST('Closed' AS varchar(20))
        ELSE CAST('Open' AS varchar(20))
    END                                                AS action_plan_status,

    f.intervention_id,
    f.intervention_title,

    f.contract_number,
    f.contract,
    f.subprogram,

    f.intervention_start_date,

    /* Original PRISM value */
    f.intervention_end_date,

    /* Actual end date, or inferred as start date + 1 year */
    f.effective_intervention_end                       AS calc_intervention_end_date,

    /* Status based on actual/inferred end */
    CASE
        WHEN f.intervention_end_date IS NOT NULL
            THEN CAST('Closed' AS varchar(20))

        WHEN f.effective_intervention_end IS NOT NULL
            THEN CAST('Inferred Closed' AS varchar(20))

        ELSE CAST('Open' AS varchar(20))
    END                                                AS calc_intervention_status,

    /* Original PRISM values */
    f.intervention_status_code,
    f.intervention_closure_reason_code,

    f.source_table,
    f.source_intervention_guid

FROM final_result AS f

ORDER BY
    f.action_plan_id,
    f.intervention_start_date,
    f.source_intervention_guid;