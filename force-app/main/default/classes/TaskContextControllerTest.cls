@isTest
private class TaskContextControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test Project Tasks
        List<Project_Task__c> tasks = new List<Project_Task__c>();
        
        tasks.add(new Project_Task__c(
            Name = 'Task 1 - Backlog',
            Status__c = 'Backlog',
            Priority__c = 'High',
            Account__c = testAccount.Id,
            Estimated_Hours__c = 10,
            Actual_Hours__c = 8
        ));
        
        tasks.add(new Project_Task__c(
            Name = 'Task 2 - In Progress',
            Status__c = 'In Progress',
            Priority__c = 'Medium',
            Account__c = testAccount.Id,
            Estimated_Hours__c = 20,
            Actual_Hours__c = 15,
            Progress_Percentage__c = 50
        ));
        
        insert tasks;
    }
    
    // ============================================================================
    // getDependencyData Tests
    // ============================================================================
    
    @isTest
    static void testGetDependencyData() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create parent task
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task for Dependency',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Is_Blocking__c = false,
            At_Risk_Due_to_Dependencies__c = false
        );
        insert parentTask;
        
        // Create task with dependencies
        Project_Task__c taskWithDeps = new Project_Task__c(
            Name = 'Task With Dependencies',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Parent_Task__c = parentTask.Id,
            Is_Blocking__c = true,
            At_Risk_Due_to_Dependencies__c = true
        );
        insert taskWithDeps;
        
        // Create blocking dependency task
        Project_Task__c blockingTask = new Project_Task__c(
            Name = 'Blocking Dependency Task',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Is_Blocking__c = true
        );
        insert blockingTask;
        
        // Create relationship
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = taskWithDeps.Id,
            Task_B__c = blockingTask.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship;
        
        // Create subtask
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Subtask for Dependency Test',
            Status__c = 'Completed',
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            Parent_Task__c = taskWithDeps.Id
        );
        insert subtask;
        
        Test.startTest();
        TaskContextController.DependencyDataResult result = 
            TaskContextController.getDependencyData(taskWithDeps.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.dependencies, 'Dependencies should not be null');
        System.assertNotEquals(null, result.dependentTasks, 'Dependent tasks should not be null');
        System.assertNotEquals(null, result.subtasks, 'Subtasks should not be null');
        System.assertNotEquals(null, result.parentTask, 'Parent task should not be null');
        System.assertNotEquals(null, result.subtaskProgress, 'Subtask progress should not be null');
    }
    
    @isTest
    static void testGetDependencyDataWithNull() {
        Test.startTest();
        TaskContextController.DependencyDataResult result = 
            TaskContextController.getDependencyData(null);
        Test.stopTest();
        
        System.assertEquals(null, result, 'Result should be null for null taskId');
    }
    
    @isTest
    static void testGetDependencyDataWithEmptyString() {
        Test.startTest();
        TaskContextController.DependencyDataResult result = 
            TaskContextController.getDependencyData('');
        Test.stopTest();
        
        System.assertEquals(null, result, 'Result should be null for empty taskId');
    }
    
    @isTest
    static void testGetDependencyDataWithNoDependencies() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create a task with no dependencies
        Project_Task__c standaloneTask = new Project_Task__c(
            Name = 'Standalone Task',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert standaloneTask;
        
        Test.startTest();
        TaskContextController.DependencyDataResult result = 
            TaskContextController.getDependencyData(standaloneTask.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.dependencies, 'Dependencies should not be null');
        System.assertEquals(0, result.dependencies.size(), 'Should have no dependencies');
        System.assertNotEquals(null, result.subtasks, 'Subtasks should not be null');
        System.assertEquals(0, result.subtasks.size(), 'Should have no subtasks');
    }
    
    @isTest
    static void testGetDependencyDataWithDependentTasks() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create task that other tasks depend on
        Project_Task__c blockingTask = new Project_Task__c(
            Name = 'Blocking Task',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Is_Blocking__c = true
        );
        insert blockingTask;
        
        // Create task that depends on blocking task
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Dependent Task',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert dependentTask;
        
        // Create relationship where dependentTask depends on blockingTask
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship;
        
        Test.startTest();
        // Get dependency data for blockingTask - should show dependentTask in dependentTasks list
        TaskContextController.DependencyDataResult result = 
            TaskContextController.getDependencyData(blockingTask.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.dependentTasks, 'Dependent tasks should not be null');
        System.assert(result.dependentTasks.size() > 0, 'Should have dependent tasks');
    }
    
    @isTest
    static void testGetDependencyDataWithSubtasksProgress() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task Progress',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert parentTask;
        
        // Create subtasks with various statuses
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        
        subtasks.add(new Project_Task__c(
            Name = 'Completed Subtask',
            Status__c = 'Completed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        ));
        
        subtasks.add(new Project_Task__c(
            Name = 'In Progress Subtask',
            Status__c = 'In Progress',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        ));
        
        subtasks.add(new Project_Task__c(
            Name = 'Removed Subtask',
            Status__c = 'Removed',
            Parent_Task__c = parentTask.Id,
            Account__c = testAccount.Id,
            Priority__c = 'Low'
        ));
        
        insert subtasks;
        
        Test.startTest();
        TaskContextController.DependencyDataResult result = 
            TaskContextController.getDependencyData(parentTask.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.subtaskProgress, 'Subtask progress should not be null');
        System.assertEquals(50, result.subtaskProgress.progressPercentage, 'Progress should be 50% (1 of 2 valid subtasks)');
        System.assertEquals(1, result.subtaskProgress.completedCount, 'Should have 1 completed subtask');
        System.assertEquals(2, result.subtaskProgress.totalCount, 'Should have 2 valid subtasks (removed excluded)');
    }
    
    @isTest
    static void testGetDependencyDataWithRelationshipTypes() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        // Create relationship with specific type
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = task2.Id,
            Task_B__c = task1.Id,
            Relationship_Type__c = 'Related' // Non-blocking relationship
        );
        insert relationship;
        
        Test.startTest();
        TaskContextController.DependencyDataResult result = 
            TaskContextController.getDependencyData(task2.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.dependencies, 'Dependencies should not be null');
        if (result.dependencies.size() > 0) {
            System.assertEquals('Related', result.dependencies[0].type, 'Relationship type should be preserved');
        }
    }
    
    @isTest
    static void testGetDependencyDataWithBlankRelationshipType() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        // Create relationship with blank type
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = task2.Id,
            Task_B__c = task1.Id
            // Relationship_Type__c is blank
        );
        insert relationship;
        
        Test.startTest();
        TaskContextController.DependencyDataResult result = 
            TaskContextController.getDependencyData(task2.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.dependencies, 'Dependencies should not be null');
        if (result.dependencies.size() > 0) {
            System.assertEquals('Related', result.dependencies[0].type, 'Blank relationship type should default to Related');
        }
    }
    
    // ============================================================================
    // createTaskRelationship Tests
    // ============================================================================
    
    @isTest
    static void testCreateTaskRelationship() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        Test.startTest();
        String relationshipId = TaskContextController.createTaskRelationship(
            task1.Id,
            task2.Id,
            'Related'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, relationshipId, 'Relationship ID should not be null');
        
        // Verify relationship was created
        List<Project_Task_Relationship__c> relationships = [
            SELECT Id, Task_A__c, Task_B__c, Relationship_Type__c
            FROM Project_Task_Relationship__c
            WHERE Id = :relationshipId
        ];
        System.assertEquals(1, relationships.size(), 'Relationship should be created');
        System.assertEquals(task1.Id, relationships[0].Task_A__c, 'Task A should match');
        System.assertEquals(task2.Id, relationships[0].Task_B__c, 'Task B should match');
        System.assertEquals('Related', relationships[0].Relationship_Type__c, 'Relationship type should match');
    }
    
    @isTest
    static void testCreateTaskRelationshipWithBlankType() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        Test.startTest();
        String relationshipId = TaskContextController.createTaskRelationship(
            task1.Id,
            task2.Id,
            null
        );
        Test.stopTest();
        
        System.assertNotEquals(null, relationshipId, 'Relationship ID should not be null');
        
        // Verify relationship was created with default type
        Project_Task_Relationship__c relationship = [
            SELECT Relationship_Type__c
            FROM Project_Task_Relationship__c
            WHERE Id = :relationshipId
        ];
        System.assertEquals('Related', relationship.Relationship_Type__c, 'Should default to Related');
    }
    
    @isTest
    static void testCreateTaskRelationshipSelfReference() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Test.startTest();
        try {
            TaskContextController.createTaskRelationship(
                task1.Id,
                task1.Id,
                'Related'
            );
            System.assert(false, 'Should have thrown exception for self-reference');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('cannot be related to itself'), 'Error message should mention self-reference');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTaskRelationshipDuplicate() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        // Create first relationship
        Project_Task_Relationship__c relationship1 = new Project_Task_Relationship__c(
            Task_A__c = task1.Id,
            Task_B__c = task2.Id,
            Relationship_Type__c = 'Related'
        );
        insert relationship1;
        
        Test.startTest();
        try {
            // Try to create duplicate relationship
            TaskContextController.createTaskRelationship(
                task1.Id,
                task2.Id,
                'Related'
            );
            System.assert(false, 'Should have thrown exception for duplicate');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('already exists'), 'Error message should mention duplicate');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTaskRelationshipMissingTaskA() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        Test.startTest();
        try {
            TaskContextController.createTaskRelationship(
                null,
                task2.Id,
                'Related'
            );
            System.assert(false, 'Should have thrown exception for missing Task A');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Error message should mention required');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateTaskRelationshipMissingTaskB() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Test.startTest();
        try {
            TaskContextController.createTaskRelationship(
                task1.Id,
                null,
                'Related'
            );
            System.assert(false, 'Should have thrown exception for missing Task B');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Error message should mention required');
        }
        Test.stopTest();
    }
    
    // ============================================================================
    // updateTaskRelationship Tests
    // ============================================================================
    
    @isTest
    static void testUpdateTaskRelationship() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = task1.Id,
            Task_B__c = task2.Id,
            Relationship_Type__c = 'Related'
        );
        insert relationship;
        
        Test.startTest();
        String result = TaskContextController.updateTaskRelationship(
            relationship.Id,
            'Blocking Dependency'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        
        // Verify relationship was updated
        Project_Task_Relationship__c updatedRelationship = [
            SELECT Relationship_Type__c
            FROM Project_Task_Relationship__c
            WHERE Id = :relationship.Id
        ];
        System.assertEquals('Blocking Dependency', updatedRelationship.Relationship_Type__c, 'Relationship type should be updated');
    }
    
    @isTest
    static void testUpdateTaskRelationshipWithBlankType() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = task1.Id,
            Task_B__c = task2.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship;
        
        Test.startTest();
        String result = TaskContextController.updateTaskRelationship(
            relationship.Id,
            null
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        
        // Verify relationship was updated with default type
        Project_Task_Relationship__c updatedRelationship = [
            SELECT Relationship_Type__c
            FROM Project_Task_Relationship__c
            WHERE Id = :relationship.Id
        ];
        System.assertEquals('Related', updatedRelationship.Relationship_Type__c, 'Should default to Related');
    }
    
    @isTest
    static void testUpdateTaskRelationshipNotFound() {
        Test.startTest();
        try {
            TaskContextController.updateTaskRelationship(
                'a00000000000000AAA',
                'Related'
            );
            System.assert(false, 'Should have thrown exception for not found');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not found'), 'Error message should mention not found');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateTaskRelationshipMissingId() {
        Test.startTest();
        try {
            TaskContextController.updateTaskRelationship(
                null,
                'Related'
            );
            System.assert(false, 'Should have thrown exception for missing ID');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Error message should mention required');
        }
        Test.stopTest();
    }
    
    // ============================================================================
    // deleteTaskRelationship Tests
    // ============================================================================
    
    @isTest
    static void testDeleteTaskRelationship() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = task1.Id,
            Task_B__c = task2.Id,
            Relationship_Type__c = 'Related'
        );
        insert relationship;
        
        Test.startTest();
        String result = TaskContextController.deleteTaskRelationship(relationship.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        
        // Verify relationship was deleted
        List<Project_Task_Relationship__c> relationships = [
            SELECT Id
            FROM Project_Task_Relationship__c
            WHERE Id = :relationship.Id
        ];
        System.assertEquals(0, relationships.size(), 'Relationship should be deleted');
    }
    
    @isTest
    static void testDeleteTaskRelationshipNotFound() {
        Test.startTest();
        try {
            TaskContextController.deleteTaskRelationship('a00000000000000AAA');
            System.assert(false, 'Should have thrown exception for not found');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not found'), 'Error message should mention not found');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testDeleteTaskRelationshipMissingId() {
        Test.startTest();
        try {
            TaskContextController.deleteTaskRelationship(null);
            System.assert(false, 'Should have thrown exception for missing ID');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Error message should mention required');
        }
        Test.stopTest();
    }
    
    // ============================================================================
    // getRelationshipDetails Tests
    // ============================================================================
    
    @isTest
    static void testGetRelationshipDetails() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = task1.Id,
            Task_B__c = task2.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship;
        
        Test.startTest();
        TaskContextController.RelationshipDetails details = 
            TaskContextController.getRelationshipDetails(relationship.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, details, 'Details should not be null');
        System.assertEquals(task2.Id, details.taskBId, 'Task B ID should match');
        System.assertEquals('Blocking Dependency', details.relationshipType, 'Relationship type should match');
    }
    
    @isTest
    static void testGetRelationshipDetailsWithBlankType() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = task1.Id,
            Task_B__c = task2.Id
            // Relationship_Type__c is blank
        );
        insert relationship;
        
        Test.startTest();
        TaskContextController.RelationshipDetails details = 
            TaskContextController.getRelationshipDetails(relationship.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, details, 'Details should not be null');
        System.assertEquals('Related', details.relationshipType, 'Should default to Related');
    }
    
    @isTest
    static void testGetRelationshipDetailsNotFound() {
        Test.startTest();
        try {
            TaskContextController.getRelationshipDetails('a00000000000000AAA');
            System.assert(false, 'Should have thrown exception for not found');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not found'), 'Error message should mention not found');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetRelationshipDetailsMissingId() {
        Test.startTest();
        try {
            TaskContextController.getRelationshipDetails(null);
            System.assert(false, 'Should have thrown exception for missing ID');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Error message should mention required');
        }
        Test.stopTest();
    }
    
    // ============================================================================
    // searchTasks Tests
    // ============================================================================
    
    @isTest
    static void testSearchTasks() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Search Test Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Search Test Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        Project_Task__c task3 = new Project_Task__c(
            Name = 'Other Task',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Low'
        );
        insert task3;
        
        Test.startTest();
        List<TaskContextController.TaskSearchResult> results = 
            TaskContextController.searchTasks('Search Test', null);
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() >= 2, 'Should find at least 2 tasks');
        
        // Verify results contain the search term
        for (TaskContextController.TaskSearchResult result : results) {
            System.assert(result.name.contains('Search Test'), 'Result should contain search term');
        }
    }
    
    @isTest
    static void testSearchTasksWithExclude() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task1 = new Project_Task__c(
            Name = 'Search Test Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert task1;
        
        Project_Task__c task2 = new Project_Task__c(
            Name = 'Search Test Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert task2;
        
        Test.startTest();
        List<TaskContextController.TaskSearchResult> results = 
            TaskContextController.searchTasks('Search Test', task1.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Results should not be null');
        
        // Verify excluded task is not in results
        for (TaskContextController.TaskSearchResult result : results) {
            System.assertNotEquals(task1.Id, result.id, 'Excluded task should not be in results');
        }
    }
    
    @isTest
    static void testSearchTasksWithBlankTerm() {
        Test.startTest();
        List<TaskContextController.TaskSearchResult> results = 
            TaskContextController.searchTasks('', null);
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list for blank search term');
    }
    
    @isTest
    static void testSearchTasksWithNullTerm() {
        Test.startTest();
        List<TaskContextController.TaskSearchResult> results = 
            TaskContextController.searchTasks(null, null);
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list for null search term');
    }
}

