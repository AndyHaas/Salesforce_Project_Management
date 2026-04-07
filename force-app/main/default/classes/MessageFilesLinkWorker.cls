/**
 * Portal file operations without sharing enforcement: ContentDocumentLink DML, version resolution,
 * and ContentDistribution for in-browser preview. Community users often lack CRUD on linked records
 * or ContentDistribution; callers must confirm the user may read the file before preview helpers run.
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

  /**
   * @description Maps each ContentDocument Id to its LatestPublishedVersionId for linking after upload.
   * @param contentDocumentIds Non-empty set of ContentDocument Ids.
   * @return Map from ContentDocument Id to ContentVersion Id (excludes documents with no published version).
   */
  public static Map<Id, Id> getLatestVersionIdByContentDocumentIds(Set<Id> contentDocumentIds) {
    Map<Id, Id> result = new Map<Id, Id>();
    if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
      return result;
    }
    for (ContentDocument cd : [
      SELECT Id, LatestPublishedVersionId
      FROM ContentDocument
      WHERE Id IN :contentDocumentIds AND IsDeleted = FALSE
    ]) {
      if (cd.LatestPublishedVersionId != null) {
        result.put(cd.Id, cd.LatestPublishedVersionId);
      }
    }
    return result;
  }

  /**
   * @description Ordered ContentVersion Ids for composer linking when upload returns documentId only.
   * Runs without sharing so Experience Cloud users can resolve files they attached to the host record.
   * @param contentDocumentIds Ordered ContentDocument Id strings from the client.
   * @return Parallel list (empty string when not resolved).
   */
  public static List<String> getLatestContentVersionIdsForDocumentsOrdered(List<String> contentDocumentIds) {
    List<String> ordered = new List<String>();
    if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
      return ordered;
    }

    Set<Id> idSet = new Set<Id>();
    for (String s : contentDocumentIds) {
      if (String.isBlank(s)) {
        continue;
      }
      try {
        idSet.add((Id) s);
      } catch (Exception ignored) {
      }
    }
    if (idSet.isEmpty()) {
      for (Integer i = 0; i < contentDocumentIds.size(); i++) {
        ordered.add('');
      }
      return ordered;
    }

    Map<Id, Id> docToVersion = getLatestVersionIdByContentDocumentIds(idSet);

    for (String s : contentDocumentIds) {
      if (String.isBlank(s)) {
        ordered.add('');
        continue;
      }
      try {
        Id docId = (Id) s;
        Id verId = docToVersion.get(docId);
        ordered.add(verId != null ? String.valueOf(verId) : '');
      } catch (Exception ignored) {
        ordered.add('');
      }
    }
    return ordered;
  }

  /**
   * @description Ensures the ContentVersion belongs to the given ContentDocument (Id integrity).
   * Call only after {@link MessageFilesSupport} has confirmed the user may access the file via
   * ContentDocumentLink to a known linked entity.
   *
   * @param contentVersionId ContentVersion Id to preview.
   * @param contentDocumentId Expected parent document Id.
   */
  public static void assertContentVersionMatchesDocument(Id contentVersionId, Id contentDocumentId) {
    if (contentVersionId == null || contentDocumentId == null) {
      throw new AuraHandledException('File not found or not accessible.');
    }
    List<ContentVersion> rows = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :contentVersionId AND IsDeleted = FALSE
      LIMIT 1
    ];
    if (rows.isEmpty() || rows[0].ContentDocumentId != contentDocumentId) {
      throw new AuraHandledException('File not found or not accessible.');
    }
  }

  /**
   * @description Public distribution URL for iframe preview of a ContentVersion (Experience Cloud).
   * @see MessageFilesSupport#getFilePreviewUrl
   * @param contentVersionId Non-null ContentVersion Id.
   * @return {@link ContentDistribution#DistributionPublicUrl} with view-in-browser enabled.
   */
  public static String getDistributionPublicUrlForContentVersion(Id contentVersionId) {
    if (contentVersionId == null) {
      throw new AuraHandledException('Content Version ID is required');
    }

    List<ContentDistribution> existingDistributions;
    try {
      existingDistributions = [
        SELECT DistributionPublicUrl
        FROM ContentDistribution
        WHERE ContentVersionId = :contentVersionId AND PreferencesAllowViewInBrowser = TRUE
        LIMIT 1
      ];
    } catch (QueryException qe) {
      String m = String.isBlank(qe.getMessage()) ? 'Cannot query ContentDistribution.' : qe.getMessage();
      throw new AuraHandledException(m);
    }

    if (!existingDistributions.isEmpty()) {
      return existingDistributions[0].DistributionPublicUrl;
    }

    ContentDistribution dist = new ContentDistribution();
    dist.ContentVersionId = contentVersionId;
    dist.Name = 'Preview Distribution';
    dist.PreferencesAllowViewInBrowser = true;
    dist.PreferencesLinkLatestVersion = true;
    dist.PreferencesAllowOriginalDownload = true;

    try {
      insert dist;
    } catch (DmlException e) {
      String m = e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
      if (String.isBlank(m)) {
        m =
          'Could not create a view-in-browser link. Ensure the user has Client Project Management Portal User (or Create and Read on ContentDistribution).';
      }
      throw new AuraHandledException(m);
    }

    try {
      ContentDistribution createdDist = [
        SELECT DistributionPublicUrl
        FROM ContentDistribution
        WHERE Id = :dist.Id
        LIMIT 1
      ];
      return createdDist.DistributionPublicUrl;
    } catch (Exception e) {
      String m = String.isBlank(e.getMessage()) ? 'Could not load distribution URL after create.' : e.getMessage();
      throw new AuraHandledException(m);
    }
  }
}
