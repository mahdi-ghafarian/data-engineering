/*
Client,	Action Plans,	Total interventions,	Interventions per Action Plan,	Why useful
ICT-CLT-021649	3	6	2, 2, 2	Best balanced case
ICT-CLT-000085	3	6	3, 2, 1	Multiple interventions in first two plans
ICT-CLT-000192	3	6	3, 2, 1	Good closed-to-open sequence
ICT-CLT-011441	3	6	1, 4, 1	Best case for many interventions in one middle plan
ICT-CLT-000169	3	5	1, 2, 2	Multiple interventions in later plans
ICT-CLT-000785	3	5	1, 2, 2	Similar, with an open third plan
ICT-CLT-002691	3	5	1, 3, 1	Three interventions in the middle plan
*/

WITH action_plans AS
(
    SELECT
        client_id,
        action_plan_id,
        COUNT(*) AS intervention_count
    FROM int.intervention_prism
    GROUP BY
        client_id,
        action_plan_id
),
client_summary AS
(
    SELECT
        client_id,
        COUNT(*) AS action_plan_count,
        SUM(intervention_count) AS total_intervention_count,
        MIN(intervention_count) AS minimum_interventions_per_plan,
        MAX(intervention_count) AS maximum_interventions_per_plan,
        SUM
        (
            CASE
                WHEN intervention_count >= 2 THEN 1
                ELSE 0
            END
        ) AS plans_with_multiple_interventions
    FROM action_plans
    GROUP BY client_id
)
SELECT TOP (100)
    client_id,
    action_plan_count,
    total_intervention_count,
    plans_with_multiple_interventions,
    minimum_interventions_per_plan,
    maximum_interventions_per_plan
FROM client_summary
WHERE action_plan_count >= 2
  AND plans_with_multiple_interventions >= 2
ORDER BY
    action_plan_count DESC,
    plans_with_multiple_interventions DESC,
    minimum_interventions_per_plan DESC,
    total_intervention_count DESC,
    client_id;

