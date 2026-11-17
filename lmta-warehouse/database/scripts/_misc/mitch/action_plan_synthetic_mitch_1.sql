WITH interventions AS (
    SELECT DISTINCT
        [Client ID],
        [Consent Date],
        [Intervention GUID],
        [Intervention Type],
        [Start Date],
        [Closure Date]
    FROM ict_dl2.[Mitch].[client_360]
    WHERE [Client ID] = 'ICT-CLT-039171'
),
prior_activity AS (
    SELECT
        i.*,
        MAX(i.[Closure Date]) OVER (
            PARTITION BY i.[Client ID]
            ORDER BY i.[Start Date], i.[Intervention GUID]
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS [Latest Prior Closure Date]
    FROM interventions i
),
episode_boundaries AS (
    SELECT
        *,
        CASE
            WHEN [Latest Prior Closure Date] IS NULL THEN 1
            WHEN [Start Date] > DATEADD(month, 6, [Latest Prior Closure Date]) THEN 1
            ELSE 0
        END AS [Starts New Action Plan]
    FROM prior_activity
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
        MAX([Closure Date]) AS [Last Intervention End]
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
        s.[Last Intervention End]
    FROM action_plan_summary s
    INNER JOIN action_plan_first_intervention f
        ON f.[Client ID] = s.[Client ID]
       AND f.[Action Plan Number] = s.[Action Plan Number]
)
SELECT
    i.[Client ID],
    ap.[LMTA Action Plan ID],
    ap.[Action Plan Start],
    DATEADD(month, 6, ap.[Last Intervention End]) AS [Action Plan End],
    i.[Intervention GUID] AS [Intervention ID],
    i.[Intervention Type] AS [PRISM Intervention Type],
    i.[Start Date] AS [Intervention Start],
    i.[Closure Date] AS [Intervention End]
FROM numbered_interventions i
INNER JOIN action_plans ap
    ON ap.[Client ID] = i.[Client ID]
   AND ap.[Action Plan Number] = i.[Action Plan Number]
ORDER BY
    i.[Client ID],
    ap.[Action Plan Start] desc,
    i.[Start Date] desc,
    i.[Intervention GUID];