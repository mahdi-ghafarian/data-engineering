INSERT INTO ref.almp_code
(
    parent_element,
    element,
    code,
    label,
    program_type,
    is_bypass,
    schema_version,
    effective_from,
    effective_to,
    is_active
)
VALUES
-- =========================================================
-- ACTION PLAN
-- =========================================================
('actionPlan', 'actionPlanFundingSource', '1', 'Steel Tariffs', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanFundingSource', '2', 'Softwood Lumber Tariffs', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanFundingSource', '3', 'Comprehensive Tariffs', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanFundingSource', '8', 'Not Applicable', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

('actionPlan', 'actionPlanPrecariousEmployment', '1', 'Yes', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPrecariousEmployment', '2', 'No', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPrecariousEmployment', '9', 'Prefer not to report', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

('actionPlan', 'actionPlanPreviousEmployment', '1', 'Unemployed', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousEmployment', '2', 'Employed', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousEmployment', '3', 'Self-employed', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousEmployment', '6', 'Not in labour force', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousEmployment', '7', 'Work-sharing', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousEmployment', '10', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

('actionPlan', 'actionPlanPreviousMultipleEmployment', '1', 'Yes', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousMultipleEmployment', '2', 'No', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),

('actionPlan', 'actionPlanResultCode', '1', 'Unemployed but available for work', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanResultCode', '2', 'Employed', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanResultCode', '3', 'Self-employed', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanResultCode', '4', 'Returned to School', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanResultCode', '5', 'Unspecified - participant could not be reached', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanResultCode', '6', 'Not in labour force', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanResultCode', '7', 'Work-sharing', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanResultCode', '8', 'Starting a new action plan', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),

('actionPlan', 'educationLevel', '5', 'Secondary school diploma or GED', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'educationLevel', '6', 'Some post-secondary training', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'educationLevel', '8', 'College, CEGEP or other non-university certificate or diploma', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'educationLevel', '9', 'University certificate or diploma', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'educationLevel', '13', 'Less than high school', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'educationLevel', '14', 'University degree', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'educationLevel', '15', 'Other', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'educationLevel', '98', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'educationLevel', '99', 'Prefer not to report', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

-- NOC version values assigned to actual action-plan XML elements
('actionPlan', 'actionPlanPreviousEmploymentNOCVersion', '0000', 'Not Available', 'BOTH', 1, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousEmploymentNOCVersion', '2006', 'NOC 2006', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousEmploymentNOCVersion', '2011', 'NOC 2011', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousEmploymentNOCVersion', '2016', 'NOC 2016', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousEmploymentNOCVersion', '2021', 'NOC 2021', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),

('actionPlan', 'actionPlanResultRelatedNOCVersion', '0000', 'Not Available', 'BOTH', 1, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanResultRelatedNOCVersion', '2006', 'NOC 2006', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanResultRelatedNOCVersion', '2011', 'NOC 2011', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanResultRelatedNOCVersion', '2016', 'NOC 2016', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanResultRelatedNOCVersion', '2021', 'NOC 2021', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),

-- NAICS version values assigned to actual action-plan XML elements
('actionPlan', 'actionPlanPreviousEmploymentNAICSVersion', '0000', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousEmploymentNAICSVersion', '2017', 'NAICS 2017', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanPreviousEmploymentNAICSVersion', '2022', 'NAICS 2022', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),

('actionPlan', 'actionPlanTargetNAICSVersion', '0000', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanTargetNAICSVersion', '2017', 'NAICS 2017', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlan', 'actionPlanTargetNAICSVersion', '2022', 'NAICS 2022', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),

-- =========================================================
-- ACTION PLAN FOLLOW-UP
-- =========================================================
('actionPlanFollowUp', 'actionPlanFollowUpMultipleEmployment', '1', 'Yes', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpMultipleEmployment', '2', 'No', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),

('actionPlanFollowUp', 'actionPlanFollowUpResultCode', '1', 'Unemployed but available for work', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpResultCode', '2', 'Employed', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpResultCode', '3', 'Self-employed', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpResultCode', '4', 'Returned to School', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpResultCode', '5', 'Unspecified - participant could not be reached', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpResultCode', '6', 'Not in labour force', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpResultCode', '7', 'Work-sharing', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpResultCode', '8', 'Starting a new action plan', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),

('actionPlanFollowUp', 'actionPlanFollowUpNOCVersion', '0000', 'Not Available', 'BOTH', 1, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpNOCVersion', '2006', 'NOC 2006', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpNOCVersion', '2011', 'NOC 2011', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpNOCVersion', '2016', 'NOC 2016', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpNOCVersion', '2021', 'NOC 2021', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),

('actionPlanFollowUp', 'actionPlanFollowUpNAICSVersion', '0000', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpNAICSVersion', '2017', 'NAICS 2017', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('actionPlanFollowUp', 'actionPlanFollowUpNAICSVersion', '2022', 'NAICS 2022', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),

-- =========================================================
-- ADDRESS
-- =========================================================
('address', 'province', '1', 'Newfoundland and Labrador', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '2', 'Nova Scotia', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '3', 'New Brunswick', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '4', 'Prince Edward Island', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '5', 'Quebec', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '6', 'Ontario', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '7', 'Manitoba', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '8', 'Saskatchewan', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '9', 'Alberta', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '10', 'Northwest Territories', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '11', 'British Columbia', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '12', 'Yukon', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '13', 'United States', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '14', 'Other Country', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '16', 'Nunavut', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('address', 'province', '98', 'Not Available', 'BOTH', 1, '1.5', '2026-04-15', NULL, 1),

-- =========================================================
-- CLIENT
-- =========================================================
('client', 'disability', '1', 'Yes', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'disability', '2', 'No', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'disability', '8', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),
('client', 'disability', '9', 'Prefer not to report', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

('client', 'gender', '1', 'Male', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'gender', '2', 'Female', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'gender', '3', 'Unspecified', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'gender', '9', 'Prefer not to report', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

('client', 'immigrant', '1', 'Yes', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'immigrant', '2', 'No', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'immigrant', '8', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),
('client', 'immigrant', '9', 'Prefer not to report', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

('client', 'indigenousIdentity', '1', 'Yes', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'indigenousIdentity', '2', 'No', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'indigenousIdentity', '8', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),
('client', 'indigenousIdentity', '9', 'Prefer not to report', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

('client', 'languageSpoken', '2', 'English only', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'languageSpoken', '3', 'French only', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'languageSpoken', '6', 'English and French', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'languageSpoken', '9', 'Not a federal official language', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'languageSpoken', '10', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

('client', 'maritalStatus', '1', 'Married or equivalent', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'maritalStatus', '2', 'Single', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'maritalStatus', '8', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),
('client', 'maritalStatus', '9', 'Prefer not to report', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

('client', 'visibleMinority', '1', 'Yes', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'visibleMinority', '2', 'No', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('client', 'visibleMinority', '8', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),
('client', 'visibleMinority', '9', 'Prefer not to report', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

-- =========================================================
-- INTERVENTION
-- =========================================================
('intervention', 'interventionCode', '111', 'Job Search Assistance', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '112', 'Counselling / Case Management', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '113', 'Unassisted Services', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '114', 'Other Employment Assistance Services', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '211', 'Occupational Skills Training', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '212', 'Short-term Training', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '213', 'Literacy, Essential Skills, Language Training and Adult Basic Education', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '214', 'Apprenticeship', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '215', 'Other Skills Development', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '221', 'Targeted Wage Subsidies', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '222', 'Job Creation Partnership', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '223', 'Self-employment Assistance', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '224', 'Targeted Earnings Supplements', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCode', '311', 'Fee Payer', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),

('intervention', 'interventionCredential', '1', 'Yes', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCredential', '2', 'No', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCredential', '8', 'Not Applicable', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionCredential', '9', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

('intervention', 'interventionEssentialSkills', '1', 'Yes', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionEssentialSkills', '2', 'No', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionEssentialSkills', '8', 'Not Available', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),

('intervention', 'interventionLanguageOfService', '2', 'English', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionLanguageOfService', '3', 'French', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionLanguageOfService', '9', 'Not an official language', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),

('intervention', 'interventionOutcome', '1', 'Completed', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionOutcome', '3', 'Incomplete', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionOutcome', '4', 'Failed to report', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionOutcome', '5', 'Cancelled', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionOutcome', '6', 'Rescheduled', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),

('intervention', 'interventionRelatedNOCVersion', '0000', 'Not Available', 'BOTH', 1, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionRelatedNOCVersion', '2006', 'NOC 2006', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionRelatedNOCVersion', '2011', 'NOC 2011', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionRelatedNOCVersion', '2016', 'NOC 2016', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),
('intervention', 'interventionRelatedNOCVersion', '2021', 'NOC 2021', 'BOTH', 0, '1.5', '2026-04-15', NULL, 1),

-- =========================================================
-- INTERVENTION SUPPORT
-- =========================================================
('interventionSupport', 'interventionCostCategory', '0', 'Not Applicable', 'LMTA', 1, '1.5', '2026-04-15', NULL, 1),
('interventionSupport', 'interventionCostCategory', '1', 'Transportation', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('interventionSupport', 'interventionCostCategory', '2', 'Dependent Support', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('interventionSupport', 'interventionCostCategory', '3', 'Accommodations', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('interventionSupport', 'interventionCostCategory', '4', 'Disability Support', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('interventionSupport', 'interventionCostCategory', '5', 'Mental Health Support', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('interventionSupport', 'interventionCostCategory', '6', 'Supplies Support', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('interventionSupport', 'interventionCostCategory', '7', 'Mobility / Relocation', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('interventionSupport', 'interventionCostCategory', '8', 'Tuition Fees', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1),
('interventionSupport', 'interventionCostCategory', '10', 'Other', 'LMTA', 0, '1.5', '2026-04-15', NULL, 1);