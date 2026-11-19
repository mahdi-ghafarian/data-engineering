SELECT
    client_id,
    COUNT(DISTINCT action_plan_id) AS open_action_plan_count
FROM int.prism_intervention
WHERE action_plan_status = 'Open'
GROUP BY client_id
HAVING COUNT(DISTINCT action_plan_id) > 1
ORDER BY
    open_action_plan_count DESC,
    client_id;