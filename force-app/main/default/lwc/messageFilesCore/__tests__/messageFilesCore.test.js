import { getMessageFilePreviewUrl, openShepherdDownloadInNewTab } from "c/messageFilesCore";
import getFilePreviewUrl from "@salesforce/apex/PortalTaskController.getFilePreviewUrl";

describe("messageFilesCore", () => {
  beforeEach(() => {
    getFilePreviewUrl.mockReset();
  });

  test("getMessageFilePreviewUrl calls PortalTaskController with trimmed id", async () => {
    getFilePreviewUrl.mockResolvedValue("https://example.com/preview");
    await expect(getMessageFilePreviewUrl(" 068xxx ")).resolves.toBe("https://example.com/preview");
    expect(getFilePreviewUrl).toHaveBeenCalledWith({ contentVersionId: "068xxx" });
  });

  test("getMessageFilePreviewUrl rejects blank id", async () => {
    await expect(getMessageFilePreviewUrl("")).rejects.toThrow("Content Version ID is required");
    await expect(getMessageFilePreviewUrl(null)).rejects.toThrow("Content Version ID is required");
    expect(getFilePreviewUrl).not.toHaveBeenCalled();
  });

  test("openShepherdDownloadInNewTab re-export opens window", () => {
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
});
