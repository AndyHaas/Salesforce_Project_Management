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

/** Developer submits in-review work for PM approval (In Review path). */
export const DEV_SUBMITS_PM =
  "Developer Submits for Approval to Project Manager";

/** PM sends task back to In Progress from review. */
export const PM_REJECTS_IN_PROGRESS =
  "Project Manager Rejects In Progress Task";

/** PM accepts developer work; task stays in review pipeline. */
export const PM_ACCEPTS_IN_PROGRESS =
  "Project Manager Accepts In Progress Task";

/**
 * Submission statuses for the PM submit → client completion review/decision flow.
 * @type {readonly string[]}
 */
export const SUBMIT_CLIENT_COMPLETION_STATUSES = [
  PM_SUBMITS_FOR_CLIENT_REVIEW,
  CLIENT_APPROVES_COMPLETION,
  CLIENT_REJECTS_COMPLETION
];

/**
 * Statuses where the task may be submitted for client completion approval
 * (portal / Flexipage gating; aligns with add-on `portalCommon` / `portalTaskDetail`).
 * @type {ReadonlySet<string>}
 */
export const SUBMIT_CLIENT_COMPLETION_GATE_STATUSES = Object.freeze(
  new Set([DEV_SUBMITS_PM, PM_REJECTS_IN_PROGRESS, PM_ACCEPTS_IN_PROGRESS])
);
