
# table_element_order=ELEMENT_ORDER
# Map column names in the database tables to the order of elements in the XML output
# which is defined in the XSD as <xsd:sequence>

ELEMENT_ORDER = {
    "submission": ["SchemaVersion", "agreementHolderName", "sysComment"],
    "sys_action": [
        "socialInsuranceNumber", "clientID", "agreementNumber",
        "actionPlanStartDate", "interventionStartDate", "interventionCode",
        "actionPlanID", "interventionID", "systemAction", "sysComment",
    ],
    "client": [
        "clientID", "socialInsuranceNumber", "lastName", "firstName",
        "dateOfBirth", "emailAddress", "gender", "maritalStatus",
        "numberOfDependantChildren", "languageSpoken", "disability",
        "indigenousIdentity", "immigrant", "immigrationYear", "visibleMinority",
        "streetAddress", "municipality", "province", "postalZIPCode",
        "contactPhoneNumber", "addressSysComment", "sysComment",
    ],
    "action_plan": [
        "actionPlanID", "agreementNumber", "actionPlanFundingSource",
        "educationLevel", "educationLevelComment", "provincialOfficeCode",
        "actionPlanPreviousEmployment", "actionPlanPreviousEmployerName",
        "actionPlanPreviousMultipleEmployment", "actionPlanPreviousEmploymentNOC",
        "actionPlanPreviousEmploymentNOCVersion", "actionPlanPreviousEmploymentNAICS",
        "actionPlanPreviousEmploymentNAICSVersion", "actionPlanPreviousEmploymentDate",
        "actionPlanPreviousEmploymentPayRate", "actionPlanPreviousEmploymentHours",
        "actionPlanTargetNAICS", "actionPlanTargetNAICSVersion",
        "actionPlanPrecariousEmployment", "actionPlanStartDate", "actionPlanEndDate",
        "actionPlanResultCode", "actionPlanResultDate", "sysComment",
    ],
    "followup": [
        "actionPlanFollowUpID", "actionPlanFollowUpDate",
        "actionPlanFollowUpResultCode", "actionPlanFollowUpResultDate",
        "actionPlanFollowUpEmployerName", "actionPlanFollowUpMultipleEmployment",
        "actionPlanFollowUpNOC", "actionPlanFollowUpNOCVersion",
        "actionPlanFollowUpNAICS", "actionPlanFollowUpNAICSVersion",
        "actionPlanFollowUpEmploymentPayRate", "actionPlanFollowUpEmploymentHours",
        "sysComment",
    ],
    "intervention": [
        "interventionID", "interventionTitle", "interventionCode",
        "interventionStartDate", "interventionEndDate", "interventionOutcome",
        "interventionRelatedNOC", "interventionRelatedNOCVersion",
        "interventionLanguageOfService", "interventionEssentialSkills",
        "interventionCredential", "sysComment",
    ],
    "support": [
        "interventionCost", "interventionCostCategory",
        "interventionCostCategoryComment",
    ],
}