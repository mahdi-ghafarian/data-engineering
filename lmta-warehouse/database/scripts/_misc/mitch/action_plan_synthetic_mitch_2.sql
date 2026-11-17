WITH interventions_raw AS (
    SELECT DISTINCT
        [Client ID],
        [Consent Date],
        [Intervention GUID],
        [Intervention Type],
        [Start Date],
        [Closure Date]
    FROM ict_dl2.[Mitch].[client_360]
    WHERE [Client ID] = 'ICT-CLT-039171'
      AND [Intervention GUID] IS NOT NULL
      AND [Start Date] IS NOT NULL
),
interventions AS (
    SELECT
        *,
        CASE
            WHEN [Closure Date] IS NOT NULL THEN [Closure Date]
            WHEN DATEADD(year, 1, [Start Date]) <= CAST(GETDATE() AS date) THEN DATEADD(year, 1, [Start Date])
            ELSE NULL
        END AS [Effective Intervention End],
        CASE
            WHEN [Closure Date] IS NOT NULL THEN 'Closed'
            WHEN DATEADD(year, 1, [Start Date]) <= CAST(GETDATE() AS date) THEN 'Inferred Closed'
            ELSE 'Open'
        END AS [Intervention Status]
    FROM interventions_raw
),
prior_state AS (
    SELECT
        current_i.[Client ID],
        current_i.[Consent Date],
        current_i.[Intervention GUID],
        current_i.[Intervention Type],
        current_i.[Start Date],
        current_i.[Closure Date],
        current_i.[Effective Intervention End],
        current_i.[Intervention Status],
        COUNT(prior_i.[Intervention GUID]) AS [Prior Intervention Count],
        SUM(
            CASE
                WHEN prior_i.[Intervention GUID] IS NOT NULL
                 AND prior_i.[Effective Intervention End] IS NULL THEN 1
                ELSE 0
            END
        ) AS [Prior Open Intervention Count],
        MAX(prior_i.[Effective Intervention End]) AS [Latest Prior Intervention End]
    FROM interventions current_i
    LEFT JOIN interventions prior_i
        ON prior_i.[Client ID] = current_i.[Client ID]
       AND (
            prior_i.[Start Date] < current_i.[Start Date]
            OR (
                prior_i.[Start Date] = current_i.[Start Date]
                AND prior_i.[Intervention GUID] < current_i.[Intervention GUID]
            )
       )
    GROUP BY
        current_i.[Client ID],
        current_i.[Consent Date],
        current_i.[Intervention GUID],
        current_i.[Intervention Type],
        current_i.[Start Date],
        current_i.[Closure Date],
        current_i.[Effective Intervention End],
        current_i.[Intervention Status]
),
episode_boundaries AS (
    SELECT
        *,
        CASE
            WHEN [Prior Intervention Count] = 0 THEN 1
            WHEN [Prior Open Intervention Count] > 0 THEN 0
            WHEN [Start Date] > DATEADD(month, 6, [Latest Prior Intervention End]) THEN 1
            ELSE 0
        END AS [Starts New Action Plan]
    FROM prior_state
),
numbered_interventions AS (
    SELECT
        *,
        SUM([Starts New Action Plan]) OVER (
            PARTITION BY [Client ID]
            ORDER BY [Start Date], [Intervention GUID]
            ROWS UNBOUNDED PRECEDING
        ) AS [Action Plan Number]
    FROM episode_boundaries
),
action_plan_summary AS (
    SELECT
        [Client ID],
        [Action Plan Number],
        MIN([Start Date]) AS [Action Plan Start],
        MAX([Effective Intervention End]) AS [Last Intervention End],
        SUM(
            CASE
                WHEN [Effective Intervention End] IS NULL THEN 1
                ELSE 0
            END
        ) AS [Open Intervention Count],
        SUM(
            CASE
                WHEN [Intervention Status] = 'Inferred Closed' THEN 1
                ELSE 0
            END
        ) AS [Inferred Closed Intervention Count]
    FROM numbered_interventions
    GROUP BY
        [Client ID],
        [Action Plan Number]
),
action_plan_first_intervention AS (
    SELECT
        [Client ID],
        [Action Plan Number],
        [Intervention GUID] AS [First Intervention GUID]
    FROM (
        SELECT
            [Client ID],
            [Action Plan Number],
            [Intervention GUID],
            ROW_NUMBER() OVER (
                PARTITION BY [Client ID], [Action Plan Number]
                ORDER BY [Start Date], [Intervention GUID]
            ) AS rn
        FROM numbered_interventions
    ) x
    WHERE rn = 1
),
action_plans AS (
    SELECT
        CONVERT(
            varchar(64),
            HASHBYTES(
                'SHA2_256',
                CONCAT(
                    s.[Client ID],
                    '|',
                    CONVERT(varchar(10), s.[Action Plan Start], 23),
                    '|',
                    f.[First Intervention GUID]
                )
            ),
            2
        ) AS [LMTA Action Plan ID],
        s.[Client ID],
        s.[Action Plan Number],
        s.[Action Plan Start],
        s.[Last Intervention End],
        s.[Open Intervention Count],
        s.[Inferred Closed Intervention Count],
        CASE
            WHEN s.[Open Intervention Count] = 0
             AND DATEADD(month, 6, s.[Last Intervention End]) <= CAST(GETDATE() AS date)
             AND s.[Inferred Closed Intervention Count] > 0 THEN 'Closed (Inferred)'
            WHEN s.[Open Intervention Count] = 0
             AND DATEADD(month, 6, s.[Last Intervention End]) <= CAST(GETDATE() AS date) THEN 'Closed'
            ELSE 'Open'
        END AS [Action Plan Status],
        CASE
            WHEN s.[Open Intervention Count] = 0
             AND DATEADD(month, 6, s.[Last Intervention End]) <= CAST(GETDATE() AS date)
                THEN DATEADD(month, 6, s.[Last Intervention End])
            ELSE NULL
        END AS [Action Plan End],
        CASE
            WHEN s.[Last Intervention End] IS NOT NULL
                THEN DATEADD(month, 6, s.[Last Intervention End])
            ELSE NULL
        END AS [Pending Closure Date]
    FROM action_plan_summary s
    INNER JOIN action_plan_first_intervention f
        ON f.[Client ID] = s.[Client ID]
       AND f.[Action Plan Number] = s.[Action Plan Number]
)
SELECT
    i.[Client ID],
    ap.[LMTA Action Plan ID],
    ap.[Action Plan Start],
    ap.[Action Plan End],
    ap.[Pending Closure Date],
    ap.[Action Plan Status],
    i.[Intervention GUID] AS [Intervention ID],
    i.[Intervention Type] AS [PRISM Intervention Type],
    i.[Start Date] AS [Intervention Start],
    i.[Closure Date] AS [Intervention End],
    i.[Effective Intervention End] AS [Inferred End],
    i.[Intervention Status]
FROM numbered_interventions i
INNER JOIN action_plans ap
    ON ap.[Client ID] = i.[Client ID]
   AND ap.[Action Plan Number] = i.[Action Plan Number]
ORDER BY
    i.[Client ID] DESC,
    ap.[Action Plan Start] DESC,
    i.[Start Date] DESC,
    i.[Intervention GUID];