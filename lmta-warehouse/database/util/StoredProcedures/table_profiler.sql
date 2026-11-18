/*
===============================================================================
MICROSOFT FABRIC WAREHOUSE - TABLE PROFILER STORED PROCEDURE
===============================================================================

PROCEDURE
---------
    util.table_profiler


PURPOSE
-------
Profiles every column in a Microsoft Fabric Warehouse table and returns one
combined result set.

For each column the output includes:

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

For low-cardinality columns it also returns:

    Value: <actual value>    <count> (<percentage>%)


PARAMETERS
----------
@SchemaName
    Schema containing the table.

@TableName
    Table to profile.

@LowCardinalityLimit
    Columns with this many distinct values or fewer receive a value
    distribution.

    Default: 20

@DistinctCountRowLimit
    Maximum table row count for exact distinct-count profiling.

    Default: 1,000,000

    Set to 0 to always calculate distinct values.


EXAMPLE - PROFILE PRISM CONTACT
-------------------------------

EXEC util.table_profiler
    @SchemaName = 'stg',
    @TableName = 'prism_clt_contact';


EXAMPLE - TOP 10 VALUES FOR LOW-CARDINALITY COLUMNS
---------------------------------------------------

EXEC util.table_profiler
    @SchemaName = 'stg',
    @TableName = 'prism_clt_contact',
    @LowCardinalityLimit = 10;


EXAMPLE - ALWAYS CALCULATE DISTINCT COUNTS
------------------------------------------

EXEC util.table_profiler
    @SchemaName = 'stg',
    @TableName = 'prism_clt_contact',
    @DistinctCountRowLimit = 0;


EXAMPLE - PROFILE ANOTHER TABLE
-------------------------------

EXEC util.table_profiler
    @SchemaName = 'int',
    @TableName = 'client';


FABRIC COMPATIBILITY
--------------------
    - No temporary tables
    - No joins between distributed and non-distributed objects
    - No sys.sysname persisted into a table
    - Dynamic SQL uses NVARCHAR
    - SET NOCOUNT ON suppresses "(n rows affected)"

===============================================================================
*/


CREATE   PROCEDURE util.table_profiler

    @SchemaName varchar(128),

    @TableName varchar(128),

    @LowCardinalityLimit int = 20,

    @DistinctCountRowLimit bigint = 1000000

AS

BEGIN

    SET NOCOUNT ON;


    /*=========================================================================
    1. VALIDATE PARAMETERS
    =========================================================================*/

    IF @LowCardinalityLimit < 1
    BEGIN

        THROW
            50001,
            'Low cardinality limit must be greater than zero.',
            1;

    END;


    IF @DistinctCountRowLimit < 0
    BEGIN

        THROW
            50002,
            'Distinct-count row limit cannot be negative.',
            1;

    END;


    /*=========================================================================
    2. WORKING VARIABLES
    =========================================================================*/

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


    /*=========================================================================
    3. VALIDATE THE TABLE
    =========================================================================*/

    IF NOT EXISTS
    (
        SELECT
            1

        FROM sys.tables AS t

        INNER JOIN sys.schemas AS s

            ON s.schema_id =
               t.schema_id

        WHERE

            CAST(
                s.name
                AS varchar(128)
            ) = @SchemaName

            AND

            CAST(
                t.name
                AS varchar(128)
            ) = @TableName
    )
    BEGIN

        THROW
            50003,
            'The requested table does not exist.',
            1;

    END;


    /*=========================================================================
    4. GET TABLE ROW COUNT
    =========================================================================*/

    SET @SQL =

        N'SELECT '

        + N'@OutputRowCount = COUNT_BIG(*) '

        + N'FROM '

        + @QualifiedTable

        + N';';


    EXEC sys.sp_executesql

        @SQL,

        N'@OutputRowCount bigint OUTPUT',

        @OutputRowCount =
            @RowCount OUTPUT;


    /*=========================================================================
    5. BUILD ONE PROFILE SELECT FOR EVERY COLUMN
    =========================================================================*/

    SELECT

        @ProfileSQL =

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
                    Data type
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Defined maximum length
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Nullable
                    ---------------------------------------------------------*/

                    + CASE

                        WHEN c.is_nullable = 1

                            THEN N'''YES'''

                        ELSE

                            N'''NO'''

                      END

                    + N' AS nullable, '


                    /*---------------------------------------------------------
                    Total rows
                    ---------------------------------------------------------*/

                    + N'COUNT_BIG(*) '

                    + N'AS total_rows, '


                    /*---------------------------------------------------------
                    Populated rows
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Populated percentage
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Null rows
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Null percentage
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Blank rows
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Blank percentage
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Distinct values
                    ---------------------------------------------------------*/

                    + CASE

                        WHEN

                            (
                                @DistinctCountRowLimit = 0

                                OR

                                @RowCount <=
                                @DistinctCountRowLimit
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


                    /*---------------------------------------------------------
                    Distinct percentage
                    ---------------------------------------------------------*/

                    + CASE

                        WHEN

                            (
                                @DistinctCountRowLimit = 0

                                OR

                                @RowCount <=
                                @DistinctCountRowLimit
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


                    /*---------------------------------------------------------
                    Minimum value
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Maximum value
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Minimum length
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Maximum length
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Average length
                    ---------------------------------------------------------*/

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


                    /*---------------------------------------------------------
                    Source table
                    ---------------------------------------------------------*/

                    + N'FROM '

                    + @QualifiedTable


                    AS nvarchar(max)
                ),

                N' UNION ALL '
            )

            WITHIN GROUP
            (
                ORDER BY
                    c.column_id
            )


    FROM sys.columns AS c

    INNER JOIN sys.tables AS t

        ON t.object_id =
           c.object_id

    INNER JOIN sys.schemas AS s

        ON s.schema_id =
           t.schema_id

    INNER JOIN sys.types AS ty

        ON ty.user_type_id =
           c.user_type_id

    WHERE

        CAST(
            s.name
            AS varchar(128)
        ) = @SchemaName

        AND

        CAST(
            t.name
            AS varchar(128)
        ) = @TableName;


    /*=========================================================================
    6. VALIDATE GENERATED PROFILE
    =========================================================================*/

    IF @ProfileSQL IS NULL
    BEGIN

        THROW
            50004,
            'No columns were found for the requested table.',
            1;

    END;


    /*=========================================================================
    7. BUILD LOW-CARDINALITY VALUE DISTRIBUTIONS
    =========================================================================*/

    SET @ValueSQL = NULL;


    IF
    (
        @DistinctCountRowLimit = 0

        OR

        @RowCount <=
        @DistinctCountRowLimit
    )
    BEGIN


        SELECT

            @ValueSQL =

                STRING_AGG
                (
                    CAST
                    (

                        N'SELECT '


                        /*-----------------------------------------------------
                        Column ID
                        -----------------------------------------------------*/

                        + CAST
                          (
                              c.column_id
                              AS nvarchar(20)
                          )

                        + N' AS column_id, '


                        /*-----------------------------------------------------
                        Column name
                        -----------------------------------------------------*/

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


                        /*-----------------------------------------------------
                        Metric order
                        -----------------------------------------------------*/

                        + N'1000 '

                        + N'AS metric_order, '


                        /*-----------------------------------------------------
                        Value sort order
                        -----------------------------------------------------*/

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


                        /*-----------------------------------------------------
                        Value sort
                        -----------------------------------------------------*/

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


                        /*-----------------------------------------------------
                        Display metric
                        -----------------------------------------------------*/

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


                        /*-----------------------------------------------------
                        Count and percentage
                        -----------------------------------------------------*/

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


                        /*-----------------------------------------------------
                        Source
                        -----------------------------------------------------*/

                        + N'FROM '

                        + @QualifiedTable

                        + N' '


                        /*-----------------------------------------------------
                        Group
                        -----------------------------------------------------*/

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


                        /*-----------------------------------------------------
                        Low-cardinality filter
                        -----------------------------------------------------*/

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
                    ORDER BY
                        c.column_id
                )


        FROM sys.columns AS c

        INNER JOIN sys.tables AS t

            ON t.object_id =
               c.object_id

        INNER JOIN sys.schemas AS s

            ON s.schema_id =
               t.schema_id

        INNER JOIN sys.types AS ty

            ON ty.user_type_id =
               c.user_type_id

        WHERE

            CAST(
                s.name
                AS varchar(128)
            ) = @SchemaName

            AND

            CAST(
                t.name
                AS varchar(128)
            ) = @TableName

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


    /*=========================================================================
    8. BUILD COMBINED RESULT
    =========================================================================*/

    SET @FinalSQL =

        N'WITH profile AS ('

            + @ProfileSQL

        + N'), '


        /*=====================================================================
        Classify each column
        =====================================================================*/

        + N'classified AS ('

            + N'SELECT '

                + N'*, '


                /*-------------------------------------------------------------
                Profile type
                -------------------------------------------------------------*/

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


                /*-------------------------------------------------------------
                Quality status
                -------------------------------------------------------------*/

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


        /*=====================================================================
        Convert to vertical metrics
        =====================================================================*/

        + N'vertical AS ('


            /* Column header */

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


            /* Data type */

            + N'SELECT '

                + N'column_id, column_name, '

                + N'1, 0, '''', '

                + N'''Data Type'', '

                + N'CAST(data_type AS varchar(8000)) '

            + N'FROM classified '


            + N'UNION ALL '


            /* Defined length */

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


            /* Nullable */

            + N'SELECT '

                + N'column_id, column_name, '

                + N'3, 0, '''', '

                + N'''Nullable'', '

                + N'CAST(nullable AS varchar(8000)) '

            + N'FROM classified '


            + N'UNION ALL '


            /* Total rows */

            + N'SELECT '

                + N'column_id, column_name, '

                + N'4, 0, '''', '

                + N'''Total Rows'', '

                + N'CAST(total_rows AS varchar(8000)) '

            + N'FROM classified '


            + N'UNION ALL '


            /* Populated rows */

            + N'SELECT '

                + N'column_id, column_name, '

                + N'5, 0, '''', '

                + N'''Populated Rows'', '

                + N'CAST(populated_rows AS varchar(8000)) '

            + N'FROM classified '


            + N'UNION ALL '


            /* Populated % */

            + N'SELECT '

                + N'column_id, column_name, '

                + N'6, 0, '''', '

                + N'''Populated %'', '

                + N'CAST(populated_pct AS varchar(8000)) '

            + N'FROM classified '


            + N'UNION ALL '


            /* Null rows */

            + N'SELECT '

                + N'column_id, column_name, '

                + N'7, 0, '''', '

                + N'''Null Rows'', '

                + N'CAST(null_rows AS varchar(8000)) '

            + N'FROM classified '


            + N'UNION ALL '


            /* Null % */

            + N'SELECT '

                + N'column_id, column_name, '

                + N'8, 0, '''', '

                + N'''Null %'', '

                + N'CAST(null_pct AS varchar(8000)) '

            + N'FROM classified '


            + N'UNION ALL '


            /* Blank rows */

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


            /* Blank % */

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


            /* Distinct values */

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


            /* Distinct % */

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


            /* Min value */

            + N'SELECT '

                + N'column_id, column_name, '

                + N'13, 0, '''', '

                + N'''Min Value'', '

                + N'COALESCE(min_value, ''NULL'') '

            + N'FROM classified '


            + N'UNION ALL '


            /* Max value */

            + N'SELECT '

                + N'column_id, column_name, '

                + N'14, 0, '''', '

                + N'''Max Value'', '

                + N'COALESCE(max_value, ''NULL'') '

            + N'FROM classified '


            + N'UNION ALL '


            /* Min length */

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


            /* Max length */

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


            /* Avg length */

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


            /* Profile type */

            + N'SELECT '

                + N'column_id, column_name, '

                + N'18, 0, '''', '

                + N'''Profile Type'', '

                + N'CAST(profile_type AS varchar(8000)) '

            + N'FROM classified '


            + N'UNION ALL '


            /* Quality status */

            + N'SELECT '

                + N'column_id, column_name, '

                + N'19, 0, '''', '

                + N'''Quality Status'', '

                + N'CAST(quality_status AS varchar(8000)) '

            + N'FROM classified '


        + N') ';


    /*=========================================================================
    9. ADD VALUE DISTRIBUTIONS
    =========================================================================*/

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


    /*=========================================================================
    10. EXECUTE PROFILE
    =========================================================================*/

    EXEC sys.sp_executesql
        @FinalSQL;

END;
GO

