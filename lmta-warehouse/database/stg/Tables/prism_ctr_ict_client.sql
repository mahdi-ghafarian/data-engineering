CREATE TABLE [stg].[prism_ctr_ict_client] (
    [ict_clientidid]            VARCHAR (8000) NULL,
    [ict_name]                  VARCHAR (8000) NULL,
    [ict_clientid]              VARCHAR (8000) NULL,
    [ict_clientcontactid]       VARCHAR (8000) NULL,
    [crdb7_consentdate]         VARCHAR (8000) NULL,
    [createdon]                 DATETIME2 (6)  NULL,
    [emailaddress]              VARCHAR (8000) NULL,
    [ict_age]                   INT            NULL,
    [ict_approveddate]          DATETIME2 (6)  NULL,
    [ict_birthdate]             DATETIME2 (6)  NULL,
    [ict_canvasapp_clientid]    VARCHAR (8000) NULL,
    [ict_contract]              VARCHAR (8000) NULL,
    [ict_contractnum]           VARCHAR (8000) NULL,
    [ict_email]                 VARCHAR (8000) NULL,
    [ict_firstname]             VARCHAR (8000) NULL,
    [ict_lastname]              VARCHAR (8000) NULL,
    [ict_mailingaddress]        VARCHAR (8000) NULL,
    [ict_openserviceplans]      BIT            NULL,
    [ict_phonenumber]           VARCHAR (8000) NULL,
    [ict_rationale]             VARCHAR (8000) NULL,
    [modifiedon]                DATETIME2 (6)  NULL,
    [statecode]                 INT            NULL,
    [statuscode]                INT            NULL,
    [timezoneruleversionnumber] INT            NULL
);
GO

