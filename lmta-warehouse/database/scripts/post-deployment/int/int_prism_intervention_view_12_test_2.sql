/*==============================================================================
    MICROSOFT FABRIC WAREHOUSE
    VALIDATION OF int.intervention_prism

    - Uses CTEs only
    - No temporary tables
    - No table variables
    - Returns one validation-summary result set
    - issue_count = 0 means PASS
==============================================================================*/

WITH intervention AS
(
    SELECT
        client_id,
        action_plan_id,
        action_plan_sequence,
        action_plan_start_date,
        action_plan_end_date,
        action_plan_status,
        intervention_sequence,
        intervention_type,
        intervention_id,
        intervention_title,
        contract_number,
        contract,
        subprogram,
        intervention_start_date,
        intervention_end_date,
        effective_intervention_end_date,
        intervention_status_label,
        intervention_closure_reason_label,
        intervention_guid
    FROM int.intervention_prism
),

/*==============================================================================
    One row per Action Plan
==============================================================================*/
action_plan AS
(
    SELECT
        client_id,
        action_plan_id,
        action_plan_sequence,

        MIN(action_plan_start_date)
            AS action_plan_start_date,

        MAX(action_plan_end_date)
            AS action_plan_end_date,

        MAX(action_plan_status)
            AS action_plan_status,

        MIN(intervention_start_date)
            AS earliest_intervention_start_date,

        MAX(intervention_start_date)
            AS latest_intervention_start_date,

        MAX(effective_intervention_end_date)
            AS latest_effective_intervention_end_date,

        COUNT_BIG(*)
            AS intervention_count,

        COUNT_BIG(DISTINCT intervention_guid)
            AS distinct_intervention_guid_count

    FROM intervention

    GROUP BY
        client_id,
        action_plan_id,
        action_plan_sequence
),

/*==============================================================================
    Action Plans in chronological order
==============================================================================*/
action_plan_ordered AS
(
    SELECT
        ap.*,

        LAG(ap.action_plan_start_date) OVER
        (
            PARTITION BY ap.client_id
            ORDER BY
                ap.action_plan_sequence,
                ap.action_plan_id
        )
            AS previous_action_plan_start_date,

        LAG(ap.action_plan_end_date) OVER
        (
            PARTITION BY ap.client_id
            ORDER BY
                ap.action_plan_sequence,
                ap.action_plan_id
        )
            AS previous_action_plan_end_date,

        LAG(ap.latest_intervention_start_date) OVER
        (
            PARTITION BY ap.client_id
            ORDER BY
                ap.action_plan_sequence,
                ap.action_plan_id
        )
            AS previous_latest_intervention_start_date,

        LEAD(ap.action_plan_start_date) OVER
        (
            PARTITION BY ap.client_id
            ORDER BY
                ap.action_plan_sequence,
                ap.action_plan_id
        )
            AS next_action_plan_start_date

    FROM action_plan AS ap
),

/*==============================================================================
    Independently reconstruct intervention order
==============================================================================*/
intervention_ordered AS
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
        )
            AS expected_client_intervention_sequence,

        LAG(i.intervention_start_date) OVER
        (
            PARTITION BY i.client_id
            ORDER BY
                i.intervention_start_date,
                i.intervention_type,
                i.intervention_guid
        )
            AS previous_intervention_start_date,

        LAG(i.action_plan_sequence) OVER
        (
            PARTITION BY i.client_id
            ORDER BY
                i.intervention_start_date,
                i.intervention_type,
                i.intervention_guid
        )
            AS previous_actual_action_plan_sequence

    FROM intervention AS i
),

/*==============================================================================
    Independently reconstruct the expected 24-month grouping
==============================================================================*/
expected_grouping AS
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
            ORDER BY i.expected_client_intervention_sequence
            ROWS UNBOUNDED PRECEDING
        )
            AS expected_action_plan_sequence

    FROM intervention_ordered AS i
),

/*==============================================================================
    All validation tests
==============================================================================*/
validation AS
(
    /*--------------------------------------------------------------------------
        Completeness
    --------------------------------------------------------------------------*/

    SELECT
        10 AS test_order,
        CAST('Completeness' AS varchar(50)) AS category,
        CAST('VIEW_HAS_NO_ROWS' AS varchar(100)) AS test_code,
        CAST('ERROR' AS varchar(10)) AS severity,
        CAST
        (
            CASE
                WHEN COUNT_BIG(*) = 0 THEN 1
                ELSE 0
            END
            AS bigint
        )
            AS issue_count,
        CAST('The view must contain data.' AS varchar(500))
            AS description
    FROM intervention

    UNION ALL

    SELECT
        20,
        'Completeness',
        'CLIENT_ID_MISSING',
        'ERROR',
        COUNT_BIG(*),
        'client_id is NULL or blank.'
    FROM intervention
    WHERE NULLIF(TRIM(client_id), '') IS NULL

    UNION ALL

    SELECT
        30,
        'Completeness',
        'ACTION_PLAN_ID_MISSING',
        'ERROR',
        COUNT_BIG(*),
        'action_plan_id is NULL or blank.'
    FROM intervention
    WHERE NULLIF(TRIM(action_plan_id), '') IS NULL

    UNION ALL

    SELECT
        40,
        'Completeness',
        'ACTION_PLAN_SEQUENCE_INVALID',
        'ERROR',
        COUNT_BIG(*),
        'action_plan_sequence is NULL or less than 1.'
    FROM intervention
    WHERE action_plan_sequence IS NULL
       OR action_plan_sequence < 1

    UNION ALL

    SELECT
        50,
        'Completeness',
        'ACTION_PLAN_START_DATE_MISSING',
        'ERROR',
        COUNT_BIG(*),
        'action_plan_start_date is NULL.'
    FROM intervention
    WHERE action_plan_start_date IS NULL

    UNION ALL

    SELECT
        60,
        'Completeness',
        'INTERVENTION_GUID_MISSING',
        'ERROR',
        COUNT_BIG(*),
        'intervention_guid is NULL or blank.'
    FROM intervention
    WHERE NULLIF(TRIM(intervention_guid), '') IS NULL

    UNION ALL

    SELECT
        70,
        'Completeness',
        'INTERVENTION_START_DATE_MISSING',
        'ERROR',
        COUNT_BIG(*),
        'intervention_start_date is NULL.'
    FROM intervention
    WHERE intervention_start_date IS NULL

    UNION ALL

    SELECT
        80,
        'Completeness',
        'INTERVENTION_TYPE_INVALID',
        'ERROR',
        COUNT_BIG(*),
        'intervention_type is not ict_actionplan or ict_serviceplan.'
    FROM intervention
    WHERE intervention_type IS NULL
       OR intervention_type NOT IN
          (
              'ict_actionplan',
              'ict_serviceplan'
          )

    /*--------------------------------------------------------------------------
        Uniqueness
    --------------------------------------------------------------------------*/

    UNION ALL

    SELECT
        100,
        'Uniqueness',
        'DUPLICATE_INTERVENTION_GUID',
        'ERROR',
        COALESCE(SUM(duplicate_count - 1), 0),
        'The same intervention_guid appears more than once.'
    FROM
    (
        SELECT
            intervention_guid,
            COUNT_BIG(*) AS duplicate_count
        FROM intervention
        WHERE intervention_guid IS NOT NULL
        GROUP BY intervention_guid
        HAVING COUNT_BIG(*) > 1
    ) AS d

    UNION ALL

    SELECT
        110,
        'Uniqueness',
        'INTERVENTION_ASSIGNED_TO_MULTIPLE_CLIENTS',
        'ERROR',
        COUNT_BIG(*),
        'The same intervention_guid belongs to multiple clients.'
    FROM
    (
        SELECT
            intervention_guid
        FROM intervention
        WHERE intervention_guid IS NOT NULL
        GROUP BY intervention_guid
        HAVING COUNT(DISTINCT client_id) > 1
    ) AS d

    UNION ALL

    SELECT
        120,
        'Uniqueness',
        'INTERVENTION_ASSIGNED_TO_MULTIPLE_PLANS',
        'ERROR',
        COUNT_BIG(*),
        'The same intervention_guid belongs to multiple Action Plans.'
    FROM
    (
        SELECT
            intervention_guid
        FROM intervention
        WHERE intervention_guid IS NOT NULL
        GROUP BY intervention_guid
        HAVING COUNT(DISTINCT action_plan_id) > 1
    ) AS d

    UNION ALL

    SELECT
        130,
        'Uniqueness',
        'ACTION_PLAN_ID_ASSIGNED_TO_MULTIPLE_CLIENTS',
        'ERROR',
        COUNT_BIG(*),
        'The same action_plan_id belongs to multiple clients.'
    FROM
    (
        SELECT
            action_plan_id
        FROM action_plan
        GROUP BY action_plan_id
        HAVING COUNT(DISTINCT client_id) > 1
    ) AS d

    UNION ALL

    SELECT
        140,
        'Uniqueness',
        'ACTION_PLAN_ID_FORMAT_MISMATCH',
        'ERROR',
        COUNT_BIG(*),
        'action_plan_id does not equal client_id plus Action Plan sequence.'
    FROM action_plan
    WHERE action_plan_id <>
          CAST
          (
              CONCAT
              (
                  TRIM(client_id),
                  '-',
                  CAST(action_plan_sequence AS varchar(10))
              )
              AS varchar(120)
          )

    /*--------------------------------------------------------------------------
        Action Plan sequencing
    --------------------------------------------------------------------------*/

    UNION ALL

    SELECT
        200,
        'Sequencing',
        'ACTION_PLAN_SEQUENCE_NOT_STARTING_AT_1',
        'ERROR',
        COUNT_BIG(*),
        'Each client must begin with Action Plan sequence 1.'
    FROM
    (
        SELECT
            client_id
        FROM action_plan
        GROUP BY client_id
        HAVING MIN(action_plan_sequence) <> 1
    ) AS d

    UNION ALL

    SELECT
        210,
        'Sequencing',
        'ACTION_PLAN_SEQUENCE_HAS_GAPS',
        'ERROR',
        COUNT_BIG(*),
        'Action Plan sequences must be contiguous.'
    FROM
    (
        SELECT
            client_id
        FROM action_plan
        GROUP BY client_id
        HAVING COUNT_BIG(*) <> MAX(action_plan_sequence)
            OR MIN(action_plan_sequence) <> 1
    ) AS d

    UNION ALL

    SELECT
        220,
        'Sequencing',
        'ACTION_PLAN_SEQUENCE_NOT_CHRONOLOGICAL',
        'ERROR',
        COUNT_BIG(*),
        'A higher Action Plan sequence starts before its preceding plan.'
    FROM action_plan_ordered
    WHERE previous_action_plan_start_date IS NOT NULL
      AND action_plan_start_date <
          previous_action_plan_start_date

    UNION ALL

    SELECT
        230,
        'Sequencing',
        'INTERVENTION_SEQUENCE_NOT_STARTING_AT_1',
        'ERROR',
        COUNT_BIG(*),
        'Each Action Plan must begin with intervention sequence 1.'
    FROM
    (
        SELECT
            client_id,
            action_plan_id
        FROM intervention
        GROUP BY
            client_id,
            action_plan_id
        HAVING MIN(intervention_sequence) <> 1
    ) AS d

    UNION ALL

    SELECT
        240,
        'Sequencing',
        'INTERVENTION_SEQUENCE_HAS_GAPS_OR_DUPLICATES',
        'ERROR',
        COUNT_BIG(*),
        'Intervention sequence must be unique and contiguous within each plan.'
    FROM
    (
        SELECT
            client_id,
            action_plan_id
        FROM intervention
        GROUP BY
            client_id,
            action_plan_id
        HAVING COUNT_BIG(*) <> MAX(intervention_sequence)
            OR COUNT_BIG(*) <> COUNT(DISTINCT intervention_sequence)
            OR MIN(intervention_sequence) <> 1
    ) AS d

    /*--------------------------------------------------------------------------
        Grouping
    --------------------------------------------------------------------------*/

    UNION ALL

    SELECT
        300,
        'Grouping',
        'GROUPING_DIFFERS_FROM_RECALCULATION',
        'ERROR',
        COUNT_BIG(*),
        'Actual Action Plan sequence differs from independent recalculation.'
    FROM expected_grouping
    WHERE action_plan_sequence <>
          expected_action_plan_sequence

    UNION ALL

    SELECT
        310,
        'Grouping',
        'ACTION_PLAN_START_NOT_EARLIEST_INTERVENTION',
        'ERROR',
        COUNT_BIG(*),
        'Action Plan start does not equal the earliest intervention start.'
    FROM action_plan
    WHERE action_plan_start_date <>
          earliest_intervention_start_date

    UNION ALL

    SELECT
        320,
        'Grouping',
        'INTERVENTION_BEFORE_ACTION_PLAN_START',
        'ERROR',
        COUNT_BIG(*),
        'An intervention begins before its Action Plan.'
    FROM intervention
    WHERE intervention_start_date <
          action_plan_start_date

    UNION ALL

    SELECT
        330,
        'Grouping',
        'NEW_ACTION_PLAN_CREATED_WITHIN_24_MONTHS',
        'ERROR',
        COUNT_BIG(*),
        'A new Action Plan starts within 24 months of the preceding intervention.'
    FROM action_plan_ordered
    WHERE previous_latest_intervention_start_date IS NOT NULL
      AND action_plan_start_date <=
          DATEADD
          (
              month,
              24,
              previous_latest_intervention_start_date
          )

    UNION ALL

    SELECT
        340,
        'Grouping',
        'ACTION_PLAN_BREAK_MISSED_AFTER_24_MONTH_GAP',
        'ERROR',
        COUNT_BIG(*),
        'The Action Plan did not change after a gap greater than 24 months.'
    FROM expected_grouping
    WHERE previous_intervention_start_date IS NOT NULL
      AND intervention_start_date >
          DATEADD
          (
              month,
              24,
              previous_intervention_start_date
          )
      AND action_plan_sequence =
          previous_actual_action_plan_sequence

    UNION ALL

    SELECT
        350,
        'Grouping',
        'SAME_DAY_INTERVENTIONS_SPLIT_ACROSS_PLANS',
        'ERROR',
        COUNT_BIG(*),
        'Same-day interventions for a client are assigned to different plans.'
    FROM
    (
        SELECT
            client_id,
            intervention_start_date
        FROM intervention
        GROUP BY
            client_id,
            intervention_start_date
        HAVING COUNT(DISTINCT action_plan_id) > 1
    ) AS d

    /*--------------------------------------------------------------------------
        Action Plan lifecycle
    --------------------------------------------------------------------------*/

    UNION ALL

    SELECT
        400,
        'Lifecycle',
        'ACTION_PLAN_STATUS_INVALID',
        'ERROR',
        COUNT_BIG(*),
        'Status must be Open, Closed, or Future.'
    FROM action_plan
    WHERE action_plan_status IS NULL
       OR action_plan_status NOT IN
          (
              'Open',
              'Closed',
              'Future'
          )

    UNION ALL

    SELECT
        410,
        'Lifecycle',
        'MULTIPLE_OPEN_ACTION_PLANS',
        'ERROR',
        COUNT_BIG(*),
        'A client has more than one Open Action Plan.'
    FROM
    (
        SELECT
            client_id
        FROM action_plan
        WHERE action_plan_status = 'Open'
        GROUP BY client_id
        HAVING COUNT_BIG(*) > 1
    ) AS d

    UNION ALL

    SELECT
        420,
        'Lifecycle',
        'FUTURE_PLAN_NOT_MARKED_FUTURE',
        'ERROR',
        COUNT_BIG(*),
        'An Action Plan starting after today is not marked Future.'
    FROM action_plan
    WHERE action_plan_start_date >
          CAST(GETDATE() AS date)
      AND action_plan_status <> 'Future'

    UNION ALL

    SELECT
        430,
        'Lifecycle',
        'STARTED_PLAN_MARKED_FUTURE',
        'ERROR',
        COUNT_BIG(*),
        'An Action Plan starting on or before today is marked Future.'
    FROM action_plan
    WHERE action_plan_start_date <=
          CAST(GETDATE() AS date)
      AND action_plan_status = 'Future'

    UNION ALL

    SELECT
        440,
        'Lifecycle',
        'OPEN_PLAN_HAS_END_DATE',
        'ERROR',
        COUNT_BIG(*),
        'An Open Action Plan has a populated end date.'
    FROM action_plan
    WHERE action_plan_status = 'Open'
      AND action_plan_end_date IS NOT NULL

    UNION ALL

    SELECT
        450,
        'Lifecycle',
        'FUTURE_PLAN_HAS_END_DATE',
        'ERROR',
        COUNT_BIG(*),
        'A Future Action Plan has a populated end date.'
    FROM action_plan
    WHERE action_plan_status = 'Future'
      AND action_plan_end_date IS NOT NULL

    UNION ALL

    SELECT
        460,
        'Lifecycle',
        'CLOSED_PLAN_HAS_NO_END_DATE',
        'ERROR',
        COUNT_BIG(*),
        'A Closed Action Plan has no end date.'
    FROM action_plan
    WHERE action_plan_status = 'Closed'
      AND action_plan_end_date IS NULL

    UNION ALL

    SELECT
        470,
        'Lifecycle',
        'CLOSED_PLAN_ENDS_IN_FUTURE',
        'ERROR',
        COUNT_BIG(*),
        'A Closed Action Plan has a future end date.'
    FROM action_plan
    WHERE action_plan_status = 'Closed'
      AND action_plan_end_date >
          CAST(GETDATE() AS date)

    UNION ALL

    SELECT
        480,
        'Lifecycle',
        'ACTION_PLAN_END_BEFORE_START',
        'ERROR',
        COUNT_BIG(*),
        'Action Plan end precedes Action Plan start.'
    FROM action_plan
    WHERE action_plan_end_date IS NOT NULL
      AND action_plan_end_date <
          action_plan_start_date

    UNION ALL

    SELECT
        490,
        'Lifecycle',
        'CLOSED_PLAN_END_DIFFERS_FROM_24_MONTH_RULE',
        'ERROR',
        COUNT_BIG(*),
        'Closed Action Plan end is not latest intervention start plus 24 months.'
    FROM action_plan
    WHERE action_plan_status = 'Closed'
      AND action_plan_end_date <>
          DATEADD
          (
              month,
              24,
              latest_intervention_start_date
          )

    UNION ALL

    SELECT
        500,
        'Lifecycle',
        'EXPIRED_PLAN_NOT_CLOSED',
        'ERROR',
        COUNT_BIG(*),
        'The 24-month end has arrived but the Action Plan is not Closed.'
    FROM action_plan
    WHERE action_plan_start_date <=
          CAST(GETDATE() AS date)
      AND DATEADD
          (
              month,
              24,
              latest_intervention_start_date
          ) <= CAST(GETDATE() AS date)
      AND action_plan_status <> 'Closed'

    UNION ALL

    SELECT
        510,
        'Lifecycle',
        'CURRENT_PLAN_NOT_OPEN',
        'ERROR',
        COUNT_BIG(*),
        'A started and unexpired Action Plan is not Open.'
    FROM action_plan
    WHERE action_plan_start_date <=
          CAST(GETDATE() AS date)
      AND DATEADD
          (
              month,
              24,
              latest_intervention_start_date
          ) > CAST(GETDATE() AS date)
      AND action_plan_status <> 'Open'

    UNION ALL

    SELECT
        520,
        'Lifecycle',
        'SEQUENTIAL_ACTION_PLANS_OVERLAP',
        'ERROR',
        COUNT_BIG(*),
        'The previous Action Plan end is after the next Action Plan start.'
    FROM action_plan_ordered
    WHERE previous_action_plan_end_date IS NOT NULL
      AND previous_action_plan_end_date >
          action_plan_start_date

    /*--------------------------------------------------------------------------
        Intervention dates
    --------------------------------------------------------------------------*/

    UNION ALL

    SELECT
        600,
        'Intervention dates',
        'ACTUAL_END_BEFORE_START',
        'ERROR',
        COUNT_BIG(*),
        'Actual intervention end precedes intervention start.'
    FROM intervention
    WHERE intervention_end_date IS NOT NULL
      AND intervention_end_date <
          intervention_start_date

    UNION ALL

    SELECT
        610,
        'Intervention dates',
        'EFFECTIVE_END_BEFORE_START',
        'ERROR',
        COUNT_BIG(*),
        'Effective intervention end precedes intervention start.'
    FROM intervention
    WHERE effective_intervention_end_date IS NOT NULL
      AND effective_intervention_end_date <
          intervention_start_date

    UNION ALL

    SELECT
        620,
        'Intervention dates',
        'EFFECTIVE_END_EXCEEDS_24_MONTHS',
        'ERROR',
        COUNT_BIG(*),
        'Effective intervention end exceeds start plus 24 months.'
    FROM intervention
    WHERE effective_intervention_end_date >
          DATEADD
          (
              month,
              24,
              intervention_start_date
          )

    UNION ALL

    SELECT
        630,
        'Intervention dates',
        'EFFECTIVE_END_MISSING_AFTER_24_MONTHS',
        'ERROR',
        COUNT_BIG(*),
        'An intervention older than 24 months has no effective end.'
    FROM intervention
    WHERE DATEADD
          (
              month,
              24,
              intervention_start_date
          ) <= CAST(GETDATE() AS date)
      AND effective_intervention_end_date IS NULL

    UNION ALL

    SELECT
        640,
        'Intervention dates',
        'EFFECTIVE_END_AFTER_ACTION_PLAN_END',
        'ERROR',
        COUNT_BIG(*),
        'Effective intervention end is later than Action Plan end.'
    FROM intervention
    WHERE action_plan_end_date IS NOT NULL
      AND effective_intervention_end_date IS NOT NULL
      AND effective_intervention_end_date >
          action_plan_end_date

    UNION ALL

    SELECT
        650,
        'Intervention dates',
        'INTERVENTION_START_AFTER_ACTION_PLAN_END',
        'ERROR',
        COUNT_BIG(*),
        'An intervention starts after its assigned Action Plan ended.'
    FROM intervention
    WHERE action_plan_end_date IS NOT NULL
      AND intervention_start_date >
          action_plan_end_date

    UNION ALL

    SELECT
        660,
        'Intervention dates',
        'CLOSED_PLAN_HAS_INTERVENTION_WITHOUT_END',
        'ERROR',
        COUNT_BIG(*),
        'A Closed Action Plan contains an intervention without an effective end.'
    FROM intervention
    WHERE action_plan_status = 'Closed'
      AND effective_intervention_end_date IS NULL

    UNION ALL

    SELECT
        670,
        'Intervention dates',
        'FUTURE_INTERVENTION_IN_NON_FUTURE_PLAN',
        'WARNING',
        COUNT_BIG(*),
        'A future intervention belongs to an Open or Closed Action Plan.'
    FROM intervention
    WHERE intervention_start_date >
          CAST(GETDATE() AS date)
      AND action_plan_status <> 'Future'

    UNION ALL

    SELECT
        680,
        'Intervention dates',
        'ACTUAL_END_EXCEEDS_24_MONTH_CAP',
        'WARNING',
        COUNT_BIG(*),
        'Actual PRISM end exceeds the current effective-end cap.'
    FROM intervention
    WHERE intervention_end_date >
          DATEADD
          (
              month,
              24,
              intervention_start_date
          )

    /*--------------------------------------------------------------------------
        Data consistency
    --------------------------------------------------------------------------*/

    UNION ALL

    SELECT
        700,
        'Consistency',
        'ACTION_PLAN_START_INCONSISTENT_ACROSS_ROWS',
        'ERROR',
        COUNT_BIG(*),
        'Rows for the same Action Plan contain different start dates.'
    FROM
    (
        SELECT
            client_id,
            action_plan_id
        FROM intervention
        GROUP BY
            client_id,
            action_plan_id
        HAVING COUNT(DISTINCT action_plan_start_date) > 1
    ) AS d

    UNION ALL

    SELECT
        710,
        'Consistency',
        'ACTION_PLAN_END_INCONSISTENT_ACROSS_ROWS',
        'ERROR',
        COUNT_BIG(*),
        'Rows for the same Action Plan contain different end dates.'
    FROM
    (
        SELECT
            client_id,
            action_plan_id
        FROM intervention
        GROUP BY
            client_id,
            action_plan_id
        HAVING COUNT(DISTINCT action_plan_end_date) > 1
    ) AS d

    UNION ALL

    SELECT
        720,
        'Consistency',
        'ACTION_PLAN_STATUS_INCONSISTENT_ACROSS_ROWS',
        'ERROR',
        COUNT_BIG(*),
        'Rows for the same Action Plan contain different statuses.'
    FROM
    (
        SELECT
            client_id,
            action_plan_id
        FROM intervention
        GROUP BY
            client_id,
            action_plan_id
        HAVING COUNT(DISTINCT action_plan_status) > 1
    ) AS d

    /*--------------------------------------------------------------------------
        Grouping risks
    --------------------------------------------------------------------------*/

    UNION ALL

    SELECT
        800,
        'Grouping risk',
        'ACTION_PLAN_SPANS_MORE_THAN_24_MONTHS',
        'WARNING',
        COUNT_BIG(*),
        'Chaining created an Action Plan spanning more than 24 months.'
    FROM action_plan
    WHERE latest_intervention_start_date >
          DATEADD
          (
              month,
              24,
              action_plan_start_date
          )

    UNION ALL

    SELECT
        810,
        'Grouping risk',
        'ACTION_PLAN_SPANS_MORE_THAN_60_MONTHS',
        'WARNING',
        COUNT_BIG(*),
        'Action Plan first-to-latest intervention span exceeds 60 months.'
    FROM action_plan
    WHERE latest_intervention_start_date >
          DATEADD
          (
              month,
              60,
              action_plan_start_date
          )

    UNION ALL

    SELECT
        820,
        'Grouping risk',
        'ACTION_PLAN_HAS_MORE_THAN_20_INTERVENTIONS',
        'WARNING',
        COUNT_BIG(*),
        'A large Action Plan may represent chained service episodes.'
    FROM action_plan
    WHERE intervention_count > 20

    UNION ALL

    SELECT
        830,
        'Grouping risk',
        'CLIENT_HAS_MORE_THAN_10_ACTION_PLANS',
        'WARNING',
        COUNT_BIG(*),
        'A client has an unusually large number of Action Plans.'
    FROM
    (
        SELECT
            client_id
        FROM action_plan
        GROUP BY client_id
        HAVING COUNT_BIG(*) > 10
    ) AS d

    UNION ALL

    SELECT
        840,
        'Grouping risk',
        'CLIENT_HAS_OPEN_AND_FUTURE_PLANS',
        'INFO',
        COUNT_BIG(*),
        'A client has a current Open plan and at least one Future plan.'
    FROM
    (
        SELECT
            client_id
        FROM action_plan
        GROUP BY client_id
        HAVING SUM
               (
                   CASE
                       WHEN action_plan_status = 'Open' THEN 1
                       ELSE 0
                   END
               ) >= 1
           AND SUM
               (
                   CASE
                       WHEN action_plan_status = 'Future' THEN 1
                       ELSE 0
                   END
               ) >= 1
    ) AS d

    /*--------------------------------------------------------------------------
        Label quality
    --------------------------------------------------------------------------*/

    UNION ALL

    SELECT
        900,
        'Labels',
        'INTERVENTION_STATUS_LABEL_MISSING',
        'WARNING',
        COUNT_BIG(*),
        'Intervention status could not be resolved to a label.'
    FROM intervention
    WHERE NULLIF(TRIM(intervention_status_label), '') IS NULL

    UNION ALL

    SELECT
        910,
        'Labels',
        'END_DATE_WITHOUT_CLOSURE_REASON',
        'WARNING',
        COUNT_BIG(*),
        'Actual end date exists but closure reason label is missing.'
    FROM intervention
    WHERE intervention_end_date IS NOT NULL
      AND NULLIF
          (
              TRIM(intervention_closure_reason_label),
              ''
          ) IS NULL

    UNION ALL

    SELECT
        920,
        'Labels',
        'CLOSURE_REASON_WITHOUT_END_DATE',
        'WARNING',
        COUNT_BIG(*),
        'Closure reason exists but actual end date is missing.'
    FROM intervention
    WHERE intervention_end_date IS NULL
      AND NULLIF
          (
              TRIM(intervention_closure_reason_label),
              ''
          ) IS NOT NULL
)

/*==============================================================================
    Final validation summary
==============================================================================*/
SELECT
    test_order,
    category,
    test_code,
    severity,
    issue_count,

    CASE
        WHEN issue_count = 0
            THEN 'PASS'

        WHEN severity = 'ERROR'
            THEN 'FAIL'

        WHEN severity = 'WARNING'
            THEN 'REVIEW'

        ELSE 'INFO'
    END
        AS test_result,

    description

FROM validation

ORDER BY
    CASE severity
        WHEN 'ERROR' THEN 1
        WHEN 'WARNING' THEN 2
        WHEN 'INFO' THEN 3
        ELSE 4
    END,
    test_order;