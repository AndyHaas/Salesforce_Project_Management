import { getFileIconName, formatFileSize } from "../portalFileAttachmentsUtils";

describe("portalFileAttachmentsUtils", () => {
  test("getFileIconName maps known extensions", () => {
    expect(getFileIconName("pdf")).toBe("doctype:pdf");
    expect(getFileIconName("PDF")).toBe("doctype:pdf");
    expect(getFileIconName(".xlsx")).toBe("doctype:excel");
  });

  test("getFileIconName defaults for unknown", () => {
    expect(getFileIconName("zzz")).toBe("doctype:attachment");
    expect(getFileIconName("")).toBe("doctype:attachment");
  });

  test("formatFileSize", () => {
    expect(formatFileSize(null, "—")).toBe("—");
    expect(formatFileSize(0)).toBe("0 B");
    expect(formatFileSize(500)).toBe("500 B");
    expect(formatFileSize(2048)).toBe("2.0 KB");
    expect(formatFileSize(1536000)).toMatch(/MB/);
  });
});
