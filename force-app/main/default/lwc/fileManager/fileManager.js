import { LightningElement, api, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getFilesForLinkedRecord from "@salesforce/apex/TaskContextController.getFilesForLinkedRecord";
import { splitFileNameForPortalRow } from "c/portalCommon";

/**
 * Unified file list + optional upload for records, static rows (e.g. message attachments),
 * or composer pending uploads (lightning-file-upload + removable list).
 */
export default class FileManager extends LightningElement {
  /** "record" | "list" | "composer" */
  @api variant = "record";

  @api recordId;

  /** For variant=list: rows like MessageFilesSupport.FileRow */
  @api fileRows;

  @api cardTitle = "Files";

  _showCardExplicit;
  @api
  get showCard() {
    if (this._showCardExplicit !== undefined) {
      return this._showCardExplicit;
    }
    return this.variant === "record";
  }
  set showCard(value) {
    if (value === undefined) {
      this._showCardExplicit = undefined;
      return;
    }
    this._showCardExplicit = value === true || value === "true";
  }

  _showUpload = true;
  @api
  get showUpload() {
    return this._showUpload;
  }
  set showUpload(value) {
    this._showUpload = value === true || value === "true";
  }

  _showPreview = true;
  @api
  get showPreview() {
    return this._showPreview;
  }
  set showPreview(value) {
    this._showPreview = value === true || value === "true";
  }

  _showDownload = true;
  @api
  get showDownload() {
    return this._showDownload;
  }
  set showDownload(value) {
    this._showDownload = value === true || value === "true";
  }

  _showDelete = false;
  @api
  get showDelete() {
    return this._showDelete;
  }
  set showDelete(value) {
    this._showDelete = value === true || value === "true";
  }

  @api acceptedFormats = ".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.jpg,.jpeg,.png,.gif,.zip,.rar";

  @api uploadHelpText;

  @track _uploadedFileIds = [];
  /** @type {Array<{contentDocumentId: string, contentVersionId: string, title: string, fileExtension: string}>} */
  @track _pendingComposerFiles = [];
  @track _renderFileUpload = true;

  _wiredFilesResult;

  @wire(getFilesForLinkedRecord, { linkedEntityId: "$wireRecordId" })
  wiredFiles(result) {
    this._wiredFilesResult = result;
  }

  get isComposerVariant() {
    return this.variant === "composer";
  }

  get isRecordVariant() {
    return this.variant === "record";
  }

  get isListVariant() {
    return this.variant === "list";
  }

  get wireRecordId() {
    return this.isRecordVariant && this.recordId ? String(this.recordId) : undefined;
  }

  get wrapperClass() {
    return this.showCard ? "slds-card file-manager file-manager_record" : "file-manager file-manager_record";
  }

  get innerBodyClass() {
    return this.showCard ? "slds-card__body slds-card__body_inner" : "";
  }

  get listSpacingClass() {
    return this.showRecordUpload ? "slds-m-top_small" : "";
  }

  get wiredRowsMapped() {
    const { data, error } = this._wiredFilesResult || {};
    if (error) {
      console.error("fileManager wired files error:", JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
      return [];
    }
    if (!data || !Array.isArray(data)) {
      return [];
    }
    return data.map((f) => ({
      contentDocumentId: f.id,
      contentVersionId: f.versionId,
      title: f.title || "File",
      fileExtension: (f.extension || "").toLowerCase()
    }));
  }

  get displayFileRows() {
    if (this.isListVariant) {
      return Array.isArray(this.fileRows) ? this.fileRows : [];
    }
    if (this.isRecordVariant) {
      return this.wiredRowsMapped;
    }
    return [];
  }

  get hasDisplayFiles() {
    return this.displayFileRows.length > 0;
  }

  get showRecordUpload() {
    return this.isRecordVariant && this.showUpload && !!this.recordId;
  }

  get showEmptyRecordHint() {
    return (
      this.isRecordVariant &&
      !this.hasDisplayFiles &&
      !(this._wiredFilesResult && this._wiredFilesResult.loading)
    );
  }

  get renderComposerUpload() {
    return this._renderFileUpload && !!this.recordId;
  }

  get pendingComposerFiles() {
    return this._pendingComposerFiles;
  }

  get hasPendingComposerFiles() {
    return Array.isArray(this._pendingComposerFiles) && this._pendingComposerFiles.length > 0;
  }

  handleRecordUploadFinished() {
    Promise.resolve().then(() => {
      if (this._wiredFilesResult) {
        refreshApex(this._wiredFilesResult).catch((e) => {
          console.error("fileManager refreshApex:", e);
        });
      }
    });
  }

  /**
   * Upload-finished runs inside the platform file-upload stack; updating @track state synchronously
   * can re-enter Lightning internals and surface as [NoErrorObjectAvailable] Script error. Defer work.
   */
  handleComposerUploadFinished(event) {
    const raw = event?.detail?.files;
    const uploadedFiles = Array.isArray(raw) ? raw : [];
    if (uploadedFiles.length === 0) {
      return;
    }
    Promise.resolve().then(() => {
      this.applyComposerUploadFinishedPayload(uploadedFiles);
    });
  }

  applyComposerUploadFinishedPayload(uploadedFiles) {
    try {
      const newIds = [];
      const newRows = [];
      for (const file of uploadedFiles) {
        if (!file) {
          continue;
        }
        const contentVersionId = file.contentVersionId;
        if (!contentVersionId) {
          continue;
        }
        newIds.push(contentVersionId);
        const contentDocumentId = file.documentId || file.contentDocumentId;
        const { title, fileExtension } = splitFileNameForPortalRow(file.name);
        newRows.push({
          contentDocumentId: contentDocumentId || undefined,
          contentVersionId,
          title,
          fileExtension
        });
      }
      if (newIds.length === 0) {
        return;
      }
      this._uploadedFileIds = [...this._uploadedFileIds, ...newIds];
      this._pendingComposerFiles = [...this._pendingComposerFiles, ...newRows];
    } catch (e) {
      console.error("fileManager applyComposerUploadFinishedPayload:", e);
    }
  }

  handleComposerFileRemove(event) {
    const { contentVersionId, contentDocumentId } = event.detail || {};
    this._pendingComposerFiles = this._pendingComposerFiles.filter((f) => {
      if (contentVersionId && f.contentVersionId === contentVersionId) {
        return false;
      }
      if (contentDocumentId && f.contentDocumentId === contentDocumentId && !contentVersionId) {
        return false;
      }
      return true;
    });
    if (contentVersionId) {
      this._uploadedFileIds = this._uploadedFileIds.filter((id) => id !== contentVersionId);
    }
    if (this._pendingComposerFiles.length === 0 && this._uploadedFileIds.length === 0) {
      this._renderFileUpload = false;
      Promise.resolve().then(() => {
        this._renderFileUpload = true;
      });
    }
  }

  /**
   * @returns ContentVersion Ids accumulated in composer variant (for linking after message insert).
   */
  @api
  getUploadedContentVersionIds() {
    return Array.isArray(this._uploadedFileIds) ? [...this._uploadedFileIds] : [];
  }

  /** Clears composer pending files and remounts the upload control when needed. */
  @api
  resetComposerState() {
    const remount = this._pendingComposerFiles.length > 0 || this._uploadedFileIds.length > 0;
    this._uploadedFileIds = [];
    this._pendingComposerFiles = [];
    if (remount) {
      this._renderFileUpload = false;
      Promise.resolve().then(() => {
        this._renderFileUpload = true;
      });
    }
  }
}
