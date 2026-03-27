/**
 * Supplies ContentDocument metadata for Message__c records so portal and internal UIs
 * can render attachment lists without duplicating SOQL in each controller.
 * Uses with sharing so file visibility follows the running user.
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
   * Returns attachment rows grouped by message Id. Messages with no files are omitted.
   *
   * @param messageIds Message__c Ids as strings (from LWC).
   * @return One entry per message that has at least one ContentDocumentLink.
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
      } catch (Exception e) {
        // skip invalid ids
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
