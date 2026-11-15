/*
    Works for Fabric but not for Dataverse because of the THROW and EXEC commands
    Tested with Visual Studio Code
*/

DECLARE @SchemaName SYSNAME = N'stg';
DECLARE @TableName  SYSNAME = N'prism_clt_contact';

DECLARE @Sql NVARCHAR(MAX);

SELECT @Sql =
    N'SELECT ' +
    STRING_AGG(
        CAST(
            N'COUNT_BIG(' + QUOTENAME(c.name) + N') AS ' + QUOTENAME(c.name)
            AS NVARCHAR(MAX)
        ),
        N', '
    ) +
    N' FROM ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)
FROM sys.columns AS c
JOIN sys.tables AS t
    ON t.object_id = c.object_id
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = @SchemaName
  AND t.name = @TableName;

IF @Sql IS NULL
    THROW 50000, 'Table not found or table has no visible columns.', 1;

EXEC sys.sp_executesql @Sql;