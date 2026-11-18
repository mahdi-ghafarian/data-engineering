CREATE TABLE [stg].[prism_ctr_pcm_contracttype] (
    [pcm_contracttypeid] VARCHAR (8000) NULL,
    [pcm_name]           VARCHAR (8000) NULL,
    [ict_siteextension]  VARCHAR (8000) NULL,
    [pcm_approvaloption] INT            NULL,
    [pcm_approvalruleid] VARCHAR (8000) NULL,
    [pcm_contracttypes]  INT            NULL,
    [createdon]          DATETIME2 (6)  NULL,
    [modifiedon]         DATETIME2 (6)  NULL,
    [statecode]          INT            NULL,
    [statuscode]         INT            NULL
);
GO

