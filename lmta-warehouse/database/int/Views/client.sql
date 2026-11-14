CREATE   VIEW [int].[client]
AS

/*==============================================================
  Purpose
  -------
  Produce the current integrated LMTA client representation from
  [stg].[prism_clt_contact].

  Assumptions
  -----------
  1. ref.code_map contains no more than one active row for each:
       source_system
       source_table
       source_column
       source_code
       almp_element
       almp_program_type
       almp_schema_version

  2. Historical mappings remain in ref.code_map with is_active = 0.

  3. int.client represents the current interpretation and therefore
     uses only rows where is_active = 1.

  4. Validation errors are handled during the submission build and
     stored in ctl.validation_error, not exposed by this view.
==============================================================*/

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
)
SELECT
    /*----------------------------------------------------------
      Stable integrated identifier
    ----------------------------------------------------------*/
    CAST(c.contactid AS varchar(100)) AS client_id,

    /*----------------------------------------------------------
      Client identifiers
    ----------------------------------------------------------*/
    NULLIF
    (
        LTRIM(RTRIM(CAST(c.ict_clientid AS varchar(30)))),
        ''
    ) AS clientID,

    NULLIF
    (
        REPLACE
        (
            REPLACE
            (
                REPLACE
                (
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

    /*----------------------------------------------------------
      Client name and demographic information
    ----------------------------------------------------------*/
    NULLIF
    (
        LTRIM(RTRIM(CAST(c.lastname AS varchar(100)))),
        ''
    ) AS lastName,

    NULLIF
    (
        LTRIM(RTRIM(CAST(c.firstname AS varchar(100)))),
        ''
    ) AS firstName,

    TRY_CONVERT(date, c.ict_dateofbirth) AS dateOfBirth,

    NULLIF
    (
        LTRIM(RTRIM(CAST(c.emailaddress1 AS varchar(254)))),
        ''
    ) AS emailAddress,

    gender.almp_code AS gender,

    marital_status.almp_code AS maritalStatus,

    CASE
        WHEN TRY_CONVERT(int, c.numberofchildren) BETWEEN 0 AND 99
            THEN TRY_CONVERT(int, c.numberofchildren)
        ELSE NULL
    END AS numberOfDependantChildren,

    language_spoken.almp_code AS languageSpoken,

    disability.almp_code AS disability,

    indigenous_identity.almp_code AS indigenousIdentity,

    immigrant.almp_code AS immigrant,

    CASE
        WHEN immigrant.almp_code = '1'
         AND TRY_CONVERT
             (
                 int,
                 c.ict_yearofpermanentresidency
             ) BETWEEN 1000 AND 9999
        THEN RIGHT
        (
            '0000'
            + CAST
              (
                  TRY_CONVERT
                  (
                      int,
                      c.ict_yearofpermanentresidency
                  ) AS varchar(4)
              ),
            4
        )
        ELSE NULL
    END AS immigrationYear,

    visible_minority.almp_code AS visibleMinority,

    /*----------------------------------------------------------
      Address
    ----------------------------------------------------------*/
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
                        CAST(c.address1_line1 AS varchar(250))
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
                        CAST(c.address1_line2 AS varchar(250))
                    )
                ),
                ''
            )
        ),
        ''
    ) AS streetAddress,

    NULLIF
    (
        LTRIM
        (
            RTRIM
            (
                CAST(c.address1_city AS varchar(100))
            )
        ),
        ''
    ) AS municipality,

    province.almp_code AS province,

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
                        CAST(c.address1_postalcode AS varchar(10))
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
        NULLIF
        (
            LTRIM
            (
                RTRIM
                (
                    CAST(c.mobilephone AS varchar(30))
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
                    CAST(c.telephone2 AS varchar(30))
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
                    CAST(c.telephone1 AS varchar(30))
                )
            ),
            ''
        )
    ) AS contactPhoneNumber,

    CAST(NULL AS varchar(1000)) AS addressSysComment,

    NULLIF
    (
        LTRIM
        (
            RTRIM
            (
                CAST(c.ict_message AS varchar(1000))
            )
        ),
        ''
    ) AS sysComment

FROM [stg].[prism_clt_contact] AS c

LEFT JOIN gender_map AS gender
    ON gender.source_code =
       CAST(c.gendercode AS varchar(50))

LEFT JOIN marital_status_map AS marital_status
    ON marital_status.source_code =
       CAST(c.familystatuscode AS varchar(50))

LEFT JOIN language_map AS language_spoken
    ON language_spoken.source_code =
       CAST(c.ict_languageofservices AS varchar(50))

LEFT JOIN disability_map AS disability
    ON disability.source_code =
       CAST(c.ict_disability AS varchar(50))

LEFT JOIN indigenous_identity_map AS indigenous_identity
    ON indigenous_identity.source_code =
       CAST(c.ict_indigenousidentity AS varchar(50))

LEFT JOIN immigrant_map AS immigrant
    ON immigrant.source_code =
       CAST
       (
           c.ict_citizenshipimmigrationstatus
           AS varchar(50)
       )

LEFT JOIN visible_minority_map AS visible_minority
    ON visible_minority.source_code =
       CAST(c.ict_visibleminority AS varchar(50))

LEFT JOIN province_map AS province
    ON province.source_code =
       CAST(c.address1_stateorprovince AS varchar(50))

WHERE c.ict_clientid IS NOT NULL
  AND c.statecode = 0;
GO

