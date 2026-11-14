/*==============================================================
  1. POPULATE TABLE
==============================================================*/

INSERT INTO ref.almp_code
(
    almp_element,
    almp_code,
    almp_label,
    program_type,
    is_bypass_value,
    schema_version,
    effective_from,
    effective_to,
    is_active
)
VALUES

/* Province */
('province','1','Newfoundland and Labrador','ALL',0,'1.5','2026-04-15',NULL,1),
('province','2','Nova Scotia','ALL',0,'1.5','2026-04-15',NULL,1),
('province','3','New Brunswick','ALL',0,'1.5','2026-04-15',NULL,1),
('province','4','Prince Edward Island','ALL',0,'1.5','2026-04-15',NULL,1),
('province','5','Quebec','ALL',0,'1.5','2026-04-15',NULL,1),
('province','6','Ontario','ALL',0,'1.5','2026-04-15',NULL,1),
('province','7','Manitoba','ALL',0,'1.5','2026-04-15',NULL,1),
('province','8','Saskatchewan','ALL',0,'1.5','2026-04-15',NULL,1),
('province','9','Alberta','ALL',0,'1.5','2026-04-15',NULL,1),
('province','10','Northwest Territories','ALL',0,'1.5','2026-04-15',NULL,1),
('province','11','British Columbia','ALL',0,'1.5','2026-04-15',NULL,1),
('province','12','Yukon','ALL',0,'1.5','2026-04-15',NULL,1),
('province','13','United States','ALL',0,'1.5','2026-04-15',NULL,1),
('province','14','Other Country','ALL',0,'1.5','2026-04-15',NULL,1),
('province','16','Nunavut','ALL',0,'1.5','2026-04-15',NULL,1),
('province','98','Not Available','ALL',1,'1.5','2026-04-15',NULL,1),

/* Education */
('educationLevel','5','Secondary school diploma or GED','ALL',0,'1.5','2026-04-15',NULL,1),
('educationLevel','6','Some post-secondary training','ALL',0,'1.5','2026-04-15',NULL,1),
('educationLevel','8','College, CEGEP or other non-university certificate or diploma','ALL',0,'1.5','2026-04-15',NULL,1),
('educationLevel','9','University certificate or diploma','ALL',0,'1.5','2026-04-15',NULL,1),
('educationLevel','13','Less than high school','LMTA',0,'1.5','2026-04-15',NULL,1),
('educationLevel','14','University degree','LMTA',0,'1.5','2026-04-15',NULL,1),
('educationLevel','15','Other','LMTA',0,'1.5','2026-04-15',NULL,1),
('educationLevel','98','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('educationLevel','99','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Language */
('languageSpoken','2','English only','ALL',0,'1.5','2026-04-15',NULL,1),
('languageSpoken','3','French only','ALL',0,'1.5','2026-04-15',NULL,1),
('languageSpoken','6','English and French','ALL',0,'1.5','2026-04-15',NULL,1),
('languageSpoken','9','Not a federal official language','LMTA',0,'1.5','2026-04-15',NULL,1),
('languageSpoken','10','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Gender */
('gender','1','Male','ALL',0,'1.5','2026-04-15',NULL,1),
('gender','2','Female','ALL',0,'1.5','2026-04-15',NULL,1),
('gender','3','Unspecified','ALL',0,'1.5','2026-04-15',NULL,1),
('gender','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Marital status */
('maritalStatus','1','Married or equivalent','ALL',0,'1.5','2026-04-15',NULL,1),
('maritalStatus','2','Single','ALL',0,'1.5','2026-04-15',NULL,1),
('maritalStatus','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('maritalStatus','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Disability */
('disability','1','Yes','ALL',0,'1.5','2026-04-15',NULL,1),
('disability','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),
('disability','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('disability','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Indigenous identity */
('indigenousIdentity','1','Yes','ALL',0,'1.5','2026-04-15',NULL,1),
('indigenousIdentity','2','No','ALL',0,'1.5','2026-04-15',NULL,1),
('indigenousIdentity','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('indigenousIdentity','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Immigrant */
('immigrant','1','Yes','ALL',0,'1.5','2026-04-15',NULL,1),
('immigrant','2','No','ALL',0,'1.5','2026-04-15',NULL,1),
('immigrant','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('immigrant','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Visible minority */
('visibleMinority','1','Yes','ALL',0,'1.5','2026-04-15',NULL,1),
('visibleMinority','2','No','ALL',0,'1.5','2026-04-15',NULL,1),
('visibleMinority','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('visibleMinority','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Previous employment */
('actionPlanPreviousEmployment','1','Unemployed','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousEmployment','2','Employed','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousEmployment','3','Self-employed','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousEmployment','6','Not in labour force','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousEmployment','7','Work-sharing','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousEmployment','10','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Previous multiple employment */
('actionPlanPreviousMultipleEmployment','1','Yes','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousMultipleEmployment','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Precarious employment */
('actionPlanPrecariousEmployment','1','Yes','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanPrecariousEmployment','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanPrecariousEmployment','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Action Plan result */
('actionPlanResultCode','1','Unemployed but available for work','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','2','Employed','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','3','Self-employed','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','4','Returned to School','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','5','Unspecified - participant could not be reached','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','6','Not in labour force','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','7','Work-sharing','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','8','Starting a new action plan','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Funding source */
('actionPlanFundingSource','1','Steel Tariffs','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFundingSource','2','Softwood Lumber Tariffs','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFundingSource','3','Comprehensive Tariffs','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFundingSource','8','Not Applicable','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Follow-up result */
('actionPlanFollowUpResultCode','1','Unemployed but available for work','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','2','Employed','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','3','Self-employed','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','4','Returned to School','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','5','Unspecified - participant could not be reached','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','6','Not in labour force','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','7','Work-sharing','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','8','Starting a new action plan','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Follow-up multiple employment */
('actionPlanFollowUpMultipleEmployment','1','Yes','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpMultipleEmployment','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Intervention codes */
('interventionCode','111','Job Search Assistance','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','112','Counselling / Case Management','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','113','Unassisted Services','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','114','Other Employment Assistance Services','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','211','Occupational Skills Training','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','212','Short-term Training','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','213','Literacy, Essential Skills, Language Training and Adult Basic Education','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','214','Apprenticeship','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','215','Other Skills Development','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','221','Targeted Wage Subsidies','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','222','Job Creation Partnership','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','223','Self-employment Assistance','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','224','Targeted Earnings Supplements','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','311','Fee Payer','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Intervention outcome */
('interventionOutcome','1','Completed','ALL',0,'1.5','2026-04-15',NULL,1),
('interventionOutcome','3','Incomplete','ALL',0,'1.5','2026-04-15',NULL,1),
('interventionOutcome','4','Failed to report','ALL',0,'1.5','2026-04-15',NULL,1),
('interventionOutcome','5','Cancelled','ALL',0,'1.5','2026-04-15',NULL,1),
('interventionOutcome','6','Rescheduled','ALL',0,'1.5','2026-04-15',NULL,1),

/* Intervention language */
('interventionLanguageOfService','2','English','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionLanguageOfService','3','French','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionLanguageOfService','9','Not an official language','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Credential */
('interventionCredential','1','Yes','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCredential','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCredential','8','Not Applicable','LMTA',1,'1.5','2026-04-15',NULL,1),
('interventionCredential','9','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Essential skills */
('interventionEssentialSkills','1','Yes','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionEssentialSkills','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionEssentialSkills','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Intervention support cost categories */
('interventionCostCategory','0','Not Applicable','LMTA',1,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','1','Transportation','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','2','Dependent Support','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','3','Accommodations','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','4','Disability Support','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','5','Mental Health Support','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','6','Supplies Support','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','7','Mobility / Relocation','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','8','Tuition Fees','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','10','Other','LMTA',0,'1.5','2026-04-15',NULL,1),

/* NOC versions */
('NOCVersion','0000','Not Available','ALL',1,'1.5','2026-04-15',NULL,1),
('NOCVersion','2006','NOC 2006','ALL',0,'1.5','2026-04-15',NULL,1),
('NOCVersion','2011','NOC 2011','ALL',0,'1.5','2026-04-15',NULL,1),
('NOCVersion','2016','NOC 2016','ALL',0,'1.5','2026-04-15',NULL,1),
('NOCVersion','2021','NOC 2021','ALL',0,'1.5','2026-04-15',NULL,1),

/* NAICS versions */
('NAICSVersion','0000','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('NAICSVersion','2017','NAICS 2017','LMTA',0,'1.5','2026-04-15',NULL,1),
('NAICSVersion','2022','NAICS 2022','LMTA',0,'1.5','2026-04-15',NULL,1);

GO


/*==============================================================
  2. VERIFY
==============================================================*/

SELECT
    almp_element,
    COUNT(*) AS code_count
FROM ref.almp_code
GROUP BY almp_element
ORDER BY almp_element;

GO

SELECT *
FROM ref.almp_code
ORDER BY
    almp_element,
    almp_code;

GO