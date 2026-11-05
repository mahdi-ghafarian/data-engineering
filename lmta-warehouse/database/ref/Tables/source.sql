CREATE TABLE [ref].[source] (
    [source_system]     VARCHAR (50)  NOT NULL,
    [entity_name]       VARCHAR (100) NOT NULL,
    [attribute_name]    VARCHAR (100) NOT NULL,
    [priority_rank]     INT           NOT NULL,
    [frequency]         VARCHAR (20)  NULL,
    [expected_lag_days] INT           NULL,
    [is_required]       BIT           NOT NULL,
    [is_active]         BIT           NOT NULL
);
GO

