UPDATE ref.code_map
SET
    source_label = 'Unspecified',
    almp_code = '3',
    mapping_note = 'Manual correction: mapped to ALMP gender Unspecified.'
WHERE source_system = 'PRISM_CLT'
  AND source_table = 'contact'
  AND source_column = 'gendercode'
  AND source_value = 'PUT_PRISM_VALUE_HERE'
  AND almp_element_name = 'gender'
  AND almp_schema_version = '1.5';