import { LightningElement, api, track } from "lwc";
import getFilePreviewUrl from "@salesforce/apex/MessageFilesSupport.getFilePreviewUrl";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { openShepherdDownloadInNewTab } from "c/portalCommon";

let titleIdSequence = 0;

/**
 * Shared modal for in-page file preview in the portal (Portal Add-On pattern).
 * Resolves a ContentDistribution view URL via MessageFilesSupport.getFilePreviewUrl (Experience Cloud–friendly).
 */
export default class PortalFilePreviewModal extends LightningElement {
  /** Unique title id per instance so aria-labelledby stays valid if multiple modals exist. */
  headingId = `portal-file-preview-title-${++titleIdSequence}`;

  @track isOpen = false;
  @track loading = false;
  @track previewUrl;
  @track titleLabel = "File";

  /** Shepherd fallback when ContentDistribution preview fails (permissions, etc.). */
  _fallbackDocId;
  _fallbackVersionId;

  _escapeCloseHandler = (e) => {
    if (e.key === "Escape") {
      this.closePreview();
    }
  };

  disconnectedCallback() {
    this._removeEscapeListener();
  }

  _removeEscapeListener() {
    if (typeof window !== "undefined") {
      window.removeEventListener("keydown", this._escapeCloseHandler);
    }
  }

  _addEscapeListener() {
    if (typeof window !== "undefined") {
      window.addEventListener("keydown", this._escapeCloseHandler);
    }
  }

  /**
   * Opens the modal and loads a browser-viewable URL for the ContentVersion.
   *
   * @param {{ contentVersionId: string, contentDocumentId?: string, linkedEntityId?: string, title?: string }} config
   */
  @api
  async openPreview(config) {
    const contentVersionId = config?.contentVersionId;
    const title = config?.title || "File";
    if (!contentVersionId) {
      return;
    }

    const doc = config?.contentDocumentId != null ? String(config.contentDocumentId).trim() : "";
    this._fallbackDocId = doc || null;
    this._fallbackVersionId = String(contentVersionId).trim();

    this.isOpen = true;
    this.loading = true;
    this.previewUrl = undefined;
    this.titleLabel = title;
    this._addEscapeListener();

    try {
      const linkedEntityId = config?.linkedEntityId != null ? String(config.linkedEntityId).trim() : "";
      const payload = { contentVersionId };
      if (doc) {
        payload.contentDocumentId = doc;
      }
      if (linkedEntityId) {
        payload.linkedEntityId = linkedEntityId;
      }
      const url = await getFilePreviewUrl(payload);
      this.previewUrl = url;
    } catch (err) {
      console.error("File preview error:", err);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Preview unavailable",
          message: this.formatError(err),
          variant: "error"
        })
      );
      openShepherdDownloadInNewTab(this._fallbackDocId, this._fallbackVersionId);
      this.closePreview();
    } finally {
      this.loading = false;
    }
  }

  /**
   * Closes the modal and clears preview state.
   */
  @api
  closePreview() {
    this._removeEscapeListener();
    this.isOpen = false;
    this.loading = false;
    this.previewUrl = undefined;
    this.titleLabel = "File";
    this._fallbackDocId = undefined;
    this._fallbackVersionId = undefined;
  }

  /**
   * True while the preview dialog is open (parents can ignore Escape for other modals).
   */
  @api
  get isPreviewActive() {
    return this.isOpen === true;
  }

  handleBackdropClick() {
    this.closePreview();
  }

  handleOpenInNewTab() {
    if (this.previewUrl && typeof window !== "undefined") {
      window.open(this.previewUrl, "_blank", "noopener,noreferrer");
    }
  }

  get openInNewTabDisabled() {
    return this.loading || !this.previewUrl;
  }

  formatError(err) {
    if (!err) {
      return "Unknown error";
    }
    const body = err.body;
    if (body) {
      if (Array.isArray(body) && body[0] && body[0].message) {
        return String(body[0].message);
      }
      if (typeof body.message === "string" && body.message) {
        return body.message;
      }
      if (body.pageErrors && body.pageErrors[0] && body.pageErrors[0].message) {
        return String(body.pageErrors[0].message);
      }
    }
    if (err.message) {
      return err.message;
    }
    return "Unable to open preview";
  }
}
