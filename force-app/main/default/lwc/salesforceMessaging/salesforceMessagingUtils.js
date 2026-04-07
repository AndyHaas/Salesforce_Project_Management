/**
 * Pure helpers for resolving record context from Lightning page reference.
 * Used by salesforceMessaging wrapper for testability.
 *
 * @param {object} [pageRef] CurrentPageReference wire value
 * @returns {string|undefined} recordId from state or attributes
 */
export function extractRecordIdFromPageReference(pageRef) {
  if (!pageRef) {
    return undefined;
  }
  const { attributes = {}, state = {} } = pageRef;
  return state.recordId || attributes.recordId;
}

/**
 * Maps record page object type to related context ids for messaging.
 *
 * @param {string} recordId Salesforce record Id
 * @param {string} [objectApiName] attributes.objectApiName from page reference
 * @returns {{ relatedAccountId?: string, relatedProjectId?: string, relatedTaskId?: string }}
 */
export function relatedIdsFromRecordAndObject(recordId, objectApiName) {
  if (!recordId || !objectApiName) {
    return {};
  }
  if (objectApiName === "Account") {
    return { relatedAccountId: recordId };
  }
  if (objectApiName === "Project__c") {
    return { relatedProjectId: recordId };
  }
  if (objectApiName === "Project_Task__c") {
    return { relatedTaskId: recordId };
  }
  return {};
}
