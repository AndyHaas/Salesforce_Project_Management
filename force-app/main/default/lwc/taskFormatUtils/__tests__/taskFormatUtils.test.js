import { formatDate, formatPercent, formatNumber } from "c/taskFormatUtils";

describe("taskFormatUtils", () => {
  test("formatDate returns empty when falsy", () => {
    expect(formatDate(null, "x")).toBe("x");
    expect(formatDate(undefined, "x")).toBe("x");
  });

  test("formatDate returns raw value when not parseable as date", () => {
    expect(formatDate("not-a-date")).toBe("not-a-date");
  });

  test("formatPercent formats number", () => {
    expect(formatPercent(12.5)).toBe("12.50%");
    expect(formatPercent("", "-")).toBe("-");
  });

  test("formatNumber trims integers and fixes decimals", () => {
    expect(formatNumber(3)).toBe("3");
    expect(formatNumber(3.456)).toBe("3.46");
  });
});
