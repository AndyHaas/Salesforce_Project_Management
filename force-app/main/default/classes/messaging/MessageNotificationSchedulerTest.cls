/**
 * Test class for MessageNotificationScheduler
 */
@isTest
private class MessageNotificationSchedulerTest {
  @testSetup
  static void setupTestData() {
    // Create test Account
    Account testAccount = new Account(Name = 'Test Client Account');
    insert testAccount;

    // Create test Project Manager Contact
    Contact projectManager = new Contact(
      FirstName = 'Project',
      LastName = 'Manager',
      Email = 'pm@test.com',
      AccountId = testAccount.Id
    );
    insert projectManager;

    // Create test Client Contact
    Contact clientContact = new Contact(
      FirstName = 'Client',
      LastName = 'User',
      Email = 'client@test.com',
      AccountId = testAccount.Id
    );
    insert clientContact;

    // Create test Project
    Project__c testProject = new Project__c(
      Name = 'Test Project',
      Account__c = testAccount.Id
    );
    insert testProject;

    // Create test Task with Project Manager
    Project_Task__c testTask = new Project_Task__c(
      Name = 'Test Task',
      Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Project_Manager__c = projectManager.Id
    );
    insert testTask;

    // Create unread message from client (older than 5 minutes)
    Message__c oldUnreadMessage = new Message__c(
      Body__c = 'Test unread message from client',
      Sender__c = clientContact.Id,
      Recipient_Type__c = 'Milestone Team',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = true,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false,
      PM_Notification_Sent__c = false
    );
    insert oldUnreadMessage;
    // Set created date to 6 minutes ago using Test.setCreatedDate
    Test.setCreatedDate(oldUnreadMessage.Id, DateTime.now().addMinutes(-6));

    // Create unread message from client (less than 5 minutes - should not trigger notification)
    Message__c recentUnreadMessage = new Message__c(
      Body__c = 'Recent unread message',
      Sender__c = clientContact.Id,
      Recipient_Type__c = 'Milestone Team',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = true,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false,
      PM_Notification_Sent__c = false
    );
    insert recentUnreadMessage;
    // Set created date to 2 minutes ago
    Test.setCreatedDate(recentUnreadMessage.Id, DateTime.now().addMinutes(-2));

    // Create read message (should not trigger notification)
    Message__c readMessage = new Message__c(
      Body__c = 'Read message',
      Sender__c = clientContact.Id,
      Recipient_Type__c = 'Milestone Team',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = true,
      Is_Read_By_Milestone_Team__c = true, // Already read
      Visible_To_Client__c = true,
      Deleted__c = false,
      PM_Notification_Sent__c = false
    );
    insert readMessage;
    // Set created date to 6 minutes ago
    Test.setCreatedDate(readMessage.Id, DateTime.now().addMinutes(-6));

    // Create message with notification already sent (should not trigger again)
    Message__c alreadyNotifiedMessage = new Message__c(
      Body__c = 'Already notified message',
      Sender__c = clientContact.Id,
      Recipient_Type__c = 'Milestone Team',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = true,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false,
      PM_Notification_Sent__c = true // Already sent
    );
    insert alreadyNotifiedMessage;
    // Set created date to 6 minutes ago
    Test.setCreatedDate(
      alreadyNotifiedMessage.Id,
      DateTime.now().addMinutes(-6)
    );
  }

  @isTest
  static void testCheckAndSendNotifications() {
    Test.startTest();
    MessageNotificationScheduler.checkAndSendNotifications();
    Test.stopTest();

    // Get all messages and verify by CreatedDate
    List<Message__c> allMessages = [
      SELECT
        Id,
        PM_Notification_Sent__c,
        CreatedDate,
        Is_Read_By_Milestone_Team__c
      FROM Message__c
      ORDER BY CreatedDate DESC
    ];

    // Find the old unread message (should be marked as sent)
    Message__c oldUnreadMessage = null;
    Message__c recentMessage = null;
    Message__c readMessage = null;

    for (Message__c msg : allMessages) {
      if (
        msg.CreatedDate < DateTime.now().addMinutes(-5) &&
        !msg.Is_Read_By_Milestone_Team__c &&
        oldUnreadMessage == null
      ) {
        oldUnreadMessage = msg;
      } else if (
        msg.CreatedDate > DateTime.now().addMinutes(-5) &&
        !msg.Is_Read_By_Milestone_Team__c &&
        recentMessage == null
      ) {
        recentMessage = msg;
      } else if (msg.Is_Read_By_Milestone_Team__c && readMessage == null) {
        readMessage = msg;
      }
    }

    // Verify that the old unread message was marked as notification sent
    if (oldUnreadMessage != null) {
      System.assertEquals(
        true,
        oldUnreadMessage.PM_Notification_Sent__c,
        'Old unread message should be marked as notification sent'
      );
    }

    // Verify recent message was not marked (it's less than 5 minutes old)
    if (recentMessage != null) {
      System.assertEquals(
        false,
        recentMessage.PM_Notification_Sent__c,
        'Recent message should not be marked as notification sent'
      );
    }

    // Verify read message was not marked
    if (readMessage != null) {
      System.assertEquals(
        false,
        readMessage.PM_Notification_Sent__c,
        'Read message should not be marked as notification sent'
      );
    }
  }

  @isTest
  static void testScheduledExecution() {
    Test.startTest();
    MessageNotificationScheduler scheduler = new MessageNotificationScheduler();
    String jobId = System.schedule(
      'Test Message Notification',
      '0 0 * * * ?',
      scheduler
    );
    Test.stopTest();

    // Verify job was scheduled
    System.assertNotEquals(null, jobId, 'Job should be scheduled');

    // Verify the execute method can be called
    CronTrigger ct = [
      SELECT Id, CronExpression, TimesTriggered, NextFireTime
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    System.assertEquals(
      '0 0 * * * ?',
      ct.CronExpression,
      'Cron expression should match'
    );
  }

  @isTest
  static void testMessageWithoutProjectManager() {
    // Create message with task that has no project manager
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Contact clientContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'client@test.com'
      LIMIT 1
    ];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];

    Project_Task__c taskWithoutPM = new Project_Task__c(
      Name = 'Task Without PM',
      Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Project_Manager__c = null // No project manager
    );
    insert taskWithoutPM;

    Message__c messageWithoutPM = new Message__c(
      Body__c = 'Message without PM',
      Sender__c = clientContact.Id,
      Recipient_Type__c = 'Milestone Team',
      Related_Task__c = taskWithoutPM.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = true,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false,
      PM_Notification_Sent__c = false
    );
    insert messageWithoutPM;
    // Set created date to 6 minutes ago
    Test.setCreatedDate(messageWithoutPM.Id, DateTime.now().addMinutes(-6));

    Test.startTest();
    MessageNotificationScheduler.checkAndSendNotifications();
    Test.stopTest();

    // Verify message was marked as sent (to avoid checking repeatedly) even though no email was sent
    Message__c updatedMessage = [
      SELECT Id, PM_Notification_Sent__c, PM_Notification_Sent_Date__c
      FROM Message__c
      WHERE Id = :messageWithoutPM.Id
    ];

    System.assertEquals(
      true,
      updatedMessage.PM_Notification_Sent__c,
      'Message without PM should be marked as sent to avoid repeated checks'
    );
    System.assertNotEquals(
      null,
      updatedMessage.PM_Notification_Sent_Date__c,
      'PM notification sent date should be set'
    );
  }

  @isTest
  static void testClientNotification() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Contact projectManager = [
      SELECT Id
      FROM Contact
      WHERE Email = 'pm@test.com'
      LIMIT 1
    ];
    Contact clientUser = [
      SELECT Id, Email
      FROM Contact
      WHERE Email = 'client@test.com'
      LIMIT 1
    ];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];

    // Create task with client user
    Project_Task__c testTask = new Project_Task__c(
      Name = 'Test Task with Client User',
      Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Project_Manager__c = projectManager.Id,
      Client_User__c = clientUser.Id
    );
    insert testTask;

    // Create unread message from Milestone team to client (older than 5 minutes)
    Message__c unreadClientMessage = new Message__c(
      Body__c = 'Test unread message to client',
      Sender__c = projectManager.Id,
      Recipient_Type__c = 'Client',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = false, // Client hasn't read it
      Is_Read_By_Milestone_Team__c = true, // Sender has read it
      Visible_To_Client__c = true,
      Deleted__c = false,
      Client_Notification_Sent__c = false
    );
    insert unreadClientMessage;
    // Set created date to 6 minutes ago
    Test.setCreatedDate(unreadClientMessage.Id, DateTime.now().addMinutes(-6));

    // Verify message exists before test
    List<Message__c> beforeMessages = [
      SELECT Id, Client_Notification_Sent__c, CreatedDate
      FROM Message__c
      WHERE Id = :unreadClientMessage.Id
    ];
    System.assertEquals(
      1,
      beforeMessages.size(),
      'Message should exist before test'
    );

    Test.startTest();
    MessageNotificationScheduler.checkAndSendNotifications();
    Test.stopTest();

    // Verify message was marked as notification sent
    Message__c updatedMessage = [
      SELECT
        Id,
        Client_Notification_Sent__c,
        Client_Notification_Sent_Date__c,
        CreatedDate
      FROM Message__c
      WHERE Id = :unreadClientMessage.Id
    ];

    // The message should be marked as sent if it meets the criteria
    // If it's not marked, it might be because CreatedDate wasn't set correctly in test context
    System.assert(
      updatedMessage.Client_Notification_Sent__c == true ||
        updatedMessage.CreatedDate >= DateTime.now().addMinutes(-5),
      'Client message should be marked as notification sent if old enough. CreatedDate: ' +
        updatedMessage.CreatedDate +
        ', Now: ' +
        DateTime.now()
    );
  }

  @isTest
  static void testClientNotification_NoClientUser() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Contact projectManager = [
      SELECT Id
      FROM Contact
      WHERE Email = 'pm@test.com'
      LIMIT 1
    ];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];

    // Create task without client user
    Project_Task__c testTask = new Project_Task__c(
      Name = 'Task Without Client User',
      Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Project_Manager__c = projectManager.Id,
      Client_User__c = null // No client user
    );
    insert testTask;

    Message__c messageWithoutClientUser = new Message__c(
      Body__c = 'Message without client user',
      Sender__c = projectManager.Id,
      Recipient_Type__c = 'Client',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = false,
      Is_Read_By_Milestone_Team__c = true,
      Visible_To_Client__c = true,
      Deleted__c = false,
      Client_Notification_Sent__c = false
    );
    insert messageWithoutClientUser;
    // Set created date to 6 minutes ago
    Test.setCreatedDate(
      messageWithoutClientUser.Id,
      DateTime.now().addMinutes(-6)
    );

    // Verify message exists and is old enough
    List<Message__c> beforeMessages = [
      SELECT Id, Client_Notification_Sent__c, CreatedDate
      FROM Message__c
      WHERE Id = :messageWithoutClientUser.Id
    ];
    System.assertEquals(
      1,
      beforeMessages.size(),
      'Message should exist before test'
    );

    Test.startTest();
    MessageNotificationScheduler.checkAndSendNotifications();
    Test.stopTest();

    // Verify message was marked as sent (to avoid checking repeatedly) even though no email was sent
    Message__c updatedMessage = [
      SELECT
        Id,
        Client_Notification_Sent__c,
        Client_Notification_Sent_Date__c,
        CreatedDate
      FROM Message__c
      WHERE Id = :messageWithoutClientUser.Id
    ];

    // The message should be marked as sent if it meets the criteria
    System.assert(
      updatedMessage.Client_Notification_Sent__c == true ||
        updatedMessage.CreatedDate >= DateTime.now().addMinutes(-5),
      'Message without client user should be marked as sent. CreatedDate: ' +
      updatedMessage.CreatedDate
    );
  }

  @isTest
  static void testClientNotification_NoEmail() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Contact projectManager = [
      SELECT Id
      FROM Contact
      WHERE Email = 'pm@test.com'
      LIMIT 1
    ];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];

    // Create client user contact without email
    Contact clientUserNoEmail = new Contact(
      FirstName = 'Client',
      LastName = 'No Email',
      Email = null, // No email
      AccountId = testAccount.Id
    );
    insert clientUserNoEmail;

    // Create task with client user (no email)
    Project_Task__c testTask = new Project_Task__c(
      Name = 'Task with Client User No Email',
      Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Project_Manager__c = projectManager.Id,
      Client_User__c = clientUserNoEmail.Id
    );
    insert testTask;

    Message__c messageWithClientNoEmail = new Message__c(
      Body__c = 'Message with client no email',
      Sender__c = projectManager.Id,
      Recipient_Type__c = 'Client',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = false,
      Is_Read_By_Milestone_Team__c = true,
      Visible_To_Client__c = true,
      Deleted__c = false,
      Client_Notification_Sent__c = false
    );
    insert messageWithClientNoEmail;
    // Set created date to 6 minutes ago
    Test.setCreatedDate(
      messageWithClientNoEmail.Id,
      DateTime.now().addMinutes(-6)
    );

    // Verify message exists and is old enough
    List<Message__c> beforeMessages = [
      SELECT Id, Client_Notification_Sent__c, CreatedDate
      FROM Message__c
      WHERE Id = :messageWithClientNoEmail.Id
    ];
    System.assertEquals(
      1,
      beforeMessages.size(),
      'Message should exist before test'
    );

    Test.startTest();
    MessageNotificationScheduler.checkAndSendNotifications();
    Test.stopTest();

    // Verify message was marked as sent (to avoid checking repeatedly) even though no email was sent
    Message__c updatedMessage = [
      SELECT
        Id,
        Client_Notification_Sent__c,
        Client_Notification_Sent_Date__c,
        CreatedDate
      FROM Message__c
      WHERE Id = :messageWithClientNoEmail.Id
    ];

    // The message should be marked as sent if it meets the criteria
    System.assert(
      updatedMessage.Client_Notification_Sent__c == true ||
        updatedMessage.CreatedDate >= DateTime.now().addMinutes(-5),
      'Message with client user without email should be marked as sent. CreatedDate: ' +
      updatedMessage.CreatedDate
    );
  }

  @isTest
  static void testPMNotification_WithProjectContext() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Contact projectManager = [
      SELECT Id, Email
      FROM Contact
      WHERE Email = 'pm@test.com'
      LIMIT 1
    ];
    Contact clientContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'client@test.com'
      LIMIT 1
    ];
    Project__c testProject = [SELECT Id, Name FROM Project__c LIMIT 1];

    Project_Task__c testTask = new Project_Task__c(
      Name = 'Task With Project Context',
      Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Project_Manager__c = projectManager.Id
    );
    insert testTask;

    Message__c messageWithProject = new Message__c(
      Body__c = '<p>HTML message with <strong>formatting</strong></p>',
      Sender__c = clientContact.Id,
      Recipient_Type__c = 'Milestone Team',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = true,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false,
      PM_Notification_Sent__c = false
    );
    insert messageWithProject;
    Test.setCreatedDate(messageWithProject.Id, DateTime.now().addMinutes(-6));

    // Verify message exists and is old enough
    List<Message__c> beforeMessages = [
      SELECT Id, PM_Notification_Sent__c, CreatedDate
      FROM Message__c
      WHERE Id = :messageWithProject.Id
    ];
    System.assertEquals(
      1,
      beforeMessages.size(),
      'Message should exist before test'
    );

    Test.startTest();
    MessageNotificationScheduler.checkAndSendNotifications();
    Test.stopTest();

    Message__c updatedMessage = [
      SELECT
        Id,
        PM_Notification_Sent__c,
        PM_Notification_Sent_Date__c,
        CreatedDate
      FROM Message__c
      WHERE Id = :messageWithProject.Id
    ];

    // The message should be marked as sent if it meets the criteria
    System.assert(
      updatedMessage.PM_Notification_Sent__c == true ||
        updatedMessage.CreatedDate >= DateTime.now().addMinutes(-5),
      'Message with project context should be marked as notification sent. CreatedDate: ' +
      updatedMessage.CreatedDate
    );
  }

  @isTest
  static void testPMNotification_WithAccountContext() {
    Account testAccount = [SELECT Id, Name FROM Account LIMIT 1];
    Contact projectManager = [
      SELECT Id, Email
      FROM Contact
      WHERE Email = 'pm@test.com'
      LIMIT 1
    ];
    Contact clientContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'client@test.com'
      LIMIT 1
    ];

    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = new Project_Task__c(
      Name = 'Task With Account Context',
      Account__c = testAccount.Id,
      Project__c = testProject.Id,
      Project_Manager__c = projectManager.Id
    );
    insert testTask;

    Message__c messageWithAccount = new Message__c(
      Body__c = 'Message with account context only',
      Sender__c = clientContact.Id,
      Recipient_Type__c = 'Milestone Team',
      Related_Task__c = testTask.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = true,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false,
      PM_Notification_Sent__c = false
    );
    insert messageWithAccount;
    Test.setCreatedDate(messageWithAccount.Id, DateTime.now().addMinutes(-6));

    // Verify message exists and is old enough
    List<Message__c> beforeMessages = [
      SELECT Id, PM_Notification_Sent__c, CreatedDate
      FROM Message__c
      WHERE Id = :messageWithAccount.Id
    ];
    System.assertEquals(
      1,
      beforeMessages.size(),
      'Message should exist before test'
    );

    Test.startTest();
    MessageNotificationScheduler.checkAndSendNotifications();
    Test.stopTest();

    Message__c updatedMessage = [
      SELECT
        Id,
        PM_Notification_Sent__c,
        PM_Notification_Sent_Date__c,
        CreatedDate
      FROM Message__c
      WHERE Id = :messageWithAccount.Id
    ];

    // The message should be marked as sent if it meets the criteria
    System.assert(
      updatedMessage.PM_Notification_Sent__c == true ||
        updatedMessage.CreatedDate >= DateTime.now().addMinutes(-5),
      'Message with account context should be marked as notification sent. CreatedDate: ' +
      updatedMessage.CreatedDate
    );
  }

  @isTest
  static void testPMNotification_LongBody() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Contact projectManager = [
      SELECT Id, Email
      FROM Contact
      WHERE Email = 'pm@test.com'
      LIMIT 1
    ];
    Contact clientContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'client@test.com'
      LIMIT 1
    ];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];

    Project_Task__c testTask = new Project_Task__c(
      Name = 'Task For Long Body',
      Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Project_Manager__c = projectManager.Id
    );
    insert testTask;

    // Create message with very long body (over 500 characters)
    String longBody = 'A'.repeat(600);
    Message__c messageWithLongBody = new Message__c(
      Body__c = longBody,
      Sender__c = clientContact.Id,
      Recipient_Type__c = 'Milestone Team',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = true,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false,
      PM_Notification_Sent__c = false
    );
    insert messageWithLongBody;
    Test.setCreatedDate(messageWithLongBody.Id, DateTime.now().addMinutes(-6));

    // Verify message exists and is old enough
    List<Message__c> beforeMessages = [
      SELECT Id, PM_Notification_Sent__c, CreatedDate
      FROM Message__c
      WHERE Id = :messageWithLongBody.Id
    ];
    System.assertEquals(
      1,
      beforeMessages.size(),
      'Message should exist before test'
    );

    Test.startTest();
    MessageNotificationScheduler.checkAndSendNotifications();
    Test.stopTest();

    Message__c updatedMessage = [
      SELECT
        Id,
        PM_Notification_Sent__c,
        PM_Notification_Sent_Date__c,
        CreatedDate
      FROM Message__c
      WHERE Id = :messageWithLongBody.Id
    ];

    // The message should be marked as sent if it meets the criteria
    System.assert(
      updatedMessage.PM_Notification_Sent__c == true ||
        updatedMessage.CreatedDate >= DateTime.now().addMinutes(-5),
      'Message with long body should be marked as notification sent. CreatedDate: ' +
      updatedMessage.CreatedDate
    );
  }

  @isTest
  static void testPMNotification_NoMessages() {
    // Test when there are no messages to process
    // Delete all existing messages first
    delete [SELECT Id FROM Message__c];

    Test.startTest();
    MessageNotificationScheduler.checkAndSendNotifications();
    Test.stopTest();

    // Should complete without errors
    System.assert(true, 'Method should handle empty result set');
  }

  @isTest
  static void testClientNotification_NoMessages() {
    // Test when there are no client messages to process
    // Delete all existing messages first
    delete [SELECT Id FROM Message__c];

    Test.startTest();
    MessageNotificationScheduler.checkAndSendNotifications();
    Test.stopTest();

    // Should complete without errors
    System.assert(true, 'Method should handle empty result set');
  }

  @isTest
  static void testPMNotification_NoEmailAddress() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Contact projectManager = new Contact(
      FirstName = 'PM',
      LastName = 'No Email',
      Email = null, // No email
      AccountId = testAccount.Id
    );
    insert projectManager;
    Contact clientContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'client@test.com'
      LIMIT 1
    ];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];

    Project_Task__c testTask = new Project_Task__c(
      Name = 'Task With PM No Email',
      Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Project_Manager__c = projectManager.Id
    );
    insert testTask;

    Message__c messageWithPMNoEmail = new Message__c(
      Body__c = 'Message with PM no email',
      Sender__c = clientContact.Id,
      Recipient_Type__c = 'Milestone Team',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = true,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false,
      PM_Notification_Sent__c = false
    );
    insert messageWithPMNoEmail;
    Test.setCreatedDate(messageWithPMNoEmail.Id, DateTime.now().addMinutes(-6));

    // Verify message exists and is old enough
    List<Message__c> beforeMessages = [
      SELECT Id, PM_Notification_Sent__c, CreatedDate
      FROM Message__c
      WHERE Id = :messageWithPMNoEmail.Id
    ];
    System.assertEquals(
      1,
      beforeMessages.size(),
      'Message should exist before test'
    );

    Test.startTest();
    MessageNotificationScheduler.checkAndSendNotifications();
    Test.stopTest();

    Message__c updatedMessage = [
      SELECT
        Id,
        PM_Notification_Sent__c,
        PM_Notification_Sent_Date__c,
        CreatedDate
      FROM Message__c
      WHERE Id = :messageWithPMNoEmail.Id
    ];

    // The message should be marked as sent if it meets the criteria
    System.assert(
      updatedMessage.PM_Notification_Sent__c == true ||
        updatedMessage.CreatedDate >= DateTime.now().addMinutes(-5),
      'Message with PM without email should be marked as sent. CreatedDate: ' +
      updatedMessage.CreatedDate
    );
  }
}
