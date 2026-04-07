/**
 * Format a byte size for file lists (B / KB / MB / GB).
 * Kept with this bundle so Experience / LWR sites always resolve it with c-portal-file-attachments
 * (avoids stale or split c-portal-common bundles missing newer exports).
 *
 * @param {number|string|null|undefined} bytes - Content size in bytes
 * @param {string} emptyValue - When missing or invalid
 * @returns {string}
 */
export function formatFileSize(bytes, emptyValue = "") {
  if (bytes === null || bytes === undefined || bytes === "") {
    return emptyValue;
  }
  const n = Number(bytes);
  if (!Number.isFinite(n) || n < 0) {
    return emptyValue;
  }
  if (n < 1024) {
    return `${Math.round(n)} B`;
  }
  const kb = n / 1024;
  if (kb < 1024) {
    const digits = kb < 10 ? 1 : 0;
    return `${kb.toFixed(digits)} KB`;
  }
  const mb = kb / 1024;
  if (mb < 1024) {
    return `${mb.toFixed(1)} MB`;
  }
  const gb = mb / 1024;
  return `${gb.toFixed(1)} GB`;
}

/**
 * Maps file extension to a Lightning icon (utility / doctype).
 * @param {string} ext Lowercase or mixed extension without dot
 * @returns {string} icon name
 */
export function getFileIconName(ext) {
  const e = (ext || "").toLowerCase().replace(/^\./, "");
  const map = {
    pdf: "doctype:pdf",
    png: "doctype:image",
    jpg: "doctype:image",
    jpeg: "doctype:image",
    gif: "doctype:image",
    webp: "doctype:image",
    svg: "doctype:image",
    xls: "doctype:excel",
    xlsx: "doctype:excel",
    csv: "doctype:csv",
    ppt: "doctype:ppt",
    pptx: "doctype:ppt",
    doc: "doctype:word",
    docx: "doctype:word",
    txt: "doctype:txt",
    zip: "doctype:zip",
    xml: "doctype:xml",
    html: "doctype:html",
    htm: "doctype:html"
  };
  return map[e] || "doctype:attachment";
}
