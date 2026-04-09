import {
  ensureSitePath,
  shepherdDownloadPath,
  openShepherdDownloadInNewTab,
  splitFileNameForPortalRow
} from "c/experiencePathUtils";

describe("experiencePathUtils", () => {
  describe("ensureSitePath", () => {
    test("returns slash for falsy path", () => {
      expect(ensureSitePath("")).toBe("/");
      expect(ensureSitePath(null)).toBe("/");
      expect(ensureSitePath(undefined)).toBe("/");
    });

    test("normalizes leading slash", () => {
      expect(ensureSitePath("tasks")).toBe("/tasks");
      expect(ensureSitePath("/tasks")).toBe("/tasks");
    });

    test("prepends /s when on Experience path and target lacks /s", () => {
      expect(ensureSitePath("project/abc", { currentPathname: "/s/home" })).toBe(
        "/s/project/abc"
      );
      expect(ensureSitePath("/project/abc", { currentPathname: "/s/" })).toBe(
        "/s/project/abc"
      );
    });

    test("preserves path prefix before /s/ (e.g. partner sites)", () => {
      expect(
        ensureSitePath("/sfc/servlet.shepherd/document/download/069xx", {
          currentPathname: "/partners/s/home"
        })
      ).toBe("/partners/s/sfc/servlet.shepherd/document/download/069xx");
    });

    test("does not double /s when already present", () => {
      expect(ensureSitePath("/s/tasks", { currentPathname: "/s/home" })).toBe("/s/tasks");
      expect(ensureSitePath("/s/tasks", { currentPathname: "/partners/s/home" })).toBe(
        "/s/tasks"
      );
    });

    test("leaves path unchanged when not on Experience /s context", () => {
      expect(ensureSitePath("tasks", { currentPathname: "/lightning/page/home" })).toBe(
        "/tasks"
      );
    });
  });

  describe("shepherdDownloadPath", () => {
    test("prefers document over version", () => {
      expect(shepherdDownloadPath("", "")).toBe("");
      expect(shepherdDownloadPath("069000000000001", "")).toBe(
        "/sfc/servlet.shepherd/document/download/069000000000001"
      );
      expect(shepherdDownloadPath("", "068000000000001")).toBe(
        "/sfc/servlet.shepherd/version/download/068000000000001"
      );
      expect(shepherdDownloadPath("069AAA", "068BBB")).toBe(
        "/sfc/servlet.shepherd/document/download/069AAA"
      );
    });
  });

  test("openShepherdDownloadInNewTab uses ensureSitePath and window.open", () => {
    const openSpy = jest.spyOn(window, "open").mockImplementation(() => null);
    delete window.location;
    window.location = { pathname: "/partners/s/home" };
    openShepherdDownloadInNewTab("069XX", null);
    expect(openSpy).toHaveBeenCalledWith(
      "/partners/s/sfc/servlet.shepherd/document/download/069XX",
      "_blank",
      "noopener,noreferrer"
    );
    openSpy.mockRestore();
  });

  test("splitFileNameForPortalRow matches ContentDocument title + extension shape", () => {
    expect(splitFileNameForPortalRow("Quarterly Report.pdf")).toEqual({
      title: "Quarterly Report",
      fileExtension: "pdf"
    });
    expect(splitFileNameForPortalRow("noextension")).toEqual({
      title: "noextension",
      fileExtension: ""
    });
    expect(splitFileNameForPortalRow("")).toEqual({
      title: "Attachment",
      fileExtension: ""
    });
    expect(splitFileNameForPortalRow("archive.tar.gz")).toEqual({
      title: "archive.tar",
      fileExtension: "gz"
    });
  });
});
