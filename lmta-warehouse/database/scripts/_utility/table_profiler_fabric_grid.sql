/*
===============================================================================
MICROSOFT FABRIC WAREHOUSE - TABLE DATA PROFILER
===============================================================================

PURPOSE
-------
Profile EVERY column in a Fabric Warehouse table.

CHANGE ONLY:
    @SchemaName
    @TableName


MAIN OUTPUT
-----------
One row per column containing:

    column_id
    column_name
    data_type
    defined_length
    nullable

    total_rows
    populated_rows
    populated_pct

    null_rows
    null_pct

    blank_rows
    blank_pct

    distinct_values
    distinct_pct

    min_value
    max_value

    min_length
    max_length
    avg_length

    profile_type
    quality_status


FABRIC COMPATIBILITY
--------------------
- No temporary tables
- No distributed/non-distributed temp table joins
- sys.sysname is converted explicitly
- Dynamic SQL uses NVARCHAR
- SET NOCOUNT ON suppresses "(n rows affected)"
===============================================================================
*/

SET NOCOUNT ON;


/*=============================================================================
1. CONFIGURATION
=============================================================================*/

DECLARE @SchemaName varchar(128) = 'stg';

DECLARE @TableName varchar(128) =
    'prism_clt_contact';


/*
Exact distinct counts can be expensive on extremely large tables.

0:
    Always calculate COUNT(DISTINCT).

1000000:
    Calculate only if table contains <= 1,000,000 rows.

For your development profiling, 1,000,000 is a reasonable starting point.
*/

DECLARE @DistinctCountRowLimit bigint =
    1000000;


/*=============================================================================
2. VARIABLES
=============================================================================*/

DECLARE @QualifiedTable nvarchar(300);

DECLARE @SQL nvarchar(max);

DECLARE @ProfileSQL nvarchar(max);

DECLARE @RowCount bigint;


SET @QualifiedTable =

    QUOTENAME(@SchemaName)

    + N'.'

    + QUOTENAME(@TableName);


/*=============================================================================
3. VALIDATE TABLE
=============================================================================*/

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
5. BUILD PROFILE QUERY FOR EVERY COLUMN
=============================================================================*/

SELECT

    @ProfileSQL =

        STRING_AGG
        (
            CAST
            (

                N'SELECT '


                /*=============================================================
                COLUMN POSITION
                =============================================================*/

                + CAST(
                    c.column_id
                    AS nvarchar(20)
                  )

                + N' AS column_id, '


                /*=============================================================
                COLUMN NAME
                =============================================================*/

                + N''''
                + REPLACE(
                    CAST(
                        c.name
                        AS nvarchar(128)
                    ),
                    N'''',
                    N''''''
                  )
                + N''' AS column_name, '


                /*=============================================================
                DATA TYPE
                =============================================================*/

                + N''''
                + REPLACE(
                    CAST(
                        ty.name
                        AS nvarchar(128)
                    ),
                    N'''',
                    N''''''
                  )
                + N''' AS data_type, '


                /*=============================================================
                DEFINED LENGTH
                =============================================================*/

                + CASE

                    WHEN ty.name IN
                    (
                        'varchar',
                        'char',
                        'varbinary',
                        'binary'
                    )

                    THEN
                        CAST(
                            c.max_length
                            AS nvarchar(20)
                        )


                    WHEN ty.name IN
                    (
                        'nvarchar',
                        'nchar'
                    )

                    THEN
                        CAST(
                            c.max_length / 2
                            AS nvarchar(20)
                        )


                    ELSE

                        N'CAST(NULL AS int)'

                  END

                + N' AS defined_length, '


                /*=============================================================
                PRECISION
                =============================================================*/

                + CAST(
                    CAST(
                        c.precision
                        AS int
                    )
                    AS nvarchar(20)
                  )

                + N' AS precision_value, '


                /*=============================================================
                SCALE
                =============================================================*/

                + CAST(
                    CAST(
                        c.scale
                        AS int
                    )
                    AS nvarchar(20)
                  )

                + N' AS scale_value, '


                /*=============================================================
                NULLABLE
                =============================================================*/

                + CASE

                    WHEN c.is_nullable = 1

                    THEN N'''YES'''

                    ELSE N'''NO'''

                  END

                + N' AS nullable, '


                /*=============================================================
                TOTAL ROWS
                =============================================================*/

                + N'COUNT_BIG(*) '

                + N'AS total_rows, '


                /*=============================================================
                POPULATED ROWS
                =============================================================*/

                + N'SUM('

                    + N'CASE '

                    + N'WHEN '

                    + QUOTENAME(
                        CAST(
                            c.name
                            AS nvarchar(128)
                        )
                      )

                    + N' IS NOT NULL '

                    + N'THEN CAST(1 AS bigint) '

                    + N'ELSE CAST(0 AS bigint) '

                    + N'END'

                + N') AS populated_rows, '


                /*=============================================================
                POPULATED PERCENT
                =============================================================*/

                + N'CAST('

                    + N'100.0 * '

                    + N'SUM('

                        + N'CASE '

                        + N'WHEN '

                        + QUOTENAME(
                            CAST(
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


                /*=============================================================
                NULL ROWS
                =============================================================*/

                + N'SUM('

                    + N'CASE '

                    + N'WHEN '

                    + QUOTENAME(
                        CAST(
                            c.name
                            AS nvarchar(128)
                        )
                      )

                    + N' IS NULL '

                    + N'THEN CAST(1 AS bigint) '

                    + N'ELSE CAST(0 AS bigint) '

                    + N'END'

                + N') AS null_rows, '


                /*=============================================================
                NULL PERCENT
                =============================================================*/

                + N'CAST('

                    + N'100.0 * '

                    + N'SUM('

                        + N'CASE '

                        + N'WHEN '

                        + QUOTENAME(
                            CAST(
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


                /*=============================================================
                BLANK ROWS

                Applies only to character columns.
                =============================================================*/

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

                            + QUOTENAME(
                                CAST(
                                    c.name
                                    AS nvarchar(128)
                                )
                              )

                            + N' IS NOT NULL '

                            + N'AND '

                            + N'NULLIF('

                                + N'TRIM('

                                    + N'CAST('

                                    + QUOTENAME(
                                        CAST(
                                            c.name
                                            AS nvarchar(128)
                                        )
                                      )

                                    + N' AS varchar(8000))'

                                + N')'

                            + N', '''') '

                            + N'IS NULL '

                            + N'THEN CAST(1 AS bigint) '

                            + N'ELSE CAST(0 AS bigint) '

                            + N'END'

                        + N')'


                    ELSE

                        N'CAST(NULL AS bigint)'

                  END

                + N' AS blank_rows, '


                /*=============================================================
                BLANK PERCENT
                =============================================================*/

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

                                + QUOTENAME(
                                    CAST(
                                        c.name
                                        AS nvarchar(128)
                                    )
                                  )

                                + N' IS NOT NULL '

                                + N'AND '

                                + N'NULLIF('

                                    + N'TRIM('

                                        + N'CAST('

                                        + QUOTENAME(
                                            CAST(
                                                c.name
                                                AS nvarchar(128)
                                            )
                                          )

                                        + N' AS varchar(8000))'

                                    + N')'

                                + N', '''') '

                                + N'IS NULL '

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


                /*=============================================================
                DISTINCT VALUES
                =============================================================*/

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

                        + QUOTENAME(
                            CAST(
                                c.name
                                AS nvarchar(128)
                            )
                          )

                        + N')'


                    ELSE

                        N'CAST(NULL AS bigint)'

                  END

                + N' AS distinct_values, '


                /*=============================================================
                DISTINCT PERCENT

                Distinct count / populated rows.
                =============================================================*/

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

                            + QUOTENAME(
                                CAST(
                                    c.name
                                    AS nvarchar(128)
                                )
                              )

                            + N') '

                            + N'/ NULLIF('

                                + N'SUM('

                                    + N'CASE '

                                    + N'WHEN '

                                    + QUOTENAME(
                                        CAST(
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


                /*=============================================================
                MINIMUM VALUE
                =============================================================*/

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

                            + QUOTENAME(
                                CAST(
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


                /*=============================================================
                MAXIMUM VALUE
                =============================================================*/

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

                            + QUOTENAME(
                                CAST(
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


                /*=============================================================
                MINIMUM TEXT LENGTH
                =============================================================*/

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

                                + QUOTENAME(
                                    CAST(
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


                /*=============================================================
                MAXIMUM TEXT LENGTH
                =============================================================*/

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

                                + QUOTENAME(
                                    CAST(
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


                /*=============================================================
                AVERAGE TEXT LENGTH
                =============================================================*/

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

                                        + QUOTENAME(
                                            CAST(
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


                /*=============================================================
                SOURCE TABLE
                =============================================================*/

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
7. FINAL CLEAN PROFILE

This is the only main result you need to read.

PROFILE TYPE
------------
EMPTY
    Entire column is NULL/blank.

CONSTANT
    Only one distinct populated value.

LOW CARDINALITY
    <= 20 distinct values.
    Useful for codes, categories and mapping analysis.

LIKELY KEY
    Every populated value is distinct.

ATTRIBUTE
    Normal descriptive / measure column.


QUALITY STATUS
--------------
EMPTY
HIGH NULL
HAS BLANKS
LENGTH LIMIT
OK
=============================================================================*/

SET @SQL =

    N'SELECT '

    /* Identity */
    + N'column_id, '
    + N'column_name, '
    + N'data_type, '

    /* Structure */
    + N'defined_length, '
    + N'nullable, '

    /* Population */
    + N'total_rows, '
    + N'populated_rows, '
    + N'populated_pct, '

    /* Missingness */
    + N'null_rows, '
    + N'null_pct, '
    + N'blank_rows, '
    + N'blank_pct, '

    /* Cardinality */
    + N'distinct_values, '
    + N'distinct_pct, '

    /* Value range */
    + N'min_value, '
    + N'max_value, '

    /* String sizes */
    + N'min_length, '
    + N'max_length, '
    + N'avg_length, '


    /*=========================================================================
    PROFILE TYPE
    =========================================================================*/

    + N'CASE '

        /* Empty */
        + N'WHEN populated_rows = 0 '

        + N'THEN ''EMPTY'' '


        /* Constant */
        + N'WHEN distinct_values = 1 '

        + N'THEN ''CONSTANT'' '


        /* Likely key */
        + N'WHEN distinct_values = populated_rows '

        + N'AND populated_rows > 0 '

        + N'THEN ''LIKELY KEY'' '


        /* Low cardinality */
        + N'WHEN distinct_values <= 20 '

        + N'THEN ''LOW CARDINALITY'' '


        /* Normal attribute */
        + N'ELSE ''ATTRIBUTE'' '

    + N'END '

    + N'AS profile_type, '


    /*=========================================================================
    QUALITY STATUS
    =========================================================================*/

    + N'CASE '


        /* Entire column empty */
        + N'WHEN populated_rows = 0 '

        + N'THEN ''EMPTY'' '


        /* More than half null */
        + N'WHEN null_pct >= 50 '

        + N'THEN ''HIGH NULL'' '


        /* Blank strings */
        + N'WHEN blank_rows > 0 '

        + N'THEN ''HAS BLANKS'' '


        /* Data reaching configured maximum */
        + N'WHEN defined_length IS NOT NULL '

        + N'AND max_length >= defined_length '

        + N'THEN ''LENGTH LIMIT'' '


        /* Otherwise */
        + N'ELSE ''OK'' '


    + N'END '

    + N'AS quality_status '


    /*=========================================================================
    SOURCE
    =========================================================================*/

    + N'FROM ('

        + @ProfileSQL

    + N') AS p '


    /*=========================================================================
    ORDER
    =========================================================================*/

    + N'ORDER BY '

    + N'column_id;';


/*=============================================================================
8. EXECUTE PROFILE
=============================================================================*/

EXEC sys.sp_executesql
    @SQL;