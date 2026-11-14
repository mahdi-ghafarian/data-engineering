CREATE TABLE [int].[intervention]
(
    /* Technical hierarchy keys */
    [intervention_id]                   bigint NOT NULL,
    [action_plan_id]                    bigint NOT NULL,

    /*
        Retained because it may simplify reporting-window selection
        and hierarchy validation. It is not needed to serialize XML.
    */
    [client_id]                         bigint NULL,

    /* Intervention business fields */
    [interventionID]                    varchar(30)      NULL,
    [interventionCode]                  int              NULL,
    [interventionTitle]                 varchar(150)     NULL,
    [interventionStartDate]             date             NULL,
    [interventionEndDate]               date             NULL,
    [interventionOutcome]               int              NULL,

    [interventionRelatedNOC]            varchar(5)       NULL,
    [interventionRelatedNOCVersion]     varchar(4)       NULL,
    [interventionLanguageOfService]     int              NULL,
    [interventionEssentialSkills]       int              NULL,
    [interventionCredential]            int              NULL,

    [sysComment]                        varchar(100)     NULL
);
GO

