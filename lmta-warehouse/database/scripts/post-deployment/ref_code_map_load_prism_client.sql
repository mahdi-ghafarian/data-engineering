/*
Populate ref.code_map for PRISM client coded fields.

Assumes ref.code_map has been truncated.

PRISM:
    source_value = source code
    source_label = source description

ALMP:
    almp_code  = federal code
    almp_value = federal description from ref.almp_code
*/

WITH prism AS
(
    SELECT DISTINCT
        CAST('PRISM_CLT' AS VARCHAR(50))
            COLLATE Latin1_General_100_BIN2_UTF8 AS source_system,

        CAST('contact' AS VARCHAR(100))
            COLLATE Latin1_General_100_BIN2_UTF8 AS source_table,

        LOWER(TRIM(pc.COLUMN_NAME))
            COLLATE Latin1_General_100_BIN2_UTF8 AS source_column,

        CAST(pc.CHOICE_VALUE AS VARCHAR(200))
            COLLATE Latin1_General_100_BIN2_UTF8 AS source_value,

        CAST(TRIM(pc.CHOICE_NAME) AS VARCHAR(500))
            COLLATE Latin1_General_100_BIN2_UTF8 AS source_label,

        LOWER(TRIM(pc.CHOICE_NAME))
            COLLATE Latin1_General_100_BIN2_UTF8 AS source_label_lower

    FROM stg.prism_choice pc

    WHERE LOWER(TRIM(pc.MODULE_NAME))
              COLLATE Latin1_General_100_BIN2_UTF8
          = 'client'

      AND LOWER(TRIM(pc.TABLE_NAME))
              COLLATE Latin1_General_100_BIN2_UTF8
          = 'contact'

      AND LOWER(TRIM(pc.COLUMN_NAME))
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

mapped AS
(
    SELECT
        *,

        /* Target ALMP element */
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


        /* Target ALMP code */
        CASE

            /* =====================================================
               GENDER
               ALMP:
               1 Male
               2 Female
               3 Unspecified
               9 Prefer not to report
               ===================================================== */

            WHEN source_column = 'gendercode'
             AND source_label_lower = 'male'
                THEN '1'

            WHEN source_column = 'gendercode'
             AND source_label_lower = 'female'
                THEN '2'

            WHEN source_column = 'gendercode'
             AND
             (
                 source_label_lower LIKE '%prefer%'
                 OR source_label_lower LIKE '%declin%'
                 OR source_label_lower LIKE '%refus%'
             )
                THEN '9'

            WHEN source_column = 'gendercode'
                THEN '3'


            /* =====================================================
               MARITAL STATUS
               ALMP:
               1 Married/equivalent
               2 Single
               9 Prefer not to report
               ===================================================== */

            WHEN source_column = 'familystatuscode'
             AND
             (
                 source_label_lower LIKE '%married%'
                 OR source_label_lower LIKE '%common law%'
                 OR source_label_lower LIKE '%common-law%'
                 OR source_label_lower LIKE '%partner%'
             )
                THEN '1'

            WHEN source_column = 'familystatuscode'
             AND
             (
                 source_label_lower LIKE '%prefer%'
                 OR source_label_lower LIKE '%declin%'
                 OR source_label_lower LIKE '%refus%'
                 OR source_label_lower LIKE '%unknown%'
             )
                THEN '9'

            WHEN source_column = 'familystatuscode'
                THEN '2'


            /* =====================================================
               LANGUAGE
               ALMP:
               2 English only
               3 French only
               6 English & French
               9 Not a federal official language
               ===================================================== */

            WHEN source_column = 'ict_languageofservices'
             AND source_label_lower LIKE '%english%'
             AND source_label_lower LIKE '%french%'
                THEN '6'

            WHEN source_column = 'ict_languageofservices'
             AND source_label_lower LIKE '%english%'
                THEN '2'

            WHEN source_column = 'ict_languageofservices'
             AND source_label_lower LIKE '%french%'
                THEN '3'

            WHEN source_column = 'ict_languageofservices'
                THEN '9'


            /* =====================================================
               DISABILITY
               1 Yes
               2 No
               9 Prefer not to report
               ===================================================== */

            WHEN source_column = 'ict_disability'
             AND source_label_lower = 'yes'
                THEN '1'

            WHEN source_column = 'ict_disability'
             AND source_label_lower = 'no'
                THEN '2'

            WHEN source_column = 'ict_disability'
                THEN '9'


            /* =====================================================
               INDIGENOUS IDENTITY
               1 Yes
               2 No
               9 Prefer not to report
               ===================================================== */

            WHEN source_column = 'ict_indigenousidentity'
             AND
             (
                 source_label_lower LIKE '%first nation%'
                 OR source_label_lower LIKE '%metis%'
                 OR source_label_lower LIKE '%métis%'
                 OR source_label_lower LIKE '%inuit%'
                 OR source_label_lower = 'indigenous'
                 OR source_label_lower = 'yes'
             )
                THEN '1'

            WHEN source_column = 'ict_indigenousidentity'
             AND
             (
                 source_label_lower = 'no'
                 OR source_label_lower LIKE '%non-indigenous%'
                 OR source_label_lower LIKE '%not indigenous%'
             )
                THEN '2'

            WHEN source_column = 'ict_indigenousidentity'
                THEN '9'


            /* =====================================================
               IMMIGRANT
               1 Yes
               2 No
               9 Prefer not to report
               ===================================================== */

            WHEN source_column =
                 'ict_citizenshipimmigrationstatus'
             AND
             (
                 source_label_lower LIKE '%prefer%'
                 OR source_label_lower LIKE '%declin%'
                 OR source_label_lower LIKE '%refus%'
                 OR source_label_lower LIKE '%unknown%'
             )
                THEN '9'

            WHEN source_column =
                 'ict_citizenshipimmigrationstatus'
             AND
             (
                 source_label_lower LIKE '%canadian citizen%'
                 OR source_label_lower = 'citizen'
                 OR source_label_lower LIKE '%born in canada%'
                 OR source_label_lower LIKE '%non-immigrant%'
                 OR source_label_lower = 'no'
             )
                THEN '2'

            WHEN source_column =
                 'ict_citizenshipimmigrationstatus'
                THEN '1'


            /* =====================================================
               VISIBLE MINORITY
               1 Yes
               2 No
               9 Prefer not to report
               ===================================================== */

            WHEN source_column = 'ict_visibleminority'
             AND source_label_lower = 'yes'
                THEN '1'

            WHEN source_column = 'ict_visibleminority'
             AND source_label_lower = 'no'
                THEN '2'

            WHEN source_column = 'ict_visibleminority'
                THEN '9'

        END COLLATE Latin1_General_100_BIN2_UTF8
            AS almp_code,

        CASE
            WHEN source_column = 'gendercode'
             AND source_label_lower NOT IN ('male', 'female')
             AND source_label_lower NOT LIKE '%prefer%'
             AND source_label_lower NOT LIKE '%declin%'
             AND source_label_lower NOT LIKE '%refus%'
                THEN
                    'Judgement: source gender mapped to ALMP Unspecified.'

            WHEN source_column = 'familystatuscode'
             AND
             (
                 source_label_lower LIKE '%divorc%'
                 OR source_label_lower LIKE '%separat%'
                 OR source_label_lower LIKE '%widow%'
             )
                THEN
                    'Judgement: non-partnered marital status mapped to ALMP Single.'

            WHEN source_column =
                 'ict_citizenshipimmigrationstatus'
             AND source_label_lower NOT LIKE '%canadian citizen%'
             AND source_label_lower <> 'citizen'
             AND source_label_lower NOT LIKE '%born in canada%'
             AND source_label_lower NOT LIKE '%non-immigrant%'
             AND source_label_lower <> 'no'
             AND source_label_lower NOT LIKE '%prefer%'
             AND source_label_lower NOT LIKE '%declin%'
             AND source_label_lower NOT LIKE '%refus%'
             AND source_label_lower NOT LIKE '%unknown%'
                THEN
                    'Judgement: source immigration status mapped to ALMP immigrant Yes.'

            ELSE
                'Direct PRISM-to-ALMP client mapping.'
        END COLLATE Latin1_General_100_BIN2_UTF8
            AS mapping_note

    FROM prism
)

INSERT INTO ref.code_map
(
    source_system,
    source_table,
    source_column,
    source_value,
    source_label,

    almp_element,
    almp_code,
    almp_value,
    almp_program_type,
    almp_schema_version,

    effective_from,
    effective_to,
    mapping_note
)

SELECT DISTINCT
    m.source_system,
    m.source_table,
    m.source_column,
    m.source_value,
    m.source_label,

    m.almp_element,
    m.almp_code,

    /* authoritative ALMP description */
    CAST(a.almp_value AS VARCHAR(20))
        COLLATE Latin1_General_100_BIN2_UTF8,

    'BOTH',
    '1.5',

    CAST('2026-04-15' AS DATE),
    NULL,

    m.mapping_note

FROM mapped m

INNER JOIN ref.almp_code a
    ON a.code_domain
           COLLATE Latin1_General_100_BIN2_UTF8
       =
       m.almp_element
           COLLATE Latin1_General_100_BIN2_UTF8

   AND a.almp_code
           COLLATE Latin1_General_100_BIN2_UTF8
       =
       m.almp_code
           COLLATE Latin1_General_100_BIN2_UTF8

   AND a.schema_version
           COLLATE Latin1_General_100_BIN2_UTF8
       =
       '1.5'

   AND a.is_active = 1;