SELECT
    pc.CHOICE_VALUE AS prism_value,
    pc.CHOICE_NAME AS prism_label,

    CASE
        WHEN LOWER(pc.CHOICE_NAME) = 'male'
            THEN '1'

        WHEN LOWER(pc.CHOICE_NAME) = 'female'
            THEN '2'

        WHEN LOWER(pc.CHOICE_NAME) = 'unspecified'
            THEN '3'

        WHEN LOWER(pc.CHOICE_NAME) IN
             (
                 'prefer not to answer',
                 'prefer not to respond',
                 'prefer not to disclose',
                 'prefer not to report'
             )
            THEN '9'
    END AS expected_almp_code

FROM stg.prism_choice AS pc

WHERE LOWER(pc.MODULE_NAME) = 'client'
  AND LOWER(pc.TABLE_NAME) = 'contact'
  AND LOWER(pc.COLUMN_NAME) = 'gendercode'

ORDER BY pc.CHOICE_VALUE;-- Write your own SQL object definition here, and it'll be included in your package.
