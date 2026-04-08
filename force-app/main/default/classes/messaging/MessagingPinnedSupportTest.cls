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

  @IsTest
  static void getPinnedMessages_taskScope_milestoneAndClient() {
    Account acc = new Account(Name = 'Pin Task Acc');
    insert acc;
    Project__c proj = new Project__c(Name = 'Pin Task Proj', Account__c = acc.Id, Status__c = 'Not Started');
    insert proj;
    Project_Task__c task = new Project_Task__c(
      Name = 'Pin Task',
      Status__c = 'Backlog',
      Account__c = acc.Id,
      Project__c = proj.Id
    );
    insert task;

    Contact sender = new Contact(LastName = 'PinTaskSender', AccountId = acc.Id);
    insert sender;

    Message__c parent = new Message__c(
      Body__c = 'Parent',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false,
      Related_Task__c = task.Id,
      Is_Pinned__c = true
    );
    insert parent;

    Message__c replyPin = new Message__c(
      Body__c = 'Reply pin',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false,
      Related_Task__c = task.Id,
      Is_Pinned__c = true,
      Reply_To__c = parent.Id
    );
    insert replyPin;

    List<MessagingPinnedSupport.MessageRow> internalRows = MessagingPinnedSupport.getPinnedMessages(
      null,
      null,
      null,
      String.valueOf(task.Id),
      true
    );
    System.assertEquals(2, internalRows.size());

    List<MessagingPinnedSupport.MessageRow> clientRows = MessagingPinnedSupport.getPinnedMessages(
      null,
      null,
      null,
      String.valueOf(task.Id),
      false
    );
    System.assertEquals(2, clientRows.size());
    MessagingPinnedSupport.MessageRow replyRow;
    for (MessagingPinnedSupport.MessageRow r : clientRows) {
      if (r.body == 'Reply pin') {
        replyRow = r;
      }
    }
    System.assertNotEquals(null, replyRow);
    System.assertEquals(String.valueOf(parent.Id), replyRow.replyToMessageId);
  }

  @IsTest
  static void getPinnedMessages_projectScope_returnsPinned() {
    Account acc = new Account(Name = 'Pin Proj Acc');
    insert acc;
    Project__c proj = new Project__c(Name = 'Pin Proj', Account__c = acc.Id, Status__c = 'Not Started');
    insert proj;
    Contact sender = new Contact(LastName = 'PinProjSender', AccountId = acc.Id);
    insert sender;

    Message__c pin = new Message__c(
      Body__c = 'Proj pin',
      Sender__c = sender.Id,
      Recipient_Type__c = 'Milestone Team',
      Account__c = acc.Id,
      Visible_To_Client__c = true,
      Deleted__c = false,
      Related_Project__c = proj.Id,
      Is_Pinned__c = true
    );
    insert pin;

    List<MessagingPinnedSupport.MessageRow> rows = MessagingPinnedSupport.getPinnedMessages(
      null,
      null,
      String.valueOf(proj.Id),
      null,
      true
    );
    System.assertEquals(1, rows.size());
    System.assertEquals(String.valueOf(proj.Id), rows[0].relatedProjectId);
  }
}
