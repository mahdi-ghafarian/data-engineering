CREATE   VIEW int.prism_client
AS
SELECT
    CAST('PRISM' AS varchar(50))                        AS source_system,
    LEFT(c.ict_clientid, 30)                            AS clientID,
    LEFT(c.ict_sin, 9)                                  AS socialInsuranceNumber,
    LEFT(c.lastname, 100)                               AS lastName,
    LEFT(c.firstname, 100)                              AS firstName,
    CAST(c.ict_dateofbirth AS date)                     AS dateOfBirth,
    LEFT(c.emailaddress1, 254)                          AS emailAddress,
    gender.almp_code                                    AS gender,
    marital.almp_code                                   AS maritalStatus,
    c.numberofchildren                                  AS numberOfDependantChildren,
    language.almp_code                                  AS languageSpoken,
    disability.almp_code                                AS disability,
    indigenous.almp_code                                AS indigenousIdentity,
    immigrant.almp_code                                 AS immigrant,
    LEFT(c.ict_yearofpermanentresidency, 4)             AS immigrationYear,
    minority.almp_code                                  AS visibleMinority,

    LEFT(
        CONCAT_WS(
            ', ',
            NULLIF(LTRIM(RTRIM(c.address1_line1)), ''),
            NULLIF(LTRIM(RTRIM(c.address1_line2)), ''),
            NULLIF(LTRIM(RTRIM(c.address1_line3)), '')
        ),
        150
    )                                                   AS streetAddress,

    LEFT(c.address1_city, 100)                          AS municipality,
    province.almp_code                                  AS province,
    LEFT(c.address1_postalcode, 10)                     AS postalZIPCode,

    LEFT(
        COALESCE(
            NULLIF(LTRIM(RTRIM(c.mobilephone)), ''),
            NULLIF(LTRIM(RTRIM(c.telephone2)), ''),
            NULLIF(LTRIM(RTRIM(c.telephone1)), '')
        ),
        30
    )                                                   AS contactPhoneNumber,

    CAST(NULL AS varchar(100))                          AS addressSysComment,
    LEFT(c.ict_message, 100)                            AS sysComment

FROM stg.prism_clt_contact AS c

LEFT JOIN ref.code_map AS gender
    ON  gender.source_system = 'PRISM'
    AND gender.source_table = 'contact'
    AND gender.source_column = 'gendercode'
    AND gender.source_code = c.gendercode
    AND gender.almp_element = 'gender'
    AND gender.is_active = 1

LEFT JOIN ref.code_map AS marital
    ON  marital.source_system = 'PRISM'
    AND marital.source_table = 'contact'
    AND marital.source_column = 'familystatuscode'
    AND marital.source_code = c.familystatuscode
    AND marital.almp_element = 'maritalStatus'
    AND marital.is_active = 1

LEFT JOIN ref.code_map AS language
    ON  language.source_system = 'PRISM'
    AND language.source_table = 'contact'
    AND language.source_column = 'ict_languageofservices'
    AND language.source_code = c.ict_languageofservices
    AND language.almp_element = 'languageSpoken'
    AND language.is_active = 1

LEFT JOIN ref.code_map AS disability
    ON  disability.source_system = 'PRISM'
    AND disability.source_table = 'contact'
    AND disability.source_column = 'ict_disability'
    AND disability.source_code = c.ict_disability
    AND disability.almp_element = 'disability'
    AND disability.is_active = 1

LEFT JOIN ref.code_map AS indigenous
    ON  indigenous.source_system = 'PRISM'
    AND indigenous.source_table = 'contact'
    AND indigenous.source_column = 'ict_indigenousidentity'
    AND indigenous.source_code = c.ict_indigenousidentity
    AND indigenous.almp_element = 'indigenousIdentity'
    AND indigenous.is_active = 1

LEFT JOIN ref.code_map AS immigrant
    ON  immigrant.source_system = 'PRISM'
    AND immigrant.source_table = 'contact'
    AND immigrant.source_column = 'ict_citizenshipimmigrationstatus'
    AND immigrant.source_code = c.ict_citizenshipimmigrationstatus
    AND immigrant.almp_element = 'immigrant'
    AND immigrant.is_active = 1

LEFT JOIN ref.code_map AS minority
    ON  minority.source_system = 'PRISM'
    AND minority.source_table = 'contact'
    AND minority.source_column = 'ict_visibleminority'
    AND minority.source_code = c.ict_visibleminority
    AND minority.almp_element = 'visibleMinority'
    AND minority.is_active = 1

LEFT JOIN ref.code_map AS province
    ON  province.source_system = 'PRISM'
    AND province.source_table = 'contact'
    AND province.source_column = 'address1_stateorprovince'
    AND province.source_code = c.address1_stateorprovince
    AND province.almp_element = 'province'
    AND province.is_active = 1

WHERE c.ict_clientid IS NOT NULL
  AND c.statecode = 0;
GO

