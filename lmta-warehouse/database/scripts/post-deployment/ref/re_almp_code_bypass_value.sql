UPDATE ref.almp_code
SET is_bypass =
    CASE
        WHEN almp_label IN (
            'Not Available',
            'Prefer not to report',
            'Not Applicable'
        )
        THEN 1
        ELSE 0
    END;