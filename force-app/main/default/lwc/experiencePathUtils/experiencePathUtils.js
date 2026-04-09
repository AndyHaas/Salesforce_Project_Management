/**
 * @description Core helpers for Experience Cloud URL paths and Salesforce Files shepherd downloads.
 * Canonical home for logic previously duplicated between this module and `portalCommon`.
 */

/**
 * Ensures Experience Cloud URLs include the /s prefix when needed.
 * Handles bare `/s/...` sites and prefixed paths such as `/partners/s/...`.
 *
 * @param {string} path target path (with or without leading slash)
 * @param {{ currentPathname?: string }} options optional current pathname for context
 * @returns {string} normalized path with required prefix
 */
export function ensureSitePath(path, { currentPathname = "" } = {}) {
  if (!path) {
    return "/";
  }

  const normalized = path.startsWith("/") ? path : `/${path}`;

  if (normalized.startsWith("/s/")) {
    return normalized;
  }

  const siteSegmentIdx = currentPathname.indexOf("/s/");
  if (siteSegmentIdx >= 0) {
    const prefix = currentPathname.substring(0, siteSegmentIdx);
    return `${prefix}/s${normalized}`;
  }

  return normalized;
}

/**
 * Core-relative Salesforce Files shepherd path (before {@link #ensureSitePath}).
 * Used for “open in new tab” fallback when ContentDistribution preview is unavailable.
 *
 * @param {string} [contentDocumentId]
 * @param {string} [contentVersionId]
 * @returns {string} path like `/sfc/servlet.shepherd/...` or ""
 */
export function shepherdDownloadPath(contentDocumentId, contentVersionId) {
  const doc = contentDocumentId != null ? String(contentDocumentId).trim() : "";
  const ver = contentVersionId != null ? String(contentVersionId).trim() : "";
  if (doc) {
    return `/sfc/servlet.shepherd/document/download/${doc}`;
  }
  if (ver) {
    return `/sfc/servlet.shepherd/version/download/${ver}`;
  }
  return "";
}

/**
 * Opens a shepherd file URL in a new browser tab with Experience Cloud site prefixing.
 *
 * @param {string} [contentDocumentId]
 * @param {string} [contentVersionId]
 */
export function openShepherdDownloadInNewTab(contentDocumentId, contentVersionId) {
  if (typeof window === "undefined") {
    return;
  }
  const path = shepherdDownloadPath(contentDocumentId, contentVersionId);
  if (!path) {
    return;
  }
  const url = ensureSitePath(path, { currentPathname: window.location.pathname || "" });
  window.open(url, "_blank", "noopener,noreferrer");
}

/**
 * Splits a browser / lightning-file-upload file name into title + extension so rows match
 * ContentDocument Title + FileExtension (same shape as message/task file rows from Apex).
 *
 * @param {string} [name] Full file name, often including extension (e.g. "Spec.pdf")
 * @returns {{ title: string, fileExtension: string }} Extension is lowercase without dot, or ""
 */
export function splitFileNameForPortalRow(name) {
  if (name == null || String(name).trim() === "") {
    return { title: "Attachment", fileExtension: "" };
  }
  const s = String(name).trim();
  const lastDot = s.lastIndexOf(".");
  if (lastDot <= 0 || lastDot === s.length - 1) {
    return { title: s, fileExtension: "" };
  }
  const ext = s.slice(lastDot + 1).toLowerCase();
  const title = s.slice(0, lastDot);
  return { title: title.length ? title : s, fileExtension: ext || "" };
}
