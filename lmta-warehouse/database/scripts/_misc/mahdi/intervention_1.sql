/*==============================================================================
  PRISM interventions

  Combines:
    1. PRISM Client action plans
    2. PRISM Contract service plans

  Values remain in PRISM format.
  No ALMP/XSD mappings are applied.
==============================================================================*/

SELECT 
    CAST('ict_actionplan' AS varchar(100))             AS source_table,

    LEFT(c.ict_clientid, 100)                          AS client_id,
    LEFT(ap.ict_name, 100)                             AS intervention_id,
    CAST('Career Counselling' AS varchar(500))         AS intervention_title,

    CAST(NULL AS varchar(100))                         AS contract_number,
    CAST(NULL AS varchar(500))                         AS contract,
    CAST(NULL AS varchar(500))                         AS subprogram,

    CAST(ap.ict_actionplanstartdate AS date)           AS intervention_start_date,
    CAST(ap.ict_closuredate AS date)                   AS intervention_end_date,

    ap.ict_actionplanstatus                            AS intervention_status_code,
    ap.ict_closurereason                               AS closure_reason_code,

    LEFT(ap.ict_client, 100)                           AS source_client_guid,
    LEFT(ap.ict_actionplanid, 100)                     AS source_intervention_guid,
    CAST(NULL AS varchar(100))                         AS source_contract_guid,

    ap.statecode                                       AS state_code,
    ap.statuscode                                      AS status_code

FROM stg.prism_clt_ict_actionplan AS ap

LEFT JOIN stg.prism_clt_contact AS c
    ON c.contactid = ap.ict_client

WHERE c.ict_clientid IS NOT NULL 
    AND c.statecode = 0



UNION ALL


SELECT
    CAST('ict_serviceplan' AS varchar(100))            AS source_table,

    LEFT(cc.ict_clientidid, 100)                       AS client_id,
    LEFT(sp.ict_name, 100)                             AS intervention_id,

    LEFT(
        COALESCE(
            NULLIF(TRIM(ct.pcm_name), ''),
            NULLIF(TRIM(sub.ict_name), ''),
            NULLIF(TRIM(sp.ict_name), '')
        ),
        500
    )                                                  AS intervention_title,

    LEFT(ct.pcm_contractnum, 100)                      AS contract_number,
    LEFT(ct.pcm_name, 500)                             AS contract,
    LEFT(sub.ict_name, 500)                            AS subprogram,

    CAST(sp.ict_startdate AS date)                     AS intervention_start_date,
    CAST(sp.ict_closuredate AS date)                   AS intervention_end_date,

    sp.ict_serviceplanstatus                           AS intervention_status_code,
    sp.ict_closurereason                               AS closure_reason_code,

    LEFT(sp.ict_client, 100)                           AS source_client_guid,
    LEFT(sp.ict_serviceplanid, 100)                    AS source_intervention_guid,
    LEFT(sp.ict_contractid, 100)                       AS source_contract_guid,

    sp.statecode                                       AS state_code,
    sp.statuscode                                      AS status_code

FROM stg.prism_ctr_ict_serviceplan AS sp

LEFT JOIN stg.prism_ctr_ict_client AS cc
    ON cc.ict_clientid = sp.ict_client

LEFT JOIN stg.prism_ctr_pcm_contract AS ct
    ON ct.pcm_contractid = sp.ict_contractid

LEFT JOIN stg.prism_ctr_ict_subprogram AS sub
    ON sub.ict_subprogramid = ct.ict_subprogramtype

WHERE cc.ict_clientidid IS NOT NULL 
    AND cc.statecode = 0


ORDER BY
    client_id, intervention_start_date;

