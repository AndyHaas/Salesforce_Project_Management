/**
 * Tests MessageFilesSupport.getFilesForMessages for Message__c ContentDocumentLinks.
 */
@IsTest
private class MessageFilesSupportTest {
  @IsTest
  static void getFilesForMessages_returnsRowsForLinkedDocuments() {
    Account acc = new Account(Name = 'Msg Files Account');
    insert acc;

    Contact sender = new Contact(
      FirstName = 'Send',
      LastName = 'Er',
      AccountId = acc.Id
    );
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
    System.assertEquals(
      String.valueOf(docId),
      rows[0].files[0].contentDocumentId
    );
    System.assertEquals('Spec', rows[0].files[0].title);
  }

  @IsTest
  static void getFilesForMessages_emptyInput_returnsEmpty() {
    System.assertEquals(
      0,
      MessageFilesSupport.getFilesForMessages(new List<String>()).size()
    );
    System.assertEquals(
      0,
      MessageFilesSupport.getFilesForMessages(null).size()
    );
  }
}
