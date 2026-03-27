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
