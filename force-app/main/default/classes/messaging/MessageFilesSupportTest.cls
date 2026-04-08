/**
 * Tests {@link MessageFilesSupport#getFilesForMessages} for Message__c ContentDocumentLinks.
 */
@IsTest
private class MessageFilesSupportTest {
  @IsTest
  static void getFilesForMessages_returnsRowsForLinkedDocuments() {
    Account acc = new Account(Name = 'Msg Files Account');
    insert acc;

    Contact sender = new Contact(FirstName = 'Send', LastName = 'Er', AccountId = acc.Id);
    insert sender;

    Message__c msg = new Message__c(
      Body__c = 'Message with file',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    ContentVersion cv = new ContentVersion(
      Title = 'Spec',
      PathOnClient = 'Spec.pdf',
      VersionData = Blob.valueOf('PDF'),
      FirstPublishLocationId = msg.Id
    );
    insert cv;

    Id docId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ]
    .ContentDocumentId;

    Test.startTest();
    List<MessageFilesSupport.MessageFilesResult> rows = MessageFilesSupport.getFilesForMessages(
      new List<String>{ String.valueOf(msg.Id) }
    );
    Test.stopTest();

    System.assertEquals(1, rows.size(), 'One message with files');
    System.assertEquals(String.valueOf(msg.Id), rows[0].messageId);
    System.assertEquals(1, rows[0].files.size());
    System.assertEquals(String.valueOf(docId), rows[0].files[0].contentDocumentId);
    System.assertEquals('Spec', rows[0].files[0].title);
    System.assertEquals(3L, rows[0].files[0].contentSize, 'VersionData blob length');
    System.assertNotEquals(null, rows[0].files[0].createdDate);

    List<MessageFilesSupport.AttachmentLinkRow> raw = MessageFilesSupport.loadMessageAttachmentLinks(
      new Set<Id>{ msg.Id }
    );
    System.assertEquals(1, raw.size(), 'Shared loader returns same attachment count');
    System.assertEquals(msg.Id, raw[0].linkedEntityId);
    System.assertEquals(String.valueOf(docId), String.valueOf(raw[0].contentDocumentId));
  }

  @IsTest
  static void getContentDocumentIdForVersionId_resolvesWhenVisible() {
    Account acc = new Account(Name = 'Version to document');
    insert acc;

    ContentVersion cv = new ContentVersion(
      Title = 'Lookup',
      PathOnClient = 'Lookup.txt',
      VersionData = Blob.valueOf('x'),
      FirstPublishLocationId = acc.Id
    );
    insert cv;

    Id docId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ]
    .ContentDocumentId;

    Test.startTest();
    String resolved = MessageFilesSupport.getContentDocumentIdForVersionId(String.valueOf(cv.Id));
    String blank = MessageFilesSupport.getContentDocumentIdForVersionId('');
    String bad = MessageFilesSupport.getContentDocumentIdForVersionId('not-an-id');
    Test.stopTest();

    System.assertEquals(String.valueOf(docId), resolved);
    System.assertEquals(null, blank);
    System.assertEquals(null, bad);
  }

  @IsTest
  static void getLatestContentVersionIdsForDocuments_preservesOrderAndResolves() {
    Account acc = new Account(Name = 'Version resolve account');
    insert acc;

    Contact sender = new Contact(FirstName = 'V', LastName = 'Resolve', AccountId = acc.Id);
    insert sender;

    Message__c msg = new Message__c(
      Body__c = 'Host',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    ContentVersion cv = new ContentVersion(
      Title = 'ResolveMe',
      PathOnClient = 'ResolveMe.pdf',
      VersionData = Blob.valueOf('x'),
      FirstPublishLocationId = msg.Id
    );
    insert cv;

    Id docId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ]
    .ContentDocumentId;

    Test.startTest();
    List<String> out = MessageFilesSupport.getLatestContentVersionIdsForDocuments(
      new List<String>{ '', String.valueOf(docId), 'bad' }
    );
    Test.stopTest();

    System.assertEquals(3, out.size(), 'Output length matches input');
    System.assertEquals('', out[0]);
    System.assertEquals(String.valueOf(cv.Id), out[1]);
    System.assertEquals('', out[2]);
  }

  @IsTest
  static void getFilesForMessages_emptyInput_returnsEmpty() {
    System.assertEquals(0, MessageFilesSupport.getFilesForMessages(new List<String>()).size());
    System.assertEquals(0, MessageFilesSupport.getFilesForMessages(null).size());
  }

  @IsTest
  static void getFilesForMessages_ignoresInvalidIdStrings() {
    Account acc = new Account(Name = 'Msg Files Account');
    insert acc;

    Contact sender = new Contact(FirstName = 'Send', LastName = 'Er', AccountId = acc.Id);
    insert sender;

    Message__c msg = new Message__c(
      Body__c = 'Message with file',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    ContentVersion cv = new ContentVersion(
      Title = 'Spec',
      PathOnClient = 'Spec.pdf',
      VersionData = Blob.valueOf('PDF'),
      FirstPublishLocationId = msg.Id
    );
    insert cv;

    Id docId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ]
    .ContentDocumentId;

    Test.startTest();
    List<MessageFilesSupport.MessageFilesResult> rows = MessageFilesSupport.getFilesForMessages(
      new List<String>{ 'not-a-valid-id', '', String.valueOf(msg.Id) }
    );
    Test.stopTest();

    System.assertEquals(1, rows.size(), 'Invalid strings skipped; one message with files');
    System.assertEquals(String.valueOf(msg.Id), rows[0].messageId);
    System.assertEquals(1, rows[0].files.size());
    System.assertEquals(String.valueOf(docId), rows[0].files[0].contentDocumentId);
  }

  @IsTest
  static void linkFilesToMessageAndContext_linksMessageAndContextRecord() {
    Account acc = new Account(Name = 'Link Context Account');
    insert acc;

    Contact sender = new Contact(FirstName = 'Send', LastName = 'Er', AccountId = acc.Id);
    insert sender;

    Message__c msg = new Message__c(
      Body__c = 'With attachment',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    ContentVersion cv = new ContentVersion(
      Title = 'DraftDoc',
      PathOnClient = 'DraftDoc.pdf',
      VersionData = Blob.valueOf('PDF'),
      FirstPublishLocationId = UserInfo.getUserId()
    );
    insert cv;

    Id docId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ]
    .ContentDocumentId;

    Test.startTest();
    MessageFilesSupport.linkFilesToMessageAndContext(
      String.valueOf(msg.Id),
      new List<String>{ String.valueOf(cv.Id) },
      String.valueOf(acc.Id)
    );
    Test.stopTest();

    // ContentDocumentLink: use LinkedEntityId = (not filter by ContentDocumentId alone).
    Integer msgLinkCount = [
      SELECT COUNT()
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :msg.Id AND ContentDocumentId = :docId AND IsDeleted = FALSE
    ];
    Integer accLinkCount = [
      SELECT COUNT()
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :acc.Id AND ContentDocumentId = :docId AND IsDeleted = FALSE
    ];

    System.assertEquals(1, msgLinkCount, 'Document should link to Message__c');
    System.assertEquals(1, accLinkCount, 'Document should link to Account context');
  }

  @IsTest
  static void linkFilesToMessageAndContext_idempotent_skipsExistingPairs() {
    Account acc = new Account(Name = 'Idempotent Account');
    insert acc;

    Contact sender = new Contact(FirstName = 'Send', LastName = 'Er', AccountId = acc.Id);
    insert sender;

    Message__c msg = new Message__c(
      Body__c = 'Msg',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    ContentVersion cv = new ContentVersion(
      Title = 'Dup',
      PathOnClient = 'Dup.pdf',
      VersionData = Blob.valueOf('x'),
      FirstPublishLocationId = msg.Id
    );
    insert cv;

    Id docId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ]
    .ContentDocumentId;

    // Only the Account link is added by linkFiles; message link already exists from FirstPublishLocationId.
    Integer accLinksBefore = [
      SELECT COUNT()
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :acc.Id AND ContentDocumentId = :docId AND IsDeleted = FALSE
    ];

    Test.startTest();
    MessageFilesSupport.linkFilesToMessageAndContext(
      String.valueOf(msg.Id),
      new List<String>{ String.valueOf(cv.Id) },
      String.valueOf(acc.Id)
    );
    MessageFilesSupport.linkFilesToMessageAndContext(
      String.valueOf(msg.Id),
      new List<String>{ String.valueOf(cv.Id) },
      String.valueOf(acc.Id)
    );
    Test.stopTest();

    Integer accLinksAfter = [
      SELECT COUNT()
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :acc.Id AND ContentDocumentId = :docId AND IsDeleted = FALSE
    ];

    System.assertEquals(0, accLinksBefore, 'Account should have no file link before');
    System.assertEquals(1, accLinksAfter, 'Second call must not duplicate the Account link');
  }

  @IsTest
  static void deleteMessageAndAttachments_removesFilesAndSoftDeletes() {
    Account acc = new Account(Name = 'Delete Msg Account');
    insert acc;

    Contact sender = new Contact(FirstName = 'Send', LastName = 'Er', AccountId = acc.Id);
    insert sender;

    Message__c msg = new Message__c(
      Body__c = 'With file',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    ContentVersion cv = new ContentVersion(
      Title = 'Attach',
      PathOnClient = 'Attach.pdf',
      VersionData = Blob.valueOf('PDF'),
      FirstPublishLocationId = msg.Id
    );
    insert cv;

    Id docId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ]
    .ContentDocumentId;

    Test.startTest();
    MessageFilesSupport.deleteMessageAndAttachments(String.valueOf(msg.Id));
    Test.stopTest();

    Message__c after = [SELECT Deleted__c FROM Message__c WHERE Id = :msg.Id];
    System.assertEquals(true, after.Deleted__c, 'Message soft-deleted');

    List<ContentDocument> docs = [
      SELECT Id, IsDeleted
      FROM ContentDocument
      WHERE Id = :docId
      ALL ROWS
    ];
    System.assertEquals(1, docs.size(), 'Document row still traceable in test');
    System.assertEquals(true, docs[0].IsDeleted, 'ContentDocument deleted');
  }

  @IsTest
  static void deleteMessageAndAttachments_nonOwnerThrows() {
    Account acc = new Account(Name = 'Other User Acc');
    insert acc;

    Contact sender = new Contact(FirstName = 'Send', LastName = 'Er', AccountId = acc.Id);
    insert sender;

    Message__c msg = new Message__c(
      Body__c = 'No delete',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    Profile standard = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User other = new User(
      Alias = 'odel',
      Email = 'odel@test.org',
      EmailEncodingKey = 'UTF-8',
      LastName = 'OtherDel',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = standard.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'odel' + String.valueOf(Crypto.getRandomInteger()) + '@test.org'
    );
    insert other;

    Boolean threw = false;
    Test.startTest();
    System.runAs(other) {
      try {
        MessageFilesSupport.deleteMessageAndAttachments(String.valueOf(msg.Id));
      } catch (AuraHandledException expected) {
        // In test context getMessage() is often the generic "Script-thrown exception".
        threw = true;
      }
    }
    Test.stopTest();

    System.assertEquals(true, threw, 'Non-owner should not delete');
    Message__c unchanged = [SELECT Deleted__c FROM Message__c WHERE Id = :msg.Id];
    System.assertEquals(false, unchanged.Deleted__c);
  }

  @IsTest
  static void getFilePreviewUrl_blankThrows() {
    Boolean threw = false;
    try {
      MessageFilesSupport.getFilePreviewUrl('', null, null);
    } catch (AuraHandledException expected) {
      threw = true;
    }
    System.assertEquals(true, threw, 'Blank version Id should throw');
  }

  @IsTest
  static void getFilePreviewUrl_returnsDistributionPublicUrl() {
    Account acc = new Account(Name = 'Preview URL Account');
    insert acc;

    ContentVersion cv = new ContentVersion(
      Title = 'PreviewDoc',
      PathOnClient = 'PreviewDoc.pdf',
      VersionData = Blob.valueOf('PDFBYTES'),
      FirstPublishLocationId = acc.Id
    );
    insert cv;

    Test.startTest();
    String url = MessageFilesSupport.getFilePreviewUrl(String.valueOf(cv.Id), null, null);
    Test.stopTest();

    System.assert(!String.isBlank(url), 'Distribution URL should be returned');
    System.assert(url.startsWith('http'), 'Public URL expected');
  }

  @IsTest
  static void getFilePreviewUrl_withLinkedEntityAndDoc_returnsDistributionPublicUrl() {
    Account acc = new Account(Name = 'Preview CDL Account');
    insert acc;

    Contact sender = new Contact(FirstName = 'P', LastName = 'Review', AccountId = acc.Id);
    insert sender;

    Message__c msg = new Message__c(
      Body__c = 'With file',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    ContentVersion cv = new ContentVersion(
      Title = 'CDLPreview',
      PathOnClient = 'CDLPreview.pdf',
      VersionData = Blob.valueOf('X'),
      FirstPublishLocationId = msg.Id
    );
    insert cv;

    Id docId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ]
    .ContentDocumentId;

    Test.startTest();
    String url = MessageFilesSupport.getFilePreviewUrl(
      String.valueOf(cv.Id),
      String.valueOf(docId),
      String.valueOf(msg.Id)
    );
    Test.stopTest();

    System.assert(!String.isBlank(url), 'Distribution URL should be returned');
    System.assert(url.startsWith('http'), 'Public URL expected');
  }

  @IsTest
  static void getFilePreviewUrl_wrongLinkedEntityThrows() {
    Account acc = new Account(Name = 'Preview Wrong LE');
    insert acc;

    Contact sender = new Contact(FirstName = 'W', LastName = 'Rong', AccountId = acc.Id);
    insert sender;

    Message__c msg = new Message__c(
      Body__c = 'Host',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    Message__c otherMsg = new Message__c(
      Body__c = 'Other',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert otherMsg;

    ContentVersion cv = new ContentVersion(
      Title = 'OnlyOnFirst',
      PathOnClient = 'OnlyOnFirst.pdf',
      VersionData = Blob.valueOf('Z'),
      FirstPublishLocationId = msg.Id
    );
    insert cv;

    Id docId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ]
    .ContentDocumentId;

    Boolean threw = false;
    Test.startTest();
    try {
      MessageFilesSupport.getFilePreviewUrl(String.valueOf(cv.Id), String.valueOf(docId), String.valueOf(otherMsg.Id));
    } catch (AuraHandledException expected) {
      threw = true;
    }
    Test.stopTest();

    System.assertEquals(true, threw, 'No ContentDocumentLink from other message — should throw');
  }

  @IsTest
  static void getFilesForMessages_skipsNonIdStrings() {
    System.assertEquals(
      0,
      MessageFilesSupport.getFilesForMessages(new List<String>{ 'not-a-valid-salesforce-id' }).size()
    );
  }

  @IsTest
  static void getContentDocumentIdForVersionId_invalidReturnsNull() {
    System.assertEquals(null, MessageFilesSupport.getContentDocumentIdForVersionId('not-a-valid-id'));
    System.assertEquals(null, MessageFilesSupport.getContentDocumentIdForVersionId(''));
  }

  @IsTest
  static void getContentDocumentIdForVersionId_missingVersionReturnsNull() {
    System.assertEquals(null, MessageFilesSupport.getContentDocumentIdForVersionId('068000000000000AAA'));
  }

  @IsTest
  static void getFilePreviewUrl_resolvesDocumentWhenLinkedEntityProvidedWithoutDocId() {
    Account acc = new Account(Name = 'Preview Resolve Acc');
    insert acc;
    Contact sender = new Contact(LastName = 'PV', AccountId = acc.Id);
    insert sender;
    Message__c msg = new Message__c(
      Body__c = 'P',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;
    ContentVersion cv = new ContentVersion(
      Title = 'PreviewR',
      PathOnClient = 'pr.pdf',
      VersionData = Blob.valueOf('p'),
      FirstPublishLocationId = acc.Id
    );
    insert cv;
    Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
    insert new ContentDocumentLink(
      LinkedEntityId = msg.Id,
      ContentDocumentId = docId,
      ShareType = 'V',
      Visibility = 'AllUsers'
    );

    Test.startTest();
    String url = MessageFilesSupport.getFilePreviewUrl(String.valueOf(cv.Id), null, String.valueOf(msg.Id));
    Test.stopTest();
    System.assert(!String.isBlank(url));
  }

  @IsTest
  static void getFilePreviewUrl_whenLinkedEntitySetButVersionUnknown_throws() {
    Account acc = new Account(Name = 'Bad Ver Acc');
    insert acc;
    Contact sender = new Contact(LastName = 'BV', AccountId = acc.Id);
    insert sender;
    Message__c msg = new Message__c(
      Body__c = 'B',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;
    Boolean threw = false;
    try {
      MessageFilesSupport.getFilePreviewUrl('068000000000000AAA', null, String.valueOf(msg.Id));
    } catch (AuraHandledException expected) {
      threw = true;
    }
    System.assert(threw);
  }

  @IsTest
  static void getFilePreviewUrl_invalidVersionIdThrowsGenericHandledMessage() {
    Boolean threw = false;
    try {
      MessageFilesSupport.getFilePreviewUrl('not-a-valid-version-id', null, null);
    } catch (AuraHandledException e) {
      threw = true;
    }
    System.assert(threw, 'Invalid version Id should surface AuraHandledException');
  }

  @IsTest
  static void deleteMessageAndAttachments_allowedWhenRunningUserIsCreatedByButNotSender() {
    Account acc = new Account(Name = 'Delete Creator Row');
    insert acc;
    Contact otherSender = new Contact(LastName = 'NotRunner', AccountId = acc.Id);
    insert otherSender;
    Message__c msg = new Message__c(
      Body__c = 'Creator delete path',
      Sender__c = otherSender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    Test.startTest();
    MessageFilesSupport.deleteMessageAndAttachments(String.valueOf(msg.Id));
    Test.stopTest();

    System.assertEquals(true, [SELECT Deleted__c FROM Message__c WHERE Id = :msg.Id].Deleted__c);
  }

  @IsTest
  static void deleteMessageAndAttachments_secondInvocationThrowsNotFound() {
    Account acc = new Account(Name = 'Double Delete Acc');
    insert acc;
    Contact otherSender = new Contact(LastName = 'DD', AccountId = acc.Id);
    insert otherSender;
    Message__c msg = new Message__c(
      Body__c = 'Twice',
      Sender__c = otherSender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msg;

    MessageFilesSupport.deleteMessageAndAttachments(String.valueOf(msg.Id));

    Boolean threw = false;
    try {
      MessageFilesSupport.deleteMessageAndAttachments(String.valueOf(msg.Id));
    } catch (AuraHandledException expected) {
      threw = true;
    }
    System.assert(threw);
  }
}
