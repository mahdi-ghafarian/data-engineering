CREATE TABLE [ref].[almp_code] (
    [almp_element]    VARCHAR (100) NOT NULL,
    [almp_code]       VARCHAR (20)  NOT NULL,
    [almp_label]      VARCHAR (500) NOT NULL,
    [program_type]    VARCHAR (10)  NOT NULL,
    [is_bypass_value] BIT           NOT NULL,
    [schema_version]  VARCHAR (10)  NOT NULL,
    [effective_from]  DATE          NOT NULL,
    [effective_to]    DATE          NULL,
    [is_active]       BIT           NOT NULL
);