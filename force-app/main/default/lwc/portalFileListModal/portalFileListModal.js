/**
 * Read-only file list in LightningModal. Opened from c-file-manager list overflow (View more).
 * Uses lightning/modal so it stacks above Experience Cloud messaging UI.
 */
import { api } from "lwc";
import LightningModal from "lightning/modal";

export default class PortalFileListModal extends LightningModal {
  /** Modal title (pass as headerLabel from Modal.open). */
  @api headerLabel = "All attachments";

  /** Rows: { contentDocumentId, contentVersionId?, title, fileExtension } */
  @api fileRows = [];

  _showPreview = true;
  _showDelete = false;

  @api
  get showPreview() {
    return this._showPreview;
  }
  set showPreview(value) {
    this._showPreview = value === true || value === "true";
  }

  @api
  get showDelete() {
    return this._showDelete;
  }
  set showDelete(value) {
    this._showDelete = value === true || value === "true";
  }

  handleClose() {
    this.close();
  }
}
