CREATE TABLE [almp].[client] (
    [submission_id]             BIGINT        NOT NULL,
    [client_id]                 BIGINT        NOT NULL,
    [clientID]                  VARCHAR (30)  NULL,
    [socialInsuranceNumber]     VARCHAR (9)   NOT NULL,
    [lastName]                  VARCHAR (100) NULL,
    [firstName]                 VARCHAR (100) NULL,
    [dateOfBirth]               DATE          NOT NULL,
    [emailAddress]              VARCHAR (254) NULL,
    [gender]                    INT           NOT NULL,
    [maritalStatus]             INT           NULL,
    [numberOfDependantChildren] INT           NULL,
    [languageSpoken]            INT           NULL,
    [disability]                INT           NOT NULL,
    [indigenousIdentity]        INT           NULL,
    [immigrant]                 INT           NULL,
    [immigrationYear]           VARCHAR (4)   NULL,
    [visibleMinority]           INT           NULL,
    [streetAddress]             VARCHAR (200) NULL,
    [municipality]              VARCHAR (100) NULL,
    [province]                  INT           NULL,
    [postalZIPCode]             VARCHAR (20)  NULL,
    [contactPhoneNumber]        VARCHAR (30)  NULL,
    [addressSysComment]         VARCHAR (100) NULL,
    [sysComment]                VARCHAR (100) NULL
);
GO

