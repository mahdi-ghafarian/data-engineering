CREATE TABLE [int].[action_plan_followup]
(
    /* Technical hierarchy keys */
    [action_plan_followup_id]                   bigint NOT NULL,
    [action_plan_id]                            bigint NOT NULL,

    /*
        Used to select at most five follow-ups deterministically.
        Lower values should be selected first.
    */
    [submission_priority]                       int              NOT NULL,

    /* Follow-Up business fields */
    [actionPlanFollowUpID]                      varchar(30)      NULL,
    [actionPlanFollowUpDate]                    date             NULL,
    [actionPlanFollowUpResultCode]              int              NULL,
    [actionPlanFollowUpEmploymentDate]          date             NULL,
    [actionPlanFollowUpEmployerName]            varchar(150)     NULL,
    [actionPlanFollowUpMultipleEmployment]      int              NULL,
    [actionPlanFollowUpNAICS]                   varchar(6)       NULL,
    [actionPlanFollowUpNAICSVersion]            varchar(4)       NULL,

    /*
        Use the full XSD element names.
        The shortened PayRate/Hours names in some documentation
        must not be used.
    */
    [actionPlanFollowUpEmploymentPayRate]       decimal(10,2)    NULL,
    [actionPlanFollowUpEmploymentHours]         decimal(6,2)     NULL,

    [sysComment]                                varchar(100)     NULL
);
GO

