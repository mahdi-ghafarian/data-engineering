/*
===============================================================================
DATAVERSE NULL / BLANK PROFILER QUERY GENERATOR
===============================================================================

PARAMETERS

@TableName:
    Required Dataverse table logical name.

@ColumnName:
    NULL        = profile all text columns
    column name = profile only that column

EXAMPLES

All text columns:
    DECLARE @TableName  varchar(128) = 'contact';
    DECLARE @ColumnName varchar(128) = NULL;

One column only:
    DECLARE @TableName  varchar(128) = 'contact';
    DECLARE @ColumnName varchar(128) = 'address1_city';

OUTPUT OF GENERATED PROFILER

    column_name
    total_rows
    null_rows
    null_pct
    blank_rows
    blank_pct
    populated_rows
    populated_pct

Percentages are returned as text with exactly 1 decimal place.
===============================================================================
*/


DECLARE @TableName  varchar(128) = 'ict_occupation';
DECLARE @ColumnName varchar(128) = 'ict_noccode';


/*
Example for one column:

DECLARE @TableName  varchar(128) = 'ict_occupation';
DECLARE @ColumnName varchar(128) = 'ict_name';

*/


SELECT
    STRING_AGG(

        CAST(

            'SELECT '


            /* ===============================================================
               COLUMN NAME
               =============================================================== */

            + ''''
            + REPLACE(c.name, '''', '''''')
            + ''' AS column_name, '


            /* ===============================================================
               TOTAL ROWS
               =============================================================== */

            + 'COUNT(*) AS total_rows, '


            /* ===============================================================
               NULL ROWS
               =============================================================== */

            + 'SUM('
            + 'CASE '
            + 'WHEN [' + REPLACE(c.name, ']', ']]') + '] IS NULL '
            + 'THEN 1 '
            + 'ELSE 0 '
            + 'END'
            + ') AS null_rows, '


            /* ===============================================================
               NULL %
               =============================================================== */

            + 'CONVERT(varchar(10), '
            + 'CAST(ROUND('
            + '100.0 * '
            + 'SUM(CASE '
            + 'WHEN [' + REPLACE(c.name, ']', ']]') + '] IS NULL '
            + 'THEN 1 '
            + 'ELSE 0 '
            + 'END) '
            + '/ NULLIF(COUNT(*), 0), '
            + '1'
            + ') AS decimal(5,1))'
            + ') AS null_pct, '


            /* ===============================================================
               BLANK ROWS
               =============================================================== */

            + 'SUM('
            + 'CASE '
            + 'WHEN [' + REPLACE(c.name, ']', ']]') + '] IS NOT NULL '
            + 'AND NULLIF('
            + 'LTRIM(RTRIM('
            + 'CAST(['
            + REPLACE(c.name, ']', ']]')
            + '] AS nvarchar(4000))'
            + ')), '
            + ''''''
            + ') IS NULL '
            + 'THEN 1 '
            + 'ELSE 0 '
            + 'END'
            + ') AS blank_rows, '


            /* ===============================================================
               BLANK %
               =============================================================== */

            + 'CONVERT(varchar(10), '
            + 'CAST(ROUND('
            + '100.0 * '
            + 'SUM(CASE '
            + 'WHEN [' + REPLACE(c.name, ']', ']]') + '] IS NOT NULL '
            + 'AND NULLIF('
            + 'LTRIM(RTRIM('
            + 'CAST(['
            + REPLACE(c.name, ']', ']]')
            + '] AS nvarchar(4000))'
            + ')), '
            + ''''''
            + ') IS NULL '
            + 'THEN 1 '
            + 'ELSE 0 '
            + 'END) '
            + '/ NULLIF(COUNT(*), 0), '
            + '1'
            + ') AS decimal(5,1))'
            + ') AS blank_pct, '


            /* ===============================================================
               POPULATED ROWS
               =============================================================== */

            + 'SUM('
            + 'CASE '
            + 'WHEN [' + REPLACE(c.name, ']', ']]') + '] IS NOT NULL '
            + 'AND NULLIF('
            + 'LTRIM(RTRIM('
            + 'CAST(['
            + REPLACE(c.name, ']', ']]')
            + '] AS nvarchar(4000))'
            + ')), '
            + ''''''
            + ') IS NOT NULL '
            + 'THEN 1 '
            + 'ELSE 0 '
            + 'END'
            + ') AS populated_rows, '


            /* ===============================================================
               POPULATED %
               =============================================================== */

            + 'CONVERT(varchar(10), '
            + 'CAST(ROUND('
            + '100.0 * '
            + 'SUM(CASE '
            + 'WHEN [' + REPLACE(c.name, ']', ']]') + '] IS NOT NULL '
            + 'AND NULLIF('
            + 'LTRIM(RTRIM('
            + 'CAST(['
            + REPLACE(c.name, ']', ']]')
            + '] AS nvarchar(4000))'
            + ')), '
            + ''''''
            + ') IS NOT NULL '
            + 'THEN 1 '
            + 'ELSE 0 '
            + 'END) '
            + '/ NULLIF(COUNT(*), 0), '
            + '1'
            + ') AS decimal(5,1))'
            + ') AS populated_pct '


            /* ===============================================================
               TABLE
               =============================================================== */

            + 'FROM dbo.['
            + REPLACE(@TableName, ']', ']]')
            + ']'

        AS varchar(max)),

        ' UNION ALL '

    ) AS profiler_query


/* ===========================================================================
   DATAVERSE METADATA
   =========================================================================== */

FROM sys.columns AS c

INNER JOIN sys.tables AS t
    ON c.object_id = t.object_id


WHERE t.name = @TableName


/* ===========================================================================
   OPTIONAL COLUMN FILTER
   =========================================================================== */

AND
(
    @ColumnName IS NULL
    OR c.name = @ColumnName
)


/* ===========================================================================
   TEXT COLUMNS ONLY

       167 = varchar
       175 = char
       231 = nvarchar
       239 = nchar
   =========================================================================== */

AND c.system_type_id IN
(
    167,
    175,
    231,
    239
);