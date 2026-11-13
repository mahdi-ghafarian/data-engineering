UPDATE ref.code_map
SET
    almp_code = '9',
    almp_label='Prefer not to report',
    mapping_note = 'Manual correction'
WHERE source_system = 'PRISM_CLT'
  AND source_table = 'contact'
  AND source_column = 'gendercode'
  AND source_code = '802500001'
  AND almp_schema_version = '1.5';
