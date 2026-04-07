import {
  filterAccountPicklistOptions,
  buildAccountFilterPayload
} from "../accountFilterUtils";

const accounts = [
  { label: "Acme Corp", value: "001AAA" },
  { label: "Beta LLC", value: "001BBB" },
  { label: "Acme Subsidiary", value: "001CCC" }
];

describe("accountFilterUtils", () => {
  test("filterAccountPicklistOptions excludes selected", () => {
    expect(
      filterAccountPicklistOptions(accounts, ["001AAA"], "")
    ).toEqual([
      { label: "Beta LLC", value: "001BBB" },
      { label: "Acme Subsidiary", value: "001CCC" }
    ]);
  });

  test("filterAccountPicklistOptions filters by search term case-insensitively", () => {
    expect(
      filterAccountPicklistOptions(accounts, [], "acme")
    ).toEqual([
      { label: "Acme Corp", value: "001AAA" },
      { label: "Acme Subsidiary", value: "001CCC" }
    ]);
  });

  test("filterAccountPicklistOptions combines search and selection exclusion", () => {
    expect(
      filterAccountPicklistOptions(accounts, ["001AAA"], "acme")
    ).toEqual([{ label: "Acme Subsidiary", value: "001CCC" }]);
  });

  test("filterAccountPicklistOptions handles empty inputs", () => {
    expect(filterAccountPicklistOptions(null, [], "")).toEqual([]);
    expect(filterAccountPicklistOptions(accounts, null, "   ")).toEqual(accounts);
  });

  test("buildAccountFilterPayload shapes accountId for LMS compatibility", () => {
    expect(buildAccountFilterPayload([])).toEqual({
      accountIds: [],
      accountId: ""
    });
    expect(buildAccountFilterPayload(["001x"])).toEqual({
      accountIds: ["001x"],
      accountId: "001x"
    });
    expect(buildAccountFilterPayload(["001x", "001y"])).toEqual({
      accountIds: ["001x", "001y"],
      accountId: null
    });
  });
});
