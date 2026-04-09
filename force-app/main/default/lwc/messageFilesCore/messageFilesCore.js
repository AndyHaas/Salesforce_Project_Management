import getFilePreviewUrl from "@salesforce/apex/PortalTaskController.getFilePreviewUrl";

export { openShepherdDownloadInNewTab } from "c/experiencePathUtils";

/**
 * Core entry point for portal file preview in messaging / c-file-manager flows:
 * ContentDistribution view URL from {@link PortalTaskController.getFilePreviewUrl}, plus
 * {@link openShepherdDownloadInNewTab} re-exported for error fallback (single import surface).
 *
 * @param {string} contentVersionId Salesforce ContentVersion Id
 * @returns {Promise<string>} Distribution public URL for iframe / new tab
 */
export async function getMessageFilePreviewUrl(contentVersionId) {
  const id = contentVersionId != null ? String(contentVersionId).trim() : "";
  if (!id) {
    return Promise.reject(new Error("Content Version ID is required"));
  }
  return getFilePreviewUrl({ contentVersionId: id });
}
