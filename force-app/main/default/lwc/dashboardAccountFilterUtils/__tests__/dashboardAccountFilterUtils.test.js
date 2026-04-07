import {
  accountIdsFromFilterMessage,
  resolveEffectiveAccountIds
} from "c/dashboardAccountFilterUtils";

describe("dashboardAccountFilterUtils", () => {
  test("accountIdsFromFilterMessage returns undefined when missing or no keys", () => {
    expect(accountIdsFromFilterMessage(undefined)).toBeUndefined();
    expect(accountIdsFromFilterMessage(null)).toBeUndefined();
    expect(accountIdsFromFilterMessage({})).toBeUndefined();
  });

  test("accountIdsFromFilterMessage prefers accountIds array", () => {
    expect(accountIdsFromFilterMessage({ accountIds: ["001A", "001B"] })).toEqual([
      "001A",
      "001B"
    ]);
    expect(accountIdsFromFilterMessage({ accountIds: "bad" })).toEqual([]);
  });

  test("accountIdsFromFilterMessage uses accountId when accountIds absent", () => {
    expect(accountIdsFromFilterMessage({ accountId: "001X" })).toEqual(["001X"]);
    expect(accountIdsFromFilterMessage({ accountId: "" })).toEqual([]);
  });

  test("resolveEffectiveAccountIds prefers filtered list", () => {
    expect(resolveEffectiveAccountIds(["001A"], "001B")).toEqual(["001A"]);
    expect(resolveEffectiveAccountIds([], "001B")).toEqual(["001B"]);
    expect(resolveEffectiveAccountIds([], undefined)).toEqual([]);
    expect(resolveEffectiveAccountIds(null, "001C")).toEqual(["001C"]);
  });
});
