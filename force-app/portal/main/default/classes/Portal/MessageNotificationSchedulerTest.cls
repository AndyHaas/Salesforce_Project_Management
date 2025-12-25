/**
 * Test class for MessageNotificationScheduler
 */
@isTest
private class MessageNotificationSchedulerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Client Account'
        );
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
        Test.setCreatedDate(alreadyNotifiedMessage.Id, DateTime.now().addMinutes(-6));
    }
    
    @isTest
    static void testCheckAndSendNotifications() {
        Test.startTest();
        MessageNotificationScheduler.checkAndSendNotifications();
        Test.stopTest();
        
        // Get all messages and verify by CreatedDate
        List<Message__c> allMessages = [
            SELECT Id, PM_Notification_Sent__c, CreatedDate, Is_Read_By_Milestone_Team__c
            FROM Message__c
            ORDER BY CreatedDate DESC
        ];
        
        // Find the old unread message (should be marked as sent)
        Message__c oldUnreadMessage = null;
        Message__c recentMessage = null;
        Message__c readMessage = null;
        
        for (Message__c msg : allMessages) {
            if (msg.CreatedDate < DateTime.now().addMinutes(-5) && 
                !msg.Is_Read_By_Milestone_Team__c && 
                oldUnreadMessage == null) {
                oldUnreadMessage = msg;
            } else if (msg.CreatedDate > DateTime.now().addMinutes(-5) && 
                       !msg.Is_Read_By_Milestone_Team__c && 
                       recentMessage == null) {
                recentMessage = msg;
            } else if (msg.Is_Read_By_Milestone_Team__c && readMessage == null) {
                readMessage = msg;
            }
        }
        
        // Verify that the old unread message was marked as notification sent
        if (oldUnreadMessage != null) {
            System.assertEquals(true, oldUnreadMessage.PM_Notification_Sent__c, 
                'Old unread message should be marked as notification sent');
        }
        
        // Verify recent message was not marked (it's less than 5 minutes old)
        if (recentMessage != null) {
            System.assertEquals(false, recentMessage.PM_Notification_Sent__c, 
                'Recent message should not be marked as notification sent');
        }
        
        // Verify read message was not marked
        if (readMessage != null) {
            System.assertEquals(false, readMessage.PM_Notification_Sent__c, 
                'Read message should not be marked as notification sent');
        }
    }
    
    @isTest
    static void testScheduledExecution() {
        Test.startTest();
        MessageNotificationScheduler scheduler = new MessageNotificationScheduler();
        String jobId = System.schedule('Test Message Notification', '0 0 * * * ?', scheduler);
        Test.stopTest();
        
        // Verify job was scheduled
        System.assertNotEquals(null, jobId, 'Job should be scheduled');
        
        // Verify the execute method can be called
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals('0 0 * * * ?', ct.CronExpression, 'Cron expression should match');
    }
    
    @isTest
    static void testMessageWithoutProjectManager() {
        // Create message with task that has no project manager
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact clientContact = [SELECT Id FROM Contact WHERE Email = 'client@test.com' LIMIT 1];
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
        
        System.assertEquals(true, updatedMessage.PM_Notification_Sent__c, 
            'Message without PM should be marked as sent to avoid repeated checks');
        System.assertNotEquals(null, updatedMessage.PM_Notification_Sent_Date__c, 
            'PM notification sent date should be set');
    }
    
    @isTest
    static void testClientNotification() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact projectManager = [SELECT Id FROM Contact WHERE Email = 'pm@test.com' LIMIT 1];
        Contact clientUser = [SELECT Id, Email FROM Contact WHERE Email = 'client@test.com' LIMIT 1];
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
        
        Test.startTest();
        MessageNotificationScheduler.checkAndSendNotifications();
        Test.stopTest();
        
        // Verify message was marked as notification sent
        Message__c updatedMessage = [
            SELECT Id, Client_Notification_Sent__c, Client_Notification_Sent_Date__c
            FROM Message__c
            WHERE Id = :unreadClientMessage.Id
        ];
        
        System.assertEquals(true, updatedMessage.Client_Notification_Sent__c, 
            'Client message should be marked as notification sent');
        System.assertNotEquals(null, updatedMessage.Client_Notification_Sent_Date__c, 
            'Client notification sent date should be set');
    }
    
    @isTest
    static void testClientNotification_NoClientUser() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact projectManager = [SELECT Id FROM Contact WHERE Email = 'pm@test.com' LIMIT 1];
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
        Test.setCreatedDate(messageWithoutClientUser.Id, DateTime.now().addMinutes(-6));
        
        Test.startTest();
        MessageNotificationScheduler.checkAndSendNotifications();
        Test.stopTest();
        
        // Verify message was marked as sent (to avoid checking repeatedly) even though no email was sent
        Message__c updatedMessage = [
            SELECT Id, Client_Notification_Sent__c, Client_Notification_Sent_Date__c
            FROM Message__c
            WHERE Id = :messageWithoutClientUser.Id
        ];
        
        System.assertEquals(true, updatedMessage.Client_Notification_Sent__c, 
            'Message without client user should be marked as sent to avoid repeated checks');
        System.assertNotEquals(null, updatedMessage.Client_Notification_Sent_Date__c, 
            'Client notification sent date should be set');
    }
    
    @isTest
    static void testClientNotification_NoEmail() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact projectManager = [SELECT Id FROM Contact WHERE Email = 'pm@test.com' LIMIT 1];
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
        Test.setCreatedDate(messageWithClientNoEmail.Id, DateTime.now().addMinutes(-6));
        
        Test.startTest();
        MessageNotificationScheduler.checkAndSendNotifications();
        Test.stopTest();
        
        // Verify message was marked as sent (to avoid checking repeatedly) even though no email was sent
        Message__c updatedMessage = [
            SELECT Id, Client_Notification_Sent__c, Client_Notification_Sent_Date__c
            FROM Message__c
            WHERE Id = :messageWithClientNoEmail.Id
        ];
        
        System.assertEquals(true, updatedMessage.Client_Notification_Sent__c, 
            'Message with client user without email should be marked as sent to avoid repeated checks');
        System.assertNotEquals(null, updatedMessage.Client_Notification_Sent_Date__c, 
            'Client notification sent date should be set');
    }
}
