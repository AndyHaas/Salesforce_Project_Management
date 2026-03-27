import {
  STANDARD_ACCOUNT_KEY_PREFIX,
  ACCOUNT_SEL_THIS,
  ACCOUNT_SEL_ALL,
  salesforceIdsEqual
} from "../groupedTaskListUtils";

describe("groupedTaskListUtils", () => {
  test("constants", () => {
    expect(STANDARD_ACCOUNT_KEY_PREFIX).toBe("001");
    expect(ACCOUNT_SEL_THIS).toBe("__THIS_ACCOUNT__");
    expect(ACCOUNT_SEL_ALL).toBe("__ALL_ACCOUNTS__");
  });

  test("salesforceIdsEqual", () => {
    expect(salesforceIdsEqual(null, "001xx")).toBe(false);
    expect(salesforceIdsEqual("001000000000000AAA", "001000000000000")).toBe(
      true
    );
    expect(salesforceIdsEqual("abc", "def")).toBe(false);
  });
});
