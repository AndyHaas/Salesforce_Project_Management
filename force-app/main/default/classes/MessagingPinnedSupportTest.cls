/**
 * Tests {@link MessagingPinnedSupport#getPinnedMessages}.
 */
@IsTest
private class MessagingPinnedSupportTest {
  @IsTest
  static void getPinnedMessages_emptyContext_returnsEmpty() {
    System.assertEquals(0, MessagingPinnedSupport.getPinnedMessages(null, null, null, null, true).size());
  }

  @IsTest
  static void getPinnedMessages_accountScope_returnsPinnedRows() {
    Account acc = new Account(Name = 'Pin Acc');
    insert acc;

    Contact sender = new Contact(FirstName = 'S', LastName = 'R', AccountId = acc.Id);
    insert sender;

    Message__c pin = new Message__c(
      Body__c = 'Pinned',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false,
      Is_Pinned__c = true
    );
    insert pin;

    Test.startTest();
    List<MessagingPinnedSupport.MessageRow> rows = MessagingPinnedSupport.getPinnedMessages(
      null,
      String.valueOf(acc.Id),
      null,
      null,
      true
    );
    Test.stopTest();

    System.assertEquals(1, rows.size(), 'Pinned account-level message should be returned');
    System.assertEquals(String.valueOf(pin.Id), rows[0].id);
    System.assertEquals(true, rows[0].isPinned);
  }

  @IsTest
  static void getPinnedMessages_accountScope_clientVisibleOnly() {
    Account acc = new Account(Name = 'Pin Acc Only');
    insert acc;

    Contact sender = new Contact(FirstName = 'S', LastName = 'R', AccountId = acc.Id);
    insert sender;

    Message__c internalPin = new Message__c(
      Body__c = 'Internal only',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = false,
      Deleted__c = false,
      Is_Pinned__c = true
    );
    insert internalPin;

    Test.startTest();
    List<MessagingPinnedSupport.MessageRow> portalView = MessagingPinnedSupport.getPinnedMessages(
      'Milestone Team',
      String.valueOf(acc.Id),
      null,
      null,
      false
    );
    List<MessagingPinnedSupport.MessageRow> internalView = MessagingPinnedSupport.getPinnedMessages(
      null,
      String.valueOf(acc.Id),
      null,
      null,
      true
    );
    Test.stopTest();

    System.assertEquals(0, portalView.size(), 'Portal-style caller should not see team-only pin');
    System.assertEquals(1, internalView.size(), 'Milestone team should see team-only pin');
  }
}
