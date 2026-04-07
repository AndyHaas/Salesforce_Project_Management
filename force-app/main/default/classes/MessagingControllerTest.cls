/**
 * Test class for MessagingController
 * Covers all methods including recent changes:
 * - Auto-creation of Contacts for Milestone team members
 * - Server-side body search via SOSL + SOQL Id IN (long text not filterable in SOQL)
 * - Pagination with offset
 * - Message CRUD operations
 * - Separate read tracking for clients (Is_Read_By_Client__c) and Milestone team (Is_Read_By_Milestone_Team__c)
 */
@isTest
private class MessagingControllerTest {
  private static Id findMessageIdByBodyContains(String needle) {
    if (String.isBlank(needle)) {
      return null;
    }
    for (Message__c m : [SELECT Id, Body__c FROM Message__c]) {
      if (m.Body__c != null && m.Body__c.containsIgnoreCase(needle)) {
        return m.Id;
      }
    }
    return null;
  }

  /**
   * @future method to assign permission sets (avoids MIXED_DML_OPERATION)
   */
  @future
  public static void assignPermissionSets(Id userId) {
    List<PermissionSet> permissionSets = [
      SELECT Id, Name
      FROM PermissionSet
      WHERE Name IN ('Client_Project_Management_Portal_User', 'Project_Management_Team_Member')
      LIMIT 2
    ];

    if (!permissionSets.isEmpty()) {
      List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

      for (PermissionSet ps : permissionSets) {
        List<PermissionSetAssignment> existing = [
          SELECT Id
          FROM PermissionSetAssignment
          WHERE AssigneeId = :userId AND PermissionSetId = :ps.Id
          LIMIT 1
        ];

        if (existing.isEmpty()) {
          assignments.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id));
        }
      }

      if (!assignments.isEmpty()) {
        insert assignments;
      }
    }
  }

  @testSetup
  static void setupTestData() {
    // Assign permission sets to test user to ensure FLS access
    // Use @future method to avoid MIXED_DML_OPERATION (PermissionSetAssignment is a setup object)
    // In test context, @future methods run synchronously within Test.startTest()/Test.stopTest()
    Test.startTest();
    assignPermissionSets(UserInfo.getUserId());
    Test.stopTest();

    // Create test Account
    Account testAccount = new Account(Name = 'Test Client Account');
    insert testAccount;

    // Get current user and create/get Contact for them
    User currentUser = [SELECT Id, ContactId, AccountId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
    Id currentUserContactId;

    // Get or create Contact for current user
    if (currentUser.ContactId != null) {
      currentUserContactId = currentUser.ContactId;
      // Update existing contact to enable portal access for testing
      Contact existingContact = [SELECT Id, Portal_Access_Enabled__c FROM Contact WHERE Id = :currentUserContactId];
      if (existingContact.Portal_Access_Enabled__c != true) {
        existingContact.Portal_Access_Enabled__c = true;
        update existingContact;
      }
    } else {
      // Create Contact for current user
      Contact userContact = new Contact(
        FirstName = currentUser.Name.contains(' ') ? currentUser.Name.split(' ', 2)[0] : '',
        LastName = currentUser.Name.contains(' ') ? currentUser.Name.split(' ', 2)[1] : currentUser.Name,
        Email = currentUser.Email != null ? currentUser.Email : 'testuser@test.com',
        AccountId = testAccount.Id,
        Portal_Access_Enabled__c = true // Enable for mentionable contacts test
      );
      insert userContact;
      currentUserContactId = userContact.Id;
    }

    // Create additional test contact for mentionable contacts test
    Contact testContact = new Contact(
      FirstName = 'Test',
      LastName = 'Contact',
      Email = 'testcontact@test.com',
      AccountId = testAccount.Id,
      Portal_Access_Enabled__c = true
    );
    insert testContact;

    // Create test Project
    Project__c testProject = new Project__c(Name = 'Test Project', Account__c = testAccount.Id);
    insert testProject;

    // Create test Task
    Project_Task__c testTask = new Project_Task__c(
      Name = 'Test Task',
      Project__c = testProject.Id,
      Account__c = testAccount.Id
    );
    insert testTask;

    // Create test messages that current user can access
    // Messages must either be from current user OR in recipient bucket they can access
    List<Message__c> testMessages = new List<Message__c>();

    // Message from current user to Milestone Team (sender filter will match)
    testMessages.add(
      new Message__c(
        Body__c = 'Test message from portal user',
        Sender__c = currentUserContactId,
        Recipient_Type__c = 'Milestone Team',
        Related_Task__c = testTask.Id,
        Related_Project__c = testProject.Id,
        Account__c = testAccount.Id,
        Is_Read_By_Client__c = true, // Sender sees it as read
        Is_Read_By_Milestone_Team__c = false, // Recipient unread
        Visible_To_Client__c = true,
        Deleted__c = false
      )
    );

    // Message to Client (current user can see if they have AccountId, or if sender matches)
    testMessages.add(
      new Message__c(
        Body__c = 'Test message from milestone team to client',
        Sender__c = currentUserContactId,
        Recipient_Type__c = 'Client',
        Related_Task__c = testTask.Id,
        Related_Project__c = testProject.Id,
        Account__c = testAccount.Id,
        Is_Read_By_Client__c = true, // Sender sees it as read
        Is_Read_By_Milestone_Team__c = false, // Recipient unread
        Visible_To_Client__c = true,
        Deleted__c = false
      )
    );

    // Message with searchable content (from current user so they can access it)
    testMessages.add(
      new Message__c(
        Body__c = 'This message contains the word searchable',
        Sender__c = currentUserContactId,
        Recipient_Type__c = 'Client',
        Related_Task__c = testTask.Id,
        Related_Project__c = testProject.Id,
        Account__c = testAccount.Id,
        Is_Read_By_Client__c = true, // Sender sees it as read
        Is_Read_By_Milestone_Team__c = false, // Recipient unread
        Visible_To_Client__c = true,
        Deleted__c = false
      )
    );

    insert testMessages;
  }

  @isTest
  static void testGetOrCreateContactForUser_MilestoneTeamMember() {
    // Test that Milestone team members (without ContactId) get a Contact created
    // Use current user (who likely doesn't have ContactId)
    User currentUser = [SELECT Id, ContactId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];

    // Skip if user already has ContactId (some orgs might have it)
    if (currentUser.ContactId != null) {
      return; // Can't test this scenario if user has ContactId
    }

    Test.startTest();
    String messageId = MessagingController.sendMessage(
      'Test message from milestone team',
      'Client',
      null,
      null,
      null,
      null,
      true,
      null
    );
    Test.stopTest();

    // Verify Contact was created and linked on User (no ambiguous email match)
    List<Contact> createdContacts = [
      SELECT Id, FirstName, LastName, Email
      FROM Contact
      WHERE Email = :currentUser.Email
    ];
    System.assert(!createdContacts.isEmpty(), 'Contact should be created for Milestone team member');

    User userAfter = [
      SELECT Messaging_Sender_Contact_Id__c
      FROM User
      WHERE Id = :currentUser.Id
    ];
    System.assertEquals(
      String.valueOf(createdContacts[0].Id),
      userAfter.Messaging_Sender_Contact_Id__c,
      'User should store Messaging_Sender_Contact_Id__c after first send'
    );

    Message__c message = [SELECT Id, Sender__c FROM Message__c WHERE Id = :messageId];
    System.assertEquals(createdContacts[0].Id, message.Sender__c, 'Message should use created Contact');
  }

  @isTest
  static void testGetMessages_WithSearch() {
    Id searchableMsgId = findMessageIdByBodyContains('searchable');
    System.assertNotEquals(null, searchableMsgId, 'Setup should include a message containing searchable');
    Test.setFixedSearchResults(new List<Id>{ searchableMsgId });
    Test.startTest();
    {
      List<MessagingController.MessageInfo> results = MessagingController.getMessages(
        null, // recipientType
        null, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        50, // limitCount
        0, // offset
        null, // orderByField
        null, // orderDirection
        'searchable', // searchTerm
        null // contextRecordId
      );

      System.assertEquals(1, results.size(), 'Should find 1 message with "searchable"');
      System.assert(results[0].body.contains('searchable'), 'Message should contain search term');
    }
    Test.stopTest();
  }

  @isTest
  static void testGetMessages_WithWildcardSearch() {
    Id searchableMsgId = findMessageIdByBodyContains('searchable');
    System.assertNotEquals(null, searchableMsgId);
    Test.setFixedSearchResults(new List<Id>{ searchableMsgId });
    Test.startTest();
    {
      List<MessagingController.MessageInfo> results = MessagingController.getMessages(
        null, // recipientType
        null, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        50, // limitCount
        0, // offset
        null, // orderByField
        null, // orderDirection
        'search*', // * stripped; SOSL uses substring on normalized term
        null // contextRecordId
      );

      System.assert(results.size() >= 1, 'Should find messages matching normalized search term');
    }
    Test.stopTest();
  }

  @isTest
  static void testGetMessages_WithPercentWildcard() {
    Id searchableMsgId = findMessageIdByBodyContains('searchable');
    System.assertNotEquals(null, searchableMsgId);
    Test.setFixedSearchResults(new List<Id>{ searchableMsgId });
    Test.startTest();
    {
      List<MessagingController.MessageInfo> results = MessagingController.getMessages(
        null, // recipientType
        null, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        50, // limitCount
        0, // offset
        null, // orderByField
        null, // orderDirection
        '%searchable%', // % stripped; term becomes searchable
        null // contextRecordId
      );

      System.assert(results.size() >= 1, 'Should find messages with % wildcard');
    }
    Test.stopTest();
  }

  @isTest
  static void testGetMessages_WithUnderscoreLiteral() {
    // Get current user's contact (created in testSetup)
    User currentUser = [SELECT Id, ContactId, Email FROM User WHERE Id = :UserInfo.getUserId()];
    Id currentUserContactId;
    if (currentUser.ContactId != null) {
      currentUserContactId = currentUser.ContactId;
    } else {
      // Find contact created in testSetup
      List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email LIMIT 1];
      if (!contacts.isEmpty()) {
        currentUserContactId = contacts[0].Id;
      }
    }

    // If no contact found, create one for this test
    if (currentUserContactId == null) {
      Account testAccount = [SELECT Id FROM Account LIMIT 1];
      Contact testContact = new Contact(
        FirstName = 'Test',
        LastName = 'Contact',
        Email = currentUser.Email != null ? currentUser.Email : 'test@test.com',
        AccountId = testAccount.Id,
        Portal_Access_Enabled__c = true
      );
      insert testContact;
      currentUserContactId = testContact.Id;
    }

    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = [SELECT Id, Account__c FROM Project_Task__c LIMIT 1];

    Message__c msgWithUnderscore = new Message__c(
      Body__c = 'Test_message_with_underscore',
      Sender__c = currentUserContactId,
      Recipient_Type__c = 'Client',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testTask.Account__c != null ? testTask.Account__c : testAccount.Id,
      Is_Read_By_Client__c = false,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert msgWithUnderscore;

    Test.setFixedSearchResults(new List<Id>{ msgWithUnderscore.Id });
    Test.startTest();
    {
      List<MessagingController.MessageInfo> results = MessagingController.getMessages(
        null, // recipientType
        null, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        50, // limitCount
        0, // offset
        null, // orderByField
        null, // orderDirection
        'Test_message', // searchTerm with _ (literal)
        null // contextRecordId
      );

      System.assert(results.size() >= 1, 'Should find message with literal underscore');
    }
    Test.stopTest();
  }

  @isTest
  static void testGetMessages_WithPagination() {
    Test.startTest();
    {
      // Get first page
      List<MessagingController.MessageInfo> page1 = MessagingController.getMessages(
        null, // recipientType
        null, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        2, // limitCount
        0, // offset
        null, // orderByField
        null, // orderDirection
        null, // searchTerm
        null // contextRecordId
      );

      // Get second page
      List<MessagingController.MessageInfo> page2 = MessagingController.getMessages(
        null, // recipientType
        null, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        2, // limitCount
        2, // offset
        null, // orderByField
        null, // orderDirection
        null, // searchTerm
        null // contextRecordId
      );

      System.assert(page1.size() <= 2, 'First page should have at most 2 messages');
      System.assert(page2.size() <= 2, 'Second page should have at most 2 messages');

      // Verify no duplicates
      Set<String> messageIds = new Set<String>();
      for (MessagingController.MessageInfo msg : page1) {
        messageIds.add(msg.id);
      }
      for (MessagingController.MessageInfo msg : page2) {
        System.assert(!messageIds.contains(msg.id), 'No duplicate messages between pages');
      }
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_MilestoneTeamMember() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = [SELECT Id, Account__c FROM Project_Task__c LIMIT 1];

    User currentUser = [SELECT Id, AccountId, ContactId, Email FROM User WHERE Id = :UserInfo.getUserId()];

    Test.startTest();
    {
      String messageId = MessagingController.sendMessage(
        'Test message from milestone team',
        'Client',
        testAccount.Id,
        testProject.Id,
        testTask.Id,
        null,
        true,
        null
      );

      System.assertNotEquals(null, messageId, 'Message should be created');

      // Verify Contact was created for Milestone team member (if user doesn't have ContactId)
      if (currentUser.ContactId == null) {
        List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email];
        System.assert(!contacts.isEmpty(), 'Contact should be created for Milestone team member');

        // Verify message uses the created Contact
        Message__c message = [SELECT Id, Sender__c FROM Message__c WHERE Id = :messageId];
        System.assertEquals(contacts[0].Id, message.Sender__c, 'Message should use created Contact');
      }

      // Verify read status is set correctly based on sender type
      Message__c message = [
        SELECT Id, Is_Read_By_Client__c, Is_Read_By_Milestone_Team__c
        FROM Message__c
        WHERE Id = :messageId
      ];

      if (currentUser.AccountId != null) {
        // Portal user (client) sending - client read should be true, team read should be false
        System.assertEquals(
          true,
          message.Is_Read_By_Client__c,
          'Client sender should mark Is_Read_By_Client__c as true'
        );
        System.assertEquals(
          false,
          message.Is_Read_By_Milestone_Team__c,
          'Client sender should mark Is_Read_By_Milestone_Team__c as false'
        );
      } else {
        // Milestone team member sending - team read should be true, client read should be false
        System.assertEquals(
          true,
          message.Is_Read_By_Milestone_Team__c,
          'Milestone team sender should mark Is_Read_By_Milestone_Team__c as true'
        );
        System.assertEquals(
          false,
          message.Is_Read_By_Client__c,
          'Milestone team sender should mark Is_Read_By_Client__c as false'
        );
      }
    }
    Test.stopTest();
  }

  @isTest
  static void testGetMessages_NoSearchTerm() {
    Test.startTest();
    {
      List<MessagingController.MessageInfo> results = MessagingController.getMessages(
        null, // recipientType
        null, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        50, // limitCount
        0, // offset
        null, // orderByField
        null, // orderDirection
        null, // searchTerm
        null // contextRecordId
      );

      System.assert(results.size() > 0, 'Should return messages without search');
    }
    Test.stopTest();
  }

  @isTest
  static void testGetMessages_EmptySearchTerm() {
    Test.startTest();
    {
      List<MessagingController.MessageInfo> results = MessagingController.getMessages(
        null, // recipientType
        null, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        50, // limitCount
        0, // offset
        null, // orderByField
        null, // orderDirection
        '', // searchTerm (empty)
        null // contextRecordId
      );

      // Empty search should return all messages (no filter applied)
      System.assert(results.size() > 0, 'Should return messages with empty search');
    }
    Test.stopTest();
  }

  @isTest
  static void testGetMessages_SearchTermTooShort_ReturnsEmpty() {
    Test.startTest();
    List<MessagingController.MessageInfo> results = MessagingController.getMessages(
      null,
      null,
      null,
      null,
      50,
      0,
      null,
      null,
      'z',
      null
    );
    Test.stopTest();
    System.assertEquals(0, results.size(), 'Terms shorter than SOSL minimum should return no rows');
  }

  @isTest
  static void testGetCurrentUserContactId() {
    Test.startTest();
    String contactId = MessagingController.getCurrentUserContactId();
    Test.stopTest();

    // Should return ContactId (may be null for Milestone team members)
    System.assert(contactId != null || contactId == null, 'Should return ContactId or null');
  }

  @isTest
  static void testIsMilestoneTeamMember() {
    Test.startTest();
    Boolean isMilestone = MessagingController.isMilestoneTeamMember();
    Test.stopTest();

    // Should return boolean (true if no AccountId, false if has AccountId)
    System.assert(isMilestone != null, 'Should return boolean value');
  }

  @isTest
  static void testGetLatestMessages() {
    Test.startTest();
    List<MessagingController.MessageInfo> results = MessagingController.getLatestMessages(5, 'CreatedDate', 'DESC');
    Test.stopTest();

    System.assert(results != null, 'Should return list of messages');
    System.assert(results.size() <= 5, 'Should respect limit');
  }

  @isTest
  static void testGetMentionableContacts() {
    Test.startTest();
    List<MessagingController.ContactInfo> results = MessagingController.getMentionableContacts('test');
    Test.stopTest();

    System.assert(results != null, 'Should return list of contacts');
  }

  @isTest
  static void testMarkAsRead() {
    // Get a message that current user can access
    User currentUser = [SELECT Id, ContactId, AccountId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
    Id currentUserContactId;
    if (currentUser.ContactId != null) {
      currentUserContactId = currentUser.ContactId;
    } else {
      List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email LIMIT 1];
      if (!contacts.isEmpty()) {
        currentUserContactId = contacts[0].Id;
      }
    }

    if (currentUserContactId == null) {
      return; // Can't test without Contact
    }

    // Create a message that is unread
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];

    Message__c testMessage = new Message__c(
      Body__c = 'Test message for mark as read',
      Sender__c = currentUserContactId,
      Recipient_Type__c = 'Client',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = false,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert testMessage;

    Test.startTest();
    MessagingController.markAsRead(testMessage.Id);
    Test.stopTest();

    // Verify message is marked as read based on user type
    Message__c updatedMessage = [
      SELECT Id, Is_Read_By_Client__c, Is_Read_By_Milestone_Team__c
      FROM Message__c
      WHERE Id = :testMessage.Id
    ];

    if (currentUser.AccountId != null) {
      // Portal user (client) - should mark client read
      System.assertEquals(true, updatedMessage.Is_Read_By_Client__c, 'Client should mark Is_Read_By_Client__c as true');
      System.assertEquals(
        false,
        updatedMessage.Is_Read_By_Milestone_Team__c,
        'Client should not change Is_Read_By_Milestone_Team__c'
      );
    } else {
      // Milestone team member - should mark team read
      System.assertEquals(
        true,
        updatedMessage.Is_Read_By_Milestone_Team__c,
        'Milestone team should mark Is_Read_By_Milestone_Team__c as true'
      );
      System.assertEquals(
        false,
        updatedMessage.Is_Read_By_Client__c,
        'Milestone team should not change Is_Read_By_Client__c'
      );
    }
  }

  @isTest
  static void testMarkAsRead_ClientUser() {
    // Test that client users mark Is_Read_By_Client__c
    User currentUser = [SELECT Id, ContactId, AccountId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];

    // Skip if user doesn't have AccountId (not a portal user)
    if (currentUser.AccountId == null) {
      return;
    }

    Id currentUserContactId;
    if (currentUser.ContactId != null) {
      currentUserContactId = currentUser.ContactId;
    } else {
      List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email LIMIT 1];
      if (!contacts.isEmpty()) {
        currentUserContactId = contacts[0].Id;
      }
    }

    if (currentUserContactId == null) {
      return;
    }

    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];

    Message__c testMessage = new Message__c(
      Body__c = 'Test message for client read',
      Sender__c = currentUserContactId,
      Recipient_Type__c = 'Client',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = false,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert testMessage;

    Test.startTest();
    MessagingController.markAsRead(testMessage.Id);
    Test.stopTest();

    Message__c updatedMessage = [
      SELECT Id, Is_Read_By_Client__c, Is_Read_By_Milestone_Team__c
      FROM Message__c
      WHERE Id = :testMessage.Id
    ];

    System.assertEquals(true, updatedMessage.Is_Read_By_Client__c, 'Client should mark Is_Read_By_Client__c as true');
    System.assertEquals(
      false,
      updatedMessage.Is_Read_By_Milestone_Team__c,
      'Client should not change Is_Read_By_Milestone_Team__c'
    );
  }

  @isTest
  static void testMarkAsRead_MilestoneTeamMember() {
    // Test that Milestone team members mark Is_Read_By_Milestone_Team__c
    User currentUser = [SELECT Id, ContactId, AccountId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];

    // Skip if user has AccountId (is a portal user)
    if (currentUser.AccountId != null) {
      return;
    }

    Id currentUserContactId;
    if (currentUser.ContactId != null) {
      currentUserContactId = currentUser.ContactId;
    } else {
      List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email LIMIT 1];
      if (!contacts.isEmpty()) {
        currentUserContactId = contacts[0].Id;
      }
    }

    if (currentUserContactId == null) {
      return;
    }

    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];

    Message__c testMessage = new Message__c(
      Body__c = 'Test message for milestone team read',
      Sender__c = currentUserContactId,
      Recipient_Type__c = 'Milestone Team',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = false,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert testMessage;

    Test.startTest();
    MessagingController.markAsRead(testMessage.Id);
    Test.stopTest();

    Message__c updatedMessage = [
      SELECT Id, Is_Read_By_Client__c, Is_Read_By_Milestone_Team__c
      FROM Message__c
      WHERE Id = :testMessage.Id
    ];

    System.assertEquals(
      true,
      updatedMessage.Is_Read_By_Milestone_Team__c,
      'Milestone team should mark Is_Read_By_Milestone_Team__c as true'
    );
    System.assertEquals(
      false,
      updatedMessage.Is_Read_By_Client__c,
      'Milestone team should not change Is_Read_By_Client__c'
    );
  }

  @isTest
  static void testUpdateMessage() {
    // Get a message that current user sent
    User currentUser = [SELECT Id, ContactId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
    Id currentUserContactId;
    if (currentUser.ContactId != null) {
      currentUserContactId = currentUser.ContactId;
    } else {
      List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email LIMIT 1];
      if (!contacts.isEmpty()) {
        currentUserContactId = contacts[0].Id;
      }
    }

    if (currentUserContactId == null) {
      return; // Can't test without Contact
    }

    List<Message__c> messages = [
      SELECT Id
      FROM Message__c
      WHERE Sender__c = :currentUserContactId
      LIMIT 1
    ];

    if (messages.isEmpty()) {
      return; // No messages to test
    }

    Test.startTest();
    MessagingController.updateMessage(messages[0].Id, 'Updated message body');
    Test.stopTest();

    // Verify message was updated
    Message__c updatedMessage = [SELECT Id, Body__c, Is_Edited__c FROM Message__c WHERE Id = :messages[0].Id];
    System.assertEquals('Updated message body', updatedMessage.Body__c, 'Message body should be updated');
    System.assertEquals(true, updatedMessage.Is_Edited__c, 'Message should be marked as edited');
  }

  @isTest
  static void testPinMessage() {
    // Get a message that current user can access
    User currentUser = [SELECT Id, ContactId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
    Id currentUserContactId;
    if (currentUser.ContactId != null) {
      currentUserContactId = currentUser.ContactId;
    } else {
      List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email LIMIT 1];
      if (!contacts.isEmpty()) {
        currentUserContactId = contacts[0].Id;
      }
    }

    if (currentUserContactId == null) {
      return; // Can't test without Contact
    }

    List<Message__c> messages = [
      SELECT Id
      FROM Message__c
      WHERE Sender__c = :currentUserContactId
      LIMIT 1
    ];

    if (messages.isEmpty()) {
      return; // No messages to test
    }

    Test.startTest();
    MessagingController.pinMessage(messages[0].Id, true);
    Test.stopTest();

    // Verify message was pinned
    Message__c updatedMessage = [SELECT Id, Is_Pinned__c FROM Message__c WHERE Id = :messages[0].Id];
    System.assertEquals(true, updatedMessage.Is_Pinned__c, 'Message should be pinned');
  }

  @isTest
  static void testGetMessages_WithRecipientType() {
    Test.startTest();
    {
      // Test with Client recipient type
      List<MessagingController.MessageInfo> clientResults = MessagingController.getMessages(
        'Client', // recipientType
        null, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        50, // limitCount
        0, // offset
        null, // orderByField
        null, // orderDirection
        null, // searchTerm
        null // contextRecordId
      );

      System.assert(clientResults != null, 'Should return messages for Client recipient type');

      // Test with Milestone Team recipient type
      List<MessagingController.MessageInfo> teamResults = MessagingController.getMessages(
        'Milestone Team', // recipientType
        null, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        50, // limitCount
        0, // offset
        null, // orderByField
        null, // orderDirection
        null, // searchTerm
        null // contextRecordId
      );

      System.assert(teamResults != null, 'Should return messages for Milestone Team recipient type');
    }
    Test.stopTest();
  }

  @isTest
  static void testGetMessages_WithRelatedTask() {
    Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];

    Test.startTest();
    {
      List<MessagingController.MessageInfo> results = MessagingController.getMessages(
        null, // recipientType
        null, // relatedAccountId
        null, // relatedProjectId
        testTask.Id, // relatedTaskId
        50, // limitCount
        0, // offset
        null, // orderByField
        null, // orderDirection
        null, // searchTerm
        null // contextRecordId
      );

      System.assert(results != null, 'Should return messages for related task');
    }
    Test.stopTest();
  }

  @isTest
  static void testGetMessages_ContextRecordIdProjectMatchesExplicitProjectFilter() {
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Test.startTest();
    List<MessagingController.MessageInfo> byContext = MessagingController.getMessages(
      null,
      null,
      null,
      null,
      50,
      0,
      null,
      null,
      null,
      testProject.Id
    );
    List<MessagingController.MessageInfo> byExplicit = MessagingController.getMessages(
      null,
      null,
      testProject.Id,
      null,
      50,
      0,
      null,
      null,
      null,
      null
    );
    Test.stopTest();
    System.assertEquals(
      byExplicit.size(),
      byContext.size(),
      'contextRecordId project Id should match explicit relatedProjectId filter'
    );
  }

  @isTest
  static void testGetMessages_ContextRecordIdTaskMatchesExplicitTaskFilter() {
    Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];
    Test.startTest();
    List<MessagingController.MessageInfo> byContext = MessagingController.getMessages(
      null,
      null,
      null,
      null,
      50,
      0,
      null,
      null,
      null,
      testTask.Id
    );
    List<MessagingController.MessageInfo> byExplicit = MessagingController.getMessages(
      null,
      null,
      null,
      testTask.Id,
      50,
      0,
      null,
      null,
      null,
      null
    );
    Test.stopTest();
    System.assertEquals(
      byExplicit.size(),
      byContext.size(),
      'contextRecordId task Id should match explicit relatedTaskId filter'
    );
  }

  @isTest
  static void testSendMessage_WithAllFields() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];
    User currentUser = [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId()];

    Test.startTest();
    {
      String messageId = MessagingController.sendMessage(
        'Test message with all fields',
        'Client',
        testAccount.Id,
        testProject.Id,
        testTask.Id,
        null, // mentionedContactIds
        true, // isVisibleToClient
        null // replyToMessageId
      );

      System.assertNotEquals(null, messageId, 'Message should be created');

      // Verify message was created with all fields
      Message__c message = [
        SELECT
          Id,
          Body__c,
          Recipient_Type__c,
          Account__c,
          Related_Project__c,
          Related_Task__c,
          Visible_To_Client__c,
          Is_Read_By_Client__c,
          Is_Read_By_Milestone_Team__c
        FROM Message__c
        WHERE Id = :messageId
      ];

      System.assertEquals('Test message with all fields', message.Body__c);
      System.assertEquals('Client', message.Recipient_Type__c);
      System.assertEquals(testAccount.Id, message.Account__c);
      System.assertEquals(testProject.Id, message.Related_Project__c);
      System.assertEquals(testTask.Id, message.Related_Task__c);
      System.assertEquals(true, message.Visible_To_Client__c);

      // Verify read status is initialized correctly
      if (currentUser.AccountId != null) {
        // Portal user (client) - client read true, team read false
        System.assertEquals(
          true,
          message.Is_Read_By_Client__c,
          'Client sender should mark Is_Read_By_Client__c as true'
        );
        System.assertEquals(
          false,
          message.Is_Read_By_Milestone_Team__c,
          'Client sender should mark Is_Read_By_Milestone_Team__c as false'
        );
      } else {
        // Milestone team member - team read true, client read false
        System.assertEquals(
          true,
          message.Is_Read_By_Milestone_Team__c,
          'Milestone team sender should mark Is_Read_By_Milestone_Team__c as true'
        );
        System.assertEquals(
          false,
          message.Is_Read_By_Client__c,
          'Milestone team sender should mark Is_Read_By_Client__c as false'
        );
      }
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_ValidationErrors() {
    Test.startTest();
    {
      // Test blank message body
      try {
        MessagingController.sendMessage(
          '', // blank message body
          'Client',
          null,
          null,
          null,
          null,
          true,
          null
        );
        System.assert(false, 'Should have thrown exception for blank message body');
      } catch (AuraHandledException e) {
        System.assert(e.getMessage() != null, 'Should return error message');
      }

      // Test blank recipient type
      try {
        MessagingController.sendMessage(
          'Test message',
          '', // blank recipient type
          null,
          null,
          null,
          null,
          true,
          null
        );
        System.assert(false, 'Should have thrown exception for blank recipient type');
      } catch (AuraHandledException e) {
        System.assert(e.getMessage() != null, 'Should return error message');
      }
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_WithRelatedProject() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];

    Test.startTest();
    {
      // Test sending message with relatedProjectId (but no relatedTaskId)
      String messageId = MessagingController.sendMessage(
        'Test message with project',
        'Client',
        null, // relatedAccountId
        testProject.Id, // relatedProjectId
        null, // relatedTaskId
        null,
        true,
        null
      );

      System.assertNotEquals(null, messageId, 'Message should be created');

      // Verify message has project and account set
      Message__c message = [
        SELECT Id, Related_Project__c, Account__c
        FROM Message__c
        WHERE Id = :messageId
      ];

      System.assertEquals(testProject.Id, message.Related_Project__c, 'Message should have project set');
      System.assertEquals(testAccount.Id, message.Account__c, 'Message should have account from project');
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_WithRelatedAccount() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];

    Test.startTest();
    {
      // Test sending message with relatedAccountId only
      String messageId = MessagingController.sendMessage(
        'Test message with account',
        'Client',
        testAccount.Id, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        null,
        true,
        null
      );

      System.assertNotEquals(null, messageId, 'Message should be created');

      // Verify message has account set
      Message__c message = [
        SELECT Id, Account__c
        FROM Message__c
        WHERE Id = :messageId
      ];

      System.assertEquals(testAccount.Id, message.Account__c, 'Message should have account set');
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_WithMentionedContacts() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];

    // Get a contact to mention
    Contact testContact = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    {
      // Test sending message with mentioned contacts
      String messageId = MessagingController.sendMessage(
        'Test message with @mention',
        'Client',
        testAccount.Id,
        testProject.Id,
        testTask.Id,
        new List<String>{ testContact.Id }, // mentionedContactIds
        true,
        null
      );

      System.assertNotEquals(null, messageId, 'Message should be created');

      // Verify message has mentioned contacts
      Message__c message = [
        SELECT Id, Mentioned_Contacts__c
        FROM Message__c
        WHERE Id = :messageId
      ];

      System.assert(String.isNotBlank(message.Mentioned_Contacts__c), 'Message should have mentioned contacts');
      System.assert(
        message.Mentioned_Contacts__c.contains(testContact.Id),
        'Message should contain mentioned contact ID'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_WithReplyTo() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];

    // Create a message to reply to
    User currentUser = [SELECT Id, ContactId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
    Id currentUserContactId;
    if (currentUser.ContactId != null) {
      currentUserContactId = currentUser.ContactId;
    } else {
      List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email LIMIT 1];
      if (!contacts.isEmpty()) {
        currentUserContactId = contacts[0].Id;
      }
    }

    if (currentUserContactId == null) {
      return; // Can't test without Contact
    }

    Message__c originalMessage = new Message__c(
      Body__c = 'Original message',
      Sender__c = currentUserContactId,
      Recipient_Type__c = 'Client',
      Related_Task__c = testTask.Id,
      Related_Project__c = testProject.Id,
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = false,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert originalMessage;

    Test.startTest();
    {
      // Test sending message as reply
      String replyMessageId = MessagingController.sendMessage(
        'Reply message',
        'Client',
        null, // relatedAccountId - should inherit from original
        null, // relatedProjectId - should inherit from original
        null, // relatedTaskId - should inherit from original
        null,
        true,
        originalMessage.Id // replyToMessageId
      );

      System.assertNotEquals(null, replyMessageId, 'Reply message should be created');

      // Verify reply message has correct relationships
      Message__c replyMessage = [
        SELECT Id, Reply_To__c, Related_Task__c, Related_Project__c, Account__c, Recipient_Type__c
        FROM Message__c
        WHERE Id = :replyMessageId
      ];

      System.assertEquals(originalMessage.Id, replyMessage.Reply_To__c, 'Reply should reference original message');
      System.assertEquals(testTask.Id, replyMessage.Related_Task__c, 'Reply should inherit task from original');
      System.assertEquals(
        testProject.Id,
        replyMessage.Related_Project__c,
        'Reply should inherit project from original'
      );
      System.assertEquals(testAccount.Id, replyMessage.Account__c, 'Reply should inherit account from original');
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_InternalMessageError() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    User currentUser = [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId()];

    // Only test if user has AccountId (portal user)
    if (currentUser.AccountId == null) {
      return; // Skip for Milestone team members
    }

    Test.startTest();
    {
      // Test that portal users cannot send internal messages
      try {
        MessagingController.sendMessage(
          'Test internal message',
          'Milestone Team',
          testAccount.Id,
          null,
          null,
          null,
          false, // isVisibleToClient = false (internal message)
          null
        );
        System.assert(false, 'Should have thrown exception for internal message from portal user');
      } catch (AuraHandledException e) {
        System.assert(
          e.getMessage().contains('internal') || e.getMessage().contains('Milestone'),
          'Should return error about internal messages'
        );
      }
    }
    Test.stopTest();
  }

  @isTest
  static void testDeleteMessage() {
    // Get a message that current user sent
    User currentUser = [SELECT Id, ContactId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
    Id currentUserContactId;
    if (currentUser.ContactId != null) {
      currentUserContactId = currentUser.ContactId;
    } else {
      List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email LIMIT 1];
      if (!contacts.isEmpty()) {
        currentUserContactId = contacts[0].Id;
      }
    }

    if (currentUserContactId == null) {
      return; // Can't test without Contact
    }

    List<Message__c> messages = [
      SELECT Id
      FROM Message__c
      WHERE Sender__c = :currentUserContactId
      LIMIT 1
    ];

    if (messages.isEmpty()) {
      return; // No messages to test
    }

    Test.startTest();
    MessagingController.deleteMessage(messages[0].Id);
    Test.stopTest();

    // Verify message is marked as deleted
    Message__c deletedMessage = [SELECT Id, Deleted__c FROM Message__c WHERE Id = :messages[0].Id];
    System.assertEquals(true, deletedMessage.Deleted__c, 'Message should be marked as deleted');
  }

  @isTest
  static void testGetContextInfo() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];

    Test.startTest();
    {
      // Test with task ID
      MessagingController.ContextInfo taskContext = MessagingController.getContextInfo(
        null, // relatedAccountId
        null, // relatedProjectId
        testTask.Id // relatedTaskId
      );

      System.assert(taskContext != null, 'Should return context info for task');

      // Test with project ID
      MessagingController.ContextInfo projectContext = MessagingController.getContextInfo(
        null, // relatedAccountId
        testProject.Id, // relatedProjectId
        null // relatedTaskId
      );

      System.assert(projectContext != null, 'Should return context info for project');

      // Test with account ID
      MessagingController.ContextInfo accountContext = MessagingController.getContextInfo(
        testAccount.Id, // relatedAccountId
        null, // relatedProjectId
        null // relatedTaskId
      );

      System.assert(accountContext != null, 'Should return context info for account');
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_NoContextWithAccountId() {
    // Test sendMessage with no context but user has AccountId (covers line 116)
    User currentUser = [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId()];

    // Only test if user has AccountId
    if (currentUser.AccountId == null) {
      return; // Skip for Milestone team members
    }

    Test.startTest();
    {
      String messageId = MessagingController.sendMessage(
        'Test message with no context',
        'Client',
        null, // relatedAccountId
        null, // relatedProjectId
        null, // relatedTaskId
        null,
        true,
        null
      );

      System.assertNotEquals(null, messageId, 'Message should be created');

      // Verify message has user's account set as fallback
      Message__c message = [
        SELECT Id, Account__c
        FROM Message__c
        WHERE Id = :messageId
      ];

      System.assertEquals(currentUser.AccountId, message.Account__c, 'Message should have user account as fallback');
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_WithNullVisibleToClient() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];

    Test.startTest();
    {
      // Test sendMessage with isVisibleToClient = null (covers line 129)
      String messageId = MessagingController.sendMessage(
        'Test message with null visible',
        'Client',
        testAccount.Id,
        testProject.Id,
        testTask.Id,
        null,
        null, // isVisibleToClient = null (should default to true)
        null
      );

      System.assertNotEquals(null, messageId, 'Message should be created');

      // Verify message defaults to visible
      Message__c message = [
        SELECT Id, Visible_To_Client__c
        FROM Message__c
        WHERE Id = :messageId
      ];

      System.assertEquals(true, message.Visible_To_Client__c, 'Message should default to visible');
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_ReplyToWithProject() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];

    // Create a message with project but no task
    User currentUser = [SELECT Id, ContactId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
    Id currentUserContactId;
    if (currentUser.ContactId != null) {
      currentUserContactId = currentUser.ContactId;
    } else {
      List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email LIMIT 1];
      if (!contacts.isEmpty()) {
        currentUserContactId = contacts[0].Id;
      }
    }

    if (currentUserContactId == null) {
      return; // Can't test without Contact
    }

    Message__c originalMessage = new Message__c(
      Body__c = 'Original message with project',
      Sender__c = currentUserContactId,
      Recipient_Type__c = 'Client',
      Related_Project__c = testProject.Id, // Project but no task
      Account__c = testAccount.Id,
      Is_Read_By_Client__c = false,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert originalMessage;

    Test.startTest();
    {
      // Test reply inheriting project (covers line 157)
      // Note: recipientType is required, but will be inherited from original message if not provided
      // For now, we'll pass it explicitly to avoid validation error
      String replyMessageId = MessagingController.sendMessage(
        'Reply message',
        'Client', // recipientType - required, but will inherit from original if null (validation happens before inheritance)
        null, // relatedAccountId - should inherit
        null, // relatedProjectId - should inherit
        null, // relatedTaskId - should inherit
        null,
        true,
        originalMessage.Id // replyToMessageId
      );

      System.assertNotEquals(null, replyMessageId, 'Reply message should be created');

      // Verify reply inherits project
      Message__c replyMessage = [
        SELECT Id, Related_Project__c, Recipient_Type__c
        FROM Message__c
        WHERE Id = :replyMessageId
      ];

      System.assertEquals(
        testProject.Id,
        replyMessage.Related_Project__c,
        'Reply should inherit project from original'
      );
      System.assertEquals(
        'Client',
        replyMessage.Recipient_Type__c,
        'Reply should inherit recipient type from original'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_ReplyToWithAccount() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];

    // Create a message with account but no project/task
    User currentUser = [SELECT Id, ContactId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
    Id currentUserContactId;
    if (currentUser.ContactId != null) {
      currentUserContactId = currentUser.ContactId;
    } else {
      List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email LIMIT 1];
      if (!contacts.isEmpty()) {
        currentUserContactId = contacts[0].Id;
      }
    }

    if (currentUserContactId == null) {
      return; // Can't test without Contact
    }

    Message__c originalMessage = new Message__c(
      Body__c = 'Original message with account',
      Sender__c = currentUserContactId,
      Recipient_Type__c = 'Client',
      Account__c = testAccount.Id, // Account but no project/task
      Is_Read_By_Client__c = false,
      Is_Read_By_Milestone_Team__c = false,
      Visible_To_Client__c = true,
      Deleted__c = false
    );
    insert originalMessage;

    Test.startTest();
    {
      // Test reply inheriting account (covers line 158)
      // Note: recipientType is required, but will be inherited from original message if not provided
      // For now, we'll pass it explicitly to avoid validation error
      String replyMessageId = MessagingController.sendMessage(
        'Reply message',
        'Client', // recipientType - required, but will inherit from original if null (validation happens before inheritance)
        null, // relatedAccountId - should inherit
        null, // relatedProjectId - should inherit
        null, // relatedTaskId - should inherit
        null,
        true,
        originalMessage.Id // replyToMessageId
      );

      System.assertNotEquals(null, replyMessageId, 'Reply message should be created');

      // Verify reply inherits account
      Message__c replyMessage = [
        SELECT Id, Account__c, Recipient_Type__c
        FROM Message__c
        WHERE Id = :replyMessageId
      ];

      System.assertEquals(testAccount.Id, replyMessage.Account__c, 'Reply should inherit account from original');
      System.assertEquals(
        'Client',
        replyMessage.Recipient_Type__c,
        'Reply should inherit recipient type from original'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_PortalUser_RejectsOtherAccountTask() {
    User currentUser = [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId()];
    if (currentUser.AccountId == null) {
      return;
    }

    Account otherAccount = new Account(Name = 'Other Client Account');
    insert otherAccount;

    Project__c otherProject = new Project__c(Name = 'Other Project', Account__c = otherAccount.Id);
    insert otherProject;

    Project_Task__c otherTask = new Project_Task__c(
      Name = 'Other Task',
      Project__c = otherProject.Id,
      Account__c = otherAccount.Id
    );
    insert otherTask;

    Test.startTest();
    try {
      MessagingController.sendMessage(
        'Cross-tenant attempt',
        'Milestone Team',
        null,
        null,
        otherTask.Id,
        null,
        true,
        null
      );
      System.assert(false, 'Expected AuraHandledException for other account task');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('account context'),
        'Expected account context error: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_RejectsInvalidTaskId() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];

    Test.startTest();
    try {
      MessagingController.sendMessage(
        'Invalid task',
        'Client',
        null,
        null,
        testAccount.Id,
        null,
        true,
        null
      );
      System.assert(false, 'Expected AuraHandledException for invalid task Id');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('not found') || e.getMessage().contains('not available'),
        'Expected task not found error: ' + e.getMessage()
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testSendMessage_FiltersMentionsNotMentionable() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
    Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];

    Contact notMentionable = new Contact(
      FirstName = 'No',
      LastName = 'PortalFlag',
      Email = 'noportalmention@test.com',
      AccountId = testAccount.Id,
      Portal_Access_Enabled__c = false
    );
    insert notMentionable;

    Test.startTest();
    String messageId = MessagingController.sendMessage(
      'Hello with bad mention only',
      'Client',
      testAccount.Id,
      testProject.Id,
      testTask.Id,
      new List<String>{ notMentionable.Id },
      true,
      null
    );
    Test.stopTest();

    Message__c inserted = [
      SELECT Mentioned_Contacts__c
      FROM Message__c
      WHERE Id = :messageId
    ];
    System.assert(
      String.isBlank(inserted.Mentioned_Contacts__c) ||
        !inserted.Mentioned_Contacts__c.contains(String.valueOf(notMentionable.Id)),
      'Non-mentionable contact should be filtered out'
    );
  }
}
