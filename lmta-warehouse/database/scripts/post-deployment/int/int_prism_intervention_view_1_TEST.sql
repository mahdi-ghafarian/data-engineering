/*==============================================================================
    LMTA PRISM ACTION PLAN / INTERVENTION VALIDATION

    Object tested:
        int.prism_intervention

    Expected columns:
        intervention_guid
        action_plan_id
        client_id
        action_plan_status
        action_plan_start_date
        intervention_start_date
        is_intervention_closed

    Tests:
        1. Each intervention_guid appears exactly once.
        2. Each intervention belongs to exactly one action_plan_id.
        3. Every action_plan_id contains at least one intervention.
        4. A client has no more than one open Action Plan.
        5. action_plan_start_date <= intervention_start_date.
        6. A closed Action Plan has no intervention considered open.

    Important:
        Test 3 is naturally satisfied when testing only an intervention-grain view,
        because an action_plan_id cannot appear in this view without an intervention.
        The test also checks for NULL action_plan_id values. Once a separate
        int.prism_action_plan view exists, use the stronger parent-to-child test
        included at the end of this script.

    /*
    With only int.prism_intervention, Test 3 is logically guaranteed for 
    every non-null action_plan_id, because the plan appears only through 
    an intervention row. The federal hierarchy nevertheless requires every 
    Action Plan to have at least one intervention.
    */

    SELECT
        ap.client_id,
        ap.action_plan_id,
        ap.action_plan_start_date
    FROM int.prism_action_plan AS ap
    LEFT JOIN int.prism_intervention AS i
        ON i.client_id = ap.client_id
    AND i.action_plan_id = ap.action_plan_id
    WHERE i.intervention_guid IS NULL
    ORDER BY
        ap.client_id,
        ap.action_plan_start_date,
        ap.action_plan_id;

==============================================================================*/

SET NOCOUNT ON;


/*==============================================================================
    SUMMARY RESULTS
==============================================================================*/

WITH
test_01_failures AS
(
    SELECT
        intervention_guid
    FROM int.prism_intervention
    GROUP BY
        intervention_guid
    HAVING intervention_guid IS NULL
        OR COUNT(*) <> 1
),

test_02_failures AS
(
    SELECT
        intervention_guid
    FROM int.prism_intervention
    GROUP BY
        intervention_guid
    HAVING intervention_guid IS NULL
        OR COUNT(DISTINCT action_plan_id) <> 1
        OR MAX
           (
               CASE
                   WHEN action_plan_id IS NULL THEN 1
                   ELSE 0
               END
           ) = 1
),

test_03_failures AS
(
    /*
        In an intervention-grain view, an action_plan_id necessarily has at
        least one intervention row. Therefore, the meaningful failure available
        here is an intervention with no assigned action_plan_id.
    */
    SELECT
        intervention_guid
    FROM int.prism_intervention
    WHERE action_plan_id IS NULL
),

action_plan_state AS
(
    SELECT
        client_id,
        action_plan_id,

        MAX
        (
            CASE
                WHEN action_plan_status = 'Open' THEN 1
                ELSE 0
            END
        ) AS is_action_plan_open

    FROM int.prism_intervention
    GROUP BY
        client_id,
        action_plan_id
),

test_04_failures AS
(
    SELECT
        client_id
    FROM action_plan_state
    WHERE is_action_plan_open = 1
    GROUP BY
        client_id
    HAVING COUNT(DISTINCT action_plan_id) > 1
),

test_05_failures AS
(
    SELECT
        intervention_guid
    FROM int.prism_intervention
    WHERE action_plan_start_date IS NULL
       OR intervention_start_date IS NULL
       OR action_plan_start_date > intervention_start_date
),

action_plan_closure_state AS
(
    SELECT
        client_id,
        action_plan_id,

        MAX
        (
            CASE
                WHEN action_plan_status = 'Open' THEN 1
                ELSE 0
            END
        ) AS has_open_action_plan_status,

        MAX
        (
            CASE
                WHEN COALESCE(is_intervention_closed, 0) = 0 THEN 1
                ELSE 0
            END
        ) AS has_open_intervention

    FROM int.prism_intervention
    GROUP BY
        client_id,
        action_plan_id
),

test_06_failures AS
(
    SELECT
        client_id,
        action_plan_id
    FROM action_plan_closure_state
    WHERE has_open_action_plan_status = 0
      AND has_open_intervention = 1
)

SELECT
    1 AS test_number,
    CAST
    (
        'Each intervention_guid appears exactly once'
        AS varchar(200)
    ) AS test_name,
    COUNT_BIG(*) AS failure_count,
    CASE
        WHEN COUNT_BIG(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM test_01_failures

UNION ALL

SELECT
    2,
    CAST
    (
        'Each intervention belongs to exactly one action_plan_id'
        AS varchar(200)
    ),
    COUNT_BIG(*),
    CASE
        WHEN COUNT_BIG(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM test_02_failures

UNION ALL

SELECT
    3,
    CAST
    (
        'Every intervention has an action_plan_id'
        AS varchar(200)
    ),
    COUNT_BIG(*),
    CASE
        WHEN COUNT_BIG(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM test_03_failures

UNION ALL

SELECT
    4,
    CAST
    (
        'A client has no more than one open Action Plan'
        AS varchar(200)
    ),
    COUNT_BIG(*),
    CASE
        WHEN COUNT_BIG(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM test_04_failures

UNION ALL

SELECT
    5,
    CAST
    (
        'action_plan_start_date is on or before intervention_start_date'
        AS varchar(200)
    ),
    COUNT_BIG(*),
    CASE
        WHEN COUNT_BIG(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM test_05_failures

UNION ALL

SELECT
    6,
    CAST
    (
        'A closed Action Plan contains no open intervention'
        AS varchar(200)
    ),
    COUNT_BIG(*),
    CASE
        WHEN COUNT_BIG(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM test_06_failures

ORDER BY
    test_number;


/*==============================================================================
    TEST 1 DETAILS
    Each intervention_guid must appear exactly once.
==============================================================================*/

SELECT
    intervention_guid,
    COUNT_BIG(*) AS row_count,
    COUNT(DISTINCT action_plan_id) AS action_plan_count,
    MIN(client_id) AS first_client_id,
    MAX(client_id) AS last_client_id
FROM int.prism_intervention
GROUP BY
    intervention_guid
HAVING intervention_guid IS NULL
    OR COUNT_BIG(*) <> 1
ORDER BY
    row_count DESC,
    intervention_guid;


/*==============================================================================
    TEST 2 DETAILS
    Each intervention must belong to exactly one Action Plan.

    This test is kept separate from Test 1 because a duplicated intervention
    could either:
        - repeat under the same action_plan_id; or
        - appear under multiple action_plan_id values.
==============================================================================*/

SELECT
    intervention_guid,
    COUNT_BIG(*) AS row_count,
    COUNT(DISTINCT action_plan_id) AS action_plan_count,
    MIN(action_plan_id) AS first_action_plan_id,
    MAX(action_plan_id) AS last_action_plan_id
FROM int.prism_intervention
GROUP BY
    intervention_guid
HAVING intervention_guid IS NULL
    OR COUNT(DISTINCT action_plan_id) <> 1
    OR MAX
       (
           CASE
               WHEN action_plan_id IS NULL THEN 1
               ELSE 0
           END
       ) = 1
ORDER BY
    intervention_guid;


/*==============================================================================
    TEST 3 DETAILS
    Within this intervention-grain view, verify that every intervention has a
    parent action_plan_id.

    A stronger Action Plan-without-intervention test requires a separate
    Action Plan parent dataset.
==============================================================================*/

SELECT
    client_id,
    intervention_guid,
    intervention_type,
    intervention_id,
    intervention_start_date,
    action_plan_id
FROM int.prism_intervention
WHERE action_plan_id IS NULL
ORDER BY
    client_id,
    intervention_start_date,
    intervention_guid;


/*==============================================================================
    TEST 4 DETAILS
    A client must not have more than one open Action Plan.

    An Action Plan is treated as open when at least one row belonging to that
    Action Plan has action_plan_status = 'Open'.
==============================================================================*/

WITH action_plan_state AS
(
    SELECT
        client_id,
        action_plan_id,
        MIN(action_plan_start_date) AS action_plan_start_date,

        MAX
        (
            CASE
                WHEN action_plan_status = 'Open' THEN 1
                ELSE 0
            END
        ) AS is_action_plan_open

    FROM int.prism_intervention
    GROUP BY
        client_id,
        action_plan_id
),

clients_with_multiple_open_plans AS
(
    SELECT
        client_id
    FROM action_plan_state
    WHERE is_action_plan_open = 1
    GROUP BY
        client_id
    HAVING COUNT(DISTINCT action_plan_id) > 1
)

SELECT
    aps.client_id,
    aps.action_plan_id,
    aps.action_plan_start_date,
    aps.is_action_plan_open,
    COUNT(*) OVER
    (
        PARTITION BY aps.client_id
    ) AS open_action_plan_count
FROM action_plan_state AS aps
INNER JOIN clients_with_multiple_open_plans AS f
    ON f.client_id = aps.client_id
WHERE aps.is_action_plan_open = 1
ORDER BY
    aps.client_id,
    aps.action_plan_start_date,
    aps.action_plan_id;


/*==============================================================================
    TEST 5 DETAILS
    The Action Plan cannot begin after one of its interventions.

    NULL dates are also treated as failures because the chronological rule
    cannot be proven when either date is absent.
==============================================================================*/

SELECT
    client_id,
    action_plan_id,
    intervention_guid,
    intervention_type,
    action_plan_start_date,
    intervention_start_date,

    CASE
        WHEN action_plan_start_date IS NULL
            THEN 'Missing action_plan_start_date'

        WHEN intervention_start_date IS NULL
            THEN 'Missing intervention_start_date'

        WHEN action_plan_start_date > intervention_start_date
            THEN 'Action Plan starts after intervention'

        ELSE 'Unknown'
    END AS failure_reason

FROM int.prism_intervention
WHERE action_plan_start_date IS NULL
   OR intervention_start_date IS NULL
   OR action_plan_start_date > intervention_start_date
ORDER BY
    client_id,
    action_plan_id,
    intervention_start_date,
    intervention_guid;


/*==============================================================================
    TEST 6 DETAILS
    A closed Action Plan must not contain an open intervention.

    Plan-level interpretation:
        - If any row says the plan is Open, the plan is treated as Open.
        - The plan is treated as Closed only when no row says Open.
        - Within that closed plan, every intervention must have
          is_intervention_closed = 1.

    COALESCE treats NULL is_intervention_closed as not proven closed.
==============================================================================*/

WITH action_plan_closure_state AS
(
    SELECT
        client_id,
        action_plan_id,
        MIN(action_plan_start_date) AS action_plan_start_date,

        MAX
        (
            CASE
                WHEN action_plan_status = 'Open' THEN 1
                ELSE 0
            END
        ) AS has_open_action_plan_status,

        MAX
        (
            CASE
                WHEN COALESCE(is_intervention_closed, 0) = 0 THEN 1
                ELSE 0
            END
        ) AS has_open_intervention

    FROM int.prism_intervention
    GROUP BY
        client_id,
        action_plan_id
),

invalid_closed_plans AS
(
    SELECT
        client_id,
        action_plan_id
    FROM action_plan_closure_state
    WHERE has_open_action_plan_status = 0
      AND has_open_intervention = 1
)

SELECT
    i.client_id,
    i.action_plan_id,
    i.action_plan_status,
    i.action_plan_start_date,
    i.intervention_guid,
    i.intervention_type,
    i.intervention_id,
    i.intervention_start_date,
    i.intervention_end_date,
    i.intervention_status_code,
    i.intervention_status_label,
    i.is_intervention_closed
FROM int.prism_intervention AS i
INNER JOIN invalid_closed_plans AS f
    ON f.client_id = i.client_id
   AND f.action_plan_id = i.action_plan_id
WHERE COALESCE(i.is_intervention_closed, 0) = 0
ORDER BY
    i.client_id,
    i.action_plan_id,
    i.intervention_start_date,
    i.intervention_guid;