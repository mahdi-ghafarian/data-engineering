CREATE TABLE [ref].[code_map]
(
    [source_system]       VARCHAR(50)    NOT NULL,
    [source_table]        VARCHAR(100)   NULL,
    [source_column]       VARCHAR(100)   NOT NULL,
    [source_value]        VARCHAR(200)   NOT NULL,
    [source_label]        VARCHAR(500)   NULL,

    [almp_element_name]   VARCHAR(100)   NOT NULL,
    [almp_code]           VARCHAR(20)    NOT NULL,
    [almp_program_type]   VARCHAR(10)    NOT NULL,
    [almp_schema_version] VARCHAR(10)    NOT NULL,

    [effective_from]      DATE           NOT NULL,
    [effective_to]        DATE           NULL,
    [mapping_note]        VARCHAR(1000)  NULL
);
GO