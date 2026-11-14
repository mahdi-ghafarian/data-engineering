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
      3. Generate a new GUID for client_id.
      4. Use the single active Schema 1.5 mapping.
      5. Constrain strings to target/XSD maximum lengths.
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

        /* Provincial Client ID: maximum 30 */
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

        /* Client names: maximum 100 */
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

        /* Email address: maximum 254 */
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

        /* Combine and constrain address to maximum 150 */
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

        /* Municipality: maximum 100 */
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

        /* System comment: maximum 100 */
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

        /* Source mapping values */
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
    /* New run-scoped database-generated surrogate ID */
    NEWID() AS client_id,

    pc.clientID,

    /*
        Store the SIN only when normalization produces exactly
        nine characters. Invalid SINs remain NULL and should be
        reported by submission validation.
    */
    CASE
        WHEN LEN(pc.normalizedSIN) = 9
        THEN CAST(pc.normalizedSIN AS varchar(9))
        ELSE NULL
    END AS socialInsuranceNumber,

    pc.lastName,
    pc.firstName,
    pc.dateOfBirth,
    pc.emailAddress,

    TRY_CONVERT(int, gender.almp_code)
        AS gender,

    TRY_CONVERT(int, marital_status.almp_code)
        AS maritalStatus,

    CASE
        WHEN pc.numberOfDependantChildren BETWEEN 0 AND 99
        THEN pc.numberOfDependantChildren
        ELSE NULL
    END AS numberOfDependantChildren,

    TRY_CONVERT(int, language_spoken.almp_code)
        AS languageSpoken,

    TRY_CONVERT(int, disability.almp_code)
        AS disability,

    TRY_CONVERT(int, indigenous_identity.almp_code)
        AS indigenousIdentity,

    TRY_CONVERT(int, immigrant.almp_code)
        AS immigrant,

    CASE
        WHEN immigrant.almp_code = '1'
         AND pc.immigrationYearNumber BETWEEN 1000 AND 9999
        THEN RIGHT
        (
            '0000'
            + CAST
              (
                  pc.immigrationYearNumber
                  AS varchar(4)
              ),
            4
        )
        ELSE NULL
    END AS immigrationYear,

    TRY_CONVERT(int, visible_minority.almp_code)
        AS visibleMinority,

    pc.streetAddress,
    pc.municipality,

    TRY_CONVERT(int, province.almp_code)
        AS province,

    pc.postalZIPCode,
    pc.contactPhoneNumber,

    /* No current PRISM source field is assigned to this element */
    CAST(NULL AS varchar(100))
        AS addressSysComment,

    pc.sysComment

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
       pc.provinceSourceCode;
GO


/*==============================================================
  Post-load validation
==============================================================*/

-- Summary
SELECT
    COUNT(*) AS client_count,
    COUNT(DISTINCT client_id) AS distinct_client_id_count,
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


-- Generated GUIDs must be present and unique
SELECT
    client_id,
    COUNT(*) AS row_count
FROM [int].[client]
GROUP BY client_id
HAVING client_id IS NULL
    OR COUNT(*) > 1;
GO


-- Check duplicate provincial Client IDs
SELECT
    clientID,
    COUNT(*) AS row_count
FROM [int].[client]
WHERE clientID IS NOT NULL
GROUP BY clientID
HAVING COUNT(*) > 1;
GO


-- Detect missing mandatory mapped values
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


-- Confirm eligible source count matches target count
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