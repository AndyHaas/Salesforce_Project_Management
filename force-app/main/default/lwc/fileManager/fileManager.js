import { LightningElement, api, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getFilesForLinkedRecord from "@salesforce/apex/TaskContextController.getFilesForLinkedRecord";
import { splitFileNameForPortalRow } from "c/portalCommon";
import PortalFileListModal from "c/portalFileListModal";

/**
 * Clone uploadfinished file entries to plain objects (Locker / proxy-safe) and normalize property names.
 * Docs list name + documentId; some runtimes also send contentVersionId, and guest flows may use PascalCase.
 */
function snapshotComposerUploadFileEntry(file) {
  if (!file || typeof file !== "object") {
    return null;
  }
  let base = file;
  try {
    const json = JSON.stringify(file);
    if (json && json !== "{}" && json !== "null") {
      base = JSON.parse(json);
    }
  } catch {
    // keep raw object; pickFileFields still reads common keys
  }
  const pick = (obj, keys) => {
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      const v = obj[k];
      if (v != null && v !== "") {
        return typeof v === "string" ? v.trim() : v;
      }
    }
    return undefined;
  };
  const name = pick(base, ["name", "Name"]);
  const contentVersionId = pick(base, ["contentVersionId", "ContentVersionId", "versionId", "VersionId"]);
  const documentId = pick(base, ["documentId", "DocumentId", "contentDocumentId", "ContentDocumentId"]);
  if (!contentVersionId && !documentId) {
    return null;
  }
  return {
    name,
    contentVersionId: contentVersionId != null ? String(contentVersionId) : undefined,
    documentId: documentId != null ? String(documentId) : undefined
  };
}

/**
 * Unified file list + optional upload.
 *
 * Packaging: Portal Add-On should embed this with variant "record" only (project/task/account files).
 * variant "list" and "composer" are reserved for Core messaging: c-portal-messaging and
 * c-portal-message-compose-modal. The add-on does not ship portalMessageComposeModal.
 */
export default class FileManager extends LightningElement {
  /** "record" | "list" | "composer" — Experience Cloud App Builder exposes record only; list/composer set in Core LWCs. */
  @api variant = "record";

  @api recordId;

  /** For variant=list: rows like MessageFilesSupport.FileRow */
  @api fileRows;

  /**
   * list variant only: show at most this many files inline; remainder via "View more" + modal.
   * Omit, 0, or invalid = show all (no footer).
   */
  @api listMaxVisibleFiles;

  /** list variant: modal title when opening the full file list */
  @api listOverflowModalTitle = "All attachments";

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

  /**
   * Composer pending rows only (single source of truth). Each row may have contentVersionId and/or contentDocumentId.
   * @type {Array<{contentDocumentId?: string, contentVersionId?: string, title: string, fileExtension: string}>}
   */
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

  get listMaxVisibleEffective() {
    if (!this.isListVariant) {
      return 0;
    }
    const v = this.listMaxVisibleFiles;
    if (v === undefined || v === null || v === "" || v === false) {
      return 0;
    }
    const n = typeof v === "number" ? v : parseInt(String(v), 10);
    return !isNaN(n) && n > 0 ? n : 0;
  }

  get showListFileViewMoreFooter() {
    const max = this.listMaxVisibleEffective;
    return this.isListVariant && max > 0 && this.displayFileRows.length > max;
  }

  get listVisibleFileRows() {
    const all = this.displayFileRows;
    const max = this.listMaxVisibleEffective;
    if (!this.isListVariant || max <= 0 || all.length <= max) {
      return all;
    }
    return all.slice(0, max);
  }

  get listViewMoreLabel() {
    const max = this.listMaxVisibleEffective;
    const total = this.displayFileRows.length;
    const extra = total - max;
    if (extra <= 0) {
      return "View more";
    }
    return `View ${extra} more`;
  }

  async handleOpenFileListOverflowModal() {
    if (!this.isListVariant || !this.showListFileViewMoreFooter) {
      return;
    }
    try {
      await PortalFileListModal.open({
        size: "medium",
        headerLabel: this.listOverflowModalTitle || "All attachments",
        fileRows: Array.isArray(this.displayFileRows) ? [...this.displayFileRows] : [],
        showPreview: this.showPreview,
        showDownload: this.showDownload,
        showDelete: this.showDelete
      });
    } catch (e) {
      console.error("fileManager file list modal:", JSON.stringify(e, Object.getOwnPropertyNames(e), 2));
    }
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
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      if (this._wiredFilesResult) {
        refreshApex(this._wiredFilesResult).catch((e) => {
          console.error("fileManager refreshApex:", e);
        });
      }
    }, 0);
  }

  /**
   * Upload-finished runs inside the platform file-upload stack; updating @track state synchronously
   * can re-enter Lightning internals and surface as [NoErrorObjectAvailable] Script error.
   * Defer with setTimeout(0) so we leave the platform stack before mutating LWC state (modal-safe).
   *
   * Snapshot synchronously: detail.files proxies are often invalid after the handler returns; official
   * docs emphasize name + documentId — version id may be absent until resolved at send time.
   */
  handleComposerUploadFinished(event) {
    const raw = event?.detail?.files;
    if (!Array.isArray(raw) || raw.length === 0) {
      return;
    }
    const snapshot = [];
    for (let i = 0; i < raw.length; i++) {
      const entry = snapshotComposerUploadFileEntry(raw[i]);
      if (entry) {
        snapshot.push(entry);
      }
    }
    if (snapshot.length === 0) {
      return;
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      this.applyComposerUploadFinishedPayload(snapshot);
    }, 0);
  }

  applyComposerUploadFinishedPayload(uploadedFiles) {
    try {
      const newRows = [];
      for (const file of uploadedFiles) {
        if (!file) {
          continue;
        }
        const contentVersionId = file.contentVersionId;
        const contentDocumentId = file.documentId || file.contentDocumentId;
        if (!contentVersionId && !contentDocumentId) {
          continue;
        }
        const { title, fileExtension } = splitFileNameForPortalRow(file.name);
        newRows.push({
          contentDocumentId: contentDocumentId || undefined,
          contentVersionId: contentVersionId || undefined,
          title,
          fileExtension
        });
      }
      if (newRows.length === 0) {
        return;
      }
      this._pendingComposerFiles = [...this._pendingComposerFiles, ...newRows];
    } catch (e) {
      console.error("fileManager applyComposerUploadFinishedPayload:", e);
    }
  }

  handleComposerFileRemove(event) {
    const { contentVersionId, contentDocumentId } = event.detail || {};
    const ver = contentVersionId != null && String(contentVersionId).length > 0 ? String(contentVersionId) : null;
    const doc = contentDocumentId != null && String(contentDocumentId).length > 0 ? String(contentDocumentId) : null;
    this._pendingComposerFiles = this._pendingComposerFiles.filter((f) => {
      if (ver && f.contentVersionId === ver) {
        return false;
      }
      if (doc && f.contentDocumentId === doc && !f.contentVersionId) {
        return false;
      }
      return true;
    });
    if (this._pendingComposerFiles.length === 0) {
      this._renderFileUpload = false;
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => {
        this._renderFileUpload = true;
      }, 0);
    }
  }

  /**
   * @returns ContentVersion Ids known from uploadfinished (may be incomplete — use getContentDocumentIdsNeedingVersionResolution + Apex for the rest).
   */
  @api
  getUploadedContentVersionIds() {
    const ids = [];
    const rows = Array.isArray(this._pendingComposerFiles) ? this._pendingComposerFiles : [];
    for (let i = 0; i < rows.length; i++) {
      const v = rows[i].contentVersionId;
      if (v != null && String(v).length > 0) {
        ids.push(String(v));
      }
    }
    return ids;
  }

  /**
   * ContentDocument Ids for pending rows that have no ContentVersion Id yet (document-only upload payload).
   */
  @api
  getContentDocumentIdsNeedingVersionResolution() {
    const out = [];
    const rows = Array.isArray(this._pendingComposerFiles) ? this._pendingComposerFiles : [];
    for (let i = 0; i < rows.length; i++) {
      const r = rows[i];
      const doc = r.contentDocumentId;
      const ver = r.contentVersionId;
      if (doc != null && String(doc).length > 0 && (ver == null || String(ver).length === 0)) {
        out.push(String(doc));
      }
    }
    return out;
  }

  /** Clears composer pending files and remounts the upload control when needed. */
  @api
  resetComposerState() {
    const remount = this._pendingComposerFiles.length > 0;
    this._pendingComposerFiles = [];
    if (remount) {
      this._renderFileUpload = false;
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => {
        this._renderFileUpload = true;
      }, 0);
    }
  }
}
