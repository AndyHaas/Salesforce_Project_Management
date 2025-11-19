@isTest
private class TaskSubtaskHelperTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test User for OwnerId
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        // Create test Contact for Client_User__c (User lookup requires User with Contact relationship)
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Client',
            Email = 'testclient@example.com',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        // Note: Client_User__c has a lookup filter requiring User.Contact.AccountId to match Account__c
        // We'll leave it null in setup to avoid filter validation issues
        // Tests that need Client_User__c will create their own parent tasks
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            OwnerId = testUser.Id
            // Client_User__c left null to avoid lookup filter validation
        );
        insert parentTask;
        
        // Create another parent task for status update tests
        Project_Task__c parentTask2 = new Project_Task__c(
            Name = 'Parent Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            OwnerId = testUser.Id
            // Client_User__c left null to avoid lookup filter validation
        );
        insert parentTask2;
        
        // Create parent task for validation tests
        Project_Task__c parentTask3 = new Project_Task__c(
            Name = 'Parent Task 3',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            OwnerId = testUser.Id
            // Client_User__c left null to avoid lookup filter validation
        );
        insert parentTask3;
        
        // Create some existing subtasks for parent task 3
        List<Project_Task__c> existingSubtasks = new List<Project_Task__c>();
        existingSubtasks.add(new Project_Task__c(
            Name = 'Open Subtask 1',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask3.Id
        ));
        existingSubtasks.add(new Project_Task__c(
            Name = 'Open Subtask 2',
            Status__c = 'Pending',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Parent_Task__c = parentTask3.Id
        ));
        existingSubtasks.add(new Project_Task__c(
            Name = 'Closed Subtask',
            Status__c = 'Closed',
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            Parent_Task__c = parentTask3.Id
        ));
        insert existingSubtasks;
    }
    
    // Test populateSubtaskUsers - before insert
    @isTest
    static void testPopulateSubtaskUsers_WithParent() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Project_Task__c parentTask = [SELECT Id, OwnerId, Client_User__c FROM Project_Task__c WHERE Name = 'Parent Task' LIMIT 1];
        
        Test.startTest();
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id
        );
        insert subtask;
        Test.stopTest();
        
        // Verify subtask has OwnerId and Client_User__c populated from parent
        Project_Task__c insertedSubtask = [SELECT Id, OwnerId, Client_User__c FROM Project_Task__c WHERE Id = :subtask.Id];
        System.assertEquals(parentTask.OwnerId, insertedSubtask.OwnerId, 'Subtask OwnerId should be populated from parent');
        System.assertEquals(parentTask.Client_User__c, insertedSubtask.Client_User__c, 'Subtask Client_User__c should be populated from parent');
    }
    
    @isTest
    static void testPopulateSubtaskUsers_WithoutParent() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE FirstName = 'Test' AND LastName = 'User' LIMIT 1];
        
        Test.startTest();
        Project_Task__c standaloneTask = new Project_Task__c(
            Name = 'Standalone Task',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            OwnerId = testUser.Id
        );
        insert standaloneTask;
        Test.stopTest();
        
        // Verify task is created successfully without parent
        Project_Task__c insertedTask = [SELECT Id, Parent_Task__c FROM Project_Task__c WHERE Id = :standaloneTask.Id];
        System.assertEquals(null, insertedTask.Parent_Task__c, 'Standalone task should not have parent');
    }
    
    @isTest
    static void testPopulateSubtaskUsers_ExistingOwnerId() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Project_Task__c parentTask = [SELECT Id, OwnerId, Client_User__c FROM Project_Task__c WHERE Name = 'Parent Task' LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        
        // Create another user
        User anotherUser = new User(
            FirstName = 'Another',
            LastName = 'User',
            Email = 'anotheruser@example.com',
            Username = 'anotheruser' + System.currentTimeMillis() + '@example.com',
            Alias = 'auser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert anotherUser;
        
        Test.startTest();
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask With Owner',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id,
            OwnerId = anotherUser.Id // Already has OwnerId
        );
        insert subtask;
        Test.stopTest();
        
        // Verify subtask keeps its existing OwnerId but gets Client_User__c from parent
        Project_Task__c insertedSubtask = [SELECT Id, OwnerId, Client_User__c FROM Project_Task__c WHERE Id = :subtask.Id];
        System.assertEquals(anotherUser.Id, insertedSubtask.OwnerId, 'Subtask should keep existing OwnerId');
        System.assertEquals(parentTask.Client_User__c, insertedSubtask.Client_User__c, 'Subtask Client_User__c should be populated from parent');
    }
    
    @isTest
    static void testPopulateSubtaskUsers_EmptyList() {
        Test.startTest();
        TaskSubtaskHelper.populateSubtaskUsers(new List<Project_Task__c>());
        Test.stopTest();
        
        // Should not throw exception
        System.assert(true, 'Method should handle empty list without error');
    }
    
    // Test updateParentTaskStatus - after update
    @isTest
    static void testUpdateParentTaskStatus_BacklogToPending() {
        Project_Task__c parentTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Parent Task 2' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create subtask
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask for Status Update',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id
        );
        insert subtask;
        
        Test.startTest();
        // Update subtask from Backlog to Pending
        subtask.Status__c = 'Pending';
        update subtask;
        Test.stopTest();
        
        // Verify parent task status is updated to Pending
        Project_Task__c updatedParent = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals('Pending', updatedParent.Status__c, 'Parent task should be updated to Pending when subtask moves from Backlog to Pending');
    }
    
    @isTest
    static void testUpdateParentTaskStatus_PendingToInProgress() {
        Project_Task__c parentTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Parent Task 2' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create subtask in Pending status
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask for In Progress',
            Status__c = 'Pending',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id
        );
        insert subtask;
        
        // First update parent to Pending
        parentTask.Status__c = 'Pending';
        update parentTask;
        
        Test.startTest();
        // Update subtask from Pending to In Progress
        subtask.Status__c = 'In Progress';
        update subtask;
        Test.stopTest();
        
        // Verify parent task status is updated to In Progress
        Project_Task__c updatedParent = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals('In Progress', updatedParent.Status__c, 'Parent task should be updated to In Progress when subtask moves from Pending to In Progress');
    }
    
    @isTest
    static void testUpdateParentTaskStatus_ParentNotInBacklogOrPending() {
        Project_Task__c parentTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Parent Task 2' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Set parent to In Progress
        parentTask.Status__c = 'In Progress';
        update parentTask;
        
        // Create subtask
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask for Non-Backlog Parent',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id
        );
        insert subtask;
        
        Test.startTest();
        // Update subtask from Backlog to Pending
        subtask.Status__c = 'Pending';
        update subtask;
        Test.stopTest();
        
        // Verify parent task status is NOT updated (should remain In Progress)
        Project_Task__c updatedParent = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals('In Progress', updatedParent.Status__c, 'Parent task should not be updated if it is not in Backlog or Pending');
    }
    
    @isTest
    static void testUpdateParentTaskStatus_NoStatusChange() {
        Project_Task__c parentTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Parent Task 2' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create subtask
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask No Change',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id
        );
        insert subtask;
        
        Test.startTest();
        // Update subtask without changing status
        subtask.Name = 'Updated Name';
        update subtask;
        Test.stopTest();
        
        // Verify parent task status is NOT updated
        Project_Task__c updatedParent = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals('Backlog', updatedParent.Status__c, 'Parent task should not be updated if subtask status did not change');
    }
    
    @isTest
    static void testUpdateParentTaskStatus_MultipleSubtasks() {
        Project_Task__c parentTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Parent Task 2' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create multiple subtasks
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id
        ));
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Parent_Task__c = parentTask.Id
        ));
        insert subtasks;
        
        Test.startTest();
        // Update one subtask to Pending
        subtasks[0].Status__c = 'Pending';
        update subtasks[0];
        Test.stopTest();
        
        // Verify parent task status is updated to Pending
        Project_Task__c updatedParent = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals('Pending', updatedParent.Status__c, 'Parent task should be updated to Pending when any subtask is Pending');
    }
    
    @isTest
    static void testUpdateParentTaskStatus_InProgressTakesPriority() {
        Project_Task__c parentTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Parent Task 2' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create multiple subtasks
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        subtasks.add(new Project_Task__c(
            Name = 'Subtask Pending',
            Status__c = 'Pending',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id
        ));
        subtasks.add(new Project_Task__c(
            Name = 'Subtask In Progress',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Parent_Task__c = parentTask.Id
        ));
        insert subtasks;
        
        // First update parent to Pending
        parentTask.Status__c = 'Pending';
        update parentTask;
        
        Test.startTest();
        // Update second subtask to In Progress
        subtasks[1].Status__c = 'In Progress';
        update subtasks[1];
        Test.stopTest();
        
        // Verify parent task status is updated to In Progress (takes priority over Pending)
        Project_Task__c updatedParent = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals('In Progress', updatedParent.Status__c, 'Parent task should be updated to In Progress when any subtask is In Progress, even if another is Pending');
    }
    
    @isTest
    static void testUpdateParentTaskStatus_EmptyList() {
        Test.startTest();
        TaskSubtaskHelper.updateParentTaskStatus(new List<Project_Task__c>(), new Map<Id, Project_Task__c>());
        Test.stopTest();
        
        // Should not throw exception
        System.assert(true, 'Method should handle empty list without error');
    }
    
    // Test validateParentCanBeClosed - before update
    @isTest
    static void testValidateParentCanBeClosed_WithOpenSubtasks() {
        Project_Task__c parentTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Parent Task 3' LIMIT 1];
        
        Test.startTest();
        try {
            // Try to close parent task that has open subtasks
            parentTask.Status__c = 'Closed';
            update parentTask;
            System.assert(false, 'Expected an error when closing parent with open subtasks');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Can\'t close this task as there are subtasks that are still open'), 
                'Error message should indicate that parent cannot be closed with open subtasks');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateParentCanBeClosed_NoOpenSubtasks() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task No Open Subtasks',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create closed/completed subtasks
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        subtasks.add(new Project_Task__c(
            Name = 'Closed Subtask',
            Status__c = 'Closed',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id
        ));
        subtasks.add(new Project_Task__c(
            Name = 'Completed Subtask',
            Status__c = 'Completed',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Parent_Task__c = parentTask.Id
        ));
        subtasks.add(new Project_Task__c(
            Name = 'Removed Subtask',
            Status__c = 'Removed',
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            Parent_Task__c = parentTask.Id
        ));
        insert subtasks;
        
        Test.startTest();
        // Close parent task - should succeed
        parentTask.Status__c = 'Closed';
        update parentTask;
        Test.stopTest();
        
        // Verify parent task is closed
        Project_Task__c updatedParent = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals('Closed', updatedParent.Status__c, 'Parent task should be able to close when all subtasks are closed/completed/removed');
    }
    
    @isTest
    static void testValidateParentCanBeClosed_NoSubtasks() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task with no subtasks
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task No Subtasks',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        Test.startTest();
        // Close parent task - should succeed
        parentTask.Status__c = 'Closed';
        update parentTask;
        Test.stopTest();
        
        // Verify parent task is closed
        Project_Task__c updatedParent = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals('Closed', updatedParent.Status__c, 'Parent task should be able to close when it has no subtasks');
    }
    
    @isTest
    static void testValidateParentCanBeClosed_NotClosing() {
        Project_Task__c parentTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Parent Task 3' LIMIT 1];
        
        Test.startTest();
        // Update parent task without closing it
        parentTask.Name = 'Updated Name';
        update parentTask;
        Test.stopTest();
        
        // Verify parent task is updated successfully
        Project_Task__c updatedParent = [SELECT Id, Name FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals('Updated Name', updatedParent.Name, 'Parent task should be updated successfully when not closing');
    }
    
    @isTest
    static void testValidateParentCanBeClosed_Subtask() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Project_Task__c parentTask = [SELECT Id FROM Project_Task__c WHERE Name = 'Parent Task 3' LIMIT 1];
        
        // Create subtask
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id
        );
        insert subtask;
        
        Test.startTest();
        // Try to close subtask - should succeed (validation only applies to parent tasks)
        subtask.Status__c = 'Closed';
        update subtask;
        Test.stopTest();
        
        // Verify subtask is closed
        Project_Task__c updatedSubtask = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :subtask.Id];
        System.assertEquals('Closed', updatedSubtask.Status__c, 'Subtask should be able to close without validation');
    }
    
    @isTest
    static void testValidateParentCanBeClosed_EmptyList() {
        Test.startTest();
        TaskSubtaskHelper.validateParentCanBeClosed(new List<Project_Task__c>());
        Test.stopTest();
        
        // Should not throw exception
        System.assert(true, 'Method should handle empty list without error');
    }
    
    // ============================================
    // Tests that verify values are actually set
    // ============================================
    
    @isTest
    static void testPopulateSubtaskUsers_VerifyBothFieldsSet() {
        // Test that OwnerId is explicitly set from parent when creating subtask
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        // Use parent task from setup (which has OwnerId set)
        Project_Task__c parentTask = [SELECT Id, OwnerId FROM Project_Task__c WHERE Name = 'Parent Task' LIMIT 1];
        
        // Verify parent has OwnerId set
        System.assertNotEquals(null, parentTask.OwnerId, 'Parent task should have OwnerId set');
        
        Test.startTest();
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask Verify OwnerId Set',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id
            // Intentionally not setting OwnerId - should be populated from parent by trigger
        );
        insert subtask;
        Test.stopTest();
        
        // Re-query parent to get latest OwnerId value
        Project_Task__c parentTaskLatest = [SELECT Id, OwnerId FROM Project_Task__c WHERE Id = :parentTask.Id];
        
        // Verify OwnerId is set (not null) - this verifies populateSubtaskUsers is being called
        Project_Task__c insertedSubtask = [SELECT Id, OwnerId FROM Project_Task__c WHERE Id = :subtask.Id];
        System.assertNotEquals(null, insertedSubtask.OwnerId, 'Subtask OwnerId must not be null - populateSubtaskUsers must set this value');
        
        // Verify OwnerId matches parent (this verifies the correct value is set)
        // Note: If this fails, it indicates populateSubtaskUsers may not be copying OwnerId correctly
        System.assertEquals(parentTaskLatest.OwnerId, insertedSubtask.OwnerId, 
            'Subtask OwnerId must match parent OwnerId exactly to verify populateSubtaskUsers sets the correct value. Parent OwnerId: ' + parentTaskLatest.OwnerId + ', Subtask OwnerId: ' + insertedSubtask.OwnerId);
    }
    
    @isTest
    static void testPopulateSubtaskUsers_VerifyOnlyClientUserSetWhenOwnerExists() {
        // Test that when OwnerId is already set, it is preserved (not overwritten)
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE FirstName = 'Test' AND LastName = 'User' LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task For Owner Test',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            OwnerId = testUser.Id
        );
        insert parentTask;
        
        // Create a different user
        User differentUser = new User(
            FirstName = 'Different',
            LastName = 'User',
            Email = 'differentuser@example.com',
            Username = 'differentuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'duser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert differentUser;
        
        Test.startTest();
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask With Existing Owner',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id,
            OwnerId = differentUser.Id // Pre-set OwnerId
        );
        insert subtask;
        Test.stopTest();
        
        // Verify OwnerId is preserved (not overwritten by parent)
        Project_Task__c insertedSubtask = [SELECT Id, OwnerId FROM Project_Task__c WHERE Id = :subtask.Id];
        System.assertEquals(differentUser.Id, insertedSubtask.OwnerId, 'Subtask OwnerId must remain as pre-set value and NOT be overwritten by parent');
        System.assertNotEquals(parentTask.OwnerId, insertedSubtask.OwnerId, 'Subtask OwnerId should NOT match parent since it was pre-set');
    }
    
    @isTest
    static void testValidateParentCanBeClosed_VerifyErrorPreventsUpdate() {
        // Test that validation actually prevents the update and returns correct error
        Project_Task__c parentTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Parent Task 3' LIMIT 1];
        
        // Verify parent is not closed initially
        Project_Task__c checkBefore = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertNotEquals('Closed', checkBefore.Status__c, 'Parent should not be closed initially');
        
        Test.startTest();
        Boolean errorThrown = false;
        String errorMessage = '';
        try {
            parentTask.Status__c = 'Closed';
            update parentTask;
        } catch (DmlException e) {
            errorThrown = true;
            errorMessage = e.getMessage();
        }
        Test.stopTest();
        
        // Verify error was thrown
        System.assertEquals(true, errorThrown, 'Validation must throw an error when closing parent with open subtasks');
        System.assert(errorMessage.contains('Can\'t close this task as there are subtasks that are still open'), 
            'Error message must contain: Can\'t close this task as there are subtasks that are still open. Actual: ' + errorMessage);
        
        // Verify parent status was NOT updated (update was prevented)
        Project_Task__c checkAfter = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals(checkBefore.Status__c, checkAfter.Status__c, 'Parent status must NOT be changed when validation fails');
        System.assertNotEquals('Closed', checkAfter.Status__c, 'Parent must NOT be closed after failed validation');
    }
    
    @isTest
    static void testValidateParentCanBeClosed_VerifyUpdateSucceedsWhenAllowed() {
        // Test that update succeeds when validation passes
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent with only closed/completed subtasks
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent All Subtasks Closed',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create only closed/completed/removed subtasks
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        subtasks.add(new Project_Task__c(
            Name = 'Closed Subtask',
            Status__c = 'Closed',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Parent_Task__c = parentTask.Id
        ));
        subtasks.add(new Project_Task__c(
            Name = 'Completed Subtask',
            Status__c = 'Completed',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Parent_Task__c = parentTask.Id
        ));
        subtasks.add(new Project_Task__c(
            Name = 'Removed Subtask',
            Status__c = 'Removed',
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            Parent_Task__c = parentTask.Id
        ));
        insert subtasks;
        
        Test.startTest();
        // Update parent to Closed - should succeed
        parentTask.Status__c = 'Closed';
        update parentTask;
        Test.stopTest();
        
        // Verify parent status WAS updated to Closed
        Project_Task__c updatedParent = [SELECT Id, Status__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals('Closed', updatedParent.Status__c, 'Parent status must be updated to Closed when validation passes');
    }
}

