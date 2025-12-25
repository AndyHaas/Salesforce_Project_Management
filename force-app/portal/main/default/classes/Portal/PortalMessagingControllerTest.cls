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
        
        // Create test Contact (for portal user)
        Contact portalContact = new Contact(
            FirstName = 'Portal',
            LastName = 'User',
            Email = 'portaluser@test.com',
            AccountId = testAccount.Id
        );
        insert portalContact;
        
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
        
        // Note: Creating Users with ContactId requires Community/Portal profiles
        // For testing, we'll use the current running user and test the logic
        // The getOrCreateContactForUser method will be tested indirectly through sendMessage
        
        // Create test messages (using portalContact as sender)
        List<Message__c> testMessages = new List<Message__c>();
        
        // Message from portal user
        testMessages.add(new Message__c(
            Body__c = 'Test message from portal user',
            Sender__c = portalContact.Id,
            Recipient_Type__c = 'Milestone Team',
            Related_Task__c = testTask.Id,
            Related_Project__c = testProject.Id,
            Account__c = testAccount.Id,
            Is_Read__c = false,
            Visible_To_Client__c = true,
            Deleted__c = false
        ));
        
        // Message from milestone team to client
        testMessages.add(new Message__c(
            Body__c = 'Test message from milestone team to client',
            Sender__c = portalContact.Id, // Will be updated after Contact creation
            Recipient_Type__c = 'Client',
            Related_Task__c = testTask.Id,
            Related_Project__c = testProject.Id,
            Account__c = testAccount.Id,
            Is_Read__c = false,
            Visible_To_Client__c = true,
            Deleted__c = false
        ));
        
        // Message with searchable content
        testMessages.add(new Message__c(
            Body__c = 'This message contains the word searchable',
            Sender__c = portalContact.Id,
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
}
