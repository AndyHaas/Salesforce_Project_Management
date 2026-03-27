/**
 * Single integration point for Message__c file attachments (ContentDocumentLink).
 * Portal and internal UIs should use {@link #getFilesForMessages} instead of duplicating
 * ContentDocument SOQL on Message__c or embedding file payloads in message DTOs.
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
  public static List<MessageFilesResult> getFilesForMessages(
    List<String> messageIds
  ) {
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
      row.contentVersionId = link.ContentDocument.LatestPublishedVersionId !=
        null
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
}
