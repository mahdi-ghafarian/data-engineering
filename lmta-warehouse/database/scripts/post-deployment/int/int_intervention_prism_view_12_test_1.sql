WITH action_plans AS
(
    SELECT DISTINCT
        client_id,
        action_plan_id,
        action_plan_sequence,
        action_plan_start_date,
        action_plan_end_date,
        action_plan_status

    FROM int.intervention_prism
)
SELECT
    client_id,
    COUNT(*) AS open_action_plan_count
FROM action_plans
WHERE action_plan_status = 'Open'
GROUP BY client_id
HAVING COUNT(*) > 1
ORDER BY
    open_action_plan_count DESC,
    client_id;