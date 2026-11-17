
/*
EXEC dbo.column_profiler
    @SchemaName = 'stg',
    @TableName = 'prism_clt_contact',
    @ColumnName = 'address1_stateorprovince',
    @TopN = 20;
*/

CREATE OR ALTER PROCEDURE util.column_profiler
    @SchemaName           varchar(128),
    @TableName            varchar(128),
    @ColumnName           varchar(128),
    @TopN                 int = 20,
    @CategoricalThreshold int = 20,
    @MinimumExpectedDate  date = '1900-01-01'
AS
BEGIN
    SET NOCOUNT ON;

    /*=========================================================================
    1. Validate parameters
    =========================================================================*/

    IF @TopN < 1
    BEGIN
        THROW 50000, 'Top N must be greater than zero.', 1;
    END;

    IF @CategoricalThreshold < 1
    BEGIN
        THROW 50001, 'Categorical threshold must be greater than zero.', 1;
    END;


    /*=========================================================================
    2. Working variables
    =========================================================================*/

    DECLARE @QualifiedTable nvarchar(300);
    DECLARE @QuotedColumn   nvarchar(300);
    DECLARE @SQL            nvarchar(max);

    DECLARE @DataType        varchar(128);
    DECLARE @DefinedLength   int;
    DECLARE @NumericPrecision int;
    DECLARE @NumericScale     int;
    DECLARE @IsNullable       bit;

    DECLARE @IsText     bit = 0;
    DECLARE @IsNumeric  bit = 0;
    DECLARE @IsDateTime bit = 0;
    DECLARE @IsTimeOnly bit = 0;
    DECLARE @IsBit      bit = 0;

    DECLARE @TotalRows      bigint;
    DECLARE @PopulatedRows  bigint;
    DECLARE @NullRows       bigint;
    DECLARE @DistinctValues bigint;

    DECLARE @ProfileMode varchar(30);

    DECLARE @NormalizedExpression nvarchar(max);
    DECLARE @TextExpression       nvarchar(max);

    SET @QualifiedTable =
        QUOTENAME(@SchemaName)
        + N'.'
        + QUOTENAME(@TableName);

    SET @QuotedColumn =
        QUOTENAME(@ColumnName);


    /*=========================================================================
    3. Read column metadata
    =========================================================================*/

    SELECT
        @DataType =
            CAST(ty.name AS varchar(128)),

        @DefinedLength =
            CASE
                WHEN ty.name IN
                (
                    'varchar',
                    'char',
                    'varbinary',
                    'binary'
                )
                    THEN c.max_length

                WHEN ty.name IN
                (
                    'nvarchar',
                    'nchar'
                )
                    THEN c.max_length / 2

                ELSE NULL
            END,

        @NumericPrecision =
            CAST(c.precision AS int),

        @NumericScale =
            CAST(c.scale AS int),

        @IsNullable =
            c.is_nullable,

        @IsText =
            CASE
                WHEN ty.name IN
                (
                    'varchar',
                    'nvarchar',
                    'char',
                    'nchar'
                )
                    THEN CAST(1 AS bit)
                ELSE CAST(0 AS bit)
            END,

        @IsNumeric =
            CASE
                WHEN ty.name IN
                (
                    'tinyint',
                    'smallint',
                    'int',
                    'bigint',
                    'decimal',
                    'numeric',
                    'real',
                    'float'
                )
                    THEN CAST(1 AS bit)
                ELSE CAST(0 AS bit)
            END,

        @IsDateTime =
            CASE
                WHEN ty.name IN
                (
                    'date',
                    'datetime2',
                    'time'
                )
                    THEN CAST(1 AS bit)
                ELSE CAST(0 AS bit)
            END,

        @IsTimeOnly =
            CASE
                WHEN ty.name = 'time'
                    THEN CAST(1 AS bit)
                ELSE CAST(0 AS bit)
            END,

        @IsBit =
            CASE
                WHEN ty.name = 'bit'
                    THEN CAST(1 AS bit)
                ELSE CAST(0 AS bit)
            END

    FROM sys.columns AS c

    INNER JOIN sys.tables AS t
        ON t.object_id = c.object_id

    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id

    INNER JOIN sys.types AS ty
        ON ty.user_type_id = c.user_type_id

    WHERE CAST(s.name AS varchar(128)) = @SchemaName
      AND CAST(t.name AS varchar(128)) = @TableName
      AND CAST(c.name AS varchar(128)) = @ColumnName;


    IF @DataType IS NULL
    BEGIN
        THROW 50002, 'The requested table or column does not exist.', 1;
    END;


    /*=========================================================================
    4. Get basic counts
    =========================================================================*/

    SET @SQL =
        N'SELECT '
        + N'@pTotalRows = COUNT_BIG(*), '

        + N'@pPopulatedRows = '
        + N'SUM(CASE '
        + N'WHEN ' + @QuotedColumn + N' IS NOT NULL '
        + N'THEN CAST(1 AS bigint) '
        + N'ELSE CAST(0 AS bigint) '
        + N'END), '

        + N'@pNullRows = '
        + N'SUM(CASE '
        + N'WHEN ' + @QuotedColumn + N' IS NULL '
        + N'THEN CAST(1 AS bigint) '
        + N'ELSE CAST(0 AS bigint) '
        + N'END), '

        + N'@pDistinctValues = '
        + N'COUNT(DISTINCT ' + @QuotedColumn + N') '

        + N'FROM ' + @QualifiedTable + N';';

    EXEC sys.sp_executesql
        @SQL,

        N'@pTotalRows bigint OUTPUT,
          @pPopulatedRows bigint OUTPUT,
          @pNullRows bigint OUTPUT,
          @pDistinctValues bigint OUTPUT',

        @pTotalRows = @TotalRows OUTPUT,
        @pPopulatedRows = @PopulatedRows OUTPUT,
        @pNullRows = @NullRows OUTPUT,
        @pDistinctValues = @DistinctValues OUTPUT;


    /*=========================================================================
    5. Select profile mode
    =========================================================================*/

    SET @ProfileMode =
        CASE
            WHEN @IsText = 1
                THEN 'CATEGORICAL TEXT'

            WHEN @IsBit = 1
                THEN 'CATEGORICAL BIT'

            WHEN @IsNumeric = 1
             AND @DistinctValues <= @CategoricalThreshold
                THEN 'CATEGORICAL NUMERIC'

            WHEN @IsNumeric = 1
                THEN 'CONTINUOUS NUMERIC'

            WHEN @IsDateTime = 1
                THEN 'DATE/TIME'

            ELSE 'BASIC'
        END;


    /*=========================================================================
    6. Categorical profile
    =========================================================================*/

    IF @ProfileMode IN
    (
        'CATEGORICAL TEXT',
        'CATEGORICAL BIT',
        'CATEGORICAL NUMERIC'
    )
    BEGIN

        IF @IsText = 1
        BEGIN
            SET @NormalizedExpression =
                N'CASE '
                + N'WHEN ' + @QuotedColumn + N' IS NULL '
                    + N'THEN ''[NULL]'' '
                + N'WHEN NULLIF('
                    + N'TRIM(CAST('
                    + @QuotedColumn
                    + N' AS varchar(8000))), '
                    + N''''') IS NULL '
                    + N'THEN ''[BLANK]'' '
                + N'ELSE TRIM(CAST('
                    + @QuotedColumn
                    + N' AS varchar(8000))) '
                + N'END';

            SET @TextExpression =
                N'CAST('
                + @QuotedColumn
                + N' AS varchar(8000))';
        END;
        ELSE
        BEGIN
            SET @NormalizedExpression =
                N'CASE '
                + N'WHEN ' + @QuotedColumn + N' IS NULL '
                    + N'THEN ''[NULL]'' '
                + N'ELSE CAST('
                    + @QuotedColumn
                    + N' AS varchar(8000)) '
                + N'END';

            SET @TextExpression =
                N'CAST(NULL AS varchar(8000))';
        END;


        SET @SQL =
            N'WITH normalized AS
            (
                SELECT '
                + @NormalizedExpression + N' AS normalized_value,
                       '
                + @TextExpression + N' AS text_value
                FROM ' + @QualifiedTable + N'
            ),
            summary AS
            (
                SELECT '

                + CASE
                    WHEN @IsText = 1
                    THEN
                        N'SUM(CASE
                            WHEN normalized_value = ''[BLANK]''
                                THEN CAST(1 AS bigint)
                            ELSE CAST(0 AS bigint)
                          END)'
                    ELSE
                        N'CAST(NULL AS bigint)'
                  END
                + N' AS blank_rows,

                '

                + CASE
                    WHEN @IsText = 1
                    THEN
                        N'CAST(
                            100.0 *
                            SUM(CASE
                                WHEN normalized_value = ''[BLANK]''
                                    THEN 1
                                ELSE 0
                            END)
                            / NULLIF(COUNT_BIG(*), 0)
                            AS decimal(7,2)
                          )'
                    ELSE
                        N'CAST(NULL AS decimal(7,2))'
                  END
                + N' AS blank_pct,

                MIN(
                    CASE
                        WHEN normalized_value IN (''[NULL]'', ''[BLANK]'')
                            THEN NULL
                        ELSE normalized_value
                    END
                ) AS minimum_value,

                MAX(
                    CASE
                        WHEN normalized_value IN (''[NULL]'', ''[BLANK]'')
                            THEN NULL
                        ELSE normalized_value
                    END
                ) AS maximum_value,

                '

                + CASE
                    WHEN @IsText = 1
                    THEN
                        N'MIN(CASE
                            WHEN text_value IS NULL THEN NULL
                            ELSE LEN(text_value)
                          END)'
                    ELSE
                        N'CAST(NULL AS int)'
                  END
                + N' AS minimum_length,

                '

                + CASE
                    WHEN @IsText = 1
                    THEN
                        N'MAX(CASE
                            WHEN text_value IS NULL THEN NULL
                            ELSE LEN(text_value)
                          END)'
                    ELSE
                        N'CAST(NULL AS int)'
                  END
                + N' AS maximum_length,

                '

                + CASE
                    WHEN @IsText = 1
                    THEN
                        N'CAST(
                            AVG(
                                CAST(
                                    CASE
                                        WHEN text_value IS NULL THEN NULL
                                        ELSE LEN(text_value)
                                    END
                                    AS decimal(18,2)
                                )
                            )
                            AS decimal(18,2)
                          )'
                    ELSE
                        N'CAST(NULL AS decimal(18,2))'
                  END
                + N' AS average_length

                FROM normalized
            ),
            value_counts AS
            (
                SELECT
                    normalized_value,
                    COUNT_BIG(*) AS row_count
                FROM normalized
                GROUP BY normalized_value
            ),
            ranked AS
            (
                SELECT
                    normalized_value,
                    row_count,

                    ROW_NUMBER() OVER
                    (
                        ORDER BY
                            row_count DESC,
                            normalized_value
                    ) AS value_rank,

                    SUM(row_count) OVER ()
                        AS total_rows,

                    SUM(
                        CASE
                            WHEN normalized_value = ''[NULL]''
                                THEN CAST(0 AS bigint)
                            ELSE row_count
                        END
                    ) OVER () AS populated_rows

                FROM value_counts
            ),
            distribution AS
            (
                SELECT
                    value_rank,
                    normalized_value,
                    row_count,

                    CAST(
                        100.0 * row_count
                        / NULLIF(total_rows, 0)
                        AS decimal(7,2)
                    ) AS pct_all,

                    CASE
                        WHEN normalized_value = ''[NULL]''
                            THEN CAST(NULL AS decimal(7,2))
                        ELSE
                            CAST(
                                100.0 * row_count
                                / NULLIF(populated_rows, 0)
                                AS decimal(7,2)
                            )
                    END AS pct_populated,

                    CAST(
                        100.0 *
                        SUM(row_count) OVER
                        (
                            ORDER BY
                                row_count DESC,
                                normalized_value
                            ROWS BETWEEN
                                UNBOUNDED PRECEDING
                                AND CURRENT ROW
                        )
                        / NULLIF(total_rows, 0)
                        AS decimal(7,2)
                    ) AS cumulative_pct

                FROM ranked
            ),
            metrics AS
            (
                SELECT
                    1 AS metric_order,
                    ''Schema'' AS metric,
                    CAST(@pSchema AS varchar(8000)) AS value

                UNION ALL

                SELECT
                    2,
                    ''Table'',
                    CAST(@pTable AS varchar(8000))

                UNION ALL

                SELECT
                    3,
                    ''Column'',
                    CAST(@pColumn AS varchar(8000))

                UNION ALL

                SELECT
                    4,
                    ''Data Type'',
                    CAST(@pDataType AS varchar(8000))

                UNION ALL

                SELECT
                    5,
                    ''Defined Length'',
                    COALESCE(
                        CAST(@pDefinedLength AS varchar(8000)),
                        ''N/A''
                    )

                UNION ALL

                SELECT
                    6,
                    ''Nullable'',
                    CASE
                        WHEN @pNullable = 1 THEN ''YES''
                        ELSE ''NO''
                    END

                UNION ALL

                SELECT
                    7,
                    ''Selected Profile'',
                    CAST(@pProfileMode AS varchar(8000))

                UNION ALL

                SELECT
                    8,
                    ''Categorical Threshold'',
                    CAST(@pCategoricalThreshold AS varchar(8000))

                UNION ALL

                SELECT
                    9,
                    ''Top N'',
                    CAST(@pTopN AS varchar(8000))

                UNION ALL

                SELECT
                    10,
                    ''Total Rows'',
                    CAST(@pTotalRows AS varchar(8000))

                UNION ALL

                SELECT
                    11,
                    ''Populated Rows'',
                    CAST(@pPopulatedRows AS varchar(8000))

                UNION ALL

                SELECT
                    12,
                    ''Populated %'',
                    CAST(
                        CAST(
                            100.0 * @pPopulatedRows
                            / NULLIF(@pTotalRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )

                UNION ALL

                SELECT
                    13,
                    ''Null Rows'',
                    CAST(@pNullRows AS varchar(8000))

                UNION ALL

                SELECT
                    14,
                    ''Null %'',
                    CAST(
                        CAST(
                            100.0 * @pNullRows
                            / NULLIF(@pTotalRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )

                UNION ALL

                SELECT
                    15,
                    ''Distinct Values'',
                    CAST(@pDistinctValues AS varchar(8000))

                UNION ALL

                SELECT
                    16,
                    ''Distinct % of Populated'',
                    CAST(
                        CAST(
                            100.0 * @pDistinctValues
                            / NULLIF(@pPopulatedRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )

                UNION ALL

                SELECT
                    17,
                    ''Blank Rows'',
                    COALESCE(
                        CAST(s.blank_rows AS varchar(8000)),
                        ''N/A''
                    )
                FROM summary AS s

                UNION ALL

                SELECT
                    18,
                    ''Blank %'',
                    COALESCE(
                        CAST(s.blank_pct AS varchar(8000)),
                        ''N/A''
                    )
                FROM summary AS s

                UNION ALL

                SELECT
                    19,
                    ''Minimum Value'',
                    COALESCE(s.minimum_value, ''NULL'')
                FROM summary AS s

                UNION ALL

                SELECT
                    20,
                    ''Maximum Value'',
                    COALESCE(s.maximum_value, ''NULL'')
                FROM summary AS s

                UNION ALL

                SELECT
                    21,
                    ''Minimum Length'',
                    COALESCE(
                        CAST(s.minimum_length AS varchar(8000)),
                        ''N/A''
                    )
                FROM summary AS s

                UNION ALL

                SELECT
                    22,
                    ''Maximum Length'',
                    COALESCE(
                        CAST(s.maximum_length AS varchar(8000)),
                        ''N/A''
                    )
                FROM summary AS s

                UNION ALL

                SELECT
                    23,
                    ''Average Length'',
                    COALESCE(
                        CAST(s.average_length AS varchar(8000)),
                        ''N/A''
                    )
                FROM summary AS s

                UNION ALL

                SELECT
                    100 + CAST(d.value_rank AS int),

                    ''Value: '' + d.normalized_value,

                    CAST(d.row_count AS varchar(50))
                    + '' rows | ''
                    + CAST(d.pct_all AS varchar(50))
                    + ''% of all | ''
                    + COALESCE(
                        CAST(d.pct_populated AS varchar(50)),
                        ''N/A''
                    )
                    + ''% of populated | ''
                    + CAST(d.cumulative_pct AS varchar(50))
                    + ''% cumulative''

                FROM distribution AS d

                WHERE d.value_rank <= @pTopN
            )

            SELECT
                metric,
                value

            FROM metrics

            ORDER BY
                metric_order;';


        EXEC sys.sp_executesql
            @SQL,

            N'@pSchema varchar(128),
              @pTable varchar(128),
              @pColumn varchar(128),
              @pDataType varchar(128),
              @pDefinedLength int,
              @pNullable bit,
              @pProfileMode varchar(30),
              @pCategoricalThreshold int,
              @pTopN int,
              @pTotalRows bigint,
              @pPopulatedRows bigint,
              @pNullRows bigint,
              @pDistinctValues bigint',

            @pSchema = @SchemaName,
            @pTable = @TableName,
            @pColumn = @ColumnName,
            @pDataType = @DataType,
            @pDefinedLength = @DefinedLength,
            @pNullable = @IsNullable,
            @pProfileMode = @ProfileMode,
            @pCategoricalThreshold = @CategoricalThreshold,
            @pTopN = @TopN,
            @pTotalRows = @TotalRows,
            @pPopulatedRows = @PopulatedRows,
            @pNullRows = @NullRows,
            @pDistinctValues = @DistinctValues;

        RETURN;
    END;


    /*=========================================================================
    7. Continuous numeric profile
    =========================================================================*/

    IF @ProfileMode = 'CONTINUOUS NUMERIC'
    BEGIN

        SET @SQL =
            N'WITH statistics AS
            (
                SELECT
                    CAST(
                        MIN(' + @QuotedColumn + N')
                        AS decimal(38,10)
                    ) AS minimum_value,

                    CAST(
                        MAX(' + @QuotedColumn + N')
                        AS decimal(38,10)
                    ) AS maximum_value,

                    CAST(
                        MAX(' + @QuotedColumn + N')
                        - MIN(' + @QuotedColumn + N')
                        AS decimal(38,10)
                    ) AS value_range,

                    CAST(
                        AVG(CAST(' + @QuotedColumn + N' AS float))
                        AS decimal(38,10)
                    ) AS mean_value,

                    CAST(
                        STDEV(CAST(' + @QuotedColumn + N' AS float))
                        AS decimal(38,10)
                    ) AS standard_deviation,

                    CAST(
                        APPROX_PERCENTILE_CONT(0.05)
                        WITHIN GROUP
                        (
                            ORDER BY ' + @QuotedColumn + N'
                        )
                        AS decimal(38,10)
                    ) AS p05,

                    CAST(
                        APPROX_PERCENTILE_CONT(0.25)
                        WITHIN GROUP
                        (
                            ORDER BY ' + @QuotedColumn + N'
                        )
                        AS decimal(38,10)
                    ) AS q1,

                    CAST(
                        APPROX_PERCENTILE_CONT(0.50)
                        WITHIN GROUP
                        (
                            ORDER BY ' + @QuotedColumn + N'
                        )
                        AS decimal(38,10)
                    ) AS median_value,

                    CAST(
                        APPROX_PERCENTILE_CONT(0.75)
                        WITHIN GROUP
                        (
                            ORDER BY ' + @QuotedColumn + N'
                        )
                        AS decimal(38,10)
                    ) AS q3,

                    CAST(
                        APPROX_PERCENTILE_CONT(0.95)
                        WITHIN GROUP
                        (
                            ORDER BY ' + @QuotedColumn + N'
                        )
                        AS decimal(38,10)
                    ) AS p95,

                    SUM(
                        CASE
                            WHEN ' + @QuotedColumn + N' = 0
                                THEN CAST(1 AS bigint)
                            ELSE CAST(0 AS bigint)
                        END
                    ) AS zero_count,

                    SUM(
                        CASE
                            WHEN ' + @QuotedColumn + N' < 0
                                THEN CAST(1 AS bigint)
                            ELSE CAST(0 AS bigint)
                        END
                    ) AS negative_count

                FROM ' + @QualifiedTable + N'
            ),
            metrics AS
            (
                SELECT
                    1 AS metric_order,
                    ''Schema'' AS metric,
                    CAST(@pSchema AS varchar(8000)) AS value

                UNION ALL

                SELECT
                    2,
                    ''Table'',
                    CAST(@pTable AS varchar(8000))

                UNION ALL

                SELECT
                    3,
                    ''Column'',
                    CAST(@pColumn AS varchar(8000))

                UNION ALL

                SELECT
                    4,
                    ''Data Type'',
                    CAST(@pDataType AS varchar(8000))

                UNION ALL

                SELECT
                    5,
                    ''Numeric Precision'',
                    CAST(@pPrecision AS varchar(8000))

                UNION ALL

                SELECT
                    6,
                    ''Numeric Scale'',
                    CAST(@pScale AS varchar(8000))

                UNION ALL

                SELECT
                    7,
                    ''Nullable'',
                    CASE
                        WHEN @pNullable = 1 THEN ''YES''
                        ELSE ''NO''
                    END

                UNION ALL

                SELECT
                    8,
                    ''Selected Profile'',
                    ''CONTINUOUS NUMERIC''

                UNION ALL

                SELECT
                    10,
                    ''Total Rows'',
                    CAST(@pTotalRows AS varchar(8000))

                UNION ALL

                SELECT
                    11,
                    ''Populated Rows'',
                    CAST(@pPopulatedRows AS varchar(8000))

                UNION ALL

                SELECT
                    12,
                    ''Populated %'',
                    CAST(
                        CAST(
                            100.0 * @pPopulatedRows
                            / NULLIF(@pTotalRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )

                UNION ALL

                SELECT
                    13,
                    ''Null Rows'',
                    CAST(@pNullRows AS varchar(8000))

                UNION ALL

                SELECT
                    14,
                    ''Null %'',
                    CAST(
                        CAST(
                            100.0 * @pNullRows
                            / NULLIF(@pTotalRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )

                UNION ALL

                SELECT
                    15,
                    ''Distinct Values'',
                    CAST(@pDistinctValues AS varchar(8000))

                UNION ALL

                SELECT
                    16,
                    ''Distinct % of Populated'',
                    CAST(
                        CAST(
                            100.0 * @pDistinctValues
                            / NULLIF(@pPopulatedRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )

                UNION ALL

                SELECT
                    20,
                    ''Minimum'',
                    COALESCE(
                        CAST(s.minimum_value AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    21,
                    ''Maximum'',
                    COALESCE(
                        CAST(s.maximum_value AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    22,
                    ''Range'',
                    COALESCE(
                        CAST(s.value_range AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    23,
                    ''Mean'',
                    COALESCE(
                        CAST(s.mean_value AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    24,
                    ''Standard Deviation'',
                    COALESCE(
                        CAST(s.standard_deviation AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    25,
                    ''P05'',
                    COALESCE(
                        CAST(s.p05 AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    26,
                    ''Q1 / P25'',
                    COALESCE(
                        CAST(s.q1 AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    27,
                    ''Median / P50'',
                    COALESCE(
                        CAST(s.median_value AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    28,
                    ''Q3 / P75'',
                    COALESCE(
                        CAST(s.q3 AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    29,
                    ''P95'',
                    COALESCE(
                        CAST(s.p95 AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    30,
                    ''Interquartile Range'',
                    COALESCE(
                        CAST(s.q3 - s.q1 AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    31,
                    ''Zero Count'',
                    CAST(s.zero_count AS varchar(8000))
                FROM statistics AS s

                UNION ALL

                SELECT
                    32,
                    ''Zero %'',
                    CAST(
                        CAST(
                            100.0 * s.zero_count
                            / NULLIF(@pTotalRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    33,
                    ''Negative Count'',
                    CAST(s.negative_count AS varchar(8000))
                FROM statistics AS s

                UNION ALL

                SELECT
                    34,
                    ''Negative %'',
                    CAST(
                        CAST(
                            100.0 * s.negative_count
                            / NULLIF(@pTotalRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )
                FROM statistics AS s
            )

            SELECT
                metric,
                value

            FROM metrics

            ORDER BY
                metric_order;';


        EXEC sys.sp_executesql
            @SQL,

            N'@pSchema varchar(128),
              @pTable varchar(128),
              @pColumn varchar(128),
              @pDataType varchar(128),
              @pPrecision int,
              @pScale int,
              @pNullable bit,
              @pTotalRows bigint,
              @pPopulatedRows bigint,
              @pNullRows bigint,
              @pDistinctValues bigint',

            @pSchema = @SchemaName,
            @pTable = @TableName,
            @pColumn = @ColumnName,
            @pDataType = @DataType,
            @pPrecision = @NumericPrecision,
            @pScale = @NumericScale,
            @pNullable = @IsNullable,
            @pTotalRows = @TotalRows,
            @pPopulatedRows = @PopulatedRows,
            @pNullRows = @NullRows,
            @pDistinctValues = @DistinctValues;

        RETURN;
    END;


    /*=========================================================================
    8. Date/time profile
    =========================================================================*/

    IF @ProfileMode = 'DATE/TIME'
    BEGIN

        IF @IsTimeOnly = 1
        BEGIN
            SET @SQL =
                N'WITH statistics AS
                (
                    SELECT
                        MIN(' + @QuotedColumn + N') AS earliest_time,
                        MAX(' + @QuotedColumn + N') AS latest_time
                    FROM ' + @QualifiedTable + N'
                ),
                metrics AS
                (
                    SELECT
                        1 AS metric_order,
                        ''Schema'' AS metric,
                        CAST(@pSchema AS varchar(8000)) AS value

                    UNION ALL

                    SELECT
                        2,
                        ''Table'',
                        CAST(@pTable AS varchar(8000))

                    UNION ALL

                    SELECT
                        3,
                        ''Column'',
                        CAST(@pColumn AS varchar(8000))

                    UNION ALL

                    SELECT
                        4,
                        ''Data Type'',
                        CAST(@pDataType AS varchar(8000))

                    UNION ALL

                    SELECT
                        5,
                        ''Nullable'',
                        CASE
                            WHEN @pNullable = 1 THEN ''YES''
                            ELSE ''NO''
                        END

                    UNION ALL

                    SELECT
                        6,
                        ''Selected Profile'',
                        ''DATE/TIME''

                    UNION ALL

                    SELECT
                        10,
                        ''Total Rows'',
                        CAST(@pTotalRows AS varchar(8000))

                    UNION ALL

                    SELECT
                        11,
                        ''Populated Rows'',
                        CAST(@pPopulatedRows AS varchar(8000))

                    UNION ALL

                    SELECT
                        12,
                        ''Populated %'',
                        CAST(
                            CAST(
                                100.0 * @pPopulatedRows
                                / NULLIF(@pTotalRows, 0)
                                AS decimal(7,2)
                            )
                            AS varchar(8000)
                        )

                    UNION ALL

                    SELECT
                        13,
                        ''Null Rows'',
                        CAST(@pNullRows AS varchar(8000))

                    UNION ALL

                    SELECT
                        14,
                        ''Null %'',
                        CAST(
                            CAST(
                                100.0 * @pNullRows
                                / NULLIF(@pTotalRows, 0)
                                AS decimal(7,2)
                            )
                            AS varchar(8000)
                        )

                    UNION ALL

                    SELECT
                        15,
                        ''Distinct Values'',
                        CAST(@pDistinctValues AS varchar(8000))

                    UNION ALL

                    SELECT
                        16,
                        ''Distinct % of Populated'',
                        CAST(
                            CAST(
                                100.0 * @pDistinctValues
                                / NULLIF(@pPopulatedRows, 0)
                                AS decimal(7,2)
                            )
                            AS varchar(8000)
                        )

                    UNION ALL

                    SELECT
                        20,
                        ''Earliest Time'',
                        COALESCE(
                            CAST(s.earliest_time AS varchar(8000)),
                            ''NULL''
                        )
                    FROM statistics AS s

                    UNION ALL

                    SELECT
                        21,
                        ''Latest Time'',
                        COALESCE(
                            CAST(s.latest_time AS varchar(8000)),
                            ''NULL''
                        )
                    FROM statistics AS s
                )

                SELECT
                    metric,
                    value

                FROM metrics

                ORDER BY
                    metric_order;';


            EXEC sys.sp_executesql
                @SQL,

                N'@pSchema varchar(128),
                  @pTable varchar(128),
                  @pColumn varchar(128),
                  @pDataType varchar(128),
                  @pNullable bit,
                  @pTotalRows bigint,
                  @pPopulatedRows bigint,
                  @pNullRows bigint,
                  @pDistinctValues bigint',

                @pSchema = @SchemaName,
                @pTable = @TableName,
                @pColumn = @ColumnName,
                @pDataType = @DataType,
                @pNullable = @IsNullable,
                @pTotalRows = @TotalRows,
                @pPopulatedRows = @PopulatedRows,
                @pNullRows = @NullRows,
                @pDistinctValues = @DistinctValues;

            RETURN;
        END;


        SET @SQL =
            N'WITH statistics AS
            (
                SELECT
                    MIN(' + @QuotedColumn + N') AS earliest_value,
                    MAX(' + @QuotedColumn + N') AS latest_value,

                    DATEDIFF(
                        day,
                        MIN(' + @QuotedColumn + N'),
                        MAX(' + @QuotedColumn + N')
                    ) AS range_days,

                    SUM(
                        CASE
                            WHEN ' + @QuotedColumn + N' > SYSDATETIME()
                                THEN CAST(1 AS bigint)
                            ELSE CAST(0 AS bigint)
                        END
                    ) AS future_count,

                    SUM(
                        CASE
                            WHEN ' + @QuotedColumn + N' < @pMinimumDate
                                THEN CAST(1 AS bigint)
                            ELSE CAST(0 AS bigint)
                        END
                    ) AS before_minimum_count

                FROM ' + @QualifiedTable + N'
            ),
            metrics AS
            (
                SELECT
                    1 AS metric_order,
                    ''Schema'' AS metric,
                    CAST(@pSchema AS varchar(8000)) AS value

                UNION ALL

                SELECT
                    2,
                    ''Table'',
                    CAST(@pTable AS varchar(8000))

                UNION ALL

                SELECT
                    3,
                    ''Column'',
                    CAST(@pColumn AS varchar(8000))

                UNION ALL

                SELECT
                    4,
                    ''Data Type'',
                    CAST(@pDataType AS varchar(8000))

                UNION ALL

                SELECT
                    5,
                    ''Nullable'',
                    CASE
                        WHEN @pNullable = 1 THEN ''YES''
                        ELSE ''NO''
                    END

                UNION ALL

                SELECT
                    6,
                    ''Selected Profile'',
                    ''DATE/TIME''

                UNION ALL

                SELECT
                    10,
                    ''Total Rows'',
                    CAST(@pTotalRows AS varchar(8000))

                UNION ALL

                SELECT
                    11,
                    ''Populated Rows'',
                    CAST(@pPopulatedRows AS varchar(8000))

                UNION ALL

                SELECT
                    12,
                    ''Populated %'',
                    CAST(
                        CAST(
                            100.0 * @pPopulatedRows
                            / NULLIF(@pTotalRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )

                UNION ALL

                SELECT
                    13,
                    ''Null Rows'',
                    CAST(@pNullRows AS varchar(8000))

                UNION ALL

                SELECT
                    14,
                    ''Null %'',
                    CAST(
                        CAST(
                            100.0 * @pNullRows
                            / NULLIF(@pTotalRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )

                UNION ALL

                SELECT
                    15,
                    ''Distinct Values'',
                    CAST(@pDistinctValues AS varchar(8000))

                UNION ALL

                SELECT
                    16,
                    ''Distinct % of Populated'',
                    CAST(
                        CAST(
                            100.0 * @pDistinctValues
                            / NULLIF(@pPopulatedRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )

                UNION ALL

                SELECT
                    20,
                    ''Earliest Value'',
                    COALESCE(
                        CAST(s.earliest_value AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    21,
                    ''Latest Value'',
                    COALESCE(
                        CAST(s.latest_value AS varchar(8000)),
                        ''NULL''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    22,
                    ''Range in Days'',
                    COALESCE(
                        CAST(s.range_days AS varchar(8000)),
                        ''N/A''
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    23,
                    ''Future Value Count'',
                    CAST(s.future_count AS varchar(8000))
                FROM statistics AS s

                UNION ALL

                SELECT
                    24,
                    ''Future Value %'',
                    CAST(
                        CAST(
                            100.0 * s.future_count
                            / NULLIF(@pTotalRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )
                FROM statistics AS s

                UNION ALL

                SELECT
                    25,
                    ''Minimum Expected Date'',
                    CONVERT(varchar(10), @pMinimumDate, 23)

                UNION ALL

                SELECT
                    26,
                    ''Before Minimum Date Count'',
                    CAST(s.before_minimum_count AS varchar(8000))
                FROM statistics AS s

                UNION ALL

                SELECT
                    27,
                    ''Before Minimum Date %'',
                    CAST(
                        CAST(
                            100.0 * s.before_minimum_count
                            / NULLIF(@pTotalRows, 0)
                            AS decimal(7,2)
                        )
                        AS varchar(8000)
                    )
                FROM statistics AS s
            )

            SELECT
                metric,
                value

            FROM metrics

            ORDER BY
                metric_order;';


        EXEC sys.sp_executesql
            @SQL,

            N'@pSchema varchar(128),
              @pTable varchar(128),
              @pColumn varchar(128),
              @pDataType varchar(128),
              @pNullable bit,
              @pTotalRows bigint,
              @pPopulatedRows bigint,
              @pNullRows bigint,
              @pDistinctValues bigint,
              @pMinimumDate date',

            @pSchema = @SchemaName,
            @pTable = @TableName,
            @pColumn = @ColumnName,
            @pDataType = @DataType,
            @pNullable = @IsNullable,
            @pTotalRows = @TotalRows,
            @pPopulatedRows = @PopulatedRows,
            @pNullRows = @NullRows,
            @pDistinctValues = @DistinctValues,
            @pMinimumDate = @MinimumExpectedDate;

        RETURN;
    END;


    /*=========================================================================
    9. Basic fallback profile
    =========================================================================*/

    SELECT
        metric,
        value

    FROM
    (
        SELECT
            1 AS metric_order,
            'Schema' AS metric,
            CAST(@SchemaName AS varchar(8000)) AS value

        UNION ALL

        SELECT
            2,
            'Table',
            CAST(@TableName AS varchar(8000))

        UNION ALL

        SELECT
            3,
            'Column',
            CAST(@ColumnName AS varchar(8000))

        UNION ALL

        SELECT
            4,
            'Data Type',
            CAST(@DataType AS varchar(8000))

        UNION ALL

        SELECT
            5,
            'Nullable',
            CASE
                WHEN @IsNullable = 1 THEN 'YES'
                ELSE 'NO'
            END

        UNION ALL

        SELECT
            6,
            'Selected Profile',
            'BASIC'

        UNION ALL

        SELECT
            10,
            'Total Rows',
            CAST(@TotalRows AS varchar(8000))

        UNION ALL

        SELECT
            11,
            'Populated Rows',
            CAST(@PopulatedRows AS varchar(8000))

        UNION ALL

        SELECT
            12,
            'Populated %',
            CAST(
                CAST(
                    100.0 * @PopulatedRows
                    / NULLIF(@TotalRows, 0)
                    AS decimal(7,2)
                )
                AS varchar(8000)
            )

        UNION ALL

        SELECT
            13,
            'Null Rows',
            CAST(@NullRows AS varchar(8000))

        UNION ALL

        SELECT
            14,
            'Null %',
            CAST(
                CAST(
                    100.0 * @NullRows
                    / NULLIF(@TotalRows, 0)
                    AS decimal(7,2)
                )
                AS varchar(8000)
            )

        UNION ALL

        SELECT
            15,
            'Distinct Values',
            CAST(@DistinctValues AS varchar(8000))

        UNION ALL

        SELECT
            16,
            'Distinct % of Populated',
            CAST(
                CAST(
                    100.0 * @DistinctValues
                    / NULLIF(@PopulatedRows, 0)
                    AS decimal(7,2)
                )
                AS varchar(8000)
            )

    ) AS basic_metrics

    ORDER BY
        metric_order;
END;
GO