/**
 * @description Picklist-aligned strings for `Project_Task__c.Submission_Status__c` and UI placeholders.
 * Keep in sync with `PortalTaskController.assignPortalActionFields` and the Submission_Status global value set.
 */

/** Unicode em dash — used for empty state display in portal/task UI. */
export const EM_DASH = "\u2014";

/** PM workflow: task moves from Backlog toward client approval. */
export const PM_SUBMITS_FOR_CLIENT_APPROVAL =
  "Project Manager Submits for Client Approval";

/** PM workflow: task in review, submitted for client completion sign-off. */
export const PM_SUBMITS_FOR_CLIENT_REVIEW =
  "Project Manager Submits for Client Review";

/** Client accepts completed work (terminal for this branch). */
export const CLIENT_APPROVES_COMPLETION = "Client Approves Completion";

/** Client sends task back to In Progress from completion review. */
export const CLIENT_REJECTS_COMPLETION = "Client Rejects Completion";

/**
 * Submission statuses for the PM submit → client completion review/decision flow.
 * @type {readonly string[]}
 */
export const SUBMIT_CLIENT_COMPLETION_STATUSES = [
  PM_SUBMITS_FOR_CLIENT_REVIEW,
  CLIENT_APPROVES_COMPLETION,
  CLIENT_REJECTS_COMPLETION
];
