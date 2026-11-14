/*
Assumption:
    ref.code_map has been truncated before this script runs.

Source:
    stg.prism_choice

ALMP reference:
    ref.almp_code

Target:
    ref.code_map
*/

WITH prism_choices AS
(
    SELECT DISTINCT
        CAST('PRISM_CLT' AS VARCHAR(50))
            COLLATE Latin1_General_100_BIN2_UTF8
            AS source_system,

        CAST('contact' AS VARCHAR(100))
            COLLATE Latin1_General_100_BIN2_UTF8
            AS source_table,

        LOWER(LTRIM(RTRIM(pc.COLUMN_NAME)))
            COLLATE Latin1_General_100_BIN2_UTF8
            AS source_column,

        CAST(LTRIM(RTRIM(pc.CHOICE_NAME)) AS VARCHAR(200))
            COLLATE Latin1_General_100_BIN2_UTF8
            AS source_label,

        CAST(pc.CHOICE_VALUE AS VARCHAR(20))
            COLLATE Latin1_General_100_BIN2_UTF8
            AS source_code,

        LOWER(LTRIM(RTRIM(pc.CHOICE_NAME)))
            COLLATE Latin1_General_100_BIN2_UTF8
            AS normalized_value

    FROM stg.prism_choice AS pc

    WHERE LOWER(LTRIM(RTRIM(pc.MODULE_NAME)))
              COLLATE Latin1_General_100_BIN2_UTF8
          = 'client'

      AND LOWER(LTRIM(RTRIM(pc.TABLE_NAME)))
              COLLATE Latin1_General_100_BIN2_UTF8
          = 'contact'

      AND LOWER(LTRIM(RTRIM(pc.COLUMN_NAME)))
              COLLATE Latin1_General_100_BIN2_UTF8
          IN
          (
              'gendercode',
              'familystatuscode',
              'ict_languageofservices',
              'ict_disability',
              'ict_indigenousidentity',
              'ict_citizenshipimmigrationstatus',
              'ict_visibleminority'
          )
),

mapped_choices AS
(
    SELECT
        source_system,
        source_table,
        source_column,
        source_label,
        source_code,

        CASE source_column
            WHEN 'gendercode'
                THEN 'gender'

            WHEN 'familystatuscode'
                THEN 'maritalStatus'

            WHEN 'ict_languageofservices'
                THEN 'languageSpoken'

            WHEN 'ict_disability'
                THEN 'disability'

            WHEN 'ict_indigenousidentity'
                THEN 'indigenousIdentity'

            WHEN 'ict_citizenshipimmigrationstatus'
                THEN 'immigrant'

            WHEN 'ict_visibleminority'
                THEN 'visibleMinority'
        END COLLATE Latin1_General_100_BIN2_UTF8
            AS almp_element,

        CASE
            /* =====================================================
               Gender
               1 = Male
               2 = Female
               3 = Unspecified
               9 = Prefer not to report
               ===================================================== */

            WHEN source_column = 'gendercode'
             AND normalized_value = 'male'
                THEN '1'

            WHEN source_column = 'gendercode'
             AND normalized_value = 'female'
                THEN '2'

            WHEN source_column = 'gendercode'
             AND
             (
                 normalized_value LIKE '%prefer%'
                 OR normalized_value LIKE '%declin%'
                 OR normalized_value LIKE '%refus%'
                 OR normalized_value LIKE '%not respond%'
                 OR normalized_value LIKE '%not report%'
                 OR normalized_value LIKE '%not disclose%'
             )
                THEN '9'

            WHEN source_column = 'gendercode'
                THEN '3'


            /* =====================================================
               Marital status
               1 = Married/equivalent
               2 = Single
               9 = Prefer not to report
               ===================================================== */

            WHEN source_column = 'familystatuscode'
             AND
             (
                 normalized_value LIKE '%married%'
                 OR normalized_value LIKE '%common law%'
                 OR normalized_value LIKE '%common-law%'
                 OR normalized_value LIKE '%partner%'
             )
                THEN '1'

            WHEN source_column = 'familystatuscode'
             AND
             (
                 normalized_value LIKE '%prefer%'
                 OR normalized_value LIKE '%declin%'
                 OR normalized_value LIKE '%refus%'
                 OR normalized_value LIKE '%unknown%'
                 OR normalized_value LIKE '%not respond%'
                 OR normalized_value LIKE '%not report%'
             )
                THEN '9'

            WHEN source_column = 'familystatuscode'
                THEN '2'


            /* =====================================================
               Language spoken
               2 = English only
               3 = French only
               6 = English and French
               9 = Not a federal official language
               ===================================================== */

            WHEN source_column = 'ict_languageofservices'
             AND normalized_value LIKE '%english%'
             AND normalized_value LIKE '%french%'
                THEN '6'

            WHEN source_column = 'ict_languageofservices'
             AND normalized_value LIKE '%english%'
                THEN '2'

            WHEN source_column = 'ict_languageofservices'
             AND normalized_value LIKE '%french%'
                THEN '3'

            WHEN source_column = 'ict_languageofservices'
                THEN '9'


            /* =====================================================
               Disability
               1 = Yes
               2 = No
               9 = Prefer not to report
               ===================================================== */

            WHEN source_column = 'ict_disability'
             AND normalized_value = 'yes'
                THEN '1'

            WHEN source_column = 'ict_disability'
             AND normalized_value = 'no'
                THEN '2'

            WHEN source_column = 'ict_disability'
                THEN '9'


            /* =====================================================
               Indigenous identity
               1 = Yes
               2 = No
               9 = Prefer not to report
               ===================================================== */

            WHEN source_column = 'ict_indigenousidentity'
             AND
             (
                 normalized_value LIKE '%first nation%'
                 OR normalized_value LIKE '%metis%'
                 OR normalized_value LIKE '%métis%'
                 OR normalized_value LIKE '%inuit%'
                 OR normalized_value = 'indigenous'
                 OR normalized_value = 'yes'
             )
                THEN '1'

            WHEN source_column = 'ict_indigenousidentity'
             AND
             (
                 normalized_value = 'no'
                 OR normalized_value LIKE '%non-indigenous%'
                 OR normalized_value LIKE '%not indigenous%'
             )
                THEN '2'

            WHEN source_column = 'ict_indigenousidentity'
                THEN '9'


            /* =====================================================
               Immigrant
               1 = Yes
               2 = No
               9 = Prefer not to report
               ===================================================== */

            WHEN source_column =
                 'ict_citizenshipimmigrationstatus'
             AND
             (
                 normalized_value LIKE '%prefer%'
                 OR normalized_value LIKE '%declin%'
                 OR normalized_value LIKE '%refus%'
                 OR normalized_value LIKE '%unknown%'
                 OR normalized_value LIKE '%not respond%'
                 OR normalized_value LIKE '%not report%'
             )
                THEN '9'

            WHEN source_column =
                 'ict_citizenshipimmigrationstatus'
             AND
             (
                 normalized_value LIKE '%canadian citizen%'
                 OR normalized_value = 'citizen'
                 OR normalized_value LIKE '%born in canada%'
                 OR normalized_value LIKE '%non-immigrant%'
                 OR normalized_value = 'no'
             )
                THEN '2'

            WHEN source_column =
                 'ict_citizenshipimmigrationstatus'
                THEN '1'


            /* =====================================================
               Visible minority
               1 = Yes
               2 = No
               9 = Prefer not to report
               ===================================================== */

            WHEN source_column = 'ict_visibleminority'
             AND normalized_value = 'yes'
                THEN '1'

            WHEN source_column = 'ict_visibleminority'
             AND normalized_value = 'no'
                THEN '2'

            WHEN source_column = 'ict_visibleminority'
                THEN '9'

        END COLLATE Latin1_General_100_BIN2_UTF8
            AS almp_code,

        CASE
            WHEN source_column = 'gendercode'
             AND normalized_value NOT IN ('male', 'female')
             AND normalized_value NOT LIKE '%prefer%'
             AND normalized_value NOT LIKE '%declin%'
             AND normalized_value NOT LIKE '%refus%'
                THEN
                    'Judgement: mapped source gender to ALMP Unspecified.'

            WHEN source_column = 'familystatuscode'
             AND
             (
                 normalized_value LIKE '%divorc%'
                 OR normalized_value LIKE '%separat%'
                 OR normalized_value LIKE '%widow%'
             )
                THEN
                    'Judgement: mapped non-partnered status to ALMP Single.'

            WHEN source_column =
                 'ict_citizenshipimmigrationstatus'
             AND normalized_value NOT LIKE '%canadian citizen%'
             AND normalized_value <> 'citizen'
             AND normalized_value NOT LIKE '%born in canada%'
             AND normalized_value NOT LIKE '%non-immigrant%'
             AND normalized_value <> 'no'
             AND normalized_value NOT LIKE '%prefer%'
             AND normalized_value NOT LIKE '%declin%'
             AND normalized_value NOT LIKE '%refus%'
             AND normalized_value NOT LIKE '%unknown%'
                THEN
                    'Judgement: mapped immigration status to ALMP immigrant Yes.'

            ELSE
                'Direct PRISM-to-ALMP client mapping.'
        END COLLATE Latin1_General_100_BIN2_UTF8
            AS mapping_note

    FROM prism_choices
),

almp_codes AS
(
    SELECT DISTINCT
        ac.code_domain
            COLLATE Latin1_General_100_BIN2_UTF8
            AS almp_element,

        ac.almp_code
            COLLATE Latin1_General_100_BIN2_UTF8
            AS almp_code,

        CAST(ac.almp_label AS VARCHAR(200))
            COLLATE Latin1_General_100_BIN2_UTF8
            AS almp_label

    FROM ref.almp_code AS ac

    WHERE ac.schema_version
              COLLATE Latin1_General_100_BIN2_UTF8
          = '1.5'

      AND ac.is_active = 1

      AND ac.code_domain
              COLLATE Latin1_General_100_BIN2_UTF8
          IN
          (
              'gender',
              'maritalStatus',
              'languageSpoken',
              'disability',
              'indigenousIdentity',
              'immigrant',
              'visibleMinority'
          )
)

INSERT INTO ref.code_map
(
    source_system,
    source_table,
    source_column,
    source_label,
    source_code,

    almp_element,
    almp_label,
    almp_code,
    almp_program_type,
    almp_schema_version,

    effective_from,
    effective_to,
    mapping_note
)

SELECT DISTINCT
    source.source_system,
    source.source_table,
    source.source_column,
    source.source_label,
    source.source_code,

    source.almp_element,
    target.almp_label,
    source.almp_code,

    'BOTH' AS almp_program_type,
    '1.5' AS almp_schema_version,

    CAST('2026-04-15' AS DATE) AS effective_from,
    NULL AS effective_to,

    source.mapping_note

FROM mapped_choices AS source

INNER JOIN almp_codes AS target
    ON target.almp_element =
       source.almp_element

   AND target.almp_code =
       source.almp_code;