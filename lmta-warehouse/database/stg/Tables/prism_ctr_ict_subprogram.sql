CREATE TABLE [stg].[prism_ctr_ict_subprogram] (
    [ict_subprogramid]       VARCHAR (8000) NULL,
    [ict_name]               VARCHAR (8000) NULL,
    [ict_contracttypeid]     VARCHAR (8000) NULL,
    [ict_accountcode]        VARCHAR (8000) NULL,
    [ict_entitycode]         VARCHAR (8000) NULL,
    [ict_future]             VARCHAR (8000) NULL,
    [ict_programcode]        VARCHAR (8000) NULL,
    [ict_projectcode]        VARCHAR (8000) NULL,
    [ict_projectdescription] VARCHAR (8000) NULL,
    [ict_siteextension]      VARCHAR (8000) NULL,
    [createdon]              DATETIME2 (6)  NULL,
    [modifiedon]             DATETIME2 (6)  NULL,
    [statecode]              INT            NULL,
    [statuscode]             INT            NULL
);
GO

