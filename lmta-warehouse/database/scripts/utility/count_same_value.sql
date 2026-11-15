DECLARE @SchemaName sysname = 'stg';
DECLARE @TableName  sysname = 'prism_clt_ict_actionplan';
DECLARE @SQL        nvarchar(max);

SELECT @SQL =
    STRING_AGG(
        CAST(
            'SELECT ' +
            QUOTENAME(c.name, '''') + ' AS column_name, ' +
            'COUNT_BIG(*) AS row_count, ' +
            'COUNT(DISTINCT COALESCE(' +
                'CONVERT(nvarchar(4000), ' + QUOTENAME(c.name) + '), ' +
                '''<NULL>'')) AS distinct_value_count, ' +
            'MIN(CONVERT(nvarchar(4000), ' + QUOTENAME(c.name) + ')) ' +
                'AS constant_value ' +
            'FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ' ' +
            'HAVING COUNT(DISTINCT COALESCE(' +
                'CONVERT(nvarchar(4000), ' + QUOTENAME(c.name) + '), ' +
                '''<NULL>'')) = 1'
            AS nvarchar(max)
        ),
        ' UNION ALL '
    )
FROM sys.columns AS c
INNER JOIN sys.tables AS t
    ON t.object_id = c.object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = @SchemaName
  AND t.name = @TableName
  AND c.is_computed = 0;

IF @SQL IS NULL
    THROW 50001, 'The specified table was not found.', 1;

EXEC sys.sp_executesql @SQL;