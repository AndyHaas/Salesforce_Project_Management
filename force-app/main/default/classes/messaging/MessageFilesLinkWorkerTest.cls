/**
 * @description Direct coverage for {@link MessageFilesLinkWorker} (used by {@link MessageFilesSupport}).
 */
@IsTest
private class MessageFilesLinkWorkerTest {
  @IsTest
  static void linkFilesToMessageAndContext_earlyReturns() {
    Account acc = new Account(Name = 'Worker Early');
    insert acc;
    Contact sender = new Contact(LastName = 'EarlySender', AccountId = acc.Id);
    insert sender;
    Message__c msg = new Message__c(
      Body__c = 'M',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    MessageFilesLinkWorker.linkFilesToMessageAndContext(null, new List<String>(), null);
    MessageFilesLinkWorker.linkFilesToMessageAndContext(String.valueOf(msg.Id), null, null);
    MessageFilesLinkWorker.linkFilesToMessageAndContext(String.valueOf(msg.Id), new List<String>(), null);
    MessageFilesLinkWorker.linkFilesToMessageAndContext(
      String.valueOf(msg.Id),
      new List<String>{ '', 'bad-id-format' },
      null
    );
  }

  @IsTest
  static void linkFilesToMessageAndContext_invalidMessageIdThrows() {
    Boolean threw = false;
    try {
      MessageFilesLinkWorker.linkFilesToMessageAndContext(
        'not-a-valid-message-id',
        new List<String>{ String.valueOf(UserInfo.getUserId()) },
        null
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    System.assert(threw, 'Invalid message Id');
  }

  @IsTest
  static void linkFilesToMessageAndContext_invalidContextThrows() {
    Account acc = new Account(Name = 'Ctx Bad');
    insert acc;
    Contact sender = new Contact(LastName = 'S', AccountId = acc.Id);
    insert sender;
    Message__c msg = new Message__c(
      Body__c = 'M',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;
    ContentVersion cv = new ContentVersion(
      Title = 'W',
      PathOnClient = 'w.pdf',
      VersionData = Blob.valueOf('x'),
      FirstPublishLocationId = acc.Id
    );
    insert cv;

    Boolean threw = false;
    try {
      MessageFilesLinkWorker.linkFilesToMessageAndContext(
        String.valueOf(msg.Id),
        new List<String>{ String.valueOf(cv.Id) },
        'not-valid-id'
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    System.assert(threw);
  }

  @IsTest
  static void deleteContentDocumentsLinkedToEntity_nullNoOp() {
    MessageFilesLinkWorker.deleteContentDocumentsLinkedToEntity(null);
  }

  @IsTest
  static void getLatestVersionIdByContentDocumentIds_empty() {
    System.assertEquals(0, MessageFilesLinkWorker.getLatestVersionIdByContentDocumentIds(null).size());
    System.assertEquals(0, MessageFilesLinkWorker.getLatestVersionIdByContentDocumentIds(new Set<Id>()).size());
  }

  @IsTest
  static void getLatestContentVersionIdsForDocumentsOrdered_handlesBlanksAndOrder() {
    Account acc = new Account(Name = 'Ord');
    insert acc;
    ContentVersion cv = new ContentVersion(
      Title = 'OrdDoc',
      PathOnClient = 'o.pdf',
      VersionData = Blob.valueOf('z'),
      FirstPublishLocationId = acc.Id
    );
    insert cv;
    Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;

    List<String> out = MessageFilesLinkWorker.getLatestContentVersionIdsForDocumentsOrdered(
      new List<String>{ '', String.valueOf(docId), 'bad' }
    );
    System.assertEquals(3, out.size());
    System.assertEquals('', out[0]);
    System.assertEquals(String.valueOf(cv.Id), out[1]);
    System.assertEquals('', out[2]);
  }

  @IsTest
  static void assertContentVersionMatchesDocument_successAndMismatch() {
    Account acc = new Account(Name = 'Assert CV');
    insert acc;
    ContentVersion cv = new ContentVersion(
      Title = 'A',
      PathOnClient = 'a.pdf',
      VersionData = Blob.valueOf('a'),
      FirstPublishLocationId = acc.Id
    );
    insert cv;
    Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;

    MessageFilesLinkWorker.assertContentVersionMatchesDocument(cv.Id, docId);

    Boolean threw = false;
    try {
      MessageFilesLinkWorker.assertContentVersionMatchesDocument(cv.Id, acc.Id);
    } catch (AuraHandledException e) {
      threw = true;
    }
    System.assert(threw);

    threw = false;
    try {
      MessageFilesLinkWorker.assertContentVersionMatchesDocument(null, docId);
    } catch (AuraHandledException e) {
      threw = true;
    }
    System.assert(threw);
  }

  @IsTest
  static void getDistributionPublicUrlForContentVersion_returnsUrl() {
    Account acc = new Account(Name = 'Dist');
    insert acc;
    ContentVersion cv = new ContentVersion(
      Title = 'D',
      PathOnClient = 'd.pdf',
      VersionData = Blob.valueOf('d'),
      FirstPublishLocationId = acc.Id
    );
    insert cv;

    Test.startTest();
    String url = MessageFilesLinkWorker.getDistributionPublicUrlForContentVersion(cv.Id);
    Test.stopTest();
    System.assert(!String.isBlank(url));
  }

  @IsTest
  static void getDistributionPublicUrlForContentVersion_nullThrows() {
    Boolean threw = false;
    try {
      MessageFilesLinkWorker.getDistributionPublicUrlForContentVersion(null);
    } catch (AuraHandledException e) {
      threw = true;
    }
    System.assert(threw);
  }

  @IsTest
  static void linkFilesToMessageAndContext_whenContextEqualsMessage_skipsSecondEntity() {
    Account acc = new Account(Name = 'Ctx Same As Msg');
    insert acc;
    Contact sender = new Contact(LastName = 'SameCtx', AccountId = acc.Id);
    insert sender;
    Message__c msg = new Message__c(
      Body__c = 'M',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;
    ContentVersion cv = new ContentVersion(
      Title = 'Same',
      PathOnClient = 's.pdf',
      VersionData = Blob.valueOf('s'),
      FirstPublishLocationId = acc.Id
    );
    insert cv;

    MessageFilesLinkWorker.linkFilesToMessageAndContext(
      String.valueOf(msg.Id),
      new List<String>{ String.valueOf(cv.Id) },
      String.valueOf(msg.Id)
    );
  }

  @IsTest
  static void getDistributionPublicUrlForContentVersion_reusesExistingDistribution() {
    Account acc = new Account(Name = 'Dist Reuse');
    insert acc;
    ContentVersion cv = new ContentVersion(
      Title = 'R',
      PathOnClient = 'r.pdf',
      VersionData = Blob.valueOf('r'),
      FirstPublishLocationId = acc.Id
    );
    insert cv;

    String u1 = MessageFilesLinkWorker.getDistributionPublicUrlForContentVersion(cv.Id);
    String u2 = MessageFilesLinkWorker.getDistributionPublicUrlForContentVersion(cv.Id);
    System.assertEquals(u1, u2);
    System.assert(!String.isBlank(u1));
  }
}
