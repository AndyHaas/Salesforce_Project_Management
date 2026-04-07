/**
 * Single integration point for Message__c file attachments (ContentDocumentLink).
 * Portal and internal UIs should use {@link #getFilesForMessages} instead of duplicating
 * ContentDocument SOQL on Message__c or embedding file payloads in message DTOs.
 * All message-attachment reads share {@link #loadMessageAttachmentLinks}.
 * After upload, {@link #linkFilesToMessageAndContext} links files to the message and optionally
 * to the host Account, Project__c, or Project_Task__c for Files related lists (via
 * {@link MessageFilesLinkWorker} without sharing so Experience Cloud users can complete links).
 * Uses with sharing so visibility follows the running user.
 */
public with sharing class MessageFilesSupport {
  /**
   * One file row for LWC display (preview / download URLs are built client-side).
   */
  public class FileRow {
    @AuraEnabled
    public String contentDocumentId;
    @AuraEnabled
    public String contentVersionId;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String fileExtension;
    /** ContentDocument.ContentSize in bytes */
    @AuraEnabled
    public Long contentSize;
    /** ContentDocument.CreatedDate */
    @AuraEnabled
    public Datetime createdDate;
  }

  /**
   * Files attached to a single message (LinkedEntityId = Message__c Id).
   */
  public class MessageFilesResult {
    @AuraEnabled
    public String messageId;
    @AuraEnabled
    public List<FileRow> files;
  }

  /**
   * Server-only projection of ContentDocumentLink rows for Message__c attachments.
   * Populated by {@link #loadMessageAttachmentLinks}; not exposed to LWC directly.
   */
  public class AttachmentLinkRow {
    public Id linkedEntityId;
    public Id contentDocumentId;
    public String title;
    public String fileExtension;
    public Long contentSize;
    public Datetime createdDate;
    public Id createdById;
    public String createdByName;
    public Id latestPublishedVersionId;
  }

  /**
   * Single SOQL for files linked to one or more messages. Used by {@link #getFilesForMessages}
   * and by {@link MessagingController#getMessageFiles}.
   *
   * @param messageIds Message__c Ids (empty set returns empty list).
   * @return Rows ordered by document title (stable portal list order).
   */
  public static List<AttachmentLinkRow> loadMessageAttachmentLinks(Set<Id> messageIds) {
    List<AttachmentLinkRow> rows = new List<AttachmentLinkRow>();
    if (messageIds == null || messageIds.isEmpty()) {
      return rows;
    }

    List<ContentDocumentLink> links;
    try {
      links = [
        SELECT
          LinkedEntityId,
          ContentDocumentId,
          ContentDocument.Title,
          ContentDocument.FileExtension,
          ContentDocument.ContentSize,
          ContentDocument.CreatedDate,
          ContentDocument.CreatedBy.Id,
          ContentDocument.CreatedBy.Name,
          ContentDocument.LatestPublishedVersionId
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :messageIds AND IsDeleted = FALSE
        ORDER BY ContentDocument.Title ASC
      ];
    } catch (Exception e) {
      // Experience Cloud users without ContentDocument / ContentDocumentLink read hit QueryException;
      // return no rows so the thread still loads (attachments empty). Grant file object read for full behavior.
      System.debug(
        LoggingLevel.WARN,
        'MessageFilesSupport.loadMessageAttachmentLinks: ' + e.getMessage() + ' — ' + e.getStackTraceString()
      );
      return rows;
    }

    for (ContentDocumentLink link : links) {
      if (link.ContentDocumentId == null) {
        continue;
      }
      AttachmentLinkRow r = new AttachmentLinkRow();
      r.linkedEntityId = link.LinkedEntityId;
      r.contentDocumentId = link.ContentDocumentId;
      r.title = link.ContentDocument.Title;
      r.fileExtension = link.ContentDocument.FileExtension;
      r.contentSize = link.ContentDocument.ContentSize;
      r.createdDate = link.ContentDocument.CreatedDate;
      r.createdById = link.ContentDocument.CreatedBy?.Id;
      r.createdByName = link.ContentDocument.CreatedBy?.Name;
      r.latestPublishedVersionId = link.ContentDocument.LatestPublishedVersionId;
      rows.add(r);
    }
    return rows;
  }

  /**
   * Returns attachment rows for messages that have at least one linked ContentDocument.
   * Messages with no links do not appear in the result; callers merge by message Id.
   *
   * @param messageIds Message__c Ids as strings (from LWC). Blank or non-Id strings are ignored.
   * @return One entry per message Id that has at least one ContentDocumentLink.
   */
  @AuraEnabled(cacheable=false)
  public static List<MessageFilesResult> getFilesForMessages(List<String> messageIds) {
    List<MessageFilesResult> results = new List<MessageFilesResult>();
    if (messageIds == null || messageIds.isEmpty()) {
      return results;
    }

    Set<Id> idSet = new Set<Id>();
    for (String s : messageIds) {
      if (String.isBlank(s)) {
        continue;
      }
      try {
        idSet.add((Id) s);
      } catch (StringException invalidMessageId) {
        // Ignore values that are not valid Salesforce Ids.
      }
    }
    if (idSet.isEmpty()) {
      return results;
    }

    List<AttachmentLinkRow> linkRows = loadMessageAttachmentLinks(idSet);

    Map<Id, List<FileRow>> byMessage = new Map<Id, List<FileRow>>();
    for (AttachmentLinkRow ar : linkRows) {
      Id msgId = ar.linkedEntityId;
      if (!byMessage.containsKey(msgId)) {
        byMessage.put(msgId, new List<FileRow>());
      }
      FileRow row = new FileRow();
      row.contentDocumentId = String.valueOf(ar.contentDocumentId);
      row.contentVersionId = ar.latestPublishedVersionId != null
        ? String.valueOf(ar.latestPublishedVersionId)
        : null;
      row.title = ar.title;
      row.fileExtension = ar.fileExtension;
      row.contentSize = ar.contentSize;
      row.createdDate = ar.createdDate;
      byMessage.get(msgId).add(row);
    }

    for (Id msgId : byMessage.keySet()) {
      MessageFilesResult block = new MessageFilesResult();
      block.messageId = String.valueOf(msgId);
      block.files = byMessage.get(msgId);
      results.add(block);
    }
    return results;
  }

  /**
   * Creates ContentDocumentLink rows so uploaded files appear on the message and on the host record
   * (Account, Project__c, or Project_Task__c) where the messaging component is used.
   * Skips pairs that already have a link (idempotent).
   *
   * @param messageId Message__c Id the files belong to.
   * @param contentVersionIds ContentVersion Ids from lightning-file-upload (after insert).
   * @param contextRecordId Optional Account, Project__c, or Project_Task__c Id; omit when unknown.
   */
  @AuraEnabled
  public static void linkFilesToMessageAndContext(
    String messageId,
    List<String> contentVersionIds,
    String contextRecordId
  ) {
    MessageFilesLinkWorker.linkFilesToMessageAndContext(messageId, contentVersionIds, contextRecordId);
  }

  /**
   * @description Resolves LatestPublishedVersionId for each ContentDocument Id, preserving input order.
   * Used when lightning-file-upload returns documentId but not contentVersionId (see component spec).
   * @param contentDocumentIds Ordered ContentDocument Ids; invalid strings yield blank entries at that index.
   * @return ContentVersion Ids aligned index-for-index with the input list (empty string when not resolved).
   */
  @AuraEnabled(cacheable=false)
  public static List<String> getLatestContentVersionIdsForDocuments(List<String> contentDocumentIds) {
    return MessageFilesLinkWorker.getLatestContentVersionIdsForDocumentsOrdered(contentDocumentIds);
  }

  /**
   * Resolves ContentDocument Id from ContentVersion Id for preview/download when the client row only
   * has a version Id (e.g. immediate post-upload payloads). Visibility follows the running user.
   *
   * @param contentVersionId ContentVersion Id from LWC row data.
   * @return ContentDocument Id string, or null when not found, not visible, or invalid.
   */
  @AuraEnabled(cacheable=true)
  public static String getContentDocumentIdForVersionId(String contentVersionId) {
    if (String.isBlank(contentVersionId)) {
      return null;
    }
    try {
      Id verId = (Id) contentVersionId.trim();
      List<ContentVersion> rows = [
        SELECT ContentDocumentId
        FROM ContentVersion
        WHERE Id = :verId AND IsDeleted = FALSE AND ContentDocumentId != NULL
        LIMIT 1
      ];
      if (rows.isEmpty()) {
        return null;
      }
      return String.valueOf(rows[0].ContentDocumentId);
    } catch (Exception e) {
      return null;
    }
  }

  /**
   * @description Returns a browser-viewable URL for a ContentVersion using ContentDistribution
   * (Portal Add-On pattern). Confirms the running user can read the version (with sharing), then
   * creates or reuses a distribution via {@link MessageFilesLinkWorker}. The worker runs without
   * sharing for SOQL/DML row visibility, but the running user still needs profile or permission-set
   * CRUD: Read on ContentVersion, and Create and Read on ContentDistribution (see permission set
   * Milestone_Experience_Cloud_Portal_Files).
   *
   * @param contentVersionId ContentVersion Id the user can read.
   * @return Distribution public URL suitable for iframe or new tab.
   */
  @AuraEnabled(cacheable=false)
  public static String getFilePreviewUrl(String contentVersionId) {
    if (String.isBlank(contentVersionId)) {
      throw new AuraHandledException('Content Version ID is required');
    }

    try {
      Id verId = (Id) contentVersionId.trim();

      List<ContentVersion> visibleToUser = [
        SELECT Id
        FROM ContentVersion
        WHERE Id = :verId AND IsDeleted = FALSE
        LIMIT 1
      ];
      if (visibleToUser.isEmpty()) {
        throw new AuraHandledException('File not found or not accessible.');
      }

      return MessageFilesLinkWorker.getDistributionPublicUrlForContentVersion(verId);
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'MessageFilesSupport.getFilePreviewUrl: ' +
          e.getMessage() +
          ' Type: ' +
          e.getTypeName() +
          ' Stack: ' +
          e.getStackTraceString()
      );
      throw new AuraHandledException('Unable to open file preview. Please try again.');
    }
  }

  /**
   * Soft-deletes a message (Deleted__c = true) after removing linked ContentDocument records.
   * Caller must be the message sender (Contact on User) or the user who created the row.
   *
   * @param messageId Message__c Id.
   */
  @AuraEnabled
  public static void deleteMessageAndAttachments(String messageId) {
    if (String.isBlank(messageId)) {
      throw new AuraHandledException('Message Id is required.');
    }

    Id msgId;
    try {
      msgId = (Id) messageId;
    } catch (Exception badId) {
      throw new AuraHandledException('Invalid message Id.');
    }

    List<Message__c> rows = [
      SELECT Id, Sender__c, Deleted__c, CreatedById
      FROM Message__c
      WHERE Id = :msgId AND Deleted__c = FALSE
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw new AuraHandledException('Message not found or already deleted.');
    }
    Message__c msg = rows[0];

    Id userContactId = null;
    List<User> users = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    if (!users.isEmpty()) {
      userContactId = users[0].ContactId;
    }

    Boolean isSender = userContactId != null && msg.Sender__c == userContactId;
    Boolean isCreator = msg.CreatedById == UserInfo.getUserId();
    if (!isSender && !isCreator) {
      throw new AuraHandledException('You can only delete your own messages.');
    }

    MessageFilesLinkWorker.deleteContentDocumentsLinkedToEntity(msgId);

    try {
      update new Message__c(Id = msgId, Deleted__c = true);
    } catch (DmlException e) {
      String m = e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
      throw new AuraHandledException(String.isBlank(m) ? 'Could not delete message.' : m);
    }
  }
}
