import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getContentDocumentIdForVersionId from "@salesforce/apex/MessageFilesSupport.getContentDocumentIdForVersionId";
import getLatestContentVersionIdsForDocuments from "@salesforce/apex/MessageFilesSupport.getLatestContentVersionIdsForDocuments";
import { formatDateTime, openShepherdDownloadInNewTab } from "c/portalCommon";
import { getFileIconName, formatFileSize } from "./portalFileAttachmentsUtils";

/**
 * Shared file “card” list: preview (Lightning file preview or open file in portal),
 * optional remove. Used by c-file-manager and App Builder configurations.
 */
export default class PortalFileAttachments extends NavigationMixin(LightningElement) {
  /**
   * Programmatic file rows from a parent LWC (takes precedence when non-empty).
   */
  @api files;

  _parsedAttachmentsFromBuilder = [];

  /**
   * App Builder only: JSON string array of { contentDocumentId, contentVersionId?, title, fileExtension, contentSize?, createdDate? }.
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
  _showDelete = false;

  /**
   * When true, open file preview in c-portal-file-preview-modal (Experience Cloud).
   * When false, use Lightning filePreview navigation (LEX only — not supported on Experience sites).
   * Omit to infer from URL (/s/) like {@link #isExperienceCloudRuntime}.
   */
  _isExperienceCloudApi;

  /**
   * Host record Id for file preview authorization (e.g. Message__c or Project__c). When set on
   * Experience Cloud, preview calls MessageFilesSupport.getFilePreviewUrl with linkedEntityId so
   * access follows ContentDocumentLink visibility.
   */
  @api linkedEntityId;

  @api
  get isExperienceCloud() {
    return this._isExperienceCloudApi;
  }
  set isExperienceCloud(value) {
    this._isExperienceCloudApi = value;
  }

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

  _experienceCloud;

  get effectivePreviewLinkedEntityId() {
    if (this.linkedEntityId == null || String(this.linkedEntityId).trim() === "") {
      return "";
    }
    return String(this.linkedEntityId).trim();
  }

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

  /**
   * Use in-modal ContentDistribution preview (portal; Portal Add-On pattern). LEX uses filePreview navigation.
   */
  get usePortalFilePreviewModal() {
    if (this._isExperienceCloudApi === true || this._isExperienceCloudApi === "true") {
      return true;
    }
    if (this._isExperienceCloudApi === false || this._isExperienceCloudApi === "false") {
      return false;
    }
    return this.isExperienceCloudRuntime;
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
      const sizeBytes = f.contentSize != null ? f.contentSize : f.size;
      const createdRaw = f.createdDate != null ? f.createdDate : f.uploadedAt;
      const uploadedPart = formatDateTime(createdRaw, "");
      const sizePart = formatFileSize(sizeBytes, "");
      const metaParts = [uploadedPart, sizePart].filter((p) => p && String(p).trim());
      const metaLine = metaParts.join(" · ");
      return {
        rowKey: f.contentDocumentId || f.contentVersionId || `f-${idx}`,
        contentDocumentId: f.contentDocumentId,
        contentVersionId: f.contentVersionId,
        title,
        fullName,
        fileExtension: ext,
        iconName: getFileIconName(ext),
        showDeleteRow: this.showDelete && allowDelete,
        showMetaLine: metaParts.length > 0,
        metaLine
      };
    });
  }

  handlePreviewClick(event) {
    event.preventDefault();
    event.stopPropagation();

    const docIdEarly = (event.currentTarget.dataset.documentId || "").trim();
    const versionId = (event.currentTarget.dataset.versionId || "").trim();
    const previewTitle = (event.currentTarget.dataset.previewTitle || "").trim() || "File preview";

    if (this.usePortalFilePreviewModal) {
      void this.openPreviewForExperienceCloud(docIdEarly, versionId, previewTitle);
      return;
    }

    if (docIdEarly) {
      try {
        this[NavigationMixin.Navigate]({
          type: "standard__namedPage",
          attributes: {
            pageName: "filePreview"
          },
          state: {
            recordIds: docIdEarly,
            selectedRecordId: docIdEarly
          }
        });
      } catch {
        this.openDocumentUrl(docIdEarly, null);
      }
      return;
    }

    if (versionId) {
      void this.resolveDocumentIdForOpen("", versionId)
        .then((docId) => {
          if (docId) {
            try {
              this[NavigationMixin.Navigate]({
                type: "standard__namedPage",
                attributes: {
                  pageName: "filePreview"
                },
                state: {
                  recordIds: docId,
                  selectedRecordId: docId
                }
              });
            } catch {
              this.openDocumentUrl(docId, null);
            }
            return;
          }
          this.openDocumentUrl(null, versionId);
        })
        .catch((e) => {
          console.error("portalFileAttachments: preview resolve failed", e);
        });
    }
  }

  /**
   * Experience Cloud: filePreview navigation is not supported — use embedded modal + ContentDistribution URL (Portal Add-On).
   */
  async openPreviewForExperienceCloud(docIdEarly, versionId, previewTitle) {
    let ver = (versionId || "").trim();
    const doc = (docIdEarly || "").trim();

    if (!ver && doc) {
      try {
        const list = await getLatestContentVersionIdsForDocuments({
          contentDocumentIds: [doc]
        });
        if (Array.isArray(list) && list.length > 0 && list[0]) {
          ver = String(list[0]).trim();
        }
      } catch (e) {
        console.error("portalFileAttachments: resolve version for preview failed", e);
      }
    }

    if (!ver) {
      this.openDocumentUrl(doc || null, (versionId || "").trim() || null);
      return;
    }

    const modal = this.refs.filePreviewModal;
    if (!modal || typeof modal.openPreview !== "function") {
      this.openDocumentUrl(doc || null, ver);
      return;
    }

    try {
      const le = this.effectivePreviewLinkedEntityId;
      await modal.openPreview({
        contentVersionId: ver,
        contentDocumentId: doc || undefined,
        linkedEntityId: le || undefined,
        title: previewTitle
      });
    } catch (e) {
      console.error("portalFileAttachments: preview modal failed", e);
      this.openDocumentUrl(doc || null, ver);
    }
  }

  /**
   * When only ContentVersion Id is present, resolve ContentDocument Id for LEX file preview / shepherd URLs.
   * @param {string} contentDocumentId
   * @param {string} contentVersionId
   * @returns {Promise<string|null>}
   */
  async resolveDocumentIdForOpen(contentDocumentId, contentVersionId) {
    if (contentDocumentId) {
      return contentDocumentId;
    }
    if (!contentVersionId) {
      return null;
    }
    try {
      const resolved = await getContentDocumentIdForVersionId({
        contentVersionId
      });
      return resolved || null;
    } catch (e) {
      console.error("portalFileAttachments: resolve document Id failed", e);
      return null;
    }
  }

  openDocumentUrl(contentDocumentId, contentVersionId) {
    openShepherdDownloadInNewTab(contentDocumentId, contentVersionId);
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
