import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ensureSitePath } from "c/portalCommon";
import { getFileIconName } from "./portalFileAttachmentsUtils";

/**
 * Shared file “card” list: preview (Lightning file preview or open download in portal),
 * download, optional remove. Intended for portalMessaging and portalTaskFiles.
 */
export default class PortalFileAttachments extends NavigationMixin(LightningElement) {
  /**
   * Programmatic file rows from a parent LWC (takes precedence when non-empty).
   */
  @api files;

  _parsedAttachmentsFromBuilder = [];

  /**
   * App Builder only: JSON string array of { contentDocumentId, contentVersionId?, title, fileExtension }.
   */
  @api
  get attachmentsJson() {
    return this._attachmentsJsonRaw || "";
  }
  set attachmentsJson(value) {
    this._attachmentsJsonRaw = value == null ? "" : String(value);
    this._parsedAttachmentsFromBuilder = this.parseAttachmentsJson(this._attachmentsJsonRaw);
  }

  parseAttachmentsJson(raw) {
    if (raw == null || String(raw).trim() === "") {
      return [];
    }
    try {
      const parsed = JSON.parse(String(raw));
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }

  get effectiveFileRows() {
    if (Array.isArray(this.files) && this.files.length > 0) {
      return this.files;
    }
    return this._parsedAttachmentsFromBuilder;
  }

  _showPreview = true;
  _showDownload = true;
  _showDelete = false;

  @api
  get showPreview() {
    return this._showPreview;
  }
  set showPreview(value) {
    this._showPreview = value === true || value === "true";
  }

  @api
  get showDownload() {
    return this._showDownload;
  }
  set showDownload(value) {
    this._showDownload = value === true || value === "true";
  }

  @api
  get showDelete() {
    return this._showDelete;
  }
  set showDelete(value) {
    this._showDelete = value === true || value === "true";
  }

  _experienceCloud;

  get isExperienceCloudRuntime() {
    if (this._experienceCloud !== undefined) {
      return this._experienceCloud;
    }
    if (typeof window !== "undefined" && window.location) {
      const pathname = window.location.pathname || "";
      this._experienceCloud = pathname.startsWith("/s/") || pathname.includes("/s/");
      return this._experienceCloud;
    }
    this._experienceCloud = false;
    return false;
  }

  get hasFiles() {
    return Array.isArray(this.effectiveFileRows) && this.effectiveFileRows.length > 0;
  }

  get displayFiles() {
    if (!this.hasFiles) {
      return [];
    }
    return this.effectiveFileRows.map((f, idx) => {
      const ext = (f.fileExtension || "").toLowerCase();
      const allowDelete = f.canDelete === undefined || f.canDelete === true;
      const title = f.title || "Attachment";
      const fullName = ext ? `${title}.${ext}` : title;
      return {
        rowKey: f.contentDocumentId || f.contentVersionId || `f-${idx}`,
        contentDocumentId: f.contentDocumentId,
        contentVersionId: f.contentVersionId,
        title,
        fullName,
        fileExtension: ext,
        iconName: getFileIconName(ext),
        showDeleteRow: this.showDelete && allowDelete
      };
    });
  }

  handlePreviewClick(event) {
    const docId = event.currentTarget.dataset.documentId;
    if (!docId) {
      return;
    }
    if (this.isExperienceCloudRuntime) {
      this.openDocumentUrl(docId);
      return;
    }
    try {
      this[NavigationMixin.Navigate]({
        type: "standard__namedPage",
        attributes: {
          pageName: "filePreview"
        },
        state: {
          selectedRecordId: docId
        }
      });
    } catch {
      this.openDocumentUrl(docId);
    }
  }

  handleDownloadClick(event) {
    const docId = event.currentTarget.dataset.documentId;
    this.openDocumentUrl(docId);
  }

  openDocumentUrl(contentDocumentId) {
    if (typeof window === "undefined" || !contentDocumentId) {
      return;
    }
    const path = `/sfc/servlet.shepherd/document/download/${contentDocumentId}`;
    const url = ensureSitePath(path, {
      currentPathname: window.location.pathname || ""
    });
    window.open(url, "_blank", "noopener,noreferrer");
  }

  handleRemoveClick(event) {
    const versionId = event.currentTarget.dataset.versionId;
    const documentId = event.currentTarget.dataset.documentId;
    this.dispatchEvent(
      new CustomEvent("fileremove", {
        detail: {
          contentVersionId: versionId || null,
          contentDocumentId: documentId || null
        },
        bubbles: true,
        composed: true
      })
    );
  }
}
