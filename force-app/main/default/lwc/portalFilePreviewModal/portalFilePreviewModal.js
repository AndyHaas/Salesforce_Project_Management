import { LightningElement, api, track } from "lwc";
import getFilePreviewUrl from "@salesforce/apex/MessageFilesSupport.getFilePreviewUrl";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

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
   * @param {{ contentVersionId: string, title?: string }} config
   */
  @api
  async openPreview(config) {
    const contentVersionId = config?.contentVersionId;
    const title = config?.title || "File";
    if (!contentVersionId) {
      return;
    }

    this.isOpen = true;
    this.loading = true;
    this.previewUrl = undefined;
    this.titleLabel = title;
    this._addEscapeListener();

    try {
      const url = await getFilePreviewUrl({ contentVersionId });
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
    if (err.body && err.body.message) {
      return err.body.message;
    }
    if (err.message) {
      return err.message;
    }
    return "Unable to open preview";
  }
}
