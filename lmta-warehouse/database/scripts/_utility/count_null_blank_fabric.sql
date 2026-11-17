/*
===============================================================================
FABRIC WAREHOUSE: NULL / BLANK PROFILE FOR ALL TEXT COLUMNS
===============================================================================

Returns one result table with one row per character column.

Blank:
    A non-NULL value containing only ordinary spaces, tabs,
    carriage returns, line feeds, or non-breaking spaces.

Validation:
    total_rows = null_rows + blank_rows + populated_rows
===============================================================================
*/

DECLARE @SchemaName varchar(128) = 'dbo';
DECLARE @TableName  varchar(128) = 'ICT_PGM_TBL_001';

DECLARE @ObjectID int;
DECLARE @ColumnID int = 0;
DECLARE @ColumnName sysname;
DECLARE @QualifiedTable nvarchar(300);
DECLARE @NormalizedValue nvarchar(max);
DECLARE @SQL nvarchar(max) = N'';


/* Resolve the table */

SET @QualifiedTable =
    QUOTENAME(@SchemaName)
    + N'.'
    + QUOTENAME(@TableName);


SELECT
    @ObjectID = t.object_id
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = @SchemaName
  AND t.name = @TableName;


IF @ObjectID IS NULL
BEGIN
    THROW 50001, 'Table not found.', 1;
END;


/* Build one SELECT per character column */

WHILE 1 = 1
BEGIN
    SET @ColumnName = NULL;

    SELECT TOP (1)
        @ColumnID = c.column_id,
        @ColumnName = c.name
    FROM sys.columns AS c
    INNER JOIN sys.types AS ty
        ON ty.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectID
      AND c.column_id > @ColumnID
      AND ty.name IN
      (
          'char',
          'varchar',
          'nchar',
          'nvarchar'
      )
    ORDER BY c.column_id;


    IF @ColumnName IS NULL
        BREAK;


    /*
        Normalize whitespace while preserving Unicode.
    */

    SET @NormalizedValue =
        N'NULLIF(
            TRIM(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                CAST(' + QUOTENAME(@ColumnName) + N' AS nvarchar(4000)),
                                NCHAR(9),
                                N''''
                            ),
                            NCHAR(10),
                            N''''
                        ),
                        NCHAR(13),
                        N''''
                    ),
                    NCHAR(160),
                    N''''
                )
            ),
            N''''
        )';


    IF @SQL <> N''
    BEGIN
        SET @SQL += N'
UNION ALL
';
    END;


    SET @SQL +=
        N'
SELECT
    '
        + CAST(@ColumnID AS nvarchar(20))
        + N' AS column_order,

    N'''
        + REPLACE(@ColumnName, '''', '''''')
        + N''' AS column_name,

    COUNT_BIG(*) AS total_rows,

    SUM(
        CASE
            WHEN ' + QUOTENAME(@ColumnName) + N' IS NULL
            THEN CAST(1 AS bigint)
            ELSE CAST(0 AS bigint)
        END
    ) AS null_rows,

    SUM(
        CASE
            WHEN ' + QUOTENAME(@ColumnName) + N' IS NOT NULL
             AND ' + @NormalizedValue + N' IS NULL
            THEN CAST(1 AS bigint)
            ELSE CAST(0 AS bigint)
        END
    ) AS blank_rows,

    SUM(
        CASE
            WHEN ' + QUOTENAME(@ColumnName) + N' IS NOT NULL
             AND ' + @NormalizedValue + N' IS NOT NULL
            THEN CAST(1 AS bigint)
            ELSE CAST(0 AS bigint)
        END
    ) AS populated_rows

FROM ' + @QualifiedTable;
END;


/* Ensure character columns were found */

IF @SQL = N''
BEGIN
    THROW 50002, 'No character columns found.', 1;
END;


/* Add percentages and validation */

SET @SQL =
    N'
SELECT
    column_name,
    total_rows,

    null_rows,
    CAST(
        100.0 * null_rows
        / NULLIF(total_rows, 0)
        AS decimal(7,2)
    ) AS null_pct,

    blank_rows,
    CAST(
        100.0 * blank_rows
        / NULLIF(total_rows, 0)
        AS decimal(7,2)
    ) AS blank_pct,

    populated_rows,
    CAST(
        100.0 * populated_rows
        / NULLIF(total_rows, 0)
        AS decimal(7,2)
    ) AS populated_pct,

    CASE
        WHEN total_rows =
             null_rows + blank_rows + populated_rows
        THEN ''PASS''
        ELSE ''FAIL''
    END AS validation_status

FROM
(
'
    + @SQL
    + N'
) AS profile

ORDER BY column_order;';


EXEC sys.sp_executesql @SQL;