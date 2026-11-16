CREATE TABLE [stg].[prism_clt_ict_actionplan] (
    [ict_name]                                      VARCHAR (8000) NULL,
    [ict_actionplanid]                              VARCHAR (8000) NULL,
    [ict_client]                                    VARCHAR (8000) NULL,
    [ict_actionplanstartdate]                       DATETIME2 (6)  NULL,
    [ict_actionplanstatus]                          INT            NULL,
    [ict_assessededhistory]                         VARCHAR (8000) NULL,
    [ict_closuredate]                               DATETIME2 (6)  NULL,
    [ict_closurereason]                             INT            NULL,
    [ict_doesclienteistatusallowforsection25referr] BIT            NULL,
    [ict_goalstatement]                             VARCHAR (8000) NULL,
    [ict_responseoutcome]                           INT            NULL,
    [ict_responsereceiveddate]                      DATETIME2 (6)  NULL,
    [ict_summaryofactionplan]                       VARCHAR (8000) NULL,
    [ict_surveysent]                                BIT            NULL,
    [createdon]                                     DATETIME2 (6)  NULL,
    [modifiedon]                                    DATETIME2 (6)  NULL,
    [statecode]                                     INT            NULL,
    [statuscode]                                    INT            NULL
);
GO

