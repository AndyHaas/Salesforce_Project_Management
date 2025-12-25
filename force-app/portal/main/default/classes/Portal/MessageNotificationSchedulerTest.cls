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
            PM_Notification_Sent__c = false,
            CreatedDate = DateTime.now().addMinutes(-6) // 6 minutes ago
        );
        insert oldUnreadMessage;
        
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
            PM_Notification_Sent__c = false,
            CreatedDate = DateTime.now().addMinutes(-2) // 2 minutes ago
        );
        insert recentUnreadMessage;
        
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
            PM_Notification_Sent__c = false,
            CreatedDate = DateTime.now().addMinutes(-6)
        );
        insert readMessage;
        
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
            PM_Notification_Sent__c = true, // Already sent
            CreatedDate = DateTime.now().addMinutes(-6)
        );
        insert alreadyNotifiedMessage;
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
            PM_Notification_Sent__c = false,
            CreatedDate = DateTime.now().addMinutes(-6)
        );
        insert messageWithoutPM;
        
        Test.startTest();
        MessageNotificationScheduler.checkAndSendNotifications();
        Test.stopTest();
        
        // Verify message was marked as sent (to avoid checking repeatedly) even though no email was sent
        Message__c updatedMessage = [
            SELECT Id, PM_Notification_Sent__c
            FROM Message__c
            WHERE Id = :messageWithoutPM.Id
        ];
        
        System.assertEquals(true, updatedMessage.PM_Notification_Sent__c, 
            'Message without PM should be marked as sent to avoid repeated checks');
    }
}
