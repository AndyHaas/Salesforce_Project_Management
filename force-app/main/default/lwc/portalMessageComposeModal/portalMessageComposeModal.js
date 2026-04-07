/**
 * Compose / reply dialog opened imperatively from portalMessaging via LightningModal.
 * Uses the platform overlay stack so lightning-file-upload confirmation UI stacks correctly
 * in Experience Cloud (custom SLDS modals do not).
 */
import { api, track, wire } from "lwc";
import LightningModal from "lightning/modal";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { publish, MessageContext } from "lightning/messageService";
import sendMessage from "@salesforce/apex/MessagingController.sendMessage";
import linkFilesToMessageAndContext from "@salesforce/apex/MessageFilesSupport.linkFilesToMessageAndContext";
import { splitFileNameForPortalRow } from "c/portalCommon";
import MESSAGE_UPDATE_CHANNEL from "@salesforce/messageChannel/MessageUpdate__c";

export default class PortalMessageComposeModal extends LightningModal {
  @api recordId;
  @api relatedAccountId;
  @api relatedProjectId;
  @api relatedTaskId;
  /** From parent: Experience Cloud vs LEX */
  @api isExperienceCloud;
  @api recipientType;
  @api isMilestoneTeamMember;
  @api replyToMessageId;
  @api replyingToDisplayName;
  @api replyingToPreview;

  @track messageBody = "";
  @track localRecipientType;
  @track selectedMentions = [];
  _uploadedFileIds = [];
  /** @type {Array<{contentDocumentId: string, contentVersionId: string, title: string, fileExtension: string}>} */
  @track _pendingComposerFiles = [];
  @track _renderFileUpload = true;
  /** Reply Id cleared in-modal when user cancels reply banner */
  @track _activeReplyToMessageId;

  _messageContext;

  @wire(MessageContext)
  wiredMessageContext(result) {
    if (!result) {
      return;
    }
    const { data, error } = result;
    if (data) {
      this._messageContext = data;
    } else if (error) {
      console.error("Compose modal message context:", JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
    }
  }

  connectedCallback() {
    this.localRecipientType = this.recipientType;
    this._activeReplyToMessageId = this.replyToMessageId || null;
  }

  get modalTitle() {
    return this.isReplying ? "Reply to Message" : "New Message";
  }

  get isReplying() {
    return !!this._activeReplyToMessageId;
  }

  get hasReplyPreview() {
    return !!(this.replyingToPreview && String(this.replyingToPreview).trim());
  }

  get showRecipientTypeSelector() {
    return this.isSalesforceContext && this.milestoneMember;
  }

  get isSalesforceContext() {
    return this.isExperienceCloud !== true && this.isExperienceCloud !== "true";
  }

  get milestoneMember() {
    return this.isMilestoneTeamMember === true || this.isMilestoneTeamMember === "true";
  }

  get recipientTypeOptions() {
    return [
      { label: "Client", value: "Client" },
      { label: "Milestone Team", value: "Milestone Team" }
    ];
  }

  get recipientTypeFieldHelp() {
    if (this.localRecipientType === "Client") {
      return "The client will see this message on the portal.";
    }
    if (this.localRecipientType === "Milestone Team") {
      return "Only Milestone Consulting team members will see this message; it will not appear to clients.";
    }
    return "Choose whether this message is visible to the client or limited to the Milestone team.";
  }

  get visibleToClientForSend() {
    if (!this.milestoneMember) {
      return true;
    }
    return this.localRecipientType === "Client";
  }

  get primaryFileContextRecordId() {
    const t = (v) => {
      if (v == null) {
        return "";
      }
      const s = String(v).trim();
      return s.length ? s : "";
    };
    const pageHost = t(this.recordId);
    if (pageHost) {
      return pageHost;
    }
    if (t(this.relatedTaskId)) {
      return t(this.relatedTaskId);
    }
    if (t(this.relatedProjectId)) {
      return t(this.relatedProjectId);
    }
    if (t(this.relatedAccountId)) {
      return t(this.relatedAccountId);
    }
    return null;
  }

  get composerFileUploadRecordId() {
    const id = this.primaryFileContextRecordId;
    return id ? String(id) : undefined;
  }

  get composerFileUploadHelp() {
    return (
      "Before you send, use Remove next to a file to detach anything you attached. " +
      "Attachments added by Milestone Consulting cannot be removed from the conversation."
    );
  }

  get acceptedFormats() {
    return ".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.jpg,.jpeg,.png,.gif,.zip,.rar";
  }

  get pendingComposerFiles() {
    return this._pendingComposerFiles;
  }

  get hasPendingComposerFiles() {
    return Array.isArray(this._pendingComposerFiles) && this._pendingComposerFiles.length > 0;
  }

  get renderFileUpload() {
    return this._renderFileUpload;
  }

  get composerAttachmentShowPreview() {
    return true;
  }

  get composerAttachmentShowDownload() {
    return true;
  }

  get composerAttachmentShowDelete() {
    return true;
  }

  handleMessageBodyChange(event) {
    this.messageBody = event.detail.value;
    this.parseMentions(this.messageBody);
  }

  handleRecipientTypeChange(event) {
    this.localRecipientType = event.detail.value;
  }

  parseMentions(body) {
    if (!body) {
      this.selectedMentions = [];
      return;
    }
    const mentionRegex = /@\[([^\]]+)\]\(([^)]+)\)/g;
    const mentions = [];
    let match;
    while ((match = mentionRegex.exec(body)) !== null) {
      mentions.push({
        name: match[1],
        id: match[2]
      });
    }
    this.selectedMentions = mentions;
  }

  handleUploadFinished(event) {
    const uploadedFiles = event.detail.files;
    if (!uploadedFiles || uploadedFiles.length === 0) {
      return;
    }
    const newIds = uploadedFiles.map((file) => file.contentVersionId).filter((id) => id);
    this._uploadedFileIds = [...this._uploadedFileIds, ...newIds];
    const newRows = uploadedFiles.map((file) => {
      const { title, fileExtension } = splitFileNameForPortalRow(file.name);
      return {
        contentDocumentId: file.documentId,
        contentVersionId: file.contentVersionId,
        title,
        fileExtension
      };
    });
    this._pendingComposerFiles = [...this._pendingComposerFiles, ...newRows];
  }

  resetComposerFilesState() {
    const remountUpload = this._pendingComposerFiles.length > 0 || this._uploadedFileIds.length > 0;
    this._uploadedFileIds = [];
    this._pendingComposerFiles = [];
    if (remountUpload) {
      this._renderFileUpload = false;
      Promise.resolve().then(() => {
        this._renderFileUpload = true;
      });
    }
  }

  handlePendingFileRemove(event) {
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

  handleCancelReply() {
    this._activeReplyToMessageId = null;
  }

  handleDismiss() {
    this.close({
      status: "dismissed",
      recipientType: this.localRecipientType
    });
  }

  publishMessageUpdate(action) {
    if (!this._messageContext) {
      return;
    }
    publish(this._messageContext, MESSAGE_UPDATE_CHANNEL, {
      relatedAccountId: this.relatedAccountId,
      relatedProjectId: this.relatedProjectId,
      relatedTaskId: this.relatedTaskId,
      action
    });
  }

  async handleSend() {
    const editor = this.template.querySelector(".message-rich-text-large");
    const currentMessageBody = editor ? editor.value : this.messageBody;

    if (!currentMessageBody || currentMessageBody.trim().length === 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Please enter a message",
          variant: "error"
        })
      );
      return;
    }

    try {
      const mentionedContactIds = this.selectedMentions.map((m) => m.id);
      const messageId = await sendMessage({
        messageBody: currentMessageBody,
        recipientType: this.localRecipientType,
        relatedAccountId: this.relatedAccountId,
        relatedProjectId: this.relatedProjectId,
        relatedTaskId: this.relatedTaskId,
        mentionedContactIds,
        isVisibleToClient: this.visibleToClientForSend,
        replyToMessageId: this._activeReplyToMessageId || null
      });

      if (this._uploadedFileIds && this._uploadedFileIds.length > 0) {
        try {
          await linkFilesToMessageAndContext({
            messageId,
            contentVersionIds: this._uploadedFileIds,
            contextRecordId: this.primaryFileContextRecordId || undefined
          });
        } catch (fileError) {
          console.error("Error linking files:", JSON.stringify(fileError, Object.getOwnPropertyNames(fileError), 2));
          const linkMsg =
            fileError?.body?.message ||
            fileError?.message ||
            "Files were not linked to the record. Check permissions or contact an administrator.";
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Attachments",
              message: linkMsg,
              variant: "warning",
              mode: "sticky"
            })
          );
        }
      }

      this.publishMessageUpdate("sent");
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Message sent successfully",
          variant: "success"
        })
      );

      this.close({
        status: "sent",
        recipientType: this.localRecipientType
      });
    } catch (error) {
      console.error("Error sending message:", JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message:
            "Failed to send message: " +
            (error.body?.message || error.body?.exceptionMessage || error.message || "Unknown error"),
          variant: "error"
        })
      );
    }
  }
}
