import {
  extractRecordIdFromPageReference,
  relatedIdsFromRecordAndObject
} from "../salesforceMessagingUtils";

describe("salesforceMessagingUtils", () => {
  test("extractRecordIdFromPageReference returns undefined when missing", () => {
    expect(extractRecordIdFromPageReference(undefined)).toBeUndefined();
    expect(extractRecordIdFromPageReference(null)).toBeUndefined();
  });

  test("extractRecordIdFromPageReference prefers state over attributes", () => {
    expect(
      extractRecordIdFromPageReference({
        state: { recordId: "stateId" },
        attributes: { recordId: "attrId" }
      })
    ).toBe("stateId");
  });

  test("extractRecordIdFromPageReference falls back to attributes", () => {
    expect(
      extractRecordIdFromPageReference({
        attributes: { recordId: "attrOnly" }
      })
    ).toBe("attrOnly");
  });

  test("relatedIdsFromRecordAndObject maps supported objects", () => {
    expect(relatedIdsFromRecordAndObject("a1", "Account")).toEqual({
      relatedAccountId: "a1"
    });
    expect(relatedIdsFromRecordAndObject("p1", "Project__c")).toEqual({
      relatedProjectId: "p1"
    });
    expect(relatedIdsFromRecordAndObject("t1", "Project_Task__c")).toEqual({
      relatedTaskId: "t1"
    });
  });

  test("relatedIdsFromRecordAndObject returns empty for unknown or missing", () => {
    expect(relatedIdsFromRecordAndObject("", "Account")).toEqual({});
    expect(relatedIdsFromRecordAndObject("x", undefined)).toEqual({});
    expect(relatedIdsFromRecordAndObject("x", "Contact")).toEqual({});
  });
});
