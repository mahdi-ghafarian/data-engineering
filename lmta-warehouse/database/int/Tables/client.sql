CREATE TABLE [int].[client]
(
    /* Technical hierarchy key */
    [client_id]                         uniqueidentifier NOT NULL,

    /* Client business fields */
    [clientID]                          varchar(30)      NULL,
    [socialInsuranceNumber]             varchar(9)       NULL,
    [lastName]                          varchar(100)     NULL,
    [firstName]                         varchar(100)     NULL,
    [dateOfBirth]                       date             NULL,
    [emailAddress]                      varchar(254)     NULL,
    [gender]                            int              NULL,
    [maritalStatus]                     int              NULL,
    [numberOfDependantChildren]         int              NULL,
    [languageSpoken]                    int              NULL,
    [disability]                        int              NULL,
    [indigenousIdentity]                int              NULL,
    [immigrant]                         int              NULL,
    [immigrationYear]                   varchar(4)       NULL,
    [visibleMinority]                   int              NULL,

    /* Flattened client address */
    [streetAddress]                     varchar(150)     NULL,
    [municipality]                      varchar(100)     NULL,
    [province]                          int              NULL,
    [postalZIPCode]                     varchar(10)      NULL,
    [contactPhoneNumber]                varchar(30)      NULL,
    [addressSysComment]                 varchar(100)     NULL,

    /* Valid federal output field */
    [sysComment]                        varchar(100)     NULL
);
GO
