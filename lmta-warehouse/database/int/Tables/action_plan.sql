CREATE TABLE [int].[action_plan]
(
    /* Technical hierarchy keys */
    [action_plan_id]                            bigint NOT NULL,
    [client_id]                                 bigint NOT NULL,

    /* Action Plan business fields */
    [actionPlanID]                              varchar(30)      NULL,
    [agreementNumber]                           varchar(30)      NULL,
    [actionPlanFundingSource]                   int              NULL,
    [educationLevel]                            int              NULL,
    [educationLevelComment]                     varchar(150)     NULL,
    [provincialOfficeCode]                      varchar(20)      NULL,

    [actionPlanPreviousEmployment]              int              NULL,
    [actionPlanPreviousMultipleEmployment]      int              NULL,
    [actionPlanEmployerName]                    varchar(150)     NULL,

    [actionPlanPreviousEmploymentNOC]           varchar(5)       NULL,
    [actionPlanPreviousEmploymentNOCVersion]    varchar(4)       NULL,
    [actionPlanPreviousEmploymentNAICS]         varchar(6)       NULL,
    [actionPlanPreviousEmploymentNAICSVersion]  varchar(4)       NULL,
    [actionPlanPreviousEmploymentDate]          date             NULL,
    [actionPlanPreviousEmploymentPayRate]       decimal(10,2)    NULL,
    [actionPlanPreviousEmploymentHours]         decimal(6,2)     NULL,

    [actionPlanTargetNAICS]                     varchar(6)       NULL,
    [actionPlanTargetNAICSVersion]              varchar(4)       NULL,

    [actionPlanPreviousEmploymentScheduleType]  int              NULL,
    [actionPlanPrecariousEmployment]            int              NULL,

    [actionPlanStartDate]                       date             NULL,
    [actionPlanEndDate]                         date             NULL,
    [actionPlanResultCode]                      int              NULL,
    [actionPlanResultDate]                      date             NULL,

    [actionPlanResultRelatedNOC]                varchar(5)       NULL,
    [actionPlanResultRelatedNOCVersion]         varchar(4)       NULL,
    [actionPlanResultEducationLevel]            int              NULL,
    [actionPlanFutureEducationLevel]            int              NULL,

    [sysComment]                                varchar(100)     NULL
);
GO
