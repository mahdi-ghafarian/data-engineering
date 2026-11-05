CREATE TABLE [almp].[intervention] (
    [submission_id]                 BIGINT        NOT NULL,
    [action_plan_id]                BIGINT        NOT NULL,
    [intervention_id]               BIGINT        NOT NULL,
    [interventionID]                VARCHAR (30)  NULL,
    [interventionTitle]             VARCHAR (150) NULL,
    [interventionCode]              INT           NOT NULL,
    [interventionStartDate]         DATE          NOT NULL,
    [interventionEndDate]           DATE          NULL,
    [interventionOutcome]           INT           NULL,
    [interventionRelatedNOC]        VARCHAR (5)   NULL,
    [interventionRelatedNOCVersion] VARCHAR (4)   NULL,
    [interventionLanguageOfService] INT           NULL,
    [interventionEssentialSkills]   INT           NULL,
    [interventionCredential]        INT           NULL,
    [sysComment]                    VARCHAR (100) NULL
);
GO

