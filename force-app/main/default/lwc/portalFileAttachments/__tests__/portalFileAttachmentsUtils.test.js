import { getFileIconName } from "../portalFileAttachmentsUtils";

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
});
