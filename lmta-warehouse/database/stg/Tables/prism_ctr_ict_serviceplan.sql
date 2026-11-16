CREATE TABLE [stg].[prism_ctr_ict_serviceplan] (
    [ict_name]                 VARCHAR (8000) NULL,
    [ict_client]               VARCHAR (8000) NULL,
    [ict_closuredate]          DATETIME2 (6)  NULL,
    [ict_closurereason]        INT            NULL,
    [ict_contractid]           VARCHAR (8000) NULL,
    [ict_goalstatement]        VARCHAR (8000) NULL,
    [ict_responseoutcome]      INT            NULL,
    [ict_responsereceiveddate] DATETIME2 (6)  NULL,
    [ict_serviceplanid]        VARCHAR (8000) NULL,
    [ict_serviceplanstatus]    INT            NULL,
    [ict_startdate]            DATETIME2 (6)  NULL,
    [ict_summary]              VARCHAR (8000) NULL,
    [ict_suppliername]         VARCHAR (8000) NULL,
    [ict_surveysent]           BIT            NULL,
    [createdon]                DATETIME2 (6)  NULL,
    [modifiedon]               DATETIME2 (6)  NULL,
    [statecode]                INT            NULL,
    [statuscode]               INT            NULL
);
GO

