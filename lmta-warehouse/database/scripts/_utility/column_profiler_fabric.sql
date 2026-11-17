/*
===============================================================================
MICROSOFT FABRIC WAREHOUSE
INTELLIGENT SINGLE-COLUMN PROFILER
ONE COMBINED VERTICAL RESULT
===============================================================================

CHANGE ONLY:
    @SchemaName
    @TableName
    @ColumnName
    @TopN

AUTOMATIC ROUTING:
    Text                         -> categorical
    Bit                          -> categorical
    Numeric <= threshold values  -> categorical
    Numeric > threshold values   -> continuous numeric
    Date/datetime                -> date/time
    Other                        -> basic

OUTPUT:
    Exactly one result grid:

        metric                         value
        -----------------------------  ------------------------------
        Schema                         stg
        Table                          prism_clt_contact
        Column                         gendercode
        Data Type                      int
        Selected Profile               CATEGORICAL NUMERIC
        Total Rows                     85123
        Populated Rows                 82341
        ...
        Value: 1                       42516 rows | 49.95% of all
        Value: 2                       37981 rows | 44.62% of all
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

DECLARE @ColumnName varchar(128) =
    'address1_city';

DECLARE @TopN int =
    20;

/*
Numeric columns at or below this cardinality are treated as categorical.
*/
DECLARE @CategoricalThreshold int =
    20;

/*
Used only for date/datetime profiling.
*/
DECLARE @MinimumExpectedDate date =
    '1900-01-01';


/*=============================================================================
2. VARIABLES
=============================================================================*/

DECLARE @QualifiedTable nvarchar(300);
DECLARE @QuotedColumn nvarchar(300);

DECLARE @SQL nvarchar(max);
DECLARE @NormalizedExpression nvarchar(max);
DECLARE @TextExpression nvarchar(max);

DECLARE @DataType varchar(128);
DECLARE @DefinedLength int;
DECLARE @NumericPrecision int;
DECLARE @NumericScale int;
DECLARE @IsNullable bit;

DECLARE @IsText bit = 0;
DECLARE @IsNumeric bit = 0;
DECLARE @IsDateTime bit = 0;
DECLARE @IsTimeOnly bit = 0;
DECLARE @IsBit bit = 0;

DECLARE @TotalRows bigint;
DECLARE @PopulatedRows bigint;
DECLARE @NullRows bigint;
DECLARE @DistinctValues bigint;

DECLARE @ProfileMode varchar(30);


SET @QualifiedTable =
    QUOTENAME(@SchemaName)
    + N'.'
    + QUOTENAME(@TableName);

SET @QuotedColumn =
    QUOTENAME(@ColumnName);


/*=============================================================================
3. VALIDATE CONFIGURATION
=============================================================================*/

IF @TopN < 1
BEGIN
    THROW 50000, 'Top N must be greater than zero.', 1;
END;

IF @CategoricalThreshold < 1
BEGIN
    THROW 50001, 'Categorical threshold must be greater than zero.', 1;
END;


/*=============================================================================
4. READ COLUMN METADATA
=============================================================================*/

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


/*=============================================================================
5. VALIDATE TABLE AND COLUMN
=============================================================================*/

IF @DataType IS NULL
BEGIN
    THROW 50002, 'The requested table or column does not exist.', 1;
END;


/*=============================================================================
6. BASIC COUNTS
=============================================================================*/

SET @SQL =
    N'SELECT '
    + N'@pTotalRows = COUNT_BIG(*), '

    + N'@pPopulatedRows = '
    + N'SUM'
    + N'('
        + N'CASE '
        + N'WHEN ' + @QuotedColumn + N' IS NOT NULL '
        + N'THEN CAST(1 AS bigint) '
        + N'ELSE CAST(0 AS bigint) '
        + N'END'
    + N'), '

    + N'@pNullRows = '
    + N'SUM'
    + N'('
        + N'CASE '
        + N'WHEN ' + @QuotedColumn + N' IS NULL '
        + N'THEN CAST(1 AS bigint) '
        + N'ELSE CAST(0 AS bigint) '
        + N'END'
    + N'), '

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


/*=============================================================================
7. SELECT PROFILE MODE
=============================================================================*/

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


/*=============================================================================
8. NORMALIZED EXPRESSIONS
=============================================================================*/

/*
Text values are trimmed.

NULL and blank values receive visible labels.

Non-text categorical values are converted to VARCHAR.
*/

IF @IsText = 1
BEGIN
    SET @NormalizedExpression =
        N'CASE '
        + N'WHEN ' + @QuotedColumn + N' IS NULL '
            + N'THEN ''[NULL]'' '
        + N'WHEN NULLIF'
        + N'('
            + N'TRIM'
            + N'('
                + N'CAST(' + @QuotedColumn + N' AS varchar(8000))'
            + N')'
            + N', '''
        + N''') IS NULL '
            + N'THEN ''[BLANK]'' '
        + N'ELSE '
            + N'TRIM'
            + N'('
                + N'CAST(' + @QuotedColumn + N' AS varchar(8000))'
            + N') '
        + N'END';

    SET @TextExpression =
        N'CAST(' + @QuotedColumn + N' AS varchar(8000))';
END;

ELSE
BEGIN
    SET @NormalizedExpression =
        N'CASE '
        + N'WHEN ' + @QuotedColumn + N' IS NULL '
            + N'THEN ''[NULL]'' '
        + N'ELSE CAST(' + @QuotedColumn + N' AS varchar(8000)) '
        + N'END';

    SET @TextExpression =
        N'CAST(NULL AS varchar(8000))';
END;


/*=============================================================================
9. CATEGORICAL PROFILE
=============================================================================*/

IF @ProfileMode IN
(
    'CATEGORICAL TEXT',
    'CATEGORICAL BIT',
    'CATEGORICAL NUMERIC'
)
BEGIN

    SET @SQL =
        N'WITH normalized AS '
        + N'('
            + N'SELECT '
                + @NormalizedExpression
                + N' AS normalized_value, '

                + @TextExpression
                + N' AS text_value '

            + N'FROM ' + @QualifiedTable
        + N'), '

        + N'summary AS '
        + N'('
            + N'SELECT '

            /* Blank rows */
            + CASE
                WHEN @IsText = 1
                THEN
                    N'SUM'
                    + N'('
                        + N'CASE '
                        + N'WHEN normalized_value = ''[BLANK]'' '
                        + N'THEN CAST(1 AS bigint) '
                        + N'ELSE CAST(0 AS bigint) '
                        + N'END'
                    + N')'
                ELSE
                    N'CAST(NULL AS bigint)'
              END
            + N' AS blank_rows, '

            /* Blank percentage */
            + CASE
                WHEN @IsText = 1
                THEN
                    N'CAST'
                    + N'('
                        + N'100.0 * '
                        + N'SUM'
                        + N'('
                            + N'CASE '
                            + N'WHEN normalized_value = ''[BLANK]'' '
                            + N'THEN 1 '
                            + N'ELSE 0 '
                            + N'END'
                        + N') '
                        + N'/ NULLIF(COUNT_BIG(*), 0) '
                        + N'AS decimal(7,2)'
                    + N')'
                ELSE
                    N'CAST(NULL AS decimal(7,2))'
              END
            + N' AS blank_pct, '

            /* Minimum populated value */
            + N'MIN'
            + N'('
                + N'CASE '
                + N'WHEN normalized_value IN '
                    + N'(''[NULL]'', ''[BLANK]'') '
                    + N'THEN NULL '
                + N'ELSE normalized_value '
                + N'END'
            + N') AS minimum_value, '

            /* Maximum populated value */
            + N'MAX'
            + N'('
                + N'CASE '
                + N'WHEN normalized_value IN '
                    + N'(''[NULL]'', ''[BLANK]'') '
                    + N'THEN NULL '
                + N'ELSE normalized_value '
                + N'END'
            + N') AS maximum_value, '

            /* Minimum text length */
            + CASE
                WHEN @IsText = 1
                THEN
                    N'MIN'
                    + N'('
                        + N'CASE '
                        + N'WHEN text_value IS NULL THEN NULL '
                        + N'ELSE LEN(text_value) '
                        + N'END'
                    + N')'
                ELSE
                    N'CAST(NULL AS int)'
              END
            + N' AS minimum_length, '

            /* Maximum text length */
            + CASE
                WHEN @IsText = 1
                THEN
                    N'MAX'
                    + N'('
                        + N'CASE '
                        + N'WHEN text_value IS NULL THEN NULL '
                        + N'ELSE LEN(text_value) '
                        + N'END'
                    + N')'
                ELSE
                    N'CAST(NULL AS int)'
              END
            + N' AS maximum_length, '

            /* Average text length */
            + CASE
                WHEN @IsText = 1
                THEN
                    N'CAST'
                    + N'('
                        + N'AVG'
                        + N'('
                            + N'CAST'
                            + N'('
                                + N'CASE '
                                + N'WHEN text_value IS NULL THEN NULL '
                                + N'ELSE LEN(text_value) '
                                + N'END '
                                + N'AS decimal(18,2)'
                            + N')'
                        + N') '
                        + N'AS decimal(18,2)'
                    + N')'
                ELSE
                    N'CAST(NULL AS decimal(18,2))'
              END
            + N' AS average_length '

            + N'FROM normalized'
        + N'), '

        + N'value_counts AS '
        + N'('
            + N'SELECT '
                + N'normalized_value, '
                + N'COUNT_BIG(*) AS row_count '

            + N'FROM normalized '

            + N'GROUP BY '
                + N'normalized_value'
        + N'), '

        + N'ranked AS '
        + N'('
            + N'SELECT '
                + N'normalized_value, '
                + N'row_count, '

                + N'ROW_NUMBER() OVER '
                + N'('
                    + N'ORDER BY '
                        + N'row_count DESC, '
                        + N'normalized_value'
                + N') AS value_rank, '

                + N'SUM(row_count) OVER () AS total_rows, '

                + N'SUM'
                + N'('
                    + N'CASE '
                    + N'WHEN normalized_value = ''[NULL]'' '
                    + N'THEN CAST(0 AS bigint) '
                    + N'ELSE row_count '
                    + N'END'
                + N') OVER () AS populated_rows '

            + N'FROM value_counts'
        + N'), '

        + N'distribution AS '
        + N'('
            + N'SELECT '
                + N'value_rank, '
                + N'normalized_value, '
                + N'row_count, '

                + N'CAST'
                + N'('
                    + N'100.0 * row_count '
                    + N'/ NULLIF(total_rows, 0) '
                    + N'AS decimal(7,2)'
                + N') AS pct_all, '

                + N'CASE '
                    + N'WHEN normalized_value = ''[NULL]'' '
                    + N'THEN CAST(NULL AS decimal(7,2)) '
                    + N'ELSE '
                        + N'CAST'
                        + N'('
                            + N'100.0 * row_count '
                            + N'/ NULLIF(populated_rows, 0) '
                            + N'AS decimal(7,2)'
                        + N') '
                    + N'END AS pct_populated, '

                + N'CAST'
                + N'('
                    + N'100.0 * '
                    + N'SUM(row_count) OVER '
                    + N'('
                        + N'ORDER BY '
                            + N'row_count DESC, '
                            + N'normalized_value '
                        + N'ROWS BETWEEN '
                            + N'UNBOUNDED PRECEDING '
                            + N'AND CURRENT ROW'
                    + N') '
                    + N'/ NULLIF(total_rows, 0) '
                    + N'AS decimal(7,2)'
                + N') AS cumulative_pct '

            + N'FROM ranked'
        + N'), '

        + N'metrics AS '
        + N'('

            /* Identification */

            + N'SELECT '
                + N'1 AS metric_order, '
                + N'''Schema'' AS metric, '
                + N'CAST(@pSchema AS varchar(8000)) AS value '

            + N'UNION ALL '

            + N'SELECT '
                + N'2, '
                + N'''Table'', '
                + N'CAST(@pTable AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'3, '
                + N'''Column'', '
                + N'CAST(@pColumn AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'4, '
                + N'''Data Type'', '
                + N'CAST(@pDataType AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'5, '
                + N'''Defined Length'', '
                + N'COALESCE'
                + N'('
                    + N'CAST(@pDefinedLength AS varchar(8000)), '
                    + N'''N/A'''
                + N') '

            + N'UNION ALL '

            + N'SELECT '
                + N'6, '
                + N'''Nullable'', '
                + N'CASE '
                + N'WHEN @pNullable = 1 THEN ''YES'' '
                + N'ELSE ''NO'' '
                + N'END '

            + N'UNION ALL '

            + N'SELECT '
                + N'7, '
                + N'''Selected Profile'', '
                + N'CAST(@pProfileMode AS varchar(8000)) '

            /* Completeness */

            + N'UNION ALL '

            + N'SELECT '
                + N'10, '
                + N'''Total Rows'', '
                + N'CAST(@pTotalRows AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'11, '
                + N'''Populated Rows'', '
                + N'CAST(@pPopulatedRows AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'12, '
                + N'''Populated %'', '
                + N'CAST'
                + N'('
                    + N'CAST'
                    + N'('
                        + N'100.0 * @pPopulatedRows '
                        + N'/ NULLIF(@pTotalRows, 0) '
                        + N'AS decimal(7,2)'
                    + N') '
                    + N'AS varchar(8000)'
                + N') '

            + N'UNION ALL '

            + N'SELECT '
                + N'13, '
                + N'''Null Rows'', '
                + N'CAST(@pNullRows AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'14, '
                + N'''Null %'', '
                + N'CAST'
                + N'('
                    + N'CAST'
                    + N'('
                        + N'100.0 * @pNullRows '
                        + N'/ NULLIF(@pTotalRows, 0) '
                        + N'AS decimal(7,2)'
                    + N') '
                    + N'AS varchar(8000)'
                + N') '

            + N'UNION ALL '

            + N'SELECT '
                + N'15, '
                + N'''Distinct Values'', '
                + N'CAST(@pDistinctValues AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'16, '
                + N'''Distinct % of Populated'', '
                + N'CAST'
                + N'('
                    + N'CAST'
                    + N'('
                        + N'100.0 * @pDistinctValues '
                        + N'/ NULLIF(@pPopulatedRows, 0) '
                        + N'AS decimal(7,2)'
                    + N') '
                    + N'AS varchar(8000)'
                + N') '

            /* Categorical summary */

            + N'UNION ALL '

            + N'SELECT '
                + N'17, '
                + N'''Blank Rows'', '
                + N'COALESCE'
                + N'('
                    + N'CAST(s.blank_rows AS varchar(8000)), '
                    + N'''N/A'''
                + N') '
            + N'FROM summary AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'18, '
                + N'''Blank %'', '
                + N'COALESCE'
                + N'('
                    + N'CAST(s.blank_pct AS varchar(8000)), '
                    + N'''N/A'''
                + N') '
            + N'FROM summary AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'19, '
                + N'''Minimum Value'', '
                + N'COALESCE(s.minimum_value, ''NULL'') '
            + N'FROM summary AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'20, '
                + N'''Maximum Value'', '
                + N'COALESCE(s.maximum_value, ''NULL'') '
            + N'FROM summary AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'21, '
                + N'''Minimum Length'', '
                + N'COALESCE'
                + N'('
                    + N'CAST(s.minimum_length AS varchar(8000)), '
                    + N'''N/A'''
                + N') '
            + N'FROM summary AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'22, '
                + N'''Maximum Length'', '
                + N'COALESCE'
                + N'('
                    + N'CAST(s.maximum_length AS varchar(8000)), '
                    + N'''N/A'''
                + N') '
            + N'FROM summary AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'23, '
                + N'''Average Length'', '
                + N'COALESCE'
                + N'('
                    + N'CAST(s.average_length AS varchar(8000)), '
                    + N'''N/A'''
                + N') '
            + N'FROM summary AS s '

            /* Top N distribution */

            + N'UNION ALL '

            + N'SELECT '
                + N'100 + CAST(d.value_rank AS int), '

                + N'''Value: '' '
                + N'+ d.normalized_value, '

                + N'CAST(d.row_count AS varchar(50)) '
                + N'+ '' rows | '' '
                + N'+ CAST(d.pct_all AS varchar(50)) '
                + N'+ ''% of all | '' '
                + N'+ COALESCE'
                + N'('
                    + N'CAST(d.pct_populated AS varchar(50)), '
                    + N'''N/A'''
                + N') '
                + N'+ ''% of populated | '' '
                + N'+ CAST(d.cumulative_pct AS varchar(50)) '
                + N'+ ''% cumulative'' '

            + N'FROM distribution AS d '

            + N'WHERE d.value_rank <= @pTopN'

        + N') '

        + N'SELECT '
            + N'metric, '
            + N'value '

        + N'FROM metrics '

        + N'ORDER BY metric_order;';


    EXEC sys.sp_executesql
        @SQL,

        N'@pSchema varchar(128),
          @pTable varchar(128),
          @pColumn varchar(128),
          @pDataType varchar(128),
          @pDefinedLength int,
          @pNullable bit,
          @pProfileMode varchar(30),
          @pTotalRows bigint,
          @pPopulatedRows bigint,
          @pNullRows bigint,
          @pDistinctValues bigint,
          @pTopN int',

        @pSchema = @SchemaName,
        @pTable = @TableName,
        @pColumn = @ColumnName,
        @pDataType = @DataType,
        @pDefinedLength = @DefinedLength,
        @pNullable = @IsNullable,
        @pProfileMode = @ProfileMode,
        @pTotalRows = @TotalRows,
        @pPopulatedRows = @PopulatedRows,
        @pNullRows = @NullRows,
        @pDistinctValues = @DistinctValues,
        @pTopN = @TopN;

END;


/*=============================================================================
10. CONTINUOUS NUMERIC PROFILE
=============================================================================*/

ELSE IF @ProfileMode = 'CONTINUOUS NUMERIC'
BEGIN

    SET @SQL =
        N'WITH statistics AS '
        + N'('
            + N'SELECT '

            + N'CAST'
            + N'('
                + N'MIN(' + @QuotedColumn + N') '
                + N'AS decimal(38,10)'
            + N') AS minimum_value, '

            + N'CAST'
            + N'('
                + N'MAX(' + @QuotedColumn + N') '
                + N'AS decimal(38,10)'
            + N') AS maximum_value, '

            + N'CAST'
            + N'('
                + N'MAX(' + @QuotedColumn + N') '
                + N'- MIN(' + @QuotedColumn + N') '
                + N'AS decimal(38,10)'
            + N') AS value_range, '

            + N'CAST'
            + N'('
                + N'AVG'
                + N'('
                    + N'CAST(' + @QuotedColumn + N' AS float)'
                + N') '
                + N'AS decimal(38,10)'
            + N') AS mean_value, '

            + N'CAST'
            + N'('
                + N'STDEV'
                + N'('
                    + N'CAST(' + @QuotedColumn + N' AS float)'
                + N') '
                + N'AS decimal(38,10)'
            + N') AS standard_deviation, '

            + N'CAST'
            + N'('
                + N'APPROX_PERCENTILE_CONT(0.05) '
                + N'WITHIN GROUP '
                + N'(ORDER BY ' + @QuotedColumn + N') '
                + N'AS decimal(38,10)'
            + N') AS p05, '

            + N'CAST'
            + N'('
                + N'APPROX_PERCENTILE_CONT(0.25) '
                + N'WITHIN GROUP '
                + N'(ORDER BY ' + @QuotedColumn + N') '
                + N'AS decimal(38,10)'
            + N') AS q1, '

            + N'CAST'
            + N'('
                + N'APPROX_PERCENTILE_CONT(0.50) '
                + N'WITHIN GROUP '
                + N'(ORDER BY ' + @QuotedColumn + N') '
                + N'AS decimal(38,10)'
            + N') AS median_value, '

            + N'CAST'
            + N'('
                + N'APPROX_PERCENTILE_CONT(0.75) '
                + N'WITHIN GROUP '
                + N'(ORDER BY ' + @QuotedColumn + N') '
                + N'AS decimal(38,10)'
            + N') AS q3, '

            + N'CAST'
            + N'('
                + N'APPROX_PERCENTILE_CONT(0.95) '
                + N'WITHIN GROUP '
                + N'(ORDER BY ' + @QuotedColumn + N') '
                + N'AS decimal(38,10)'
            + N') AS p95, '

            + N'SUM'
            + N'('
                + N'CASE '
                + N'WHEN ' + @QuotedColumn + N' = 0 '
                + N'THEN CAST(1 AS bigint) '
                + N'ELSE CAST(0 AS bigint) '
                + N'END'
            + N') AS zero_count, '

            + N'SUM'
            + N'('
                + N'CASE '
                + N'WHEN ' + @QuotedColumn + N' < 0 '
                + N'THEN CAST(1 AS bigint) '
                + N'ELSE CAST(0 AS bigint) '
                + N'END'
            + N') AS negative_count '

            + N'FROM ' + @QualifiedTable
        + N'), '

        + N'metrics AS '
        + N'('

            + N'SELECT '
                + N'1 AS metric_order, '
                + N'''Schema'' AS metric, '
                + N'CAST(@pSchema AS varchar(8000)) AS value '

            + N'UNION ALL '

            + N'SELECT '
                + N'2, '
                + N'''Table'', '
                + N'CAST(@pTable AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'3, '
                + N'''Column'', '
                + N'CAST(@pColumn AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'4, '
                + N'''Data Type'', '
                + N'CAST(@pDataType AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'5, '
                + N'''Numeric Precision'', '
                + N'CAST(@pPrecision AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'6, '
                + N'''Numeric Scale'', '
                + N'CAST(@pScale AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'7, '
                + N'''Nullable'', '
                + N'CASE '
                + N'WHEN @pNullable = 1 THEN ''YES'' '
                + N'ELSE ''NO'' '
                + N'END '

            + N'UNION ALL '

            + N'SELECT '
                + N'8, '
                + N'''Selected Profile'', '
                + N'''CONTINUOUS NUMERIC'' '

            + N'UNION ALL '

            + N'SELECT '
                + N'10, '
                + N'''Total Rows'', '
                + N'CAST(@pTotalRows AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'11, '
                + N'''Populated Rows'', '
                + N'CAST(@pPopulatedRows AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'12, '
                + N'''Populated %'', '
                + N'CAST'
                + N'('
                    + N'CAST'
                    + N'('
                        + N'100.0 * @pPopulatedRows '
                        + N'/ NULLIF(@pTotalRows, 0) '
                        + N'AS decimal(7,2)'
                    + N') '
                    + N'AS varchar(8000)'
                + N') '

            + N'UNION ALL '

            + N'SELECT '
                + N'13, '
                + N'''Null Rows'', '
                + N'CAST(@pNullRows AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'14, '
                + N'''Null %'', '
                + N'CAST'
                + N'('
                    + N'CAST'
                    + N'('
                        + N'100.0 * @pNullRows '
                        + N'/ NULLIF(@pTotalRows, 0) '
                        + N'AS decimal(7,2)'
                    + N') '
                    + N'AS varchar(8000)'
                + N') '

            + N'UNION ALL '

            + N'SELECT '
                + N'15, '
                + N'''Distinct Values'', '
                + N'CAST(@pDistinctValues AS varchar(8000)) '

            + N'UNION ALL '

            + N'SELECT '
                + N'20, '
                + N'''Minimum'', '
                + N'COALESCE(CAST(s.minimum_value AS varchar(8000)), ''NULL'') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'21, '
                + N'''Maximum'', '
                + N'COALESCE(CAST(s.maximum_value AS varchar(8000)), ''NULL'') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'22, '
                + N'''Range'', '
                + N'COALESCE(CAST(s.value_range AS varchar(8000)), ''NULL'') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'23, '
                + N'''Mean'', '
                + N'COALESCE(CAST(s.mean_value AS varchar(8000)), ''NULL'') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'24, '
                + N'''Standard Deviation'', '
                + N'COALESCE'
                + N'('
                    + N'CAST(s.standard_deviation AS varchar(8000)), '
                    + N'''NULL'''
                + N') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'25, '
                + N'''P05'', '
                + N'COALESCE(CAST(s.p05 AS varchar(8000)), ''NULL'') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'26, '
                + N'''Q1 / P25'', '
                + N'COALESCE(CAST(s.q1 AS varchar(8000)), ''NULL'') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'27, '
                + N'''Median / P50'', '
                + N'COALESCE(CAST(s.median_value AS varchar(8000)), ''NULL'') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'28, '
                + N'''Q3 / P75'', '
                + N'COALESCE(CAST(s.q3 AS varchar(8000)), ''NULL'') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'29, '
                + N'''P95'', '
                + N'COALESCE(CAST(s.p95 AS varchar(8000)), ''NULL'') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'30, '
                + N'''Interquartile Range'', '
                + N'COALESCE(CAST(s.q3 - s.q1 AS varchar(8000)), ''NULL'') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'31, '
                + N'''Zero Count'', '
                + N'CAST(s.zero_count AS varchar(8000)) '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'32, '
                + N'''Zero %'', '
                + N'CAST'
                + N'('
                    + N'CAST'
                    + N'('
                        + N'100.0 * s.zero_count '
                        + N'/ NULLIF(@pTotalRows, 0) '
                        + N'AS decimal(7,2)'
                    + N') '
                    + N'AS varchar(8000)'
                + N') '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'33, '
                + N'''Negative Count'', '
                + N'CAST(s.negative_count AS varchar(8000)) '
            + N'FROM statistics AS s '

            + N'UNION ALL '

            + N'SELECT '
                + N'34, '
                + N'''Negative %'', '
                + N'CAST'
                + N'('
                    + N'CAST'
                    + N'('
                        + N'100.0 * s.negative_count '
                        + N'/ NULLIF(@pTotalRows, 0) '
                        + N'AS decimal(7,2)'
                    + N') '
                    + N'AS varchar(8000)'
                + N') '
            + N'FROM statistics AS s '

        + N') '

        + N'SELECT '
            + N'metric, '
            + N'value '

        + N'FROM metrics '

        + N'ORDER BY metric_order;';


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

END;


/*=============================================================================
11. DATE/TIME PROFILE
=============================================================================*/

ELSE IF @ProfileMode = 'DATE/TIME'
BEGIN

    /*
    TIME values do not support meaningful future-date or date-range checks.
    They are instead profiled as time values.
    */

    IF @IsTimeOnly = 1
    BEGIN

        SET @SQL =
            N'WITH statistics AS '
            + N'('
                + N'SELECT '
                    + N'MIN(' + @QuotedColumn + N') AS earliest_time, '
                    + N'MAX(' + @QuotedColumn + N') AS latest_time '

                + N'FROM ' + @QualifiedTable
            + N'), '

            + N'metrics AS '
            + N'('

                + N'SELECT '
                    + N'1 AS metric_order, '
                    + N'''Schema'' AS metric, '
                    + N'CAST(@pSchema AS varchar(8000)) AS value '

                + N'UNION ALL '

                + N'SELECT '
                    + N'2, '
                    + N'''Table'', '
                    + N'CAST(@pTable AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'3, '
                    + N'''Column'', '
                    + N'CAST(@pColumn AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'4, '
                    + N'''Data Type'', '
                    + N'CAST(@pDataType AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'5, '
                    + N'''Nullable'', '
                    + N'CASE '
                    + N'WHEN @pNullable = 1 THEN ''YES'' '
                    + N'ELSE ''NO'' '
                    + N'END '

                + N'UNION ALL '

                + N'SELECT '
                    + N'6, '
                    + N'''Selected Profile'', '
                    + N'''DATE/TIME'' '

                + N'UNION ALL '

                + N'SELECT '
                    + N'10, '
                    + N'''Total Rows'', '
                    + N'CAST(@pTotalRows AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'11, '
                    + N'''Populated Rows'', '
                    + N'CAST(@pPopulatedRows AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'12, '
                    + N'''Populated %'', '
                    + N'CAST'
                    + N'('
                        + N'CAST'
                        + N'('
                            + N'100.0 * @pPopulatedRows '
                            + N'/ NULLIF(@pTotalRows, 0) '
                            + N'AS decimal(7,2)'
                        + N') '
                        + N'AS varchar(8000)'
                    + N') '

                + N'UNION ALL '

                + N'SELECT '
                    + N'13, '
                    + N'''Null Rows'', '
                    + N'CAST(@pNullRows AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'14, '
                    + N'''Null %'', '
                    + N'CAST'
                    + N'('
                        + N'CAST'
                        + N'('
                            + N'100.0 * @pNullRows '
                            + N'/ NULLIF(@pTotalRows, 0) '
                            + N'AS decimal(7,2)'
                        + N') '
                        + N'AS varchar(8000)'
                    + N') '

                + N'UNION ALL '

                + N'SELECT '
                    + N'15, '
                    + N'''Distinct Values'', '
                    + N'CAST(@pDistinctValues AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'20, '
                    + N'''Earliest Time'', '
                    + N'COALESCE'
                    + N'('
                        + N'CAST(s.earliest_time AS varchar(8000)), '
                        + N'''NULL'''
                    + N') '
                + N'FROM statistics AS s '

                + N'UNION ALL '

                + N'SELECT '
                    + N'21, '
                    + N'''Latest Time'', '
                    + N'COALESCE'
                    + N'('
                        + N'CAST(s.latest_time AS varchar(8000)), '
                        + N'''NULL'''
                    + N') '
                + N'FROM statistics AS s '

            + N') '

            + N'SELECT '
                + N'metric, '
                + N'value '

            + N'FROM metrics '

            + N'ORDER BY metric_order;';


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

    END;

    ELSE
    BEGIN

        SET @SQL =
            N'WITH statistics AS '
            + N'('
                + N'SELECT '
                    + N'MIN(' + @QuotedColumn + N') AS earliest_value, '
                    + N'MAX(' + @QuotedColumn + N') AS latest_value, '

                    + N'DATEDIFF'
                    + N'('
                        + N'day, '
                        + N'MIN(' + @QuotedColumn + N'), '
                        + N'MAX(' + @QuotedColumn + N')'
                    + N') AS range_days, '

                    + N'SUM'
                    + N'('
                        + N'CASE '
                        + N'WHEN ' + @QuotedColumn + N' > SYSDATETIME() '
                        + N'THEN CAST(1 AS bigint) '
                        + N'ELSE CAST(0 AS bigint) '
                        + N'END'
                    + N') AS future_count, '

                    + N'SUM'
                    + N'('
                        + N'CASE '
                        + N'WHEN ' + @QuotedColumn + N' < @pMinimumDate '
                        + N'THEN CAST(1 AS bigint) '
                        + N'ELSE CAST(0 AS bigint) '
                        + N'END'
                    + N') AS before_minimum_count '

                + N'FROM ' + @QualifiedTable
            + N'), '

            + N'metrics AS '
            + N'('

                + N'SELECT '
                    + N'1 AS metric_order, '
                    + N'''Schema'' AS metric, '
                    + N'CAST(@pSchema AS varchar(8000)) AS value '

                + N'UNION ALL '

                + N'SELECT '
                    + N'2, '
                    + N'''Table'', '
                    + N'CAST(@pTable AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'3, '
                    + N'''Column'', '
                    + N'CAST(@pColumn AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'4, '
                    + N'''Data Type'', '
                    + N'CAST(@pDataType AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'5, '
                    + N'''Nullable'', '
                    + N'CASE '
                    + N'WHEN @pNullable = 1 THEN ''YES'' '
                    + N'ELSE ''NO'' '
                    + N'END '

                + N'UNION ALL '

                + N'SELECT '
                    + N'6, '
                    + N'''Selected Profile'', '
                    + N'''DATE/TIME'' '

                + N'UNION ALL '

                + N'SELECT '
                    + N'10, '
                    + N'''Total Rows'', '
                    + N'CAST(@pTotalRows AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'11, '
                    + N'''Populated Rows'', '
                    + N'CAST(@pPopulatedRows AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'12, '
                    + N'''Populated %'', '
                    + N'CAST'
                    + N'('
                        + N'CAST'
                        + N'('
                            + N'100.0 * @pPopulatedRows '
                            + N'/ NULLIF(@pTotalRows, 0) '
                            + N'AS decimal(7,2)'
                        + N') '
                        + N'AS varchar(8000)'
                    + N') '

                + N'UNION ALL '

                + N'SELECT '
                    + N'13, '
                    + N'''Null Rows'', '
                    + N'CAST(@pNullRows AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'14, '
                    + N'''Null %'', '
                    + N'CAST'
                    + N'('
                        + N'CAST'
                        + N'('
                            + N'100.0 * @pNullRows '
                            + N'/ NULLIF(@pTotalRows, 0) '
                            + N'AS decimal(7,2)'
                        + N') '
                        + N'AS varchar(8000)'
                    + N') '

                + N'UNION ALL '

                + N'SELECT '
                    + N'15, '
                    + N'''Distinct Values'', '
                    + N'CAST(@pDistinctValues AS varchar(8000)) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'20, '
                    + N'''Earliest Value'', '
                    + N'COALESCE'
                    + N'('
                        + N'CAST(s.earliest_value AS varchar(8000)), '
                        + N'''NULL'''
                    + N') '
                + N'FROM statistics AS s '

                + N'UNION ALL '

                + N'SELECT '
                    + N'21, '
                    + N'''Latest Value'', '
                    + N'COALESCE'
                    + N'('
                        + N'CAST(s.latest_value AS varchar(8000)), '
                        + N'''NULL'''
                    + N') '
                + N'FROM statistics AS s '

                + N'UNION ALL '

                + N'SELECT '
                    + N'22, '
                    + N'''Range in Days'', '
                    + N'COALESCE'
                    + N'('
                        + N'CAST(s.range_days AS varchar(8000)), '
                        + N'''N/A'''
                    + N') '
                + N'FROM statistics AS s '

                + N'UNION ALL '

                + N'SELECT '
                    + N'23, '
                    + N'''Future Value Count'', '
                    + N'CAST(s.future_count AS varchar(8000)) '
                + N'FROM statistics AS s '

                + N'UNION ALL '

                + N'SELECT '
                    + N'24, '
                    + N'''Future Value %'', '
                    + N'CAST'
                    + N'('
                        + N'CAST'
                        + N'('
                            + N'100.0 * s.future_count '
                            + N'/ NULLIF(@pTotalRows, 0) '
                            + N'AS decimal(7,2)'
                        + N') '
                        + N'AS varchar(8000)'
                    + N') '
                + N'FROM statistics AS s '

                + N'UNION ALL '

                + N'SELECT '
                    + N'25, '
                    + N'''Minimum Expected Date'', '
                    + N'CONVERT(varchar(10), @pMinimumDate, 23) '

                + N'UNION ALL '

                + N'SELECT '
                    + N'26, '
                    + N'''Before Minimum Date Count'', '
                    + N'CAST(s.before_minimum_count AS varchar(8000)) '
                + N'FROM statistics AS s '

                + N'UNION ALL '

                + N'SELECT '
                    + N'27, '
                    + N'''Before Minimum Date %'', '
                    + N'CAST'
                    + N'('
                        + N'CAST'
                        + N'('
                            + N'100.0 * s.before_minimum_count '
                            + N'/ NULLIF(@pTotalRows, 0) '
                            + N'AS decimal(7,2)'
                        + N') '
                        + N'AS varchar(8000)'
                    + N') '
                + N'FROM statistics AS s '

            + N') '

            + N'SELECT '
                + N'metric, '
                + N'value '

            + N'FROM metrics '

            + N'ORDER BY metric_order;';


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

    END;

END;


/*=============================================================================
12. BASIC PROFILE
=============================================================================*/

ELSE
BEGIN

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
            CAST
            (
                CAST
                (
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
            CAST
            (
                CAST
                (
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
            CAST
            (
                CAST
                (
                    100.0 * @DistinctValues
                    / NULLIF(@PopulatedRows, 0)
                    AS decimal(7,2)
                )
                AS varchar(8000)
            )

    ) AS basic_metrics

    ORDER BY metric_order;

END;