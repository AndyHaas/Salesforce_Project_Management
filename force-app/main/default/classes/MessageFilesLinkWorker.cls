/**
 * Inserts ContentDocumentLink rows for message attachments without sharing enforcement.
 * Portal users often lack row visibility on Account / Project__c / Project_Task__c for CDL SOQL/DML
 * even when they may create Message__c rows; this worker mirrors typical "system links file" behavior.
 */
public without sharing class MessageFilesLinkWorker {
  /**
   * @see MessageFilesSupport#linkFilesToMessageAndContext
   */
  public static void linkFilesToMessageAndContext(
    String messageId,
    List<String> contentVersionIds,
    String contextRecordId
  ) {
    if (String.isBlank(messageId) || contentVersionIds == null || contentVersionIds.isEmpty()) {
      return;
    }

    Id msgId;
    try {
      msgId = (Id) messageId;
    } catch (Exception badMessageId) {
      throw new AuraHandledException('Invalid message Id.');
    }

    Set<Id> versionIds = new Set<Id>();
    for (String s : contentVersionIds) {
      if (String.isBlank(s)) {
        continue;
      }
      try {
        versionIds.add((Id) s);
      } catch (Exception ignored) {
      }
    }
    if (versionIds.isEmpty()) {
      return;
    }

    List<ContentVersion> versions = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id IN :versionIds AND IsDeleted = FALSE AND ContentDocumentId != NULL
    ];

    Set<Id> docIds = new Set<Id>();
    for (ContentVersion cv : versions) {
      docIds.add(cv.ContentDocumentId);
    }
    if (docIds.isEmpty()) {
      return;
    }

    Set<Id> targetEntityIds = new Set<Id>();
    targetEntityIds.add(msgId);

    Id contextId = null;
    if (String.isNotBlank(contextRecordId)) {
      try {
        contextId = (Id) contextRecordId;
      } catch (Exception badContext) {
        throw new AuraHandledException('Invalid context record Id.');
      }
      if (contextId != null && contextId != msgId) {
        targetEntityIds.add(contextId);
      }
    }

    List<ContentDocumentLink> existing = new List<ContentDocumentLink>();
    for (Id entityId : targetEntityIds) {
      existing.addAll(
        [
          SELECT ContentDocumentId, LinkedEntityId
          FROM ContentDocumentLink
          WHERE LinkedEntityId = :entityId AND ContentDocumentId IN :docIds AND IsDeleted = FALSE
        ]
      );
    }

    Set<String> existingPairs = new Set<String>();
    for (ContentDocumentLink link : existing) {
      existingPairs.add(String.valueOf(link.ContentDocumentId) + ':' + String.valueOf(link.LinkedEntityId));
    }

    List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
    for (Id docId : docIds) {
      String msgKey = String.valueOf(docId) + ':' + String.valueOf(msgId);
      if (!existingPairs.contains(msgKey)) {
        toInsert.add(newContentDocumentLink(docId, msgId));
        existingPairs.add(msgKey);
      }

      if (contextId != null && contextId != msgId) {
        String ctxKey = String.valueOf(docId) + ':' + String.valueOf(contextId);
        if (!existingPairs.contains(ctxKey)) {
          toInsert.add(newContentDocumentLink(docId, contextId));
          existingPairs.add(ctxKey);
        }
      }
    }

    if (toInsert.isEmpty()) {
      return;
    }

    try {
      insert toInsert;
    } catch (DmlException e) {
      String m = e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
      throw new AuraHandledException(String.isBlank(m) ? 'Could not link files to records.' : m);
    }
  }

  /**
   * Deletes every ContentDocument linked to the given record (e.g. Message__c).
   * Removes the file from all other linked records (Account, Project, etc.) as well.
   *
   * @param messageId LinkedEntityId for ContentDocumentLink rows to resolve documents from.
   */
  public static void deleteContentDocumentsLinkedToEntity(Id messageId) {
    if (messageId == null) {
      return;
    }

    List<ContentDocumentLink> links = [
      SELECT ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :messageId AND IsDeleted = FALSE
    ];

    Set<Id> docIds = new Set<Id>();
    for (ContentDocumentLink link : links) {
      if (link.ContentDocumentId != null) {
        docIds.add(link.ContentDocumentId);
      }
    }
    if (docIds.isEmpty()) {
      return;
    }

    List<ContentDocument> toDelete = new List<ContentDocument>();
    for (Id docId : docIds) {
      toDelete.add(new ContentDocument(Id = docId));
    }

    try {
      delete toDelete;
    } catch (DmlException e) {
      String m = e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
      throw new AuraHandledException(String.isBlank(m) ? 'Could not delete attached files.' : m);
    }
  }

  private static ContentDocumentLink newContentDocumentLink(Id contentDocumentId, Id linkedEntityId) {
    ContentDocumentLink cdl = new ContentDocumentLink();
    cdl.ContentDocumentId = contentDocumentId;
    cdl.LinkedEntityId = linkedEntityId;
    cdl.ShareType = 'V';
    // LEX Files related list and many sharing models expect an explicit visibility.
    cdl.Visibility = 'AllUsers';
    return cdl;
  }
}
