import { api } from "lwc";
import LightningModal from "lightning/modal";
import { ensureSitePath } from "c/portalCommon";

/**
 * In-modal file preview for Experience Cloud. Uses the same shepherd URLs as download;
 * many file types (PDF, images) render in an iframe; others may prompt download inside the frame.
 */
export default class PortalFilePreviewModal extends LightningModal {
  @api headerLabel = "File preview";
  @api contentDocumentId;
  @api contentVersionId;

  get iframeSrc() {
    const pathname = typeof window !== "undefined" ? window.location.pathname || "" : "";
    const doc = this.contentDocumentId != null ? String(this.contentDocumentId).trim() : "";
    const ver = this.contentVersionId != null ? String(this.contentVersionId).trim() : "";
    let path;
    if (doc) {
      path = `/sfc/servlet.shepherd/document/download/${doc}`;
    } else if (ver) {
      path = `/sfc/servlet.shepherd/version/download/${ver}`;
    } else {
      return "";
    }
    return ensureSitePath(path, { currentPathname: pathname });
  }

  get hasSrc() {
    return this.iframeSrc.length > 0;
  }

  get openInNewTabDisabled() {
    return !this.hasSrc;
  }

  handleOpenNewTab() {
    const url = this.iframeSrc;
    if (url && typeof window !== "undefined") {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  }

  handleClose() {
    this.close();
  }
}
