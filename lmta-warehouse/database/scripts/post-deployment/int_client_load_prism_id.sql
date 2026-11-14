/*==============================================================
  Populate [int].[client]

  Target:
      [int].[client]

  Source:
      [stg].[prism_clt_contact]

  Mapping:
      [ref].[code_map]

  Behavior:
      1. Truncate the current integration table.
      2. Load active PRISM clients.
      3. Generate a run-scoped bigint client_id.
      4. Use the single active Schema 1.5 mapping.
      5. Constrain strings to target/XSD maximum lengths.

  Important:
      - client_id is regenerated on every refresh.
      - client_id is only a technical hierarchy key.
      - clientID remains the federal/provincial business field.
==============================================================*/

TRUNCATE TABLE [int].[client];
GO


WITH active_code_map AS
(
    SELECT
        cm.source_column,
        cm.source_code,
        cm.almp_element,
        cm.almp_code
    FROM [ref].[code_map] AS cm
    WHERE cm.source_system = 'PRISM_CLT'
      AND cm.source_table = 'contact'
      AND cm.almp_program_type = 'BOTH'
      AND cm.almp_schema_version = '1.5'
      AND cm.is_active = 1
),
gender_map AS
(
    SELECT
        source_code,
        almp_code
    FROM active_code_map
    WHERE source_column = 'gendercode'
      AND almp_element = 'gender'
),
marital_status_map AS
(
    SELECT
        source_code,
        almp_code
    FROM active_code_map
    WHERE source_column = 'familystatuscode'
      AND almp_element = 'maritalStatus'
),
language_map AS
(
    SELECT
        source_code,
        almp_code
    FROM active_code_map
    WHERE source_column = 'ict_languageofservices'
      AND almp_element = 'languageSpoken'
),
disability_map AS
(
    SELECT
        source_code,
        almp_code
    FROM active_code_map
    WHERE source_column = 'ict_disability'
      AND almp_element = 'disability'
),
indigenous_identity_map AS
(
    SELECT
        source_code,
        almp_code
    FROM active_code_map
    WHERE source_column = 'ict_indigenousidentity'
      AND almp_element = 'indigenousIdentity'
),
immigrant_map AS
(
    SELECT
        source_code,
        almp_code
    FROM active_code_map
    WHERE source_column = 'ict_citizenshipimmigrationstatus'
      AND almp_element = 'immigrant'
),
visible_minority_map AS
(
    SELECT
        source_code,
        almp_code
    FROM active_code_map
    WHERE source_column = 'ict_visibleminority'
      AND almp_element = 'visibleMinority'
),
province_map AS
(
    SELECT
        source_code,
        almp_code
    FROM active_code_map
    WHERE source_column = 'address1_stateorprovince'
      AND almp_element = 'province'
),
prepared_client AS
(
    SELECT
        c.contactid,

        /* Provincial Client ID: maximum 30 characters */
        LEFT
        (
            NULLIF
            (
                LTRIM
                (
                    RTRIM
                    (
                        CAST(c.ict_clientid AS varchar(4000))
                    )
                ),
                ''
            ),
            30
        ) AS clientID,

        /* Normalize before validating SIN */
        NULLIF
        (
            REPLACE
            (
                REPLACE
                (
                    REPLACE
                    (
                        LTRIM
                        (
                            RTRIM
                            (
                                CAST(c.ict_sin AS varchar(4000))
                            )
                        ),
                        '-',
                        ''
                    ),
                    ' ',
                    ''
                ),
                '.',
                ''
            ),
            ''
        ) AS normalizedSIN,

        /* Client names: maximum 100 characters */
        LEFT
        (
            NULLIF
            (
                LTRIM
                (
                    RTRIM
                    (
                        CAST(c.lastname AS varchar(4000))
                    )
                ),
                ''
            ),
            100
        ) AS lastName,

        LEFT
        (
            NULLIF
            (
                LTRIM
                (
                    RTRIM
                    (
                        CAST(c.firstname AS varchar(4000))
                    )
                ),
                ''
            ),
            100
        ) AS firstName,

        TRY_CONVERT(date, c.ict_dateofbirth) AS dateOfBirth,

        /* Email address: maximum 254 characters */
        LEFT
        (
            NULLIF
            (
                LTRIM
                (
                    RTRIM
                    (
                        CAST(c.emailaddress1 AS varchar(4000))
                    )
                ),
                ''
            ),
            254
        ) AS emailAddress,

        TRY_CONVERT(int, c.numberofchildren)
            AS numberOfDependantChildren,

        TRY_CONVERT(int, c.ict_yearofpermanentresidency)
            AS immigrationYearNumber,

        /* Combine and constrain address to maximum 150 characters */
        LEFT
        (
            NULLIF
            (
                CONCAT_WS
                (
                    ', ',
                    NULLIF
                    (
                        LTRIM
                        (
                            RTRIM
                            (
                                CAST(c.address1_line1 AS varchar(4000))
                            )
                        ),
                        ''
                    ),
                    NULLIF
                    (
                        LTRIM
                        (
                            RTRIM
                            (
                                CAST(c.address1_line2 AS varchar(4000))
                            )
                        ),
                        ''
                    )
                ),
                ''
            ),
            150
        ) AS streetAddress,

        /* Municipality: maximum 100 characters */
        LEFT
        (
            NULLIF
            (
                LTRIM
                (
                    RTRIM
                    (
                        CAST(c.address1_city AS varchar(4000))
                    )
                ),
                ''
            ),
            100
        ) AS municipality,

        /* Postal code: normalize and constrain to maximum 10 */
        LEFT
        (
            UPPER
            (
                REPLACE
                (
                    NULLIF
                    (
                        LTRIM
                        (
                            RTRIM
                            (
                                CAST
                                (
                                    c.address1_postalcode
                                    AS varchar(4000)
                                )
                            )
                        ),
                        ''
                    ),
                    ' ',
                    ''
                )
            ),
            10
        ) AS postalZIPCode,

        /* Select preferred phone and constrain to maximum 30 */
        LEFT
        (
            COALESCE
            (
                NULLIF
                (
                    LTRIM
                    (
                        RTRIM
                        (
                            CAST(c.mobilephone AS varchar(4000))
                        )
                    ),
                    ''
                ),
                NULLIF
                (
                    LTRIM
                    (
                        RTRIM
                        (
                            CAST(c.telephone2 AS varchar(4000))
                        )
                    ),
                    ''
                ),
                NULLIF
                (
                    LTRIM
                    (
                        RTRIM
                        (
                            CAST(c.telephone1 AS varchar(4000))
                        )
                    ),
                    ''
                )
            ),
            30
        ) AS contactPhoneNumber,

        /* System comment: maximum 100 characters */
        LEFT
        (
            NULLIF
            (
                LTRIM
                (
                    RTRIM
                    (
                        CAST(c.ict_message AS varchar(4000))
                    )
                ),
                ''
            ),
            100
        ) AS sysComment,

        /* Source values used by ref.code_map */
        CAST(c.gendercode AS varchar(200))
            AS genderSourceCode,

        CAST(c.familystatuscode AS varchar(200))
            AS maritalStatusSourceCode,

        CAST(c.ict_languageofservices AS varchar(200))
            AS languageSourceCode,

        CAST(c.ict_disability AS varchar(200))
            AS disabilitySourceCode,

        CAST(c.ict_indigenousidentity AS varchar(200))
            AS indigenousIdentitySourceCode,

        CAST
        (
            c.ict_citizenshipimmigrationstatus
            AS varchar(200)
        ) AS immigrantSourceCode,

        CAST(c.ict_visibleminority AS varchar(200))
            AS visibleMinoritySourceCode,

        CAST(c.address1_stateorprovince AS varchar(200))
            AS provinceSourceCode

    FROM [stg].[prism_clt_contact] AS c
    WHERE c.ict_clientid IS NOT NULL
      AND c.statecode = 0
),
mapped_client AS
(
    SELECT
        pc.contactid,
        pc.clientID,
        pc.normalizedSIN,
        pc.lastName,
        pc.firstName,
        pc.dateOfBirth,
        pc.emailAddress,
        pc.numberOfDependantChildren,
        pc.immigrationYearNumber,
        pc.streetAddress,
        pc.municipality,
        pc.postalZIPCode,
        pc.contactPhoneNumber,
        pc.sysComment,

        TRY_CONVERT(int, gender.almp_code)
            AS gender,

        TRY_CONVERT(int, marital_status.almp_code)
            AS maritalStatus,

        TRY_CONVERT(int, language_spoken.almp_code)
            AS languageSpoken,

        TRY_CONVERT(int, disability.almp_code)
            AS disability,

        TRY_CONVERT(int, indigenous_identity.almp_code)
            AS indigenousIdentity,

        TRY_CONVERT(int, immigrant.almp_code)
            AS immigrant,

        immigrant.almp_code
            AS immigrantMappedCode,

        TRY_CONVERT(int, visible_minority.almp_code)
            AS visibleMinority,

        TRY_CONVERT(int, province.almp_code)
            AS province

    FROM prepared_client AS pc

    LEFT JOIN gender_map AS gender
        ON gender.source_code = pc.genderSourceCode

    LEFT JOIN marital_status_map AS marital_status
        ON marital_status.source_code =
           pc.maritalStatusSourceCode

    LEFT JOIN language_map AS language_spoken
        ON language_spoken.source_code =
           pc.languageSourceCode

    LEFT JOIN disability_map AS disability
        ON disability.source_code =
           pc.disabilitySourceCode

    LEFT JOIN indigenous_identity_map AS indigenous_identity
        ON indigenous_identity.source_code =
           pc.indigenousIdentitySourceCode

    LEFT JOIN immigrant_map AS immigrant
        ON immigrant.source_code =
           pc.immigrantSourceCode

    LEFT JOIN visible_minority_map AS visible_minority
        ON visible_minority.source_code =
           pc.visibleMinoritySourceCode

    LEFT JOIN province_map AS province
        ON province.source_code =
           pc.provinceSourceCode
),
numbered_client AS
(
    SELECT
        /*
            Run-scoped bigint hierarchy key.

            clientID provides meaningful ordering.
            contactid is the unique PRISM tie-breaker.
        */
        CAST
        (
            ROW_NUMBER() OVER
            (
                ORDER BY
                    mc.clientID,
                    mc.contactid
            )
            AS bigint
        ) AS client_id,

        mc.clientID,
        mc.normalizedSIN,
        mc.lastName,
        mc.firstName,
        mc.dateOfBirth,
        mc.emailAddress,
        mc.gender,
        mc.maritalStatus,
        mc.numberOfDependantChildren,
        mc.languageSpoken,
        mc.disability,
        mc.indigenousIdentity,
        mc.immigrant,
        mc.immigrantMappedCode,
        mc.immigrationYearNumber,
        mc.visibleMinority,
        mc.streetAddress,
        mc.municipality,
        mc.province,
        mc.postalZIPCode,
        mc.contactPhoneNumber,
        mc.sysComment

    FROM mapped_client AS mc
)
INSERT INTO [int].[client]
(
    client_id,
    clientID,
    socialInsuranceNumber,
    lastName,
    firstName,
    dateOfBirth,
    emailAddress,
    gender,
    maritalStatus,
    numberOfDependantChildren,
    languageSpoken,
    disability,
    indigenousIdentity,
    immigrant,
    immigrationYear,
    visibleMinority,
    streetAddress,
    municipality,
    province,
    postalZIPCode,
    contactPhoneNumber,
    addressSysComment,
    sysComment
)
SELECT
    nc.client_id,
    nc.clientID,

    /*
        Store the SIN only if normalization produces exactly
        nine characters. Invalid values remain NULL and are
        reported by submission validation.
    */
    CASE
        WHEN LEN(nc.normalizedSIN) = 9
        THEN CAST(nc.normalizedSIN AS varchar(9))
        ELSE NULL
    END AS socialInsuranceNumber,

    nc.lastName,
    nc.firstName,
    nc.dateOfBirth,
    nc.emailAddress,
    nc.gender,
    nc.maritalStatus,

    CASE
        WHEN nc.numberOfDependantChildren BETWEEN 0 AND 99
        THEN nc.numberOfDependantChildren
        ELSE NULL
    END AS numberOfDependantChildren,

    nc.languageSpoken,
    nc.disability,
    nc.indigenousIdentity,
    nc.immigrant,

    CASE
        WHEN nc.immigrantMappedCode = '1'
         AND nc.immigrationYearNumber BETWEEN 1000 AND 9999
        THEN RIGHT
        (
            '0000'
            + CAST
              (
                  nc.immigrationYearNumber
                  AS varchar(4)
              ),
            4
        )
        ELSE NULL
    END AS immigrationYear,

    nc.visibleMinority,
    nc.streetAddress,
    nc.municipality,
    nc.province,
    nc.postalZIPCode,
    nc.contactPhoneNumber,

    /* No current PRISM source field assigned to this element */
    CAST(NULL AS varchar(100))
        AS addressSysComment,

    nc.sysComment

FROM numbered_client AS nc;
GO


/*==============================================================
  Post-load validation
==============================================================*/


/* Summary */
SELECT
    COUNT(*) AS client_count,
    COUNT(DISTINCT client_id) AS distinct_client_id_count,
    MIN(client_id) AS minimum_client_id,
    MAX(client_id) AS maximum_client_id,
    SUM
    (
        CASE
            WHEN socialInsuranceNumber IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_or_invalid_sin_count
FROM [int].[client];
GO


/* bigint IDs must be present and unique */
SELECT
    client_id,
    COUNT(*) AS row_count
FROM [int].[client]
GROUP BY client_id
HAVING client_id IS NULL
    OR COUNT(*) > 1;
GO


/* Check for gaps in the current generated sequence */
SELECT
    COUNT(*) AS client_count,
    MIN(client_id) AS minimum_client_id,
    MAX(client_id) AS maximum_client_id,
    CASE
        WHEN MIN(client_id) = 1
         AND MAX(client_id) = COUNT(*)
        THEN 'CONTIGUOUS'
        ELSE 'CHECK_SEQUENCE'
    END AS sequence_status
FROM [int].[client];
GO


/* Check duplicate provincial Client IDs */
SELECT
    clientID,
    COUNT(*) AS row_count
FROM [int].[client]
WHERE clientID IS NOT NULL
GROUP BY clientID
HAVING COUNT(*) > 1;
GO


/* Detect missing mandatory mapped values */
SELECT
    client_id,
    clientID,
    gender,
    maritalStatus,
    languageSpoken,
    disability,
    indigenousIdentity,
    immigrant,
    visibleMinority,
    province
FROM [int].[client]
WHERE gender IS NULL
   OR maritalStatus IS NULL
   OR languageSpoken IS NULL
   OR disability IS NULL
   OR indigenousIdentity IS NULL
   OR immigrant IS NULL
   OR visibleMinority IS NULL
   OR province IS NULL;
GO


/* Confirm eligible source count matches target count */
SELECT
    (
        SELECT COUNT(*)
        FROM [stg].[prism_clt_contact]
        WHERE ict_clientid IS NOT NULL
          AND statecode = 0
    ) AS eligible_source_count,
    (
        SELECT COUNT(*)
        FROM [int].[client]
    ) AS integrated_client_count;
GO


/* Confirm physical client_id type */
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'int'
  AND TABLE_NAME = 'client'
  AND COLUMN_NAME = 'client_id';
GO