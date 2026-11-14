CREATE TABLE [int].[intervention_support]
(
    /* Technical hierarchy keys */
    [intervention_support_id]           bigint NOT NULL,
    [intervention_id]                   bigint NOT NULL,
    [source_system]                     varchar(50)      NOT NULL,

    /*
        Used to select at most ten supports deterministically.
        Lower values should be selected first.
    */
    [submission_priority]               int              NOT NULL,

    /* Intervention Support business fields */
    [interventionCost]                  int              NULL,
    [interventionCostCategory]          int              NULL,
    [interventionCostCategoryComment]   varchar(150)     NULL,

    [sysComment]                        varchar(100)     NULL
);
GO