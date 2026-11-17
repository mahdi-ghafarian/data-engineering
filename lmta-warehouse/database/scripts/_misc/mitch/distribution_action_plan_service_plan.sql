SELECT
    CASE
        WHEN ap_cnt > 0 AND sp_cnt > 0 THEN 'Both'
        WHEN ap_cnt > 0 THEN 'Action Plan only'
        WHEN sp_cnt > 0 THEN 'Service Plan only'
        ELSE 'Other / none'
    END AS [Combination],

    CASE
        WHEN ap_cnt = 0 THEN '0'
        WHEN ap_cnt = 1 THEN '1'
        ELSE '2+'
    END AS [Action Plans],

    CASE
        WHEN sp_cnt = 0 THEN '0'
        WHEN sp_cnt = 1 THEN '1'
        ELSE '2+'
    END AS [Service Plans],

    COUNT(*) AS [Clients],
    SUM(ap_cnt) AS [Total Action Plans],
    SUM(sp_cnt) AS [Total Service Plans],
    MAX(ap_cnt) AS [Max AP per Client],
    MAX(sp_cnt) AS [Max SP per Client]

FROM (
    SELECT
        [Client ID],

        COUNT(DISTINCT CASE
            WHEN [Intervention Type] = 'Action Plan'
            THEN [Intervention GUID]
        END) AS ap_cnt,

        COUNT(DISTINCT CASE
            WHEN [Intervention Type] = 'Service Plan'
            THEN [Intervention GUID]
        END) AS sp_cnt

    FROM ict_dl2.[Mitch].[client_360]

    WHERE [Client ID] IS NOT NULL

    GROUP BY [Client ID]
) x

GROUP BY
    CASE
        WHEN ap_cnt > 0 AND sp_cnt > 0 THEN 'Both'
        WHEN ap_cnt > 0 THEN 'Action Plan only'
        WHEN sp_cnt > 0 THEN 'Service Plan only'
        ELSE 'Other / none'
    END,

    CASE
        WHEN ap_cnt = 0 THEN '0'
        WHEN ap_cnt = 1 THEN '1'
        ELSE '2+'
    END,

    CASE
        WHEN sp_cnt = 0 THEN '0'
        WHEN sp_cnt = 1 THEN '1'
        ELSE '2+'
    END

ORDER BY
    [Combination],
    [Action Plans],
    [Service Plans];