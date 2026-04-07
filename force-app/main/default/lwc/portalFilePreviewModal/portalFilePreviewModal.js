import { api, track } from "lwc";
import LightningModal from "lightning/modal";
import { ensureSitePath } from "c/portalCommon";

/** Max bytes to hold in memory for in-modal preview (avoids huge PDFs freezing the tab). */
const MAX_PREVIEW_BYTES = 45 * 1024 * 1024;

/**
 * In-modal file preview for Experience Cloud.
 * Prefer fetch → blob: URL so Content-Disposition: attachment does not force download in the iframe.
 * Falls back to a direct shepherd iframe src (previous behavior) when fetch fails or is blocked.
 * Load starts after a microtask so LightningModal.open() can apply @api values before we read ids.
 */
export default class PortalFilePreviewModal extends LightningModal {
  @api headerLabel = "File preview";
  @api contentDocumentId;
  @api contentVersionId;

  @track loading = true;
  @track loadError = false;
  @track errorMessage = "";
  @track previewObjectUrl = "";
  /** Relative site path for iframe when blob preview is not used (legacy / resilient path). */
  @track directShepherdSrc = "";

  /** @type {string|null} */
  _objectUrlToRevoke = null;

  get iframeSrc() {
    return this.previewObjectUrl || this.directShepherdSrc || "";
  }

  get showIframe() {
    return !this.loading && !this.loadError && Boolean(this.iframeSrc);
  }

  get openInNewTabDisabled() {
    return !this.tabOpenUrl;
  }

  get tabOpenUrl() {
    return this._buildShepherdPath() ? this._absoluteShepherdUrl() : "";
  }

  connectedCallback() {
    Promise.resolve().then(() => {
      void this._loadPreview();
    });
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

  _useDirectIframeFallback() {
    const rel = this._relativeShepherdUrl();
    this.directShepherdSrc = rel || "";
  }

  async _loadPreview() {
    this.loading = true;
    this.loadError = false;
    this.errorMessage = "";
    this.directShepherdSrc = "";
    this._revokeObjectUrl();

    const relativeUrl = this._relativeShepherdUrl();
    const absoluteUrl = this._absoluteShepherdUrl();

    if (!relativeUrl || !absoluteUrl) {
      this.loading = false;
      this.loadError = true;
      this.errorMessage = "No file is available to preview.";
      return;
    }

    const tryBlob = this._isAllowedPreviewUrl(absoluteUrl);

    if (tryBlob) {
      try {
        const response = await fetch(absoluteUrl, {
          method: "GET",
          credentials: "include",
          redirect: "follow"
        });

        if (response.ok) {
          const contentType = (response.headers.get("Content-Type") || "").toLowerCase();
          if (!contentType.includes("text/html")) {
            const blob = await response.blob();
            if (blob && blob.size > 0 && blob.size <= MAX_PREVIEW_BYTES) {
              const objectUrl = URL.createObjectURL(blob);
              this._objectUrlToRevoke = objectUrl;
              this.previewObjectUrl = objectUrl;
              this.loading = false;
              return;
            }
          }
        }
      } catch (e) {
        console.error("portalFilePreviewModal: blob preview failed, using direct iframe", e);
      }
    }

    this._useDirectIframeFallback();
    if (!this.directShepherdSrc) {
      this.loadError = true;
      this.errorMessage = "Preview is not available for this file.";
    }
    this.loading = false;
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
