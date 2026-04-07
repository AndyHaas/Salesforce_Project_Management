import { api, track } from "lwc";
import LightningModal from "lightning/modal";
import { ensureSitePath } from "c/portalCommon";

/** Max bytes to hold in memory for in-modal preview (avoids huge PDFs freezing the tab). */
const MAX_PREVIEW_BYTES = 45 * 1024 * 1024;

/**
 * In-modal file preview for Experience Cloud.
 * Shepherd /download/ URLs often send Content-Disposition: attachment, which forces a download
 * when used as an iframe src. We fetch the file with the session cookie and show it via a blob:
 * URL so the browser renders PDFs/images inline instead of downloading.
 */
export default class PortalFilePreviewModal extends LightningModal {
  @api headerLabel = "File preview";
  @api contentDocumentId;
  @api contentVersionId;

  @track loading = true;
  @track loadError = false;
  @track errorMessage = "";
  @track previewObjectUrl = "";

  /** @type {string|null} */
  _objectUrlToRevoke = null;

  get showIframe() {
    return !this.loading && !this.loadError && Boolean(this.previewObjectUrl);
  }

  get openInNewTabDisabled() {
    return !this.tabOpenUrl;
  }

  get tabOpenUrl() {
    return this._buildShepherdPath() ? this._absoluteShepherdUrl() : "";
  }

  connectedCallback() {
    void this._loadPreviewAsBlob();
  }

  disconnectedCallback() {
    this._revokeObjectUrl();
  }

  _revokeObjectUrl() {
    if (this._objectUrlToRevoke) {
      URL.revokeObjectURL(this._objectUrlToRevoke);
      this._objectUrlToRevoke = null;
    }
    this.previewObjectUrl = "";
  }

  /**
   * @returns {string} path starting with /sfc/... or ""
   */
  _buildShepherdPath() {
    const doc = this.contentDocumentId != null ? String(this.contentDocumentId).trim() : "";
    const ver = this.contentVersionId != null ? String(this.contentVersionId).trim() : "";
    const q = "?operationContext=S1";
    if (doc) {
      return `/sfc/servlet.shepherd/document/download/${doc}${q}`;
    }
    if (ver) {
      return `/sfc/servlet.shepherd/version/download/${ver}${q}`;
    }
    return "";
  }

  _absoluteShepherdUrl() {
    const path = this._buildShepherdPath();
    if (!path || typeof window === "undefined") {
      return "";
    }
    const relative = ensureSitePath(path, { currentPathname: window.location.pathname || "" });
    try {
      return new URL(relative, window.location.origin).href;
    } catch {
      return "";
    }
  }

  /**
   * Only allow same-origin shepherd download URLs (defense in depth for fetch target).
   * @param {string} urlString
   * @returns {boolean}
   */
  _isAllowedPreviewUrl(urlString) {
    if (typeof window === "undefined") {
      return false;
    }
    let u;
    try {
      u = new URL(urlString);
    } catch {
      return false;
    }
    if (u.origin !== window.location.origin) {
      return false;
    }
    const p = u.pathname;
    return (
      p.includes("/sfc/servlet.shepherd/") &&
      (p.includes("/document/download/") || p.includes("/version/download/"))
    );
  }

  async _loadPreviewAsBlob() {
    this.loading = true;
    this.loadError = false;
    this.errorMessage = "";
    this._revokeObjectUrl();

    const absoluteUrl = this._absoluteShepherdUrl();
    if (!absoluteUrl) {
      this.loading = false;
      this.loadError = true;
      this.errorMessage = "No file is available to preview.";
      return;
    }

    if (!this._isAllowedPreviewUrl(absoluteUrl)) {
      this.loading = false;
      this.loadError = true;
      this.errorMessage = "Preview is not available for this file.";
      return;
    }

    try {
      const response = await fetch(absoluteUrl, {
        method: "GET",
        credentials: "include",
        redirect: "follow"
      });

      if (!response.ok) {
        this.loadError = true;
        this.errorMessage = `Could not load file (${response.status}).`;
        return;
      }

      const contentType = (response.headers.get("Content-Type") || "").toLowerCase();
      if (contentType.includes("text/html")) {
        this.loadError = true;
        this.errorMessage = "Preview could not be loaded. Try opening in a new tab.";
        return;
      }

      const blob = await response.blob();
      if (!blob || blob.size === 0) {
        this.loadError = true;
        this.errorMessage = "The file is empty or could not be read.";
        return;
      }

      if (blob.size > MAX_PREVIEW_BYTES) {
        this.loadError = true;
        this.errorMessage = "This file is too large to preview here. Use Open in new tab.";
        return;
      }

      const objectUrl = URL.createObjectURL(blob);
      this._objectUrlToRevoke = objectUrl;
      this.previewObjectUrl = objectUrl;
    } catch (e) {
      this.loadError = true;
      this.errorMessage = "Preview could not be loaded. Try opening in a new tab.";
      console.error("portalFilePreviewModal: fetch preview failed", e);
    } finally {
      this.loading = false;
    }
  }

  handleOpenNewTab() {
    const url = this.tabOpenUrl;
    if (url && typeof window !== "undefined") {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  }

  handleClose() {
    this._revokeObjectUrl();
    this.close();
  }
}
