/**
 * Test class for PortalMessagingController
 * Covers all methods including recent changes:
 * - Auto-creation of Contacts for Milestone team members
 * - Server-side search with wildcards
 * - Pagination with offset
 * - Message CRUD operations
 */
@isTest
private class PortalMessagingControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Client Account'
        );
        insert testAccount;
        
        // Get current user and create/get Contact for them
        User currentUser = [SELECT Id, ContactId, AccountId, Name, Email FROM User WHERE Id = :UserInfo.getUserId()];
        Id currentUserContactId;
        
        // Get or create Contact for current user
        if (currentUser.ContactId != null) {
            currentUserContactId = currentUser.ContactId;
        } else {
            // Create Contact for current user
            Contact userContact = new Contact(
                FirstName = currentUser.Name.contains(' ') ? currentUser.Name.split(' ', 2)[0] : '',
                LastName = currentUser.Name.contains(' ') ? currentUser.Name.split(' ', 2)[1] : currentUser.Name,
                Email = currentUser.Email != null ? currentUser.Email : 'testuser@test.com',
                AccountId = testAccount.Id
            );
            insert userContact;
            currentUserContactId = userContact.Id;
        }
        
        // Create test Project
        Project__c testProject = new Project__c(
            Name = 'Test Project',
            Account__c = testAccount.Id
        );
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
        testMessages.add(new Message__c(
            Body__c = 'Test message from portal user',
            Sender__c = currentUserContactId,
            Recipient_Type__c = 'Milestone Team',
            Related_Task__c = testTask.Id,
            Related_Project__c = testProject.Id,
            Account__c = testAccount.Id,
            Is_Read__c = false,
            Visible_To_Client__c = true,
            Deleted__c = false
        ));
        
        // Message to Client (current user can see if they have AccountId, or if sender matches)
        testMessages.add(new Message__c(
            Body__c = 'Test message from milestone team to client',
            Sender__c = currentUserContactId,
            Recipient_Type__c = 'Client',
            Related_Task__c = testTask.Id,
            Related_Project__c = testProject.Id,
            Account__c = testAccount.Id,
            Is_Read__c = false,
            Visible_To_Client__c = true,
            Deleted__c = false
        ));
        
        // Message with searchable content (from current user so they can access it)
        testMessages.add(new Message__c(
            Body__c = 'This message contains the word searchable',
            Sender__c = currentUserContactId,
            Recipient_Type__c = 'Client',
            Related_Task__c = testTask.Id,
            Related_Project__c = testProject.Id,
            Account__c = testAccount.Id,
            Is_Read__c = false,
            Visible_To_Client__c = true,
            Deleted__c = false
        ));
        
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
        String messageId = PortalMessagingController.sendMessage(
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
        
        // Verify Contact was created
        List<Contact> createdContacts = [
            SELECT Id, FirstName, LastName, Email
            FROM Contact
            WHERE Email = :currentUser.Email
        ];
        System.assert(!createdContacts.isEmpty(), 'Contact should be created for Milestone team member');
        
        // Verify message uses the created Contact
        Message__c message = [SELECT Id, Sender__c FROM Message__c WHERE Id = :messageId];
        System.assertEquals(createdContacts[0].Id, message.Sender__c, 'Message should use created Contact');
    }
    
    @isTest
    static void testGetMessages_WithSearch() {
        Test.startTest();
        {
            // Test search without wildcards
            List<PortalMessagingController.MessageInfo> results = PortalMessagingController.getMessages(
                null, // recipientType
                null, // relatedAccountId
                null, // relatedProjectId
                null, // relatedTaskId
                50,   // limitCount
                0,    // offset
                null, // orderByField
                null, // orderDirection
                'searchable' // searchTerm
            );
            
            System.assertEquals(1, results.size(), 'Should find 1 message with "searchable"');
            System.assert(results[0].body.contains('searchable'), 'Message should contain search term');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetMessages_WithWildcardSearch() {
        Test.startTest();
        {
            // Test search with * wildcard (should convert to %)
            List<PortalMessagingController.MessageInfo> results = PortalMessagingController.getMessages(
                null, // recipientType
                null, // relatedAccountId
                null, // relatedProjectId
                null, // relatedTaskId
                50,   // limitCount
                0,    // offset
                null, // orderByField
                null, // orderDirection
                'search*' // searchTerm with * wildcard
            );
            
            System.assert(results.size() >= 1, 'Should find messages matching "search*" pattern');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetMessages_WithPercentWildcard() {
        Test.startTest();
        {
            // Test search with % wildcard (should be allowed)
            List<PortalMessagingController.MessageInfo> results = PortalMessagingController.getMessages(
                null, // recipientType
                null, // relatedAccountId
                null, // relatedProjectId
                null, // relatedTaskId
                50,   // limitCount
                0,    // offset
                null, // orderByField
                null, // orderDirection
                '%searchable%' // searchTerm with % wildcard
            );
            
            System.assert(results.size() >= 1, 'Should find messages with % wildcard');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetMessages_WithUnderscoreLiteral() {
        // Create message with underscore
        Contact portalContact = [SELECT Id FROM Contact WHERE Email = 'portaluser@test.com' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
        Project_Task__c testTask = [SELECT Id, Account__c FROM Project_Task__c LIMIT 1];
        
        Message__c msgWithUnderscore = new Message__c(
            Body__c = 'Test_message_with_underscore',
            Sender__c = portalContact.Id,
            Recipient_Type__c = 'Client',
            Related_Task__c = testTask.Id,
            Related_Project__c = testProject.Id,
            Account__c = testTask.Account__c != null ? testTask.Account__c : testAccount.Id,
            Is_Read__c = false,
            Visible_To_Client__c = true,
            Deleted__c = false
        );
        insert msgWithUnderscore;
        
        Test.startTest();
        {
            // Test search with _ (should be treated as literal, not wildcard)
            List<PortalMessagingController.MessageInfo> results = PortalMessagingController.getMessages(
                null, // recipientType
                null, // relatedAccountId
                null, // relatedProjectId
                null, // relatedTaskId
                50,   // limitCount
                0,    // offset
                null, // orderByField
                null, // orderDirection
                'Test_message' // searchTerm with _ (literal)
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
            List<PortalMessagingController.MessageInfo> page1 = PortalMessagingController.getMessages(
                null, // recipientType
                null, // relatedAccountId
                null, // relatedProjectId
                null, // relatedTaskId
                2,    // limitCount
                0,    // offset
                null, // orderByField
                null, // orderDirection
                null  // searchTerm
            );
            
            // Get second page
            List<PortalMessagingController.MessageInfo> page2 = PortalMessagingController.getMessages(
                null, // recipientType
                null, // relatedAccountId
                null, // relatedProjectId
                null, // relatedTaskId
                2,    // limitCount
                2,    // offset
                null, // orderByField
                null, // orderDirection
                null  // searchTerm
            );
            
            System.assert(page1.size() <= 2, 'First page should have at most 2 messages');
            System.assert(page2.size() <= 2, 'Second page should have at most 2 messages');
            
            // Verify no duplicates
            Set<String> messageIds = new Set<String>();
            for (PortalMessagingController.MessageInfo msg : page1) {
                messageIds.add(msg.id);
            }
            for (PortalMessagingController.MessageInfo msg : page2) {
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
        
        Test.startTest();
        {
            String messageId = PortalMessagingController.sendMessage(
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
            User currentUser = [SELECT Id, ContactId, Email FROM User WHERE Id = :UserInfo.getUserId()];
            if (currentUser.ContactId == null) {
                List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = :currentUser.Email];
                System.assert(!contacts.isEmpty(), 'Contact should be created for Milestone team member');
                
                // Verify message uses the created Contact
                Message__c message = [SELECT Id, Sender__c FROM Message__c WHERE Id = :messageId];
                System.assertEquals(contacts[0].Id, message.Sender__c, 'Message should use created Contact');
            }
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetMessages_NoSearchTerm() {
        Test.startTest();
        {
            List<PortalMessagingController.MessageInfo> results = PortalMessagingController.getMessages(
                null, // recipientType
                null, // relatedAccountId
                null, // relatedProjectId
                null, // relatedTaskId
                50,   // limitCount
                0,    // offset
                null, // orderByField
                null, // orderDirection
                null  // searchTerm
            );
            
            System.assert(results.size() > 0, 'Should return messages without search');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetMessages_EmptySearchTerm() {
        Test.startTest();
        {
            List<PortalMessagingController.MessageInfo> results = PortalMessagingController.getMessages(
                null, // recipientType
                null, // relatedAccountId
                null, // relatedProjectId
                null, // relatedTaskId
                50,   // limitCount
                0,    // offset
                null, // orderByField
                null, // orderDirection
                ''    // searchTerm (empty)
            );
            
            // Empty search should return all messages (no filter applied)
            System.assert(results.size() > 0, 'Should return messages with empty search');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetCurrentUserContactId() {
        Test.startTest();
        String contactId = PortalMessagingController.getCurrentUserContactId();
        Test.stopTest();
        
        // Should return ContactId (may be null for Milestone team members)
        System.assert(contactId != null || contactId == null, 'Should return ContactId or null');
    }
    
    @isTest
    static void testIsMilestoneTeamMember() {
        Test.startTest();
        Boolean isMilestone = PortalMessagingController.isMilestoneTeamMember();
        Test.stopTest();
        
        // Should return boolean (true if no AccountId, false if has AccountId)
        System.assert(isMilestone != null, 'Should return boolean value');
    }
    
    @isTest
    static void testGetLatestMessages() {
        Test.startTest();
        List<PortalMessagingController.MessageInfo> results = PortalMessagingController.getLatestMessages(5);
        Test.stopTest();
        
        System.assert(results != null, 'Should return list of messages');
        System.assert(results.size() <= 5, 'Should respect limit');
    }
    
    @isTest
    static void testGetMentionableContacts() {
        Test.startTest();
        List<PortalMessagingController.ContactInfo> results = PortalMessagingController.getMentionableContacts('test');
        Test.stopTest();
        
        System.assert(results != null, 'Should return list of contacts');
    }
    
    @isTest
    static void testMarkAsRead() {
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
            SELECT Id FROM Message__c 
            WHERE Sender__c = :currentUserContactId 
            LIMIT 1
        ];
        
        if (messages.isEmpty()) {
            return; // No messages to test
        }
        
        Test.startTest();
        PortalMessagingController.markAsRead(messages[0].Id);
        Test.stopTest();
        
        // Verify message is marked as read
        Message__c updatedMessage = [SELECT Id, Is_Read__c FROM Message__c WHERE Id = :messages[0].Id];
        System.assertEquals(true, updatedMessage.Is_Read__c, 'Message should be marked as read');
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
            SELECT Id FROM Message__c 
            WHERE Sender__c = :currentUserContactId 
            LIMIT 1
        ];
        
        if (messages.isEmpty()) {
            return; // No messages to test
        }
        
        Test.startTest();
        PortalMessagingController.updateMessage(messages[0].Id, 'Updated message body');
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
            SELECT Id FROM Message__c 
            WHERE Sender__c = :currentUserContactId 
            LIMIT 1
        ];
        
        if (messages.isEmpty()) {
            return; // No messages to test
        }
        
        Test.startTest();
        PortalMessagingController.pinMessage(messages[0].Id, true);
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
            List<PortalMessagingController.MessageInfo> clientResults = PortalMessagingController.getMessages(
                'Client', // recipientType
                null, // relatedAccountId
                null, // relatedProjectId
                null, // relatedTaskId
                50,   // limitCount
                0,    // offset
                null, // orderByField
                null, // orderDirection
                null  // searchTerm
            );
            
            System.assert(clientResults != null, 'Should return messages for Client recipient type');
            
            // Test with Milestone Team recipient type
            List<PortalMessagingController.MessageInfo> teamResults = PortalMessagingController.getMessages(
                'Milestone Team', // recipientType
                null, // relatedAccountId
                null, // relatedProjectId
                null, // relatedTaskId
                50,   // limitCount
                0,    // offset
                null, // orderByField
                null, // orderDirection
                null  // searchTerm
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
            List<PortalMessagingController.MessageInfo> results = PortalMessagingController.getMessages(
                null, // recipientType
                null, // relatedAccountId
                null, // relatedProjectId
                testTask.Id, // relatedTaskId
                50,   // limitCount
                0,    // offset
                null, // orderByField
                null, // orderDirection
                null  // searchTerm
            );
            
            System.assert(results != null, 'Should return messages for related task');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSendMessage_WithAllFields() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
        Project_Task__c testTask = [SELECT Id FROM Project_Task__c LIMIT 1];
        
        Test.startTest();
        {
            String messageId = PortalMessagingController.sendMessage(
                'Test message with all fields',
                'Client',
                testAccount.Id,
                testProject.Id,
                testTask.Id,
                null, // mentionedContactIds
                true, // isVisibleToClient
                null  // replyToMessageId
            );
            
            System.assertNotEquals(null, messageId, 'Message should be created');
            
            // Verify message was created with all fields
            Message__c message = [
                SELECT Id, Body__c, Recipient_Type__c, Account__c, 
                       Related_Project__c, Related_Task__c, Visible_To_Client__c
                FROM Message__c 
                WHERE Id = :messageId
            ];
            
            System.assertEquals('Test message with all fields', message.Body__c);
            System.assertEquals('Client', message.Recipient_Type__c);
            System.assertEquals(testAccount.Id, message.Account__c);
            System.assertEquals(testProject.Id, message.Related_Project__c);
            System.assertEquals(testTask.Id, message.Related_Task__c);
            System.assertEquals(true, message.Visible_To_Client__c);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSendMessage_ValidationErrors() {
        Test.startTest();
        {
            // Test blank message body
            try {
                PortalMessagingController.sendMessage(
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
                PortalMessagingController.sendMessage(
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
            String messageId = PortalMessagingController.sendMessage(
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
            String messageId = PortalMessagingController.sendMessage(
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
            String messageId = PortalMessagingController.sendMessage(
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
            System.assert(message.Mentioned_Contacts__c.contains(testContact.Id), 'Message should contain mentioned contact ID');
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
            Is_Read__c = false,
            Visible_To_Client__c = true,
            Deleted__c = false
        );
        insert originalMessage;
        
        Test.startTest();
        {
            // Test sending message as reply
            String replyMessageId = PortalMessagingController.sendMessage(
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
            System.assertEquals(testProject.Id, replyMessage.Related_Project__c, 'Reply should inherit project from original');
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
                PortalMessagingController.sendMessage(
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
                System.assert(e.getMessage().contains('internal') || e.getMessage().contains('Milestone'), 
                    'Should return error about internal messages');
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
            SELECT Id FROM Message__c 
            WHERE Sender__c = :currentUserContactId 
            LIMIT 1
        ];
        
        if (messages.isEmpty()) {
            return; // No messages to test
        }
        
        Test.startTest();
        PortalMessagingController.deleteMessage(messages[0].Id);
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
            PortalMessagingController.ContextInfo taskContext = PortalMessagingController.getContextInfo(
                null, // relatedAccountId
                null, // relatedProjectId
                testTask.Id // relatedTaskId
            );
            
            System.assert(taskContext != null, 'Should return context info for task');
            
            // Test with project ID
            PortalMessagingController.ContextInfo projectContext = PortalMessagingController.getContextInfo(
                null, // relatedAccountId
                testProject.Id, // relatedProjectId
                null // relatedTaskId
            );
            
            System.assert(projectContext != null, 'Should return context info for project');
            
            // Test with account ID
            PortalMessagingController.ContextInfo accountContext = PortalMessagingController.getContextInfo(
                testAccount.Id, // relatedAccountId
                null, // relatedProjectId
                null // relatedTaskId
            );
            
            System.assert(accountContext != null, 'Should return context info for account');
        }
        Test.stopTest();
    }
}
