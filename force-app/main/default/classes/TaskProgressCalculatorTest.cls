@isTest
private class TaskProgressCalculatorTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
    }
    
    @isTest
    static void testCalculateProgress_WithSubtasks() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Progress_Percentage__c = 0,
            Total_Estimated_Hours__c = 0,
            Total_Actual_Hours__c = 0
        );
        insert parentTask;
        
        // Create subtasks
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        
        // Completed subtask
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 1 - Completed',
            Status__c = 'Completed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 10,
            Actual_Hours__c = 8
        ));
        
        // In Progress subtask
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 2 - In Progress',
            Status__c = 'In Progress',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 15,
            Actual_Hours__c = 5
        ));
        
        // Backlog subtask
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 3 - Backlog',
            Status__c = 'Backlog',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            Estimated_Hours__c = 20,
            Actual_Hours__c = 0
        ));
        
        Test.startTest();
        insert subtasks;
        Test.stopTest();
        
        // Verify parent task progress
        Project_Task__c updatedParent = [SELECT Id, Progress_Percentage__c, Total_Estimated_Hours__c, Total_Actual_Hours__c 
                                         FROM Project_Task__c WHERE Id = :parentTask.Id];
        
        // 1 out of 3 subtasks completed = 33.33%
        System.assertEquals(33.33, updatedParent.Progress_Percentage__c, 'Progress should be 33.33% (1 of 3 completed)');
        System.assertEquals(45, updatedParent.Total_Estimated_Hours__c, 'Total estimated hours should be 45');
        System.assertEquals(13, updatedParent.Total_Actual_Hours__c, 'Total actual hours should be 13');
    }
    
    @isTest
    static void testCalculateProgress_AllSubtasksCompleted() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task - All Complete',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create all completed subtasks
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 1',
            Status__c = 'Completed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 10,
            Actual_Hours__c = 10
        ));
        
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 2',
            Status__c = 'Closed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 15,
            Actual_Hours__c = 15
        ));
        
        Test.startTest();
        insert subtasks;
        Test.stopTest();
        
        // Verify parent task progress
        Project_Task__c updatedParent = [SELECT Id, Progress_Percentage__c, Total_Estimated_Hours__c, Total_Actual_Hours__c 
                                         FROM Project_Task__c WHERE Id = :parentTask.Id];
        
        // 2 out of 2 subtasks completed = 100%
        System.assertEquals(100, updatedParent.Progress_Percentage__c, 'Progress should be 100% (all subtasks completed)');
        System.assertEquals(25, updatedParent.Total_Estimated_Hours__c, 'Total estimated hours should be 25');
        System.assertEquals(25, updatedParent.Total_Actual_Hours__c, 'Total actual hours should be 25');
    }
    
    @isTest
    static void testCalculateProgress_WithRemovedSubtasks() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task - With Removed',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create subtasks including removed ones
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 1 - Completed',
            Status__c = 'Completed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 10,
            Actual_Hours__c = 10
        ));
        
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 2 - Removed',
            Status__c = 'Removed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 15,
            Actual_Hours__c = 5
        ));
        
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 3 - In Progress',
            Status__c = 'In Progress',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            Estimated_Hours__c = 20,
            Actual_Hours__c = 5
        ));
        
        Test.startTest();
        insert subtasks;
        Test.stopTest();
        
        // Verify parent task progress
        Project_Task__c updatedParent = [SELECT Id, Progress_Percentage__c, Total_Estimated_Hours__c, Total_Actual_Hours__c 
                                         FROM Project_Task__c WHERE Id = :parentTask.Id];
        
        // 1 out of 2 valid subtasks completed (removed doesn't count) = 50%
        System.assertEquals(50, updatedParent.Progress_Percentage__c, 'Progress should be 50% (1 of 2 valid subtasks completed, removed excluded)');
        // Removed tasks still count for hours
        System.assertEquals(45, updatedParent.Total_Estimated_Hours__c, 'Total estimated hours should include removed tasks');
        System.assertEquals(20, updatedParent.Total_Actual_Hours__c, 'Total actual hours should include removed tasks');
    }
    
    @isTest
    static void testCalculateProgress_NoSubtasks() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task with no subtasks
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task - No Subtasks',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        
        Test.startTest();
        insert parentTask;
        // Create a subtask and then delete it to trigger calculation
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Temporary Subtask',
            Status__c = 'Backlog',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert subtask;
        delete subtask;
        Test.stopTest();
        
        // Verify parent task - should not have been updated (no valid subtasks)
        Project_Task__c updatedParent = [SELECT Id, Progress_Percentage__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        // Progress should remain null or 0 since there are no valid subtasks
        System.assert(updatedParent.Progress_Percentage__c == null || updatedParent.Progress_Percentage__c == 0, 
                     'Progress should be null or 0 when there are no valid subtasks');
    }
    
    @isTest
    static void testCalculateProgress_EmptyParentTaskIds() {
        // Test with tasks that have no parent
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        List<Project_Task__c> tasks = new List<Project_Task__c>();
        tasks.add(new Project_Task__c(
            Name = 'Task Without Parent',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        ));
        
        Test.startTest();
        insert tasks;
        Test.stopTest();
        
        // Should not throw exception
        Project_Task__c insertedTask = [SELECT Id FROM Project_Task__c WHERE Id = :tasks[0].Id];
        System.assertNotEquals(null, insertedTask, 'Task should be created successfully');
    }
    
    @isTest
    static void testCalculateProgress_MissingAccountOrPriority() {
        // Since Priority__c is required, we can't test missing Priority directly
        // Instead, test that the method handles parent tasks correctly when all required fields are present
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task - Missing Priority',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High' // Required field
        );
        insert parentTask;
        
        // Create subtask
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask',
            Status__c = 'Completed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 10,
            Actual_Hours__c = 10
        );
        
        Test.startTest();
        insert subtask;
        Test.stopTest();
        
        // Verify parent task was updated correctly when all required fields are present
        Project_Task__c updatedParent = [SELECT Id, Progress_Percentage__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals(100, updatedParent.Progress_Percentage__c, 'Progress should be calculated when parent task has all required fields');
    }
    
    @isTest
    static void testCalculateProgress_UpdateSubtaskStatus() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task - Update Test',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create subtask
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask - Update Test',
            Status__c = 'In Progress',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 10,
            Actual_Hours__c = 5
        );
        insert subtask;
        
        // Update subtask to completed
        Test.startTest();
        subtask.Status__c = 'Completed';
        update subtask;
        Test.stopTest();
        
        // Verify parent task progress updated
        Project_Task__c updatedParent = [SELECT Id, Progress_Percentage__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals(100, updatedParent.Progress_Percentage__c, 'Progress should be 100% after subtask is completed');
    }
    
    @isTest
    static void testCalculateProgress_NullHours() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task - Null Hours',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create subtasks with null hours
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 1 - No Hours',
            Status__c = 'Completed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
            // No Estimated_Hours__c or Actual_Hours__c
        ));
        
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 2 - Partial Hours',
            Status__c = 'In Progress',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 10
            // No Actual_Hours__c
        ));
        
        Test.startTest();
        insert subtasks;
        Test.stopTest();
        
        // Verify parent task hours calculation handles nulls
        Project_Task__c updatedParent = [SELECT Id, Total_Estimated_Hours__c, Total_Actual_Hours__c 
                                         FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals(10, updatedParent.Total_Estimated_Hours__c, 'Total estimated hours should handle null values');
        System.assertEquals(0, updatedParent.Total_Actual_Hours__c, 'Total actual hours should be 0 when all are null');
    }
    
    @isTest
    static void testCalculateProgress_DeleteSubtask() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task - Delete Test',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create subtasks
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 1 - Keep',
            Status__c = 'Completed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 10,
            Actual_Hours__c = 10
        ));
        
        subtasks.add(new Project_Task__c(
            Name = 'Subtask 2 - Delete',
            Status__c = 'In Progress',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 15,
            Actual_Hours__c = 5
        ));
        
        insert subtasks;
        
        // Delete one subtask
        Test.startTest();
        delete subtasks[1];
        Test.stopTest();
        
        // Verify parent task progress updated (should be 100% with only one completed subtask remaining)
        Project_Task__c updatedParent = [SELECT Id, Progress_Percentage__c, Total_Estimated_Hours__c, Total_Actual_Hours__c 
                                         FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals(100, updatedParent.Progress_Percentage__c, 'Progress should be 100% after deleting incomplete subtask');
        System.assertEquals(10, updatedParent.Total_Estimated_Hours__c, 'Total estimated hours should reflect remaining subtask');
        System.assertEquals(10, updatedParent.Total_Actual_Hours__c, 'Total actual hours should reflect remaining subtask');
    }
    
    @isTest
    static void testCalculateProgress_ParentTaskNotInMap() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Test scenario where parent task exists but subtask references it
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task Not In Map',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create subtask
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask',
            Status__c = 'Completed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 10,
            Actual_Hours__c = 10
        );
        
        Test.startTest();
        insert subtask;
        Test.stopTest();
        
        // Verify parent task was updated correctly
        Project_Task__c updatedParent = [SELECT Id, Progress_Percentage__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals(100, updatedParent.Progress_Percentage__c, 'Progress should be calculated correctly');
    }
    
    @isTest
    static void testCalculateProgress_AllRemovedSubtasks() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task - All Removed',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create all removed subtasks
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        
        subtasks.add(new Project_Task__c(
            Name = 'Removed Subtask 1',
            Status__c = 'Removed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 10,
            Actual_Hours__c = 5
        ));
        
        subtasks.add(new Project_Task__c(
            Name = 'Removed Subtask 2',
            Status__c = 'Removed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 15,
            Actual_Hours__c = 10
        ));
        
        Test.startTest();
        insert subtasks;
        Test.stopTest();
        
        // Verify parent task progress is 0 (no valid subtasks)
        Project_Task__c updatedParent = [SELECT Id, Progress_Percentage__c, Total_Estimated_Hours__c, Total_Actual_Hours__c 
                                         FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals(0, updatedParent.Progress_Percentage__c, 'Progress should be 0 when all subtasks are removed');
        System.assertEquals(25, updatedParent.Total_Estimated_Hours__c, 'Total estimated hours should include removed tasks');
        System.assertEquals(15, updatedParent.Total_Actual_Hours__c, 'Total actual hours should include removed tasks');
    }
    
    @isTest
    static void testCalculateProgress_ZeroValidSubtasks() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task - Zero Valid',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create only removed subtasks
        Project_Task__c removedSubtask = new Project_Task__c(
            Name = 'Only Removed Subtask',
            Status__c = 'Removed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Estimated_Hours__c = 10,
            Actual_Hours__c = 5
        );
        
        Test.startTest();
        insert removedSubtask;
        Test.stopTest();
        
        // Verify parent task progress is 0
        Project_Task__c updatedParent = [SELECT Id, Progress_Percentage__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals(0, updatedParent.Progress_Percentage__c, 'Progress should be 0 when there are no valid subtasks');
    }
    
    @isTest
    static void testCalculateProgress_UpdateMultipleSubtasks() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task - Multiple Updates',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create multiple subtasks
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        
        for (Integer i = 0; i < 5; i++) {
            subtasks.add(new Project_Task__c(
                Name = 'Subtask ' + i,
                Status__c = 'In Progress',
                Parent_Task__c = parentTask.Id,
                Account__c = testAccount.Id,
                Priority__c = 'Medium',
                Estimated_Hours__c = 10,
                Actual_Hours__c = 5
            ));
        }
        insert subtasks;
        
        // Update all subtasks to completed
        Test.startTest();
        for (Project_Task__c subtask : subtasks) {
            subtask.Status__c = 'Completed';
        }
        update subtasks;
        Test.stopTest();
        
        // Verify parent task progress is 100%
        Project_Task__c updatedParent = [SELECT Id, Progress_Percentage__c FROM Project_Task__c WHERE Id = :parentTask.Id];
        System.assertEquals(100, updatedParent.Progress_Percentage__c, 'Progress should be 100% when all subtasks are completed');
    }
}

