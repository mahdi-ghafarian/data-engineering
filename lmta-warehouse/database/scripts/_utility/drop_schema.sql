DECLARE @SchemaName sysname = 'stg';
DECLARE @SQL varchar(8000) = '';

-- Drop all tables in schema
SELECT @SQL = @SQL +
    'DROP TABLE '
    + QUOTENAME(@SchemaName) + '.'
    + QUOTENAME(TABLE_NAME) + ';'
    + CHAR(10)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = @SchemaName
  AND TABLE_TYPE = 'BASE TABLE';

PRINT @SQL;
EXEC(@SQL);

-- Drop schema
SET @SQL = 'DROP SCHEMA ' + QUOTENAME(@SchemaName) + ';';

PRINT @SQL;
EXEC(@SQL);