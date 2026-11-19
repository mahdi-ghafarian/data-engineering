/*
Purpose
-------
Measure how long after a Carryover intervention the client's
next DISTINCT intervention starts.

The output shows the cumulative percentage of carryovers captured
by different candidate start-date thresholds.

Use this to evaluate whether a natural threshold exists around
3, 6, 9, 12, 15, 18, 24, etc. months.
*/

WITH carryovers AS
(
    SELECT
        client_id,
        intervention_id,
        intervention_start_date
    FROM int.prism_intervention
    WHERE calculated_intervention_status = 'Closed - Carryover'
      AND intervention_start_date IS NOT NULL
),

carryover_gaps AS
(
    SELECT
        c.client_id,
        c.intervention_id,
        c.intervention_start_date AS carryover_start_date,
        n.next_intervention_start_date,

        DATEDIFF
        (
            DAY,
            c.intervention_start_date,
            n.next_intervention_start_date
        ) AS gap_days

    FROM carryovers AS c

    OUTER APPLY
    (
        SELECT
            MIN(i.intervention_start_date) AS next_intervention_start_date
        FROM int.prism_intervention AS i
        WHERE i.client_id = c.client_id
          AND i.intervention_start_date > c.intervention_start_date
    ) AS n
),

thresholds AS
(
    SELECT  1 AS threshold_months
    UNION ALL SELECT  2
    UNION ALL SELECT  3
    UNION ALL SELECT  6
    UNION ALL SELECT  9
    UNION ALL SELECT 12
    UNION ALL SELECT 15
    UNION ALL SELECT 18
    UNION ALL SELECT 24
    UNION ALL SELECT 30
    UNION ALL SELECT 36
),

summary AS
(
    SELECT
        t.threshold_months,

        COUNT(*) AS carryovers_with_later_intervention,

        SUM
        (
            CASE
                WHEN g.next_intervention_start_date
                     <= DATEADD
                        (
                            MONTH,
                            t.threshold_months,
                            g.carryover_start_date
                        )
                THEN 1
                ELSE 0
            END
        ) AS within_threshold

    FROM carryover_gaps AS g

    CROSS JOIN thresholds AS t

    WHERE g.next_intervention_start_date IS NOT NULL

    GROUP BY
        t.threshold_months
)

SELECT
    threshold_months,

    carryovers_with_later_intervention,

    within_threshold,

    carryovers_with_later_intervention
        - within_threshold
        AS beyond_threshold,

    CAST
    (
        100.0 * within_threshold
        / NULLIF(carryovers_with_later_intervention, 0)
        AS DECIMAL(6,2)
    ) AS pct_within_threshold

FROM summary

ORDER BY
    threshold_months;