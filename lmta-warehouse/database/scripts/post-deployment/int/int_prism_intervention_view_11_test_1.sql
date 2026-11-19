WITH action_plans AS
(
    SELECT DISTINCT
        client_id,
        action_plan_id,
        action_plan_sequence,
        action_plan_start_date,
        action_plan_end_date,
        action_plan_status
    FROM int.prism_intervention
),
clients_with_multiple_open_plans AS
(
    SELECT
        client_id,
        COUNT(*) AS open_action_plan_count
    FROM action_plans
    WHERE action_plan_status = 'Open'
    GROUP BY client_id
    HAVING COUNT(*) > 1
)
SELECT
    ap.client_id,
    c.open_action_plan_count,
    ap.action_plan_id,
    ap.action_plan_sequence,
    ap.action_plan_start_date,
    ap.action_plan_end_date,
    ap.action_plan_status
FROM action_plans AS ap
INNER JOIN clients_with_multiple_open_plans AS c
    ON c.client_id = ap.client_id
WHERE ap.action_plan_status = 'Open'
ORDER BY
    ap.client_id,
    ap.action_plan_sequence;