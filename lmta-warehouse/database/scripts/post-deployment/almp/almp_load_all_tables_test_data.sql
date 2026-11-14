-- Write your own SQL object definition here, and it'll be included in your package.
/* =====================================================================
   ALMP 1.5 SYNTHETIC SEED DATA
   Target: Microsoft Fabric Warehouse
   Submission ID: 1001

   IMPORTANT
   - All people, addresses, employers and identifiers are fictional.
   - Values are selected from, or formatted according to,
     ALMPTypes.xsd.
   - The data exercises all seven almp tables.
   - Run only once unless you first remove submission_id = 1001.
   ===================================================================== */


/* =====================================================================
   OPTIONAL CLEANUP
   Delete children before parents.

   Uncomment when you need to reload this test submission.
   ===================================================================== */

/*
DELETE FROM almp.intervention_support
WHERE submission_id = 1001;

DELETE FROM almp.action_plan_followup
WHERE submission_id = 1001;

DELETE FROM almp.intervention
WHERE submission_id = 1001;

DELETE FROM almp.action_plan
WHERE submission_id = 1001;

DELETE FROM almp.client
WHERE submission_id = 1001;

DELETE FROM almp.sys_action
WHERE submission_id = 1001;

DELETE FROM almp.submission
WHERE submission_id = 1001;
*/


/* =====================================================================
   1. SUBMISSION
   ===================================================================== */

INSERT INTO almp.submission
(
    submission_id,
    SchemaVersion,
    agreementHolderName,
    sysComment
)
VALUES
(
    1001,
    '1.5',
    'Government of Saskatchewan',
    'Synthetic ALMP 1.5 test submission'
);

GO
/* =====================================================================
   2. CLIENTS

   Code selections:
   gender:
       1 = Male
       2 = Female
       3 = Unspecified
       9 = Prefer not to report

   maritalStatus:
       1 = Married or equivalent
       2 = Single

   languageSpoken:
       2 = English only
       6 = English and French

   disability:
       0/1 are accepted XML boolean lexical values
       2 = No is also an LMTA-specific enumerated value

   indigenousIdentity / immigrant / visibleMinority:
       1 = Yes
       2 = No

   province:
       8 = Saskatchewan
   ===================================================================== */

INSERT INTO almp.client
(
    submission_id,
    client_id,
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
VALUES
(
    1001,
    101,
    'SYN-CLIENT-001',
    '200000008',
    'Prairie',
    'Alex',
    '1990-04-15',
    'alex.prairie@example.test',
    1,                          -- Male
    2,                          -- Single
    0,
    2,                          -- English only
    2,                          -- No disability
    2,                          -- Not Indigenous
    2,                          -- Not an immigrant
    NULL,
    2,                          -- Not a visible minority
    '100 Example Avenue',
    'Regina',
    8,                          -- Saskatchewan
    'S4T0A1',
    '306-555-0101',
    'Synthetic address',
    'Synthetic client one'
),
(
    1001,
    102,
    'SYN-CLIENT-002',
    '300000007',
    'Willow',
    'Jordan',
    '1987-09-22',
    'jordan.willow@example.test',
    2,                          -- Female
    1,                          -- Married or equivalent
    2,
    6,                          -- English and French
    2,                          -- No disability
    2,                          -- Not Indigenous
    1,                          -- Immigrant
    '2015',
    1,                          -- Visible minority
    '200 Sample Street',
    'Saskatoon',
    8,                          -- Saskatchewan
    'S7K0A2',
    '306-555-0102',
    'Synthetic address',
    'Synthetic client two'
),
(
    1001,
    103,
    'SYN-CLIENT-003',
    '100000009',
    'Meadow',
    'Taylor',
    '1998-02-10',
    'taylor.meadow@example.test',
    3,                          -- Unspecified
    2,                          -- Single
    1,
    2,                          -- English only
    2,                          -- No disability
    1,                          -- Indigenous
    2,                          -- Not an immigrant
    NULL,
    2,                          -- Not a visible minority
    '300 Demonstration Road',
    'Moose Jaw',
    8,                          -- Saskatchewan
    'S6H0A3',
    '306-555-0103',
    'Synthetic address',
    'Synthetic client three'
);

GO

/* =====================================================================
   3. ACTION PLANS

   actionPlanFundingSource:
       1 = Steel Tariffs
       2 = Softwood Lumber Tariffs
       3 = Comprehensive Tariffs
       8 = Not Applicable

   educationLevel:
       5  = Secondary school diploma or GED
       8  = College/non-university certificate or diploma
       14 = University degree

   actionPlanPreviousEmployment:
       1 = Unemployed
       2 = Employed
       3 = Self-employed
       6 = Not in labour force
       7 = Work-sharing
      10 = Not Available

   actionPlanPreviousMultipleEmployment:
       1 = Yes
       2 = No

   actionPlanPrecariousEmployment:
       1 = Yes
       2 = No
       9 = Prefer not to report

   actionPlanResultCode:
       1 = Unemployed but available for work
       2 = Employed
       3 = Self-employed
       4 = Returned to school
       5 = Could not be reached
       6 = Not in labour force
       7 = Work-sharing for LMTA
       8 = Starting a new action plan

   Pay rates use digits only because the XSD pattern is \d{4,6}.
   Example: 2450 represents $24.50 if interpreted as cents.
   ===================================================================== */

INSERT INTO almp.action_plan
(
    submission_id,
    client_id,
    action_plan_id,
    actionPlanID,
    agreementNumber,
    actionPlanFundingSource,
    educationLevel,
    educationLevelComment,
    provincialOfficeCode,
    actionPlanPreviousEmployment,
    actionPlanPreviousEmployerName,
    actionPlanPreviousMultipleEmployment,
    actionPlanPreviousEmploymentNOC,
    actionPlanPreviousEmploymentNOCVersion,
    actionPlanPreviousEmploymentNAICS,
    actionPlanPreviousEmploymentNAICSVersion,
    actionPlanPreviousEmploymentDate,
    actionPlanPreviousEmploymentPayRate,
    actionPlanPreviousEmploymentHours,
    actionPlanTargetNAICS,
    actionPlanTargetNAICSVersion,
    actionPlanPrecariousEmployment,
    actionPlanStartDate,
    actionPlanEndDate,
    actionPlanResultCode,
    actionPlanResultDate,
    sysComment
)
VALUES
(
    1001,
    101,
    10001,
    'SYN-AP-001',
    '123456789',
    3,                          -- Comprehensive Tariffs
    8,                          -- College certificate/diploma
    NULL,
    'REGINA',
    2,                          -- Employed
    'Prairie Example Foods',
    2,                          -- No multiple employment
    '64400',
    '2021',
    '445110',
    '2022',
    '2025-01-31',
    '2150',
    '40',
    '541510',
    '2022',
    2,                          -- Not precariously employed
    '2025-02-10',
    '2025-08-31',
    2,                          -- Employed
    '2025-08-31',
    'Completed synthetic action plan'
),
(
    1001,
    102,
    10002,
    'SYN-AP-002',
    '123456789',
    8,                          -- Funding source not applicable
    14,                         -- University degree
    NULL,
    'SASKATOON',
    1,                          -- Unemployed
    NULL,
    2,                          -- No multiple employment
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    '541512',
    '2022',
    2,                          -- Not precariously employed
    '2025-03-01',
    '2025-09-30',
    2,                          -- Employed
    '2025-09-30',
    'Completed synthetic action plan'
),
(
    1001,
    103,
    10003,
    'SYN-AP-003',
    '123456789',
    8,                          -- Funding source not applicable
    5,                          -- Secondary school diploma or GED
    NULL,
    'MOOSEJAW',
    1,                          -- Unemployed
    NULL,
    2,                          -- No multiple employment
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    '624190',
    '2022',
    1,                          -- Precarious employment
    '2025-05-15',
    NULL,
    NULL,
    NULL,
    'Open synthetic action plan'
);

GO
/* =====================================================================
   4. INTERVENTIONS

   LMTA-specific intervention codes:
       111 = Job search assistance
       112 = Counselling/case management
       211 = Occupational skills training
       212 = Short-term training
       213 = Literacy, essential skills, language training and ABE
       214 = Apprenticeship
       221 = Targeted wage subsidies

   interventionOutcome:
       1 = Completed
       2 = In progress
       3 = Incomplete
       4 = Failed to report
       5 = Cancelled
       6 = Rescheduled

   interventionEssentialSkills:
       1 = Yes
       2 = No
       8 = Not Available

   interventionCredential:
       1 = Yes
       2 = No
       8 = Not applicable
       9 = Not Available
   ===================================================================== */

INSERT INTO almp.intervention
(
    submission_id,
    action_plan_id,
    intervention_id,
    interventionID,
    interventionTitle,
    interventionCode,
    interventionStartDate,
    interventionEndDate,
    interventionOutcome,
    interventionRelatedNOC,
    interventionRelatedNOCVersion,
    interventionLanguageOfService,
    interventionEssentialSkills,
    interventionCredential,
    sysComment
)
VALUES
(
    1001,
    10001,
    20001,
    'SYN-INT-001',
    'Occupational Skills Training',
    211,
    '2025-02-15',
    '2025-06-30',
    1,                          -- Completed
    '21232',
    '2021',
    2,                          -- English
    1,                          -- Essential skills included
    1,                          -- Credential obtained
    'Synthetic training intervention'
),
(
    1001,
    10001,
    20002,
    'SYN-INT-002',
    'Job Search Assistance',
    111,
    '2025-07-01',
    '2025-08-15',
    1,                          -- Completed
    '21232',
    '2021',
    2,                          -- English
    2,                          -- No essential-skills component
    8,                          -- Credential not applicable
    'Synthetic employment assistance'
),
(
    1001,
    10002,
    20003,
    'SYN-INT-003',
    'Short-Term Technical Training',
    212,
    '2025-03-10',
    '2025-08-31',
    1,                          -- Completed
    '22221',
    '2021',
    2,                          -- English
    1,                          -- Essential skills included
    1,                          -- Credential obtained
    'Synthetic technical training'
),
(
    1001,
    10003,
    20004,
    'SYN-INT-004',
    'Counselling and Case Management',
    112,
    '2025-05-20',
    NULL,
    NULL,
    NULL,
    NULL,
    2,                          -- English
    NULL,
    NULL,
    'Open synthetic intervention'
);

GO

/* =====================================================================
   5. INTERVENTION SUPPORT

   interventionCostCategory:
       0  = Not applicable
       1  = Transportation
       2  = Dependent support
       3  = Accommodations
       4  = Disability support
       5  = Mental health support
       6  = Supplies support
       7  = Mobility/relocation
       8  = Tuition fees
       10 = Other
   ===================================================================== */

INSERT INTO almp.intervention_support
(
    submission_id,
    intervention_id,
    intervention_support_id,
    interventionCost,
    interventionCostCategory,
    interventionCostCategoryComment
)
VALUES
(
    1001,
    20001,
    30001,
    4500,
    8,                          -- Tuition fees
    'Synthetic tuition cost'
),
(
    1001,
    20001,
    30002,
    600,
    1,                          -- Transportation
    'Synthetic transportation cost'
),
(
    1001,
    20003,
    30003,
    750,
    6,                          -- Supplies support
    'Synthetic training supplies'
),
(
    1001,
    20004,
    30004,
    300,
    1,                          -- Transportation
    'Synthetic local transportation'
);

GO

/* =====================================================================
   6. ACTION PLAN FOLLOW-UPS

   actionPlanFollowUpResultCode:
       1 = Unemployed but available for work
       2 = Employed
       3 = Self-employed
       4 = Returned to school
       5 = Participant could not be reached
       6 = Not in labour force
       7 = Work-sharing
       8 = Starting a new action plan

   actionPlanFollowUpMultipleEmployment:
       1 = Yes
       2 = No
   ===================================================================== */

INSERT INTO almp.action_plan_followup
(
    submission_id,
    action_plan_id,
    action_plan_followup_id,
    actionPlanFollowUpID,
    actionPlanFollowUpDate,
    actionPlanFollowUpResultCode,
    actionPlanFollowUpResultDate,
    actionPlanFollowUpEmployerName,
    actionPlanFollowUpMultipleEmployment,
    actionPlanFollowUpNOC,
    actionPlanFollowUpNOCVersion,
    actionPlanFollowUpNAICS,
    actionPlanFollowUpNAICSVersion,
    actionPlanFollowUpEmploymentPayRate,
    actionPlanFollowUpEmploymentHours,
    sysComment
)
VALUES
(
    1001,
    10001,
    40001,
    'SYN-FU-001',
    '2025-09-15',
    2,                          -- Employed
    '2025-09-15',
    'Example Technology Limited',
    2,                          -- No multiple employment
    '21232',
    '2021',
    '541510',
    '2022',
    '3050',
    '40',
    'Synthetic completed-plan follow-up'
),
(
    1001,
    10001,
    40002,
    'SYN-FU-002',
    '2025-10-31',
    2,                          -- Employed
    '2025-10-31',
    'Example Technology Limited',
    2,                          -- No multiple employment
    '21232',
    '2021',
    '541510',
    '2022',
    '3200',
    '40',
    'Synthetic second follow-up'
),
(
    1001,
    10002,
    40003,
    'SYN-FU-003',
    '2025-10-15',
    2,                          -- Employed
    '2025-10-15',
    'Prairie Systems Incorporated',
    2,                          -- No multiple employment
    '22221',
    '2021',
    '541512',
    '2022',
    '2875',
    '37.5',
    'Synthetic employment follow-up'
);

GO


/* =====================================================================
   7. SYSTEM ACTION

   systemAction:
       1 = Expire

   This row is included only to exercise the sys_action table.
   It represents a synthetic expiry instruction and should not be
   treated as part of the normal active participant scenario.

   The XSD systemType requires a choice between SIN and clientID.
   Therefore only clientID is populated here.
   ===================================================================== */

INSERT INTO almp.sys_action
(
    submission_id,
    sys_action_id,
    socialInsuranceNumber,
    clientID,
    agreementNumber,
    actionPlanStartDate,
    interventionStartDate,
    interventionCode,
    actionPlanID,
    interventionID,
    systemAction,
    sysComment
)
VALUES
(
    1001,
    50001,
    NULL,
    'SYN-EXPIRED-001',
    '123456789',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    1,                          -- Expire
    'Synthetic system-action test row'
);

GO

/* =====================================================================
   8. VERIFICATION
   ===================================================================== */

SELECT
    'submission' AS table_name,
    COUNT(*) AS row_count
FROM almp.submission
WHERE submission_id = 1001

UNION ALL

SELECT
    'client',
    COUNT(*)
FROM almp.client
WHERE submission_id = 1001

UNION ALL

SELECT
    'action_plan',
    COUNT(*)
FROM almp.action_plan
WHERE submission_id = 1001

UNION ALL

SELECT
    'action_plan_followup',
    COUNT(*)
FROM almp.action_plan_followup
WHERE submission_id = 1001

UNION ALL

SELECT
    'intervention',
    COUNT(*)
FROM almp.intervention
WHERE submission_id = 1001

UNION ALL

SELECT
    'intervention_support',
    COUNT(*)
FROM almp.intervention_support
WHERE submission_id = 1001

UNION ALL

SELECT
    'sys_action',
    COUNT(*)
FROM almp.sys_action
WHERE submission_id = 1001;