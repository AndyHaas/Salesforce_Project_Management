import {
  API_VERSION,
  getVersionLabel,
  getWelcomeLabel,
  ensureSitePath,
  shepherdDownloadPath,
  openShepherdDownloadInNewTab,
  splitFileNameForPortalRow,
  EM_DASH,
  SUBMIT_CLIENT_COMPLETION_STATUSES,
  getFieldType,
  formatDate,
  formatDateTime,
  formatTime,
  formatPhone,
  formatBoolean,
  formatPercent,
  formatCurrency,
  formatNumber,
  stripHtml,
  formatFieldValue
} from "c/portalCommon";

describe("portalCommon", () => {
  test("getVersionLabel includes API_VERSION", () => {
    expect(getVersionLabel()).toContain(
      `${API_VERSION.major}.${API_VERSION.minor}.${API_VERSION.patch}`
    );
    expect(getVersionLabel("v")).toMatch(/^v/);
  });

  test("getWelcomeLabel", () => {
    expect(getWelcomeLabel("")).toBe("Welcome");
    expect(getWelcomeLabel("  ")).toBe("Welcome");
    expect(getWelcomeLabel("Jane")).toBe("Welcome Jane");
  });

  test("re-exports core path, shepherd, file-name, and submission helpers", () => {
    expect(ensureSitePath("tasks", { currentPathname: "/s/home" })).toBe("/s/tasks");
    expect(shepherdDownloadPath("069X", "")).toContain("069X");
    expect(splitFileNameForPortalRow("a.b").fileExtension).toBe("b");
    expect(EM_DASH).toBe("\u2014");
    expect(SUBMIT_CLIENT_COMPLETION_STATUSES.length).toBe(3);
    const openSpy = jest.spyOn(window, "open").mockImplementation(() => null);
    delete window.location;
    window.location = { pathname: "/s/home" };
    openShepherdDownloadInNewTab("069Z", null);
    expect(openSpy).toHaveBeenCalled();
    openSpy.mockRestore();
  });

  test("getFieldType maps Salesforce and passthrough types", () => {
    expect(getFieldType(null)).toBe("text");
    expect(getFieldType("PERCENT")).toBe("percent");
    expect(getFieldType("TEXTAREA", { isHtmlFormatted: true })).toBe(
      "richtext"
    );
    expect(getFieldType("TEXTAREA")).toBe("textarea");
    expect(getFieldType("currency")).toBe("currency");
  });

  test("formatDate", () => {
    expect(formatDate(null, "—")).toBe("—");
    expect(formatDate(new Date(2024, 0, 5))).toBe("2024-01-05");
  });

  test("formatDateTime includes time", () => {
    const s = formatDateTime(new Date(2024, 0, 5, 8, 7));
    expect(s).toContain("2024-01-05");
    expect(s).toContain("08:07");
  });

  test("formatTime from ms since midnight", () => {
    expect(formatTime(3661000)).toBe("01:01:01");
  });

  test("formatPhone", () => {
    expect(formatPhone("")).toBe("");
    expect(formatPhone("8174056960")).toBe("(817) 405-6960");
    expect(formatPhone("18174056960")).toBe("+1 (817) 405-6960");
  });

  test("formatBoolean", () => {
    expect(formatBoolean(true)).toBe("Yes");
    expect(formatBoolean("true")).toBe("Yes");
    expect(formatBoolean(false)).toBe("No");
  });

  test("formatPercent and formatCurrency and formatNumber", () => {
    expect(formatPercent(12.5)).toBe("12.50%");
    expect(formatCurrency(10.5)).toContain("10.50");
    expect(formatNumber(3)).toBe("3");
    expect(formatNumber(3.4)).toBe("3.40");
  });

  test("stripHtml extracts text", () => {
    expect(stripHtml("<p>Hi <b>there</b></p>")).toBe("Hi there");
    expect(stripHtml(null)).toBe(null);
  });

  test("formatFieldValue dispatches by type", () => {
    expect(formatFieldValue("", "date", { emptyValue: "x" })).toBe("x");
    expect(formatFieldValue(true, "boolean")).toBe("Yes");
    expect(
      formatFieldValue("a".repeat(120), "textarea", { textareaMaxLength: 5 })
    ).toBe("aaaaa...");
    expect(formatFieldValue("<i>x</i>", "richtext")).toBe("x");
  });
});
