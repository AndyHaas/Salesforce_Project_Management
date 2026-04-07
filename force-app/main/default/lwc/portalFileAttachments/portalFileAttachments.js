import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getContentDocumentIdForVersionId from "@salesforce/apex/MessageFilesSupport.getContentDocumentIdForVersionId";
import { ensureSitePath, formatDateTime } from "c/portalCommon";
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
    const docIdEarly = (event.currentTarget.dataset.documentId || "").trim();
    const versionId = (event.currentTarget.dataset.versionId || "").trim();

    // LEX: navigation and sync window.open must run in the same turn as the click (no await before them),
    // or pop-up blockers block new tabs — especially noticeable inside Lightning modals (compose upload list).
    if (docIdEarly && this.isExperienceCloudRuntime) {
      this.openDocumentUrl(docIdEarly, null);
      return;
    }
    if (docIdEarly && !this.isExperienceCloudRuntime) {
      try {
        this[NavigationMixin.Navigate]({
          type: "standard__namedPage",
          attributes: {
            pageName: "filePreview"
          },
          state: {
            selectedRecordId: docIdEarly
          }
        });
      } catch {
        this.openDocumentUrl(docIdEarly, null);
      }
      return;
    }

    if (!docIdEarly && versionId) {
      if (this.isExperienceCloudRuntime) {
        const tab =
          typeof window !== "undefined"
            ? window.open("about:blank", "_blank", "noopener,noreferrer")
            : null;
        if (tab) {
          try {
            tab.opener = null;
          } catch {
            // ignore
          }
        }
        void this.resolveDocumentIdForOpen("", versionId)
          .then((docId) => {
            if (!tab || tab.closed) {
              return;
            }
            const pathname = typeof window !== "undefined" ? window.location.pathname || "" : "";
            if (docId) {
              const url = ensureSitePath(`/sfc/servlet.shepherd/document/download/${docId}`, {
                currentPathname: pathname
              });
              tab.location.assign(url);
              return;
            }
            const url = ensureSitePath(`/sfc/servlet.shepherd/version/download/${versionId}`, {
              currentPathname: pathname
            });
            tab.location.assign(url);
          })
          .catch((e) => {
            console.error("portalFileAttachments: preview after resolve failed", e);
            if (tab && !tab.closed) {
              tab.close();
            }
          });
        return;
      }
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
      return;
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
    if (typeof window === "undefined") {
      return;
    }
    let path;
    if (contentDocumentId) {
      path = `/sfc/servlet.shepherd/document/download/${contentDocumentId}`;
    } else if (contentVersionId) {
      path = `/sfc/servlet.shepherd/version/download/${contentVersionId}`;
    } else {
      return;
    }
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
