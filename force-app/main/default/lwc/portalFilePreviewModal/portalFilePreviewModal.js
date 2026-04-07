import { api, track } from "lwc";
import LightningModal from "lightning/modal";
import { ensureSitePath } from "c/portalCommon";

/**
 * In-modal file preview for Experience Cloud (LWR-safe).
 *
 * Uses the same shepherd paths as c-portal-file-attachments openDocumentUrl. We do not use fetch + blob:
 * URLs in an iframe — LWR Content-Security-Policy blocks framing blob: (frame-src), which breaks preview.
 */
export default class PortalFilePreviewModal extends LightningModal {
  @api headerLabel = "File preview";
  @api contentDocumentId;
  @api contentVersionId;

  @track loadError = false;
  @track errorMessage = "";
  /** Site-relative URL for iframe src (ensureSitePath + shepherd). */
  @track shepherdIframeSrc = "";

  get showIframe() {
    return !this.loadError && Boolean(this.shepherdIframeSrc);
  }

  get openInNewTabDisabled() {
    return !this.tabOpenUrl;
  }

  get tabOpenUrl() {
    return this._buildShepherdPath() ? this._absoluteShepherdUrl() : "";
  }

  connectedCallback() {
    Promise.resolve().then(() => {
      this._applyShepherdSrc();
    });
  }

  /**
   * @returns {string} path starting with /sfc/... or ""
   */
  _buildShepherdPath() {
    const doc = this.contentDocumentId != null ? String(this.contentDocumentId).trim() : "";
    const ver = this.contentVersionId != null ? String(this.contentVersionId).trim() : "";
    if (doc) {
      return `/sfc/servlet.shepherd/document/download/${doc}`;
    }
    if (ver) {
      return `/sfc/servlet.shepherd/version/download/${ver}`;
    }
    return "";
  }

  _relativeShepherdUrl() {
    const path = this._buildShepherdPath();
    if (!path || typeof window === "undefined") {
      return "";
    }
    return ensureSitePath(path, { currentPathname: window.location.pathname || "" });
  }

  _absoluteShepherdUrl() {
    const relative = this._relativeShepherdUrl();
    if (!relative || typeof window === "undefined") {
      return "";
    }
    try {
      return new URL(relative, window.location.origin).href;
    } catch {
      return "";
    }
  }

  _applyShepherdSrc() {
    const rel = this._relativeShepherdUrl();
    if (!rel) {
      this.loadError = true;
      this.errorMessage = "No file is available to preview.";
      this.shepherdIframeSrc = "";
      return;
    }
    this.loadError = false;
    this.errorMessage = "";
    this.shepherdIframeSrc = rel;
  }

  handleOpenNewTab() {
    const url = this.tabOpenUrl;
    if (url && typeof window !== "undefined") {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  }

  handleClose() {
    this.close();
  }
}
