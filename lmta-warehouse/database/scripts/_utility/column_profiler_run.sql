EXEC util.column_profiler
    @SchemaName = 'stg',
    @TableName = 'prism_clt_contact',
    @ColumnName = 'address1_stateorprovince',
    @TopN = 20;