/*==============================================================
  1. POPULATE TABLE
==============================================================*/

INSERT INTO ref.almp_code
(
    code_domain,
    xsd_type_name,
    almp_code,
    description,
    program_type,
    is_bypass_value,
    schema_version,
    effective_from,
    effective_to,
    is_active
)
VALUES

/* Province */
('province','addressProvinceCodeValue','1','Newfoundland and Labrador','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','2','Nova Scotia','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','3','New Brunswick','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','4','Prince Edward Island','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','5','Quebec','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','6','Ontario','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','7','Manitoba','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','8','Saskatchewan','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','9','Alberta','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','10','Northwest Territories','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','11','British Columbia','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','12','Yukon','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','13','United States','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','14','Other Country','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','16','Nunavut','ALL',0,'1.5','2026-04-15',NULL,1),
('province','addressProvinceCodeValue','98','Not Available','ALL',1,'1.5','2026-04-15',NULL,1),

/* Education */
('educationLevel','educationCodeValue','5','Secondary school diploma or GED','ALL',0,'1.5','2026-04-15',NULL,1),
('educationLevel','educationCodeValue','6','Some post-secondary training','ALL',0,'1.5','2026-04-15',NULL,1),
('educationLevel','educationCodeValue','8','College, CEGEP or other non-university certificate or diploma','ALL',0,'1.5','2026-04-15',NULL,1),
('educationLevel','educationCodeValue','9','University certificate or diploma','ALL',0,'1.5','2026-04-15',NULL,1),
('educationLevel','educationCodeValue','13','Less than high school','LMTA',0,'1.5','2026-04-15',NULL,1),
('educationLevel','educationCodeValue','14','University degree','LMTA',0,'1.5','2026-04-15',NULL,1),
('educationLevel','educationCodeValue','15','Other','LMTA',0,'1.5','2026-04-15',NULL,1),
('educationLevel','educationCodeValue','98','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('educationLevel','educationCodeValue','99','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Language */
('languageSpoken','languagesSpokenCodeValue','2','English only','ALL',0,'1.5','2026-04-15',NULL,1),
('languageSpoken','languagesSpokenCodeValue','3','French only','ALL',0,'1.5','2026-04-15',NULL,1),
('languageSpoken','languagesSpokenCodeValue','6','English and French','ALL',0,'1.5','2026-04-15',NULL,1),
('languageSpoken','languagesSpokenCodeValue','9','Not a federal official language','LMTA',0,'1.5','2026-04-15',NULL,1),
('languageSpoken','languagesSpokenCodeValue','10','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Gender */
('gender','genderCodeValue','1','Male','ALL',0,'1.5','2026-04-15',NULL,1),
('gender','genderCodeValue','2','Female','ALL',0,'1.5','2026-04-15',NULL,1),
('gender','genderCodeValue','3','Unspecified','ALL',0,'1.5','2026-04-15',NULL,1),
('gender','genderCodeValue','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Marital status */
('maritalStatus','maritalStatusCodeValue','1','Married or equivalent','ALL',0,'1.5','2026-04-15',NULL,1),
('maritalStatus','maritalStatusCodeValue','2','Single','ALL',0,'1.5','2026-04-15',NULL,1),
('maritalStatus','maritalStatusCodeValue','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('maritalStatus','maritalStatusCodeValue','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Disability */
('disability','disabilityCodeValue','1','Yes','ALL',0,'1.5','2026-04-15',NULL,1),
('disability','disabilityCodeValue','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),
('disability','disabilityCodeValue','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('disability','disabilityCodeValue','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Indigenous identity */
('indigenousIdentity','indigenousIdentityCodeValue','1','Yes','ALL',0,'1.5','2026-04-15',NULL,1),
('indigenousIdentity','indigenousIdentityCodeValue','2','No','ALL',0,'1.5','2026-04-15',NULL,1),
('indigenousIdentity','indigenousIdentityCodeValue','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('indigenousIdentity','indigenousIdentityCodeValue','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Immigrant */
('immigrant','immigrationStatusCodeValue','1','Yes','ALL',0,'1.5','2026-04-15',NULL,1),
('immigrant','immigrationStatusCodeValue','2','No','ALL',0,'1.5','2026-04-15',NULL,1),
('immigrant','immigrationStatusCodeValue','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('immigrant','immigrationStatusCodeValue','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Visible minority */
('visibleMinority','visibleMinorityCodeValue','1','Yes','ALL',0,'1.5','2026-04-15',NULL,1),
('visibleMinority','visibleMinorityCodeValue','2','No','ALL',0,'1.5','2026-04-15',NULL,1),
('visibleMinority','visibleMinorityCodeValue','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('visibleMinority','visibleMinorityCodeValue','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Previous employment */
('actionPlanPreviousEmployment','actionPlanPreviousEmploymentCodeValue','1','Unemployed','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousEmployment','actionPlanPreviousEmploymentCodeValue','2','Employed','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousEmployment','actionPlanPreviousEmploymentCodeValue','3','Self-employed','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousEmployment','actionPlanPreviousEmploymentCodeValue','6','Not in labour force','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousEmployment','actionPlanPreviousEmploymentCodeValue','7','Work-sharing','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousEmployment','actionPlanPreviousEmploymentCodeValue','10','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Previous multiple employment */
('actionPlanPreviousMultipleEmployment','actionPlanPreviousMultipleEmploymentCodeValue','1','Yes','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanPreviousMultipleEmployment','actionPlanPreviousMultipleEmploymentCodeValue','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Precarious employment */
('actionPlanPrecariousEmployment','actionPlanPrecariousEmploymentCodeValue','1','Yes','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanPrecariousEmployment','actionPlanPrecariousEmploymentCodeValue','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanPrecariousEmployment','actionPlanPrecariousEmploymentCodeValue','9','Prefer not to report','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Action Plan result */
('actionPlanResultCode','actionPlanResultCodeValue','1','Unemployed but available for work','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','actionPlanResultCodeValue','2','Employed','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','actionPlanResultCodeValue','3','Self-employed','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','actionPlanResultCodeValue','4','Returned to School','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','actionPlanResultCodeValue','5','Unspecified - participant could not be reached','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','actionPlanResultCodeValue','6','Not in labour force','ALL',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','actionPlanResultCodeValue','7','Work-sharing','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanResultCode','actionPlanResultCodeValue','8','Starting a new action plan','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Funding source */
('actionPlanFundingSource','actionPlanFundingSourceCodeValue','1','Steel Tariffs','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFundingSource','actionPlanFundingSourceCodeValue','2','Softwood Lumber Tariffs','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFundingSource','actionPlanFundingSourceCodeValue','3','Comprehensive Tariffs','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFundingSource','actionPlanFundingSourceCodeValue','8','Not Applicable','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Follow-up result */
('actionPlanFollowUpResultCode','actionPlanFollowUpResultCodeValue','1','Unemployed but available for work','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','actionPlanFollowUpResultCodeValue','2','Employed','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','actionPlanFollowUpResultCodeValue','3','Self-employed','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','actionPlanFollowUpResultCodeValue','4','Returned to School','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','actionPlanFollowUpResultCodeValue','5','Unspecified - participant could not be reached','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','actionPlanFollowUpResultCodeValue','6','Not in labour force','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','actionPlanFollowUpResultCodeValue','7','Work-sharing','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpResultCode','actionPlanFollowUpResultCodeValue','8','Starting a new action plan','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Follow-up multiple employment */
('actionPlanFollowUpMultipleEmployment','actionPlanFollowUpMultipleEmploymentCodeValue','1','Yes','LMTA',0,'1.5','2026-04-15',NULL,1),
('actionPlanFollowUpMultipleEmployment','actionPlanFollowUpMultipleEmploymentCodeValue','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Intervention codes */
('interventionCode','interventionCodeValue','111','Job Search Assistance','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','112','Counselling / Case Management','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','113','Unassisted Services','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','114','Other Employment Assistance Services','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','211','Occupational Skills Training','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','212','Short-term Training','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','213','Literacy, Essential Skills, Language Training and Adult Basic Education','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','214','Apprenticeship','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','215','Other Skills Development','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','221','Targeted Wage Subsidies','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','222','Job Creation Partnership','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','223','Self-employment Assistance','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','224','Targeted Earnings Supplements','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCode','interventionCodeValue','311','Fee Payer','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Intervention outcome */
('interventionOutcome','interventionOutcomeCodeValue','1','Completed','ALL',0,'1.5','2026-04-15',NULL,1),
('interventionOutcome','interventionOutcomeCodeValue','3','Incomplete','ALL',0,'1.5','2026-04-15',NULL,1),
('interventionOutcome','interventionOutcomeCodeValue','4','Failed to report','ALL',0,'1.5','2026-04-15',NULL,1),
('interventionOutcome','interventionOutcomeCodeValue','5','Cancelled','ALL',0,'1.5','2026-04-15',NULL,1),
('interventionOutcome','interventionOutcomeCodeValue','6','Rescheduled','ALL',0,'1.5','2026-04-15',NULL,1),

/* Intervention language */
('interventionLanguageOfService','interventionLanguageOfServiceCodeValue','2','English','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionLanguageOfService','interventionLanguageOfServiceCodeValue','3','French','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionLanguageOfService','interventionLanguageOfServiceCodeValue','9','Not an official language','LMTA',0,'1.5','2026-04-15',NULL,1),

/* Credential */
('interventionCredential','interventionCredentialCodeValue','1','Yes','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCredential','interventionCredentialCodeValue','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCredential','interventionCredentialCodeValue','8','Not Applicable','LMTA',1,'1.5','2026-04-15',NULL,1),
('interventionCredential','interventionCredentialCodeValue','9','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Essential skills */
('interventionEssentialSkills','interventionEssentialSkillsCodeValue','1','Yes','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionEssentialSkills','interventionEssentialSkillsCodeValue','2','No','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionEssentialSkills','interventionEssentialSkillsCodeValue','8','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),

/* Intervention support cost categories */
('interventionCostCategory','interventionCostCategoryCodeValue','0','Not Applicable','LMTA',1,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','interventionCostCategoryCodeValue','1','Transportation','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','interventionCostCategoryCodeValue','2','Dependent Support','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','interventionCostCategoryCodeValue','3','Accommodations','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','interventionCostCategoryCodeValue','4','Disability Support','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','interventionCostCategoryCodeValue','5','Mental Health Support','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','interventionCostCategoryCodeValue','6','Supplies Support','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','interventionCostCategoryCodeValue','7','Mobility / Relocation','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','interventionCostCategoryCodeValue','8','Tuition Fees','LMTA',0,'1.5','2026-04-15',NULL,1),
('interventionCostCategory','interventionCostCategoryCodeValue','10','Other','LMTA',0,'1.5','2026-04-15',NULL,1),

/* NOC versions */
('NOCVersion','NOCVersionValue','0000','Not Available','ALL',1,'1.5','2026-04-15',NULL,1),
('NOCVersion','NOCVersionValue','2006','NOC 2006','ALL',0,'1.5','2026-04-15',NULL,1),
('NOCVersion','NOCVersionValue','2011','NOC 2011','ALL',0,'1.5','2026-04-15',NULL,1),
('NOCVersion','NOCVersionValue','2016','NOC 2016','ALL',0,'1.5','2026-04-15',NULL,1),
('NOCVersion','NOCVersionValue','2021','NOC 2021','ALL',0,'1.5','2026-04-15',NULL,1),

/* NAICS versions */
('NAICSVersion','NAICSVersionValue','0000','Not Available','LMTA',1,'1.5','2026-04-15',NULL,1),
('NAICSVersion','NAICSVersionValue','2017','NAICS 2017','LMTA',0,'1.5','2026-04-15',NULL,1),
('NAICSVersion','NAICSVersionValue','2022','NAICS 2022','LMTA',0,'1.5','2026-04-15',NULL,1);

GO
/*==============================================================
  2. VERIFY
==============================================================*/

SELECT
    code_domain,
    COUNT(*) AS code_count
FROM ref.almp_code
GROUP BY code_domain
ORDER BY code_domain;

GO

SELECT *
FROM ref.almp_code
ORDER BY
    code_domain,
    almp_code;

GO