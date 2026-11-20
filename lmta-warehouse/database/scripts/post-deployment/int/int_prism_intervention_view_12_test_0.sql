select * from int.intervention_prism
-- where client_id = 'ICT-CLT-033743' -- 24 years intervention
-- where client_id = 'ICT-CLT-021649' -- multiple action plans and interventions
where client_id = 'ICT-CLT-010723' -- carryover
order by action_plan_id, intervention_start_date