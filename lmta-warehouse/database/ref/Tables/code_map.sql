CREATE TABLE [ref].[code_map] (
    [code_map_id]    BIGINT        NOT NULL,
    [source_system]  VARCHAR (50)  NOT NULL,
    [code_domain]    VARCHAR (100) NOT NULL,
    [source_value]   VARCHAR (200) NOT NULL,
    [almp_code]      VARCHAR (20)  NOT NULL,
    [program_type]   VARCHAR (10)  NOT NULL,
    [effective_from] DATE          NOT NULL,
    [effective_to]   DATE          NULL
);
GO

