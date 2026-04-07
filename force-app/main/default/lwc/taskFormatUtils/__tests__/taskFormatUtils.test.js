import { formatDate, formatPercent, formatNumber } from "c/taskFormatUtils";

describe("taskFormatUtils", () => {
  test("formatDate returns empty when falsy", () => {
    expect(formatDate(null, "x")).toBe("x");
    expect(formatDate(undefined, "x")).toBe("x");
  });

  test("formatDate returns raw value when not parseable as date", () => {
    expect(formatDate("not-a-date")).toBe("not-a-date");
  });

  test("formatDate returns YYYY-MM-DD for valid local Date", () => {
    expect(formatDate(new Date(2024, 5, 7))).toBe("2024-06-07");
  });

  test("formatPercent formats number", () => {
    expect(formatPercent(12.5)).toBe("12.50%");
    expect(formatPercent("", "-")).toBe("-");
  });

  test("formatPercent returns emptyValue when value is not a finite number", () => {
    expect(formatPercent("x", "-")).toBe("-");
    expect(formatPercent(NaN, "n/a")).toBe("n/a");
  });

  test("formatNumber trims integers and fixes decimals", () => {
    expect(formatNumber(3)).toBe("3");
    expect(formatNumber(3.456)).toBe("3.46");
  });

  test("formatNumber returns emptyValue when value is empty or not a finite number", () => {
    expect(formatNumber(undefined, "—")).toBe("—");
    expect(formatNumber(null, "—")).toBe("—");
    expect(formatNumber("bad", "—")).toBe("—");
    expect(formatNumber(NaN, "—")).toBe("—");
  });
});
