TRUNCATE TABLE int.client;

INSERT INTO int.client
(
    client_id,
    source_system,
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
    ROW_NUMBER() OVER (ORDER BY c.ict_clientid, c.contactid),
    'PRISM',
    LEFT(c.ict_clientid, 30),
    LEFT(c.ict_sin, 9),
    LEFT(c.lastname, 100),
    LEFT(c.firstname, 100),
    c.ict_dateofbirth,
    LEFT(c.emailaddress1, 254),
    gender.almp_code,
    marital.almp_code,
    c.numberofchildren,
    language.almp_code,
    disability.almp_code,
    indigenous.almp_code,
    immigrant.almp_code,
    LEFT(c.ict_yearofpermanentresidency, 4),
    minority.almp_code,
    LEFT(CONCAT_WS(', ', c.address1_line1, c.address1_line2), 150),
    LEFT(c.address1_city, 100),
    province.almp_code,
    LEFT(c.address1_postalcode, 10),
    LEFT(COALESCE(c.mobilephone, c.telephone2, c.telephone1), 30),
    NULL,
    LEFT(c.ict_message, 100)

FROM stg.prism_clt_contact c

LEFT JOIN ref.code_map gender
    ON gender.source_system = 'PRISM'
   AND gender.source_table = 'contact'
   AND gender.source_column = 'gendercode'
   AND gender.source_code = c.gendercode
   AND gender.almp_element = 'gender'
   AND gender.is_active = 1

LEFT JOIN ref.code_map marital
    ON marital.source_system = 'PRISM'
   AND marital.source_table = 'contact'
   AND marital.source_column = 'familystatuscode'
   AND marital.source_code = c.familystatuscode
   AND marital.almp_element = 'maritalStatus'
   AND marital.is_active = 1

LEFT JOIN ref.code_map language
    ON language.source_system = 'PRISM'
   AND language.source_table = 'contact'
   AND language.source_column = 'ict_languageofservices'
   AND language.source_code = c.ict_languageofservices
   AND language.almp_element = 'languageSpoken'
   AND language.is_active = 1

LEFT JOIN ref.code_map disability
    ON disability.source_system = 'PRISM'
   AND disability.source_table = 'contact'
   AND disability.source_column = 'ict_disability'
   AND disability.source_code = c.ict_disability
   AND disability.almp_element = 'disability'
   AND disability.is_active = 1

LEFT JOIN ref.code_map indigenous
    ON indigenous.source_system = 'PRISM'
   AND indigenous.source_table = 'contact'
   AND indigenous.source_column = 'ict_indigenousidentity'
   AND indigenous.source_code = c.ict_indigenousidentity
   AND indigenous.almp_element = 'indigenousIdentity'
   AND indigenous.is_active = 1

LEFT JOIN ref.code_map immigrant
    ON immigrant.source_system = 'PRISM'
   AND immigrant.source_table = 'contact'
   AND immigrant.source_column = 'ict_citizenshipimmigrationstatus'
   AND immigrant.source_code = c.ict_citizenshipimmigrationstatus
   AND immigrant.almp_element = 'immigrant'
   AND immigrant.is_active = 1

LEFT JOIN ref.code_map minority
    ON minority.source_system = 'PRISM'
   AND minority.source_table = 'contact'
   AND minority.source_column = 'ict_visibleminority'
   AND minority.source_code = c.ict_visibleminority
   AND minority.almp_element = 'visibleMinority'
   AND minority.is_active = 1

LEFT JOIN ref.code_map province
    ON province.source_system = 'PRISM'
   AND province.source_table = 'contact'
   AND province.source_column = 'address1_stateorprovince'
   AND province.source_code = c.address1_stateorprovince
   AND province.almp_element = 'province'
   AND province.is_active = 1

WHERE c.ict_clientid IS NOT NULL
  AND c.statecode = 0;