/*
===============================================================================
MICROSOFT FABRIC WAREHOUSE - COMBINED VERTICAL TABLE PROFILER
===============================================================================

PURPOSE
-------
Profiles every column and returns one combined result set.

For each column, the output contains:

    Data Type
    Defined Length
    Nullable
    Total Rows
    Populated Rows
    Populated %
    Null Rows
    Null %
    Blank Rows
    Blank %
    Distinct Values
    Distinct %
    Min Value
    Max Value
    Min Length
    Max Length
    Avg Length
    Profile Type
    Quality Status

For low-cardinality columns, the output then lists:

    Value: <actual value>    <count> (<percentage>%)

CHANGE ONLY
-----------
    @SchemaName
    @TableName

FABRIC COMPATIBILITY
--------------------
    - No temporary tables
    - No joins between distributed and non-distributed objects
    - No sys.sysname persisted into a table
    - Dynamic SQL uses NVARCHAR
    - SET NOCOUNT ON suppresses "(n rows affected)"
===============================================================================
*/

SET NOCOUNT ON;


/*=============================================================================
1. CONFIGURATION
=============================================================================*/

DECLARE @SchemaName varchar(128) =
    'stg';

DECLARE @TableName varchar(128) =
    'prism_clt_contact';


/*
Columns with this many distinct populated values or fewer are treated as
categorical. Their values, counts and percentages are listed below the profile.
*/

DECLARE @LowCardinalityLimit int =
    20;


/*
Exact distinct counts can be expensive.

0:
    Always calculate distinct counts.

1000000:
    Calculate distinct counts only when the table contains no more than
    1,000,000 rows.

Value distributions also require distinct counts, so they are skipped when
the row-count threshold is exceeded.
*/

DECLARE @DistinctCountRowLimit bigint =
    1000000;


/*=============================================================================
2. WORKING VARIABLES
=============================================================================*/

DECLARE @QualifiedTable nvarchar(300);

DECLARE @SQL nvarchar(max);

DECLARE @ProfileSQL nvarchar(max);

DECLARE @ValueSQL nvarchar(max);

DECLARE @FinalSQL nvarchar(max);

DECLARE @RowCount bigint;


SET @QualifiedTable =

    QUOTENAME(@SchemaName)

    + N'.'

    + QUOTENAME(@TableName);


/*=============================================================================
3. VALIDATE THE TABLE
=============================================================================*/

IF NOT EXISTS
(
    SELECT
        1

    FROM sys.tables AS t

    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id

    WHERE
        CAST(s.name AS varchar(128)) = @SchemaName

        AND

        CAST(t.name AS varchar(128)) = @TableName
)
BEGIN

    THROW
        50001,
        'The requested table does not exist.',
        1;

END;


/*=============================================================================
4. GET TABLE ROW COUNT
=============================================================================*/

SET @SQL =

    N'SELECT '

    + N'@OutputRowCount = COUNT_BIG(*) '

    + N'FROM '

    + @QualifiedTable

    + N';';


EXEC sys.sp_executesql

    @SQL,

    N'@OutputRowCount bigint OUTPUT',

    @OutputRowCount = @RowCount OUTPUT;


/*=============================================================================
5. BUILD ONE PROFILE SELECT FOR EVERY COLUMN

The generated statements are combined using UNION ALL.

No temporary table is used.
=============================================================================*/

SELECT

    @ProfileSQL =

        STRING_AGG
        (
            CAST
            (
                N'SELECT '


                /*-------------------------------------------------------------
                Column ID
                -------------------------------------------------------------*/

                + CAST
                  (
                      c.column_id
                      AS nvarchar(20)
                  )

                + N' AS column_id, '


                /*-------------------------------------------------------------
                Column name
                -------------------------------------------------------------*/

                + N''''
                + REPLACE
                  (
                      CAST
                      (
                          c.name
                          AS nvarchar(128)
                      ),

                      N'''',

                      N''''''
                  )
                + N''' AS column_name, '


                /*-------------------------------------------------------------
                Data type
                -------------------------------------------------------------*/

                + N''''
                + REPLACE
                  (
                      CAST
                      (
                          ty.name
                          AS nvarchar(128)
                      ),

                      N'''',

                      N''''''
                  )
                + N''' AS data_type, '


                /*-------------------------------------------------------------
                Defined maximum length
                -------------------------------------------------------------*/

                + CASE

                    WHEN ty.name IN
                    (
                        'varchar',
                        'char',
                        'varbinary',
                        'binary'
                    )
                    THEN
                        CAST
                        (
                            c.max_length
                            AS nvarchar(20)
                        )

                    WHEN ty.name IN
                    (
                        'nvarchar',
                        'nchar'
                    )
                    THEN
                        CAST
                        (
                            c.max_length / 2
                            AS nvarchar(20)
                        )

                    ELSE
                        N'CAST(NULL AS int)'

                  END

                + N' AS defined_length, '


                /*-------------------------------------------------------------
                Nullable
                -------------------------------------------------------------*/

                + CASE

                    WHEN c.is_nullable = 1
                        THEN N'''YES'''

                    ELSE
                        N'''NO'''

                  END

                + N' AS nullable, '


                /*-------------------------------------------------------------
                Total rows
                -------------------------------------------------------------*/

                + N'COUNT_BIG(*) '

                + N'AS total_rows, '


                /*-------------------------------------------------------------
                Populated rows
                -------------------------------------------------------------*/

                + N'SUM('

                    + N'CASE '

                    + N'WHEN '

                    + QUOTENAME
                      (
                          CAST
                          (
                              c.name
                              AS nvarchar(128)
                          )
                      )

                    + N' IS NOT NULL '

                    + N'THEN CAST(1 AS bigint) '

                    + N'ELSE CAST(0 AS bigint) '

                    + N'END'

                + N') AS populated_rows, '


                /*-------------------------------------------------------------
                Populated percentage
                -------------------------------------------------------------*/

                + N'CAST('

                    + N'100.0 * '

                    + N'SUM('

                        + N'CASE '

                        + N'WHEN '

                        + QUOTENAME
                          (
                              CAST
                              (
                                  c.name
                                  AS nvarchar(128)
                              )
                          )

                        + N' IS NOT NULL '

                        + N'THEN 1 '

                        + N'ELSE 0 '

                        + N'END'

                    + N') '

                    + N'/ NULLIF(COUNT_BIG(*), 0) '

                + N'AS decimal(7,2)) '

                + N'AS populated_pct, '


                /*-------------------------------------------------------------
                Null rows
                -------------------------------------------------------------*/

                + N'SUM('

                    + N'CASE '

                    + N'WHEN '

                    + QUOTENAME
                      (
                          CAST
                          (
                              c.name
                              AS nvarchar(128)
                          )
                      )

                    + N' IS NULL '

                    + N'THEN CAST(1 AS bigint) '

                    + N'ELSE CAST(0 AS bigint) '

                    + N'END'

                + N') AS null_rows, '


                /*-------------------------------------------------------------
                Null percentage
                -------------------------------------------------------------*/

                + N'CAST('

                    + N'100.0 * '

                    + N'SUM('

                        + N'CASE '

                        + N'WHEN '

                        + QUOTENAME
                          (
                              CAST
                              (
                                  c.name
                                  AS nvarchar(128)
                              )
                          )

                        + N' IS NULL '

                        + N'THEN 1 '

                        + N'ELSE 0 '

                        + N'END'

                    + N') '

                    + N'/ NULLIF(COUNT_BIG(*), 0) '

                + N'AS decimal(7,2)) '

                + N'AS null_pct, '


                /*-------------------------------------------------------------
                Blank rows

                Applies only to character columns.
                -------------------------------------------------------------*/

                + CASE

                    WHEN ty.name IN
                    (
                        'varchar',
                        'nvarchar',
                        'char',
                        'nchar'
                    )
                    THEN
                        N'SUM('

                            + N'CASE '

                            + N'WHEN '

                            + QUOTENAME
                              (
                                  CAST
                                  (
                                      c.name
                                      AS nvarchar(128)
                                  )
                              )

                            + N' IS NOT NULL '

                            + N'AND NULLIF('

                                + N'TRIM('

                                    + N'CAST('

                                    + QUOTENAME
                                      (
                                          CAST
                                          (
                                              c.name
                                              AS nvarchar(128)
                                          )
                                      )

                                    + N' AS varchar(8000))'

                                + N')'

                            + N', '''') IS NULL '

                            + N'THEN CAST(1 AS bigint) '

                            + N'ELSE CAST(0 AS bigint) '

                            + N'END'

                        + N')'

                    ELSE
                        N'CAST(NULL AS bigint)'

                  END

                + N' AS blank_rows, '


                /*-------------------------------------------------------------
                Blank percentage
                -------------------------------------------------------------*/

                + CASE

                    WHEN ty.name IN
                    (
                        'varchar',
                        'nvarchar',
                        'char',
                        'nchar'
                    )
                    THEN
                        N'CAST('

                            + N'100.0 * '

                            + N'SUM('

                                + N'CASE '

                                + N'WHEN '

                                + QUOTENAME
                                  (
                                      CAST
                                      (
                                          c.name
                                          AS nvarchar(128)
                                      )
                                  )

                                + N' IS NOT NULL '

                                + N'AND NULLIF('

                                    + N'TRIM('

                                        + N'CAST('

                                        + QUOTENAME
                                          (
                                              CAST
                                              (
                                                  c.name
                                                  AS nvarchar(128)
                                              )
                                          )

                                        + N' AS varchar(8000))'

                                    + N')'

                                + N', '''') IS NULL '

                                + N'THEN 1 '

                                + N'ELSE 0 '

                                + N'END'

                            + N') '

                            + N'/ NULLIF(COUNT_BIG(*), 0) '

                        + N'AS decimal(7,2))'

                    ELSE
                        N'CAST(NULL AS decimal(7,2))'

                  END

                + N' AS blank_pct, '


                /*-------------------------------------------------------------
                Distinct values
                -------------------------------------------------------------*/

                + CASE

                    WHEN
                        (
                            @DistinctCountRowLimit = 0

                            OR

                            @RowCount <= @DistinctCountRowLimit
                        )

                        AND

                        ty.name NOT IN
                        (
                            'xml',
                            'image',
                            'text',
                            'ntext',
                            'geography',
                            'geometry',
                            'hierarchyid',
                            'varbinary',
                            'binary',
                            'timestamp',
                            'rowversion'
                        )
                    THEN
                        N'COUNT(DISTINCT '

                        + QUOTENAME
                          (
                              CAST
                              (
                                  c.name
                                  AS nvarchar(128)
                              )
                          )

                        + N')'

                    ELSE
                        N'CAST(NULL AS bigint)'

                  END

                + N' AS distinct_values, '


                /*-------------------------------------------------------------
                Distinct percentage

                Distinct populated values divided by populated rows.
                -------------------------------------------------------------*/

                + CASE

                    WHEN
                        (
                            @DistinctCountRowLimit = 0

                            OR

                            @RowCount <= @DistinctCountRowLimit
                        )

                        AND

                        ty.name NOT IN
                        (
                            'xml',
                            'image',
                            'text',
                            'ntext',
                            'geography',
                            'geometry',
                            'hierarchyid',
                            'varbinary',
                            'binary',
                            'timestamp',
                            'rowversion'
                        )
                    THEN
                        N'CAST('

                            + N'100.0 * '

                            + N'COUNT(DISTINCT '

                            + QUOTENAME
                              (
                                  CAST
                                  (
                                      c.name
                                      AS nvarchar(128)
                                  )
                              )

                            + N') '

                            + N'/ NULLIF('

                                + N'SUM('

                                    + N'CASE '

                                    + N'WHEN '

                                    + QUOTENAME
                                      (
                                          CAST
                                          (
                                              c.name
                                              AS nvarchar(128)
                                          )
                                      )

                                    + N' IS NOT NULL '

                                    + N'THEN 1 '

                                    + N'ELSE 0 '

                                    + N'END'

                                + N')'

                            + N', 0) '

                        + N'AS decimal(7,2))'

                    ELSE
                        N'CAST(NULL AS decimal(7,2))'

                  END

                + N' AS distinct_pct, '


                /*-------------------------------------------------------------
                Minimum value
                -------------------------------------------------------------*/

                + CASE

                    WHEN ty.name NOT IN
                    (
                        'xml',
                        'image',
                        'text',
                        'ntext',
                        'geography',
                        'geometry',
                        'hierarchyid',
                        'varbinary',
                        'binary',
                        'timestamp',
                        'rowversion'
                    )
                    THEN
                        N'CAST('

                            + N'MIN('

                            + QUOTENAME
                              (
                                  CAST
                                  (
                                      c.name
                                      AS nvarchar(128)
                                  )
                              )

                            + N') '

                        + N'AS varchar(8000))'

                    ELSE
                        N'CAST(NULL AS varchar(8000))'

                  END

                + N' AS min_value, '


                /*-------------------------------------------------------------
                Maximum value
                -------------------------------------------------------------*/

                + CASE

                    WHEN ty.name NOT IN
                    (
                        'xml',
                        'image',
                        'text',
                        'ntext',
                        'geography',
                        'geometry',
                        'hierarchyid',
                        'varbinary',
                        'binary',
                        'timestamp',
                        'rowversion'
                    )
                    THEN
                        N'CAST('

                            + N'MAX('

                            + QUOTENAME
                              (
                                  CAST
                                  (
                                      c.name
                                      AS nvarchar(128)
                                  )
                              )

                            + N') '

                        + N'AS varchar(8000))'

                    ELSE
                        N'CAST(NULL AS varchar(8000))'

                  END

                + N' AS max_value, '


                /*-------------------------------------------------------------
                Minimum observed length
                -------------------------------------------------------------*/

                + CASE

                    WHEN ty.name IN
                    (
                        'varchar',
                        'nvarchar',
                        'char',
                        'nchar'
                    )
                    THEN
                        N'MIN('

                            + N'LEN('

                                + N'CAST('

                                + QUOTENAME
                                  (
                                      CAST
                                      (
                                          c.name
                                          AS nvarchar(128)
                                      )
                                  )

                                + N' AS varchar(8000))'

                            + N')'

                        + N')'

                    ELSE
                        N'CAST(NULL AS int)'

                  END

                + N' AS min_length, '


                /*-------------------------------------------------------------
                Maximum observed length
                -------------------------------------------------------------*/

                + CASE

                    WHEN ty.name IN
                    (
                        'varchar',
                        'nvarchar',
                        'char',
                        'nchar'
                    )
                    THEN
                        N'MAX('

                            + N'LEN('

                                + N'CAST('

                                + QUOTENAME
                                  (
                                      CAST
                                      (
                                          c.name
                                          AS nvarchar(128)
                                      )
                                  )

                                + N' AS varchar(8000))'

                            + N')'

                        + N')'

                    ELSE
                        N'CAST(NULL AS int)'

                  END

                + N' AS max_length, '


                /*-------------------------------------------------------------
                Average observed length
                -------------------------------------------------------------*/

                + CASE

                    WHEN ty.name IN
                    (
                        'varchar',
                        'nvarchar',
                        'char',
                        'nchar'
                    )
                    THEN
                        N'CAST('

                            + N'AVG('

                                + N'CAST('

                                    + N'LEN('

                                        + N'CAST('

                                        + QUOTENAME
                                          (
                                              CAST
                                              (
                                                  c.name
                                                  AS nvarchar(128)
                                              )
                                          )

                                        + N' AS varchar(8000))'

                                    + N')'

                                + N' AS decimal(18,2))'

                            + N')'

                        + N' AS decimal(18,2))'

                    ELSE
                        N'CAST(NULL AS decimal(18,2))'

                  END

                + N' AS avg_length '


                /*-------------------------------------------------------------
                Source table
                -------------------------------------------------------------*/

                + N'FROM '

                + @QualifiedTable

                AS nvarchar(max)
            ),

            N' UNION ALL '
        )

        WITHIN GROUP
        (
            ORDER BY c.column_id
        )

FROM sys.columns AS c

INNER JOIN sys.tables AS t
    ON t.object_id = c.object_id

INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id

INNER JOIN sys.types AS ty
    ON ty.user_type_id = c.user_type_id

WHERE
    CAST(s.name AS varchar(128)) = @SchemaName

    AND

    CAST(t.name AS varchar(128)) = @TableName;


/*=============================================================================
6. VALIDATE GENERATED PROFILE
=============================================================================*/

IF @ProfileSQL IS NULL
BEGIN

    THROW
        50002,
        'No columns were found for the requested table.',
        1;

END;


/*=============================================================================
7. BUILD LOW-CARDINALITY VALUE DISTRIBUTIONS

One SELECT is generated for every supported column.

The SELECT returns rows only when the populated distinct count is less than
or equal to @LowCardinalityLimit.

The distribution includes:
    - NULL
    - [BLANK]
    - actual populated values

The percentage is calculated against all table rows.
=============================================================================*/

IF
(
    @DistinctCountRowLimit = 0

    OR

    @RowCount <= @DistinctCountRowLimit
)
BEGIN

    SELECT

        @ValueSQL =

            STRING_AGG
            (
                CAST
                (
                    N'SELECT '

                    /*---------------------------------------------------------
                    Column ID
                    ---------------------------------------------------------*/

                    + CAST
                      (
                          c.column_id
                          AS nvarchar(20)
                      )

                    + N' AS column_id, '


                    /*---------------------------------------------------------
                    Column name
                    ---------------------------------------------------------*/

                    + N''''
                    + REPLACE
                      (
                          CAST
                          (
                              c.name
                              AS nvarchar(128)
                          ),

                          N'''',

                          N''''''
                      )

                    + N''' AS column_name, '


                    /*---------------------------------------------------------
                    Metric order

                    Distribution values appear after the standard metrics.
                    ---------------------------------------------------------*/

                    + N'1000 '

                    + N'AS metric_order, '


                    /*---------------------------------------------------------
                    Value sort order

                    NULL first, blank second, actual values afterwards.
                    ---------------------------------------------------------*/

                    + N'CASE '

                    + N'WHEN '

                    + QUOTENAME
                      (
                          CAST
                          (
                              c.name
                              AS nvarchar(128)
                          )
                      )

                    + N' IS NULL '

                    + N'THEN 0 '


                    + CASE

                        WHEN ty.name IN
                        (
                            'varchar',
                            'nvarchar',
                            'char',
                            'nchar'
                        )
                        THEN
                            N'WHEN NULLIF('

                                + N'TRIM('

                                    + N'CAST('

                                    + QUOTENAME
                                      (
                                          CAST
                                          (
                                              c.name
                                              AS nvarchar(128)
                                          )
                                      )

                                    + N' AS varchar(8000))'

                                + N')'

                            + N', '''') IS NULL '

                            + N'THEN 1 '

                        ELSE
                            N''

                      END


                    + N'ELSE 2 '

                    + N'END '

                    + N'AS value_order, '


                    /*---------------------------------------------------------
                    Value sorting
                    ---------------------------------------------------------*/

                    + N'COALESCE('

                        + N'CAST('

                        + QUOTENAME
                          (
                              CAST
                              (
                                  c.name
                                  AS nvarchar(128)
                              )
                          )

                        + N' AS varchar(8000))'

                    + N', '''') '

                    + N'AS value_sort, '


                    /*---------------------------------------------------------
                    Displayed metric
                    ---------------------------------------------------------*/

                    + N'''Value: '' + '

                    + N'CASE '

                    + N'WHEN '

                    + QUOTENAME
                      (
                          CAST
                          (
                              c.name
                              AS nvarchar(128)
                          )
                      )

                    + N' IS NULL '

                    + N'THEN ''NULL'' '


                    + CASE

                        WHEN ty.name IN
                        (
                            'varchar',
                            'nvarchar',
                            'char',
                            'nchar'
                        )
                        THEN
                            N'WHEN NULLIF('

                                + N'TRIM('

                                    + N'CAST('

                                    + QUOTENAME
                                      (
                                          CAST
                                          (
                                              c.name
                                              AS nvarchar(128)
                                          )
                                      )

                                    + N' AS varchar(8000))'

                                + N')'

                            + N', '''') IS NULL '

                            + N'THEN ''[BLANK]'' '

                        ELSE
                            N''

                      END


                    + N'ELSE '

                        + N'CAST('

                        + QUOTENAME
                          (
                              CAST
                              (
                                  c.name
                                  AS nvarchar(128)
                              )
                          )

                        + N' AS varchar(8000)) '

                    + N'END '

                    + N'AS metric, '


                    /*---------------------------------------------------------
                    Displayed count and percentage
                    ---------------------------------------------------------*/

                    + N'CAST('

                        + N'COUNT_BIG(*) '

                    + N'AS varchar(100)) '

                    + N'+ '' ('' + '

                    + N'CAST('

                        + N'CAST('

                            + N'100.0 * COUNT_BIG(*) '

                            + N'/ NULLIF('

                                + CAST
                                  (
                                      @RowCount
                                      AS nvarchar(30)
                                  )

                            + N', 0) '

                        + N'AS decimal(7,2)) '

                    + N'AS varchar(100)) '

                    + N'+ ''%)'' '

                    + N'AS value '


                    /*---------------------------------------------------------
                    Source
                    ---------------------------------------------------------*/

                    + N'FROM '

                    + @QualifiedTable

                    + N' '


                    /*---------------------------------------------------------
                    Group by actual source value
                    ---------------------------------------------------------*/

                    + N'GROUP BY '

                    + QUOTENAME
                      (
                          CAST
                          (
                              c.name
                              AS nvarchar(128)
                          )
                      )

                    + N' '


                    /*---------------------------------------------------------
                    Return values only for low-cardinality columns.

                    Count distinct ignores NULL by design.
                    ---------------------------------------------------------*/

                    + N'HAVING '

                    + N'('

                        + N'SELECT '

                        + N'COUNT(DISTINCT '

                        + QUOTENAME
                          (
                              CAST
                              (
                                  c.name
                                  AS nvarchar(128)
                              )
                          )

                        + N') '

                        + N'FROM '

                        + @QualifiedTable

                    + N') <= '

                    + CAST
                      (
                          @LowCardinalityLimit
                          AS nvarchar(20)
                      )

                    AS nvarchar(max)
                ),

                N' UNION ALL '
            )

            WITHIN GROUP
            (
                ORDER BY c.column_id
            )

    FROM sys.columns AS c

    INNER JOIN sys.tables AS t
        ON t.object_id = c.object_id

    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id

    INNER JOIN sys.types AS ty
        ON ty.user_type_id = c.user_type_id

    WHERE
        CAST(s.name AS varchar(128)) = @SchemaName

        AND

        CAST(t.name AS varchar(128)) = @TableName

        AND

        ty.name NOT IN
        (
            'xml',
            'image',
            'text',
            'ntext',
            'geography',
            'geometry',
            'hierarchyid',
            'varbinary',
            'binary',
            'timestamp',
            'rowversion'
        );

END;


/*=============================================================================
8. BUILD ONE COMBINED RESULT

The profile and value distributions are returned through the same SELECT.

Result columns:
    column_name
    metric
    value
=============================================================================*/

SET @FinalSQL =

    N'WITH profile AS ('

        + @ProfileSQL

    + N'), '


    /*=========================================================================
    Classify each column
    =========================================================================*/

    + N'classified AS ('

        + N'SELECT '

            + N'*, '


            /*-----------------------------------------------------------------
            Profile type
            -----------------------------------------------------------------*/

            + N'CASE '

                + N'WHEN populated_rows = 0 '

                    + N'THEN ''EMPTY'' '

                + N'WHEN distinct_values = 1 '

                    + N'THEN ''CONSTANT'' '

                + N'WHEN distinct_values = populated_rows '

                     + N'AND populated_rows > 0 '

                    + N'THEN ''LIKELY KEY'' '

                + N'WHEN distinct_values <= '

                + CAST
                  (
                      @LowCardinalityLimit
                      AS nvarchar(20)
                  )

                + N' THEN ''LOW CARDINALITY'' '

                + N'ELSE ''ATTRIBUTE'' '

            + N'END '

            + N'AS profile_type, '


            /*-----------------------------------------------------------------
            Quality status
            -----------------------------------------------------------------*/

            + N'CASE '

                + N'WHEN populated_rows = 0 '

                    + N'THEN ''EMPTY'' '

                + N'WHEN null_pct >= 50 '

                    + N'THEN ''HIGH NULL'' '

                + N'WHEN blank_rows > 0 '

                    + N'THEN ''HAS BLANKS'' '

                + N'WHEN defined_length IS NOT NULL '

                     + N'AND max_length >= defined_length '

                    + N'THEN ''LENGTH LIMIT'' '

                + N'ELSE ''OK'' '

            + N'END '

            + N'AS quality_status '

        + N'FROM profile'

    + N'), '


    /*=========================================================================
    Convert the profile into vertical metrics
    =========================================================================*/

    + N'vertical AS ('


        /*---------------------------------------------------------------------
        Column header
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, '

            + N'column_name, '

            + N'0 AS metric_order, '

            + N'0 AS value_order, '

            + N'CAST('''' AS varchar(8000)) AS value_sort, '

            + N'''COLUMN'' AS metric, '

            + N'CAST(column_name AS varchar(8000)) AS value '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Data type
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'1, 0, '''', '

            + N'''Data Type'', '

            + N'CAST(data_type AS varchar(8000)) '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Defined length
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'2, 0, '''', '

            + N'''Defined Length'', '

            + N'COALESCE('

                + N'CAST(defined_length AS varchar(8000)), '

                + N'''N/A'''

            + N') '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Nullable
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'3, 0, '''', '

            + N'''Nullable'', '

            + N'CAST(nullable AS varchar(8000)) '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Total rows
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'4, 0, '''', '

            + N'''Total Rows'', '

            + N'CAST(total_rows AS varchar(8000)) '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Populated rows
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'5, 0, '''', '

            + N'''Populated Rows'', '

            + N'CAST(populated_rows AS varchar(8000)) '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Populated percentage
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'6, 0, '''', '

            + N'''Populated %'', '

            + N'CAST(populated_pct AS varchar(8000)) '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Null rows
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'7, 0, '''', '

            + N'''Null Rows'', '

            + N'CAST(null_rows AS varchar(8000)) '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Null percentage
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'8, 0, '''', '

            + N'''Null %'', '

            + N'CAST(null_pct AS varchar(8000)) '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Blank rows
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'9, 0, '''', '

            + N'''Blank Rows'', '

            + N'COALESCE('

                + N'CAST(blank_rows AS varchar(8000)), '

                + N'''N/A'''

            + N') '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Blank percentage
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'10, 0, '''', '

            + N'''Blank %'', '

            + N'COALESCE('

                + N'CAST(blank_pct AS varchar(8000)), '

                + N'''N/A'''

            + N') '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Distinct values
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'11, 0, '''', '

            + N'''Distinct Values'', '

            + N'COALESCE('

                + N'CAST(distinct_values AS varchar(8000)), '

                + N'''Not calculated'''

            + N') '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Distinct percentage
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'12, 0, '''', '

            + N'''Distinct %'', '

            + N'COALESCE('

                + N'CAST(distinct_pct AS varchar(8000)), '

                + N'''Not calculated'''

            + N') '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Minimum value
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'13, 0, '''', '

            + N'''Min Value'', '

            + N'COALESCE(min_value, ''NULL'') '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Maximum value
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'14, 0, '''', '

            + N'''Max Value'', '

            + N'COALESCE(max_value, ''NULL'') '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Minimum length
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'15, 0, '''', '

            + N'''Min Length'', '

            + N'COALESCE('

                + N'CAST(min_length AS varchar(8000)), '

                + N'''N/A'''

            + N') '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Maximum length
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'16, 0, '''', '

            + N'''Max Length'', '

            + N'COALESCE('

                + N'CAST(max_length AS varchar(8000)), '

                + N'''N/A'''

            + N') '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Average length
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'17, 0, '''', '

            + N'''Avg Length'', '

            + N'COALESCE('

                + N'CAST(avg_length AS varchar(8000)), '

                + N'''N/A'''

            + N') '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Profile type
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'18, 0, '''', '

            + N'''Profile Type'', '

            + N'CAST(profile_type AS varchar(8000)) '

        + N'FROM classified '


        + N'UNION ALL '


        /*---------------------------------------------------------------------
        Quality status
        ---------------------------------------------------------------------*/

        + N'SELECT '

            + N'column_id, column_name, '

            + N'19, 0, '''', '

            + N'''Quality Status'', '

            + N'CAST(quality_status AS varchar(8000)) '

        + N'FROM classified '

    + N') ';


/*=============================================================================
9. ADD VALUE DISTRIBUTIONS TO THE SAME RESULT SET
=============================================================================*/

IF @ValueSQL IS NOT NULL
BEGIN

    SET @FinalSQL =

        @FinalSQL

        + N', value_distribution AS ('

            + @ValueSQL

        + N') '

        + N'SELECT '

            + N'column_name, '

            + N'metric, '

            + N'value '

        + N'FROM ('

            + N'SELECT '

                + N'column_id, '

                + N'column_name, '

                + N'metric_order, '

                + N'value_order, '

                + N'value_sort, '

                + N'metric, '

                + N'value '

            + N'FROM vertical '

            + N'UNION ALL '

            + N'SELECT '

                + N'column_id, '

                + N'column_name, '

                + N'metric_order, '

                + N'value_order, '

                + N'value_sort, '

                + N'metric, '

                + N'value '

            + N'FROM value_distribution '

        + N') AS combined '

        + N'ORDER BY '

            + N'column_id, '

            + N'metric_order, '

            + N'value_order, '

            + N'value_sort;';

END;

ELSE
BEGIN

    SET @FinalSQL =

        @FinalSQL

        + N'SELECT '

            + N'column_name, '

            + N'metric, '

            + N'value '

        + N'FROM vertical '

        + N'ORDER BY '

            + N'column_id, '

            + N'metric_order, '

            + N'value_order, '

            + N'value_sort;';

END;


/*=============================================================================
10. EXECUTE ONE COMBINED RESULT
=============================================================================*/

EXEC sys.sp_executesql
    @FinalSQL;