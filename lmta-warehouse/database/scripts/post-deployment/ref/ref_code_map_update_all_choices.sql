-- Update PRISM Client Indigenous Identity mappings
UPDATE ref.code_map
SET
    almp_element = 'indigenousIdentity',
    almp_label =
        CASE source_code
            WHEN '802500003' THEN 'Yes'                    -- Inuit
            WHEN '802500002' THEN 'Yes'                    -- Metis
            WHEN '802500001' THEN 'Yes'                    -- Non-Status
            WHEN '802500000' THEN 'Yes'                    -- Treaty/Registered (Status)
            WHEN '802500005' THEN 'No'                     -- Non Indigenous
            WHEN '802500004' THEN 'Prefer not to report'   -- Prefer not to respond
        END,
    almp_code =
        CASE source_code
            WHEN '802500003' THEN '1'
            WHEN '802500002' THEN '1'
            WHEN '802500001' THEN '1'
            WHEN '802500000' THEN '1'
            WHEN '802500005' THEN '2'
            WHEN '802500004' THEN '9'
        END,
    mapping_note =
        CASE source_code
            WHEN '802500003'
                THEN 'Inuit maps to ALMP Indigenous Identity Yes.'
            WHEN '802500002'
                THEN 'Metis maps to ALMP Indigenous Identity Yes.'
            WHEN '802500001'
                THEN 'Non-Status maps to ALMP Indigenous Identity Yes.'
            WHEN '802500000'
                THEN 'Treaty/Registered (Status) maps to ALMP Indigenous Identity Yes.'
            WHEN '802500005'
                THEN 'Non Indigenous maps to ALMP Indigenous Identity No.'
            WHEN '802500004'
                THEN 'Prefer not to respond maps to ALMP Prefer not to report.'
        END
WHERE source_system = 'PRISM_CLT'
  AND source_table = 'contact'
  AND source_column = 'ict_indigenousidentity'
  AND source_code IN
  (
      '802500003',
      '802500002',
      '802500001',
      '802500000',
      '802500005',
      '802500004'
  );