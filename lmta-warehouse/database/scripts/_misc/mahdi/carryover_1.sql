WITH carryovers AS
(
    SELECT
        client_id,
        intervention_id,
        intervention_title,
        intervention_start_date,
        intervention_guid
    FROM int.prism_intervention
    WHERE calculated_intervention_status = 'Closed - Carryover'
)
SELECT
    c.client_id,
    c.intervention_id,
    c.intervention_title,
    c.intervention_start_date AS carryover_start_date,

    n.next_intervention_start_date,

    DATEDIFF
    (
        day,
        c.intervention_start_date,
        n.next_intervention_start_date
    ) AS gap_days,

    CAST
    (
        DATEDIFF
        (
            day,
            c.intervention_start_date,
            n.next_intervention_start_date
        ) / 30.4375
        AS decimal(10,1)
    ) AS gap_months

FROM carryovers AS c

OUTER APPLY
(
    SELECT
        MIN(i.intervention_start_date) AS next_intervention_start_date
    FROM int.prism_intervention AS i
    WHERE i.client_id = c.client_id
      AND i.intervention_start_date > c.intervention_start_date
) AS n

ORDER BY
    c.intervention_start_date,
    c.client_id;