CREATE TABLE [almp].[action_plan_followup] (
    [submission_id]                        BIGINT        NOT NULL,
    [action_plan_id]                       BIGINT        NOT NULL,
    [action_plan_followup_id]              BIGINT        NOT NULL,
    [actionPlanFollowUpID]                 VARCHAR (30)  NULL,
    [actionPlanFollowUpDate]               DATE          NULL,
    [actionPlanFollowUpResultCode]         INT           NULL,
    [actionPlanFollowUpResultDate]         DATE          NULL,
    [actionPlanFollowUpEmployerName]       VARCHAR (100) NULL,
    [actionPlanFollowUpMultipleEmployment] INT           NULL,
    [actionPlanFollowUpNOC]                VARCHAR (5)   NULL,
    [actionPlanFollowUpNOCVersion]         VARCHAR (4)   NULL,
    [actionPlanFollowUpNAICS]              VARCHAR (6)   NULL,
    [actionPlanFollowUpNAICSVersion]       VARCHAR (4)   NULL,
    [actionPlanFollowUpEmploymentPayRate]  VARCHAR (6)   NULL,
    [actionPlanFollowUpEmploymentHours]    VARCHAR (4)   NULL,
    [sysComment]                           VARCHAR (100) NULL
);
GO

