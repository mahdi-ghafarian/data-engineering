CREATE TABLE [almp].[intervention_support] (
    [submission_id]                   BIGINT        NOT NULL,
    [intervention_id]                 BIGINT        NOT NULL,
    [intervention_support_id]         BIGINT        NOT NULL,
    [interventionCost]                INT           NOT NULL,
    [interventionCostCategory]        INT           NOT NULL,
    [interventionCostCategoryComment] VARCHAR (150) NULL
);
GO

