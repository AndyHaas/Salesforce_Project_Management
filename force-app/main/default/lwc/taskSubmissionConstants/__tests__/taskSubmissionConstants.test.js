import {
  EM_DASH,
  PM_SUBMITS_FOR_CLIENT_APPROVAL,
  PM_SUBMITS_FOR_CLIENT_REVIEW,
  CLIENT_APPROVES_COMPLETION,
  CLIENT_REJECTS_COMPLETION,
  SUBMIT_CLIENT_COMPLETION_STATUSES
} from "c/taskSubmissionConstants";

describe("taskSubmissionConstants", () => {
  test("EM_DASH is a single em dash character", () => {
    expect(EM_DASH).toBe("\u2014");
    expect(EM_DASH.length).toBe(1);
  });

  test("PM submit labels match org picklist API values", () => {
    expect(PM_SUBMITS_FOR_CLIENT_APPROVAL).toBe(
      "Project Manager Submits for Client Approval"
    );
    expect(PM_SUBMITS_FOR_CLIENT_REVIEW).toBe(
      "Project Manager Submits for Client Review"
    );
  });

  test("SUBMIT_CLIENT_COMPLETION_STATUSES lists PM submit and client outcomes", () => {
    expect(SUBMIT_CLIENT_COMPLETION_STATUSES).toEqual([
      PM_SUBMITS_FOR_CLIENT_REVIEW,
      CLIENT_APPROVES_COMPLETION,
      CLIENT_REJECTS_COMPLETION
    ]);
  });
});
