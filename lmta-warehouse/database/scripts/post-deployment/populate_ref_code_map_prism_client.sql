/*
Populate ref.code_map for PRISM client choice fields.

This starter script:
- does not use temporary tables;
- does not use code_map_id;
- handles the Warehouse collation explicitly;
- inserts only mappings matched by the rules below;
- does not insert duplicates.
*/

WITH prism_choices AS
(
    SELECT DISTINCT
        CAST('PRISM_CLT' AS VARCHAR(50))
            COLLATE Latin1_General_100_BIN2_UTF8 AS source_system,

        CAST('contact' AS VARCHAR(100))
            COLLATE Latin1_General_100_BIN2_UTF8 AS source_table,

        LOWER(pc.COLUMN_NAME)
            COLLATE Latin1_General_100_BIN2_UTF8 AS source_column,

        CAST(pc.CHOICE_VALUE AS VARCHAR(200))
            COLLATE Latin1_General_100_BIN2_UTF8 AS source_value,

        CAST(pc.CHOICE_NAME AS VARCHAR(500))
            COLLATE Latin1_General_100_BIN2_UTF8 AS source_label,

        CASE LOWER(pc.COLUMN_NAME)
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
            AS almp_element_name,

        /*
        Convert the PRISM label into the corresponding ALMP description.
        This description is then joined to ref.almp_code.
        */
        CASE
            /* Gender */
            WHEN LOWER(pc.COLUMN_NAME) = 'gendercode'
             AND LOWER(pc.CHOICE_NAME) IN
                 ('male', 'female', 'unspecified')
                THEN LOWER(pc.CHOICE_NAME)

            WHEN LOWER(pc.COLUMN_NAME) = 'gendercode'
             AND LOWER(pc.CHOICE_NAME) IN
                 (
                     'prefer not to answer',
                     'prefer not to respond',
                     'prefer not to disclose',
                     'prefer not to report'
                 )
                THEN 'prefer not to report'

            /* Marital status */
            WHEN LOWER(pc.COLUMN_NAME) = 'familystatuscode'
             AND LOWER(pc.CHOICE_NAME) IN
                 (
                     'married',
                     'common law',
                     'married common law'
                 )
                THEN 'married equivalent'

            WHEN LOWER(pc.COLUMN_NAME) = 'familystatuscode'
             AND LOWER(pc.CHOICE_NAME) = 'single'
                THEN 'single'

            WHEN LOWER(pc.COLUMN_NAME) = 'familystatuscode'
             AND LOWER(pc.CHOICE_NAME) IN
                 (
                     'prefer not to answer',
                     'prefer not to respond',
                     'prefer not to report'
                 )
                THEN 'prefer not to report'

            /* Language */
            WHEN LOWER(pc.COLUMN_NAME) = 'ict_languageofservices'
             AND LOWER(pc.CHOICE_NAME) IN
                 ('english', 'english only')
                THEN 'english only'

            WHEN LOWER(pc.COLUMN_NAME) = 'ict_languageofservices'
             AND LOWER(pc.CHOICE_NAME) IN
                 ('french', 'french only')
                THEN 'french only'

            WHEN LOWER(pc.COLUMN_NAME) = 'ict_languageofservices'
             AND LOWER(pc.CHOICE_NAME) IN
                 (
                     'english and french',
                     'english & french',
                     'english french',
                     'bilingual'
                 )
                THEN 'english and french'

            WHEN LOWER(pc.COLUMN_NAME) = 'ict_languageofservices'
             AND LOWER(pc.CHOICE_NAME) IN
                 (
                     'other',
                     'other language',
                     'neither',
                     'not a federal official language'
                 )
                THEN 'not a federal official language'

            /* Yes/No fields */
            WHEN LOWER(pc.COLUMN_NAME) IN
                 (
                     'ict_disability',
                     'ict_visibleminority'
                 )
             AND LOWER(pc.CHOICE_NAME) IN ('yes', 'no')
                THEN LOWER(pc.CHOICE_NAME)

            WHEN LOWER(pc.COLUMN_NAME) IN
                 (
                     'ict_disability',
                     'ict_visibleminority'
                 )
             AND LOWER(pc.CHOICE_NAME) IN
                 (
                     'prefer not to answer',
                     'prefer not to respond',
                     'prefer not to report'
                 )
                THEN 'prefer not to report'

            /* Indigenous identity */
            WHEN LOWER(pc.COLUMN_NAME) = 'ict_indigenousidentity'
             AND LOWER(pc.CHOICE_NAME) IN
                 (
                     'first nations',
                     'first nation',
                     'metis',
                     'métis',
                     'inuit',
                     'indigenous'
                 )
                THEN 'yes'

            WHEN LOWER(pc.COLUMN_NAME) = 'ict_indigenousidentity'
             AND LOWER(pc.CHOICE_NAME) IN
                 (
                     'no',
                     'non-indigenous',
                     'not indigenous'
                 )
                THEN 'no'

            WHEN LOWER(pc.COLUMN_NAME) = 'ict_indigenousidentity'
             AND LOWER(pc.CHOICE_NAME) IN
                 (
                     'prefer not to answer',
                     'prefer not to respond',
                     'prefer not to report'
                 )
                THEN 'prefer not to report'

            /*
            Immigration is intentionally limited to direct Yes/No labels.
            Detailed citizenship statuses should be added after reviewing
            their meaning.
            */
            WHEN LOWER(pc.COLUMN_NAME) =
                 'ict_citizenshipimmigrationstatus'
             AND LOWER(pc.CHOICE_NAME) IN ('yes', 'no')
                THEN LOWER(pc.CHOICE_NAME)

            WHEN LOWER(pc.COLUMN_NAME) =
                 'ict_citizenshipimmigrationstatus'
             AND LOWER(pc.CHOICE_NAME) IN
                 (
                     'prefer not to answer',
                     'prefer not to respond',
                     'prefer not to report'
                 )
                THEN 'prefer not to report'
        END COLLATE Latin1_General_100_BIN2_UTF8
            AS target_description

    FROM stg.prism_choice AS pc

    WHERE LOWER(pc.MODULE_NAME)
              COLLATE Latin1_General_100_BIN2_UTF8
          = 'client'
              COLLATE Latin1_General_100_BIN2_UTF8

      AND LOWER(pc.TABLE_NAME)
              COLLATE Latin1_General_100_BIN2_UTF8
          = 'contact'
              COLLATE Latin1_General_100_BIN2_UTF8

      AND LOWER(pc.COLUMN_NAME)
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
        pc.source_system,
        pc.source_table,
        pc.source_column,
        pc.source_value,
        pc.source_label,
        pc.almp_element_name,
        ac.almp_code,

        CAST
        (
            CASE
                WHEN ac.program_type = 'ALL' THEN 'BOTH'
                ELSE ac.program_type
            END
            AS VARCHAR(10)
        ) COLLATE Latin1_General_100_BIN2_UTF8
            AS almp_program_type,

        ac.schema_version AS almp_schema_version,
        ac.effective_from,
        ac.effective_to,

        CAST
        (
            'Initial PRISM client mapping based on PRISM choice label.'
            AS VARCHAR(1000)
        ) COLLATE Latin1_General_100_BIN2_UTF8
            AS mapping_note

    FROM prism_choices AS pc

    INNER JOIN ref.almp_code AS ac
        ON LOWER(ac.code_domain)
               COLLATE Latin1_General_100_BIN2_UTF8
           =
           LOWER(pc.almp_element_name)
               COLLATE Latin1_General_100_BIN2_UTF8

       AND LOWER(ac.description)
               COLLATE Latin1_General_100_BIN2_UTF8
           =
           LOWER(pc.target_description)
               COLLATE Latin1_General_100_BIN2_UTF8

       AND ac.schema_version
               COLLATE Latin1_General_100_BIN2_UTF8
           =
           '1.5'
               COLLATE Latin1_General_100_BIN2_UTF8

       AND ac.is_active = 1

    WHERE pc.target_description IS NOT NULL
)

INSERT INTO ref.code_map
(
    source_system,
    source_table,
    source_column,
    source_value,
    source_label,
    almp_element_name,
    almp_code,
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
    m.almp_element_name,
    m.almp_code,
    m.almp_program_type,
    m.almp_schema_version,
    m.effective_from,
    m.effective_to,
    m.mapping_note

FROM mapped_choices AS m

WHERE NOT EXISTS
(
    SELECT 1
    FROM ref.code_map AS existing

    WHERE existing.source_system
              COLLATE Latin1_General_100_BIN2_UTF8
          =
          m.source_system
              COLLATE Latin1_General_100_BIN2_UTF8

      AND
      (
          existing.source_table
              COLLATE Latin1_General_100_BIN2_UTF8
          =
          m.source_table
              COLLATE Latin1_General_100_BIN2_UTF8

          OR
          (
              existing.source_table IS NULL
              AND m.source_table IS NULL
          )
      )

      AND existing.source_column
              COLLATE Latin1_General_100_BIN2_UTF8
          =
          m.source_column
              COLLATE Latin1_General_100_BIN2_UTF8

      AND existing.source_value
              COLLATE Latin1_General_100_BIN2_UTF8
          =
          m.source_value
              COLLATE Latin1_General_100_BIN2_UTF8

      AND existing.almp_element_name
              COLLATE Latin1_General_100_BIN2_UTF8
          =
          m.almp_element_name
              COLLATE Latin1_General_100_BIN2_UTF8

      AND existing.almp_code
              COLLATE Latin1_General_100_BIN2_UTF8
          =
          m.almp_code
              COLLATE Latin1_General_100_BIN2_UTF8

      AND existing.almp_program_type
              COLLATE Latin1_General_100_BIN2_UTF8
          =
          m.almp_program_type
              COLLATE Latin1_General_100_BIN2_UTF8

      AND existing.almp_schema_version
              COLLATE Latin1_General_100_BIN2_UTF8
          =
          m.almp_schema_version
              COLLATE Latin1_General_100_BIN2_UTF8
);