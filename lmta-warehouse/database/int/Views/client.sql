CREATE   VIEW [int].[client]
AS

/* =============================================================
   Purpose
   -------
   Produce one current integrated LMTA client from
   stg.prism_clt_contact.

   Authoritative contracts
   -----------------------
   - LMTA Design Document v0.8
   - LMTA physical Warehouse schema dated 2026-11-13 16:51
   - Federal ALMP Schema 1.5

   Important
   ---------
   source_load_id remains NULL because the current physical
   stg.prism_clt_contact table does not contain a Warehouse
   ingestion/load identifier. This is reported as a validation
   error rather than populated with an invented value.
   ============================================================= */

WITH active_code_map AS
(
    SELECT
        cm.source_column,
        cm.source_code,
        cm.almp_element,
        cm.almp_label,
        cm.almp_code,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                cm.source_system,
                cm.source_table,
                cm.source_column,
                cm.source_code,
                cm.almp_element
            ORDER BY
                cm.effective_from DESC,
                cm.almp_code
        ) AS mapping_rank

    FROM [ref].[code_map] AS cm

    WHERE cm.source_system = 'PRISM_CLT'
      AND cm.source_table = 'contact'
      AND cm.almp_program_type = 'BOTH'
      AND cm.almp_schema_version = '1.5'
      AND cm.effective_from <= CAST(GETDATE() AS date)
      AND
      (
          cm.effective_to IS NULL
          OR cm.effective_to >= CAST(GETDATE() AS date)
      )
),

gender_map AS
(
    SELECT
        source_code,
        almp_code,
        almp_label
    FROM active_code_map
    WHERE source_column = 'gendercode'
      AND almp_element = 'gender'
      AND mapping_rank = 1
),

marital_status_map AS
(
    SELECT
        source_code,
        almp_code,
        almp_label
    FROM active_code_map
    WHERE source_column = 'familystatuscode'
      AND almp_element = 'maritalStatus'
      AND mapping_rank = 1
),

language_map AS
(
    SELECT
        source_code,
        almp_code,
        almp_label
    FROM active_code_map
    WHERE source_column = 'ict_languageofservices'
      AND almp_element = 'languageSpoken'
      AND mapping_rank = 1
),

disability_map AS
(
    SELECT
        source_code,
        almp_code,
        almp_label
    FROM active_code_map
    WHERE source_column = 'ict_disability'
      AND almp_element = 'disability'
      AND mapping_rank = 1
),

indigenous_identity_map AS
(
    SELECT
        source_code,
        almp_code,
        almp_label
    FROM active_code_map
    WHERE source_column = 'ict_indigenousidentity'
      AND almp_element = 'indigenousIdentity'
      AND mapping_rank = 1
),

immigrant_map AS
(
    SELECT
        source_code,
        almp_code,
        almp_label
    FROM active_code_map
    WHERE source_column = 'ict_citizenshipimmigrationstatus'
      AND almp_element = 'immigrant'
      AND mapping_rank = 1
),

visible_minority_map AS
(
    SELECT
        source_code,
        almp_code,
        almp_label
    FROM active_code_map
    WHERE source_column = 'ict_visibleminority'
      AND almp_element = 'visibleMinority'
      AND mapping_rank = 1
),

province_map AS
(
    /*
       This mapping will resolve only after province mappings are
       added to ref.code_map. Until then, province will be NULL and
       validation_status will be ERROR.
    */
    SELECT
        source_code,
        almp_code,
        almp_label
    FROM active_code_map
    WHERE source_column = 'address1_stateorprovince'
      AND almp_element = 'province'
      AND mapping_rank = 1
),

mapped_client AS
(
    SELECT
        /* -----------------------------------------------------
           Internal identifier
           ----------------------------------------------------- */
        CAST(c.contactid AS varchar(100)) AS client_id,

        /* -----------------------------------------------------
           Federal client fields
           ----------------------------------------------------- */
        NULLIF(
            LTRIM(RTRIM(CAST(c.ict_clientid AS varchar(30)))),
            ''
        ) AS clientID,

        NULLIF(
            REPLACE(
                REPLACE(
                    REPLACE(
                        LTRIM(RTRIM(CAST(c.ict_sin AS varchar(30)))),
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
        ) AS socialInsuranceNumber,

        NULLIF(
            LTRIM(RTRIM(CAST(c.lastname AS varchar(100)))),
            ''
        ) AS lastName,

        NULLIF(
            LTRIM(RTRIM(CAST(c.firstname AS varchar(100)))),
            ''
        ) AS firstName,

        TRY_CONVERT(date, c.ict_dateofbirth) AS dateOfBirth,

        NULLIF(
            LTRIM(RTRIM(CAST(c.emailaddress1 AS varchar(254)))),
            ''
        ) AS emailAddress,

        gm.almp_code  AS gender,
        msm.almp_code AS maritalStatus,

        CASE
            WHEN TRY_CONVERT(int, c.numberofchildren)
                 BETWEEN 0 AND 99
                THEN TRY_CONVERT(int, c.numberofchildren)
            ELSE NULL
        END AS numberOfDependantChildren,

        lm.almp_code  AS languageSpoken,
        dm.almp_code  AS disability,
        iim.almp_code AS indigenousIdentity,
        imm.almp_code AS immigrant,

        CASE
            WHEN imm.almp_code = '1'
             AND TRY_CONVERT(int, c.ict_yearofpermanentresidency)
                 BETWEEN 1000 AND 9999
                THEN RIGHT
                (
                    '0000' +
                    CAST
                    (
                        TRY_CONVERT(
                            int,
                            c.ict_yearofpermanentresidency
                        ) AS varchar(4)
                    ),
                    4
                )
            ELSE NULL
        END AS immigrationYear,

        vmm.almp_code AS visibleMinority,

        /* -----------------------------------------------------
           Federal address fields
           ----------------------------------------------------- */
        NULLIF
        (
            CONCAT_WS
            (
                ', ',
                NULLIF(
                    LTRIM(
                        RTRIM(
                            CAST(c.address1_line1 AS varchar(250))
                        )
                    ),
                    ''
                ),
                NULLIF(
                    LTRIM(
                        RTRIM(
                            CAST(c.address1_line2 AS varchar(250))
                        )
                    ),
                    ''
                )
            ),
            ''
        ) AS streetAddress,

        NULLIF(
            LTRIM(
                RTRIM(
                    CAST(c.address1_city AS varchar(100))
                )
            ),
            ''
        ) AS municipality,

        pm.almp_code AS province,

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
                            CAST(
                                c.address1_postalcode
                                AS varchar(10)
                            )
                        )
                    ),
                    ''
                ),
                ' ',
                ''
            )
        ) AS postalZIPCode,

        COALESCE
        (
            NULLIF(
                LTRIM(RTRIM(CAST(c.mobilephone AS varchar(30)))),
                ''
            ),
            NULLIF(
                LTRIM(RTRIM(CAST(c.telephone2 AS varchar(30)))),
                ''
            ),
            NULLIF(
                LTRIM(RTRIM(CAST(c.telephone1 AS varchar(30)))),
                ''
            )
        ) AS contactPhoneNumber,

        CAST(NULL AS varchar(1000)) AS addressSysComment,

        NULLIF(
            LTRIM(RTRIM(CAST(c.ict_message AS varchar(1000)))),
            ''
        ) AS sysComment,

        /* -----------------------------------------------------
           Common integration lineage columns
           ----------------------------------------------------- */
        CAST('PRISM_CLT' AS varchar(50)) AS source_system,
        CAST('contact' AS varchar(100)) AS source_table,
        CAST(c.contactid AS varchar(100)) AS source_record_id,

        /*
           Not physically available in the staging table.
           Do not manufacture a load identifier from a timestamp.
        */
        CAST(NULL AS bigint) AS source_load_id,

        TRY_CONVERT(datetime2(6), c.MODIFIED_ON)
            AS source_modified_on,

        CAST(0 AS bit) AS is_synthetic,

        CAST(
            'PRISM_CLT_CONTACT_DIRECT'
            AS varchar(100)
        ) AS derivation_rule,

        /* -----------------------------------------------------
           Retained source values for mapping diagnostics
           ----------------------------------------------------- */
        c.gendercode AS source_gender_code,
        c.familystatuscode AS source_marital_status_code,
        c.ict_languageofservices AS source_language_code,
        c.ict_disability AS source_disability_code,
        c.ict_indigenousidentity
            AS source_indigenous_identity_code,
        c.ict_citizenshipimmigrationstatus
            AS source_immigrant_code,
        c.ict_visibleminority
            AS source_visible_minority_code,
        c.address1_stateorprovince
            AS source_province_value

    FROM [stg].[prism_clt_contact] AS c

    LEFT JOIN gender_map AS gm
        ON gm.source_code =
           CAST(c.gendercode AS varchar(50))

    LEFT JOIN marital_status_map AS msm
        ON msm.source_code =
           CAST(c.familystatuscode AS varchar(50))

    LEFT JOIN language_map AS lm
        ON lm.source_code =
           CAST(c.ict_languageofservices AS varchar(50))

    LEFT JOIN disability_map AS dm
        ON dm.source_code =
           CAST(c.ict_disability AS varchar(50))

    LEFT JOIN indigenous_identity_map AS iim
        ON iim.source_code =
           CAST(c.ict_indigenousidentity AS varchar(50))

    LEFT JOIN immigrant_map AS imm
        ON imm.source_code =
           CAST(
               c.ict_citizenshipimmigrationstatus
               AS varchar(50)
           )

    LEFT JOIN visible_minority_map AS vmm
        ON vmm.source_code =
           CAST(c.ict_visibleminority AS varchar(50))

    LEFT JOIN province_map AS pm
        ON pm.source_code =
           CAST(c.address1_stateorprovince AS varchar(50))

    WHERE c.ict_clientid IS NOT NULL
      AND c.statecode = 0
),

evaluated_client AS
(
    SELECT
        mc.*,

        CASE
            WHEN mc.gender IS NULL
              OR mc.maritalStatus IS NULL
              OR mc.languageSpoken IS NULL
              OR mc.disability IS NULL
              OR mc.indigenousIdentity IS NULL
              OR mc.immigrant IS NULL
              OR mc.visibleMinority IS NULL
              OR mc.province IS NULL
                THEN CAST(0 AS bit)
            ELSE CAST(1 AS bit)
        END AS mapping_complete,

        CONCAT_WS
        (
            '; ',

            CASE
                WHEN mc.source_load_id IS NULL
                    THEN 'source_load_id is unavailable in stg.prism_clt_contact'
            END,

            CASE
                WHEN mc.socialInsuranceNumber IS NULL
                    THEN 'Missing socialInsuranceNumber'
                WHEN LEN(mc.socialInsuranceNumber) <> 9
                    THEN 'socialInsuranceNumber must contain 9 digits'
                WHEN mc.socialInsuranceNumber LIKE '%[^0-9]%'
                    THEN 'socialInsuranceNumber contains non-numeric characters'
            END,

            CASE
                WHEN mc.lastName IS NULL
                    THEN 'Missing lastName'
            END,

            CASE
                WHEN mc.dateOfBirth IS NULL
                    THEN 'Missing or invalid dateOfBirth'
                WHEN mc.dateOfBirth > CAST(GETDATE() AS date)
                    THEN 'dateOfBirth is in the future'
            END,

            CASE
                WHEN mc.gender IS NULL
                    THEN 'Missing or unmapped gendercode'
            END,

            CASE
                WHEN mc.maritalStatus IS NULL
                    THEN 'Missing or unmapped familystatuscode'
            END,

            CASE
                WHEN mc.numberOfDependantChildren IS NULL
                    THEN 'numberOfDependantChildren must be 0-99'
            END,

            CASE
                WHEN mc.languageSpoken IS NULL
                    THEN 'Missing or unmapped ict_languageofservices'
            END,

            CASE
                WHEN mc.disability IS NULL
                    THEN 'Missing or unmapped ict_disability'
            END,

            CASE
                WHEN mc.indigenousIdentity IS NULL
                    THEN 'Missing or unmapped ict_indigenousidentity'
            END,

            CASE
                WHEN mc.immigrant IS NULL
                    THEN 'Missing or unmapped ict_citizenshipimmigrationstatus'
            END,

            CASE
                WHEN mc.immigrant = '1'
                 AND mc.immigrationYear IS NULL
                    THEN 'immigrant=1 requires immigrationYear'
            END,

            CASE
                WHEN mc.visibleMinority IS NULL
                    THEN 'Missing or unmapped ict_visibleminority'
            END,

            CASE
                WHEN mc.streetAddress IS NULL
                    THEN 'Missing streetAddress'
            END,

            CASE
                WHEN mc.municipality IS NULL
                    THEN 'Missing municipality'
            END,

            CASE
                WHEN mc.province IS NULL
                    THEN 'Missing province mapping for address1_stateorprovince'
            END
        ) AS calculated_validation_message

    FROM mapped_client AS mc
)

SELECT
    /* Approved int.client contract */
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
    sysComment,

    source_system,
    source_table,
    source_record_id,
    source_load_id,
    source_modified_on,
    is_synthetic,
    derivation_rule,
    mapping_complete,

    CAST
    (
        CASE
            WHEN calculated_validation_message IS NULL
              OR calculated_validation_message = ''
                THEN 'VALID'
            ELSE 'ERROR'
        END
        AS varchar(20)
    ) AS validation_status,

    CAST
    (
        NULLIF(calculated_validation_message, '')
        AS varchar(2000)
    ) AS validation_message

FROM evaluated_client;
GO

