/**
 * Single integration point for Message__c file attachments (ContentDocumentLink).
 * Portal and internal UIs should use {@link #getFilesForMessages} instead of duplicating
 * ContentDocument SOQL on Message__c or embedding file payloads in message DTOs.
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

    List<ContentDocumentLink> links = [
      SELECT
        LinkedEntityId,
        ContentDocumentId,
        ContentDocument.Title,
        ContentDocument.FileExtension,
        ContentDocument.LatestPublishedVersionId
      FROM ContentDocumentLink
      WHERE LinkedEntityId IN :idSet AND IsDeleted = FALSE
      ORDER BY ContentDocument.Title ASC
    ];

    Map<Id, List<FileRow>> byMessage = new Map<Id, List<FileRow>>();
    for (ContentDocumentLink link : links) {
      if (link.ContentDocumentId == null) {
        continue;
      }
      Id msgId = link.LinkedEntityId;
      if (!byMessage.containsKey(msgId)) {
        byMessage.put(msgId, new List<FileRow>());
      }
      FileRow row = new FileRow();
      row.contentDocumentId = String.valueOf(link.ContentDocumentId);
      row.contentVersionId = link.ContentDocument.LatestPublishedVersionId != null
        ? String.valueOf(link.ContentDocument.LatestPublishedVersionId)
        : null;
      row.title = link.ContentDocument.Title;
      row.fileExtension = link.ContentDocument.FileExtension;
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
