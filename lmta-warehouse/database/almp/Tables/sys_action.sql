CREATE TABLE [almp].[sys_action] (
    [submission_id]         BIGINT        NOT NULL,
    [sys_action_id]         BIGINT        NOT NULL,
    [socialInsuranceNumber] VARCHAR (9)   NULL,
    [clientID]              VARCHAR (30)  NULL,
    [agreementNumber]       VARCHAR (9)   NOT NULL,
    [actionPlanStartDate]   DATE          NULL,
    [interventionStartDate] DATE          NULL,
    [interventionCode]      INT           NULL,
    [actionPlanID]          VARCHAR (30)  NULL,
    [interventionID]        VARCHAR (30)  NULL,
    [systemAction]          INT           NOT NULL,
    [sysComment]            VARCHAR (100) NULL
);
GO

