@isTest
private class TaskDependencyHelperTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test Project Tasks
        List<Project_Task__c> tasks = new List<Project_Task__c>();
        
        // Task 1 - Will be a blocking dependency
        tasks.add(new Project_Task__c(
            Name = 'Blocking Task 1',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Is_Blocking__c = false,
            At_Risk_Due_to_Dependencies__c = false
        ));
        
        // Task 2 - Will depend on Task 1
        tasks.add(new Project_Task__c(
            Name = 'Dependent Task 1',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Is_Blocking__c = false,
            At_Risk_Due_to_Dependencies__c = false
        ));
        
        // Task 3 - Another blocking task
        tasks.add(new Project_Task__c(
            Name = 'Blocking Task 2',
            Status__c = 'Pending',
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            Is_Blocking__c = false,
            At_Risk_Due_to_Dependencies__c = false
        ));
        
        // Task 4 - Will depend on Task 3
        tasks.add(new Project_Task__c(
            Name = 'Dependent Task 2',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Is_Blocking__c = false,
            At_Risk_Due_to_Dependencies__c = false
        ));
        
        // Task 5 - Completed task (should not block)
        tasks.add(new Project_Task__c(
            Name = 'Completed Task',
            Status__c = 'Completed',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Is_Blocking__c = false,
            At_Risk_Due_to_Dependencies__c = false
        ));
        
        // Task 6 - Closed task (should not block)
        tasks.add(new Project_Task__c(
            Name = 'Closed Task',
            Status__c = 'Closed',
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            Is_Blocking__c = false,
            At_Risk_Due_to_Dependencies__c = false
        ));
        
        // Task 7 - In Review task (should not block)
        tasks.add(new Project_Task__c(
            Name = 'In Review Task',
            Status__c = 'In Review',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Is_Blocking__c = false,
            At_Risk_Due_to_Dependencies__c = false
        ));
        
        // Task 8 - Removed task (should not block)
        tasks.add(new Project_Task__c(
            Name = 'Removed Task',
            Status__c = 'Removed',
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            Is_Blocking__c = false,
            At_Risk_Due_to_Dependencies__c = false
        ));
        
        insert tasks;
        
        // Create blocking dependency relationships
        // Task 2 depends on Task 1 (Task A = Task 2, Task B = Task 1)
        List<Project_Task_Relationship__c> relationships = new List<Project_Task_Relationship__c>();
        
        Project_Task__c task1 = [SELECT Id FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        Project_Task__c task2 = [SELECT Id FROM Project_Task__c WHERE Name = 'Dependent Task 1' LIMIT 1];
        Project_Task__c task3 = [SELECT Id FROM Project_Task__c WHERE Name = 'Blocking Task 2' LIMIT 1];
        Project_Task__c task4 = [SELECT Id FROM Project_Task__c WHERE Name = 'Dependent Task 2' LIMIT 1];
        Project_Task__c task5 = [SELECT Id FROM Project_Task__c WHERE Name = 'Completed Task' LIMIT 1];
        Project_Task__c task6 = [SELECT Id FROM Project_Task__c WHERE Name = 'Closed Task' LIMIT 1];
        Project_Task__c task7 = [SELECT Id FROM Project_Task__c WHERE Name = 'In Review Task' LIMIT 1];
        Project_Task__c task8 = [SELECT Id FROM Project_Task__c WHERE Name = 'Removed Task' LIMIT 1];
        
        // Task 2 depends on Task 1 (blocking dependency)
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = task2.Id,
            Task_B__c = task1.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        
        // Task 4 depends on Task 3 (blocking dependency)
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = task4.Id,
            Task_B__c = task3.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        
        // Task 2 also depends on Task 5 (completed - should not block)
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = task2.Id,
            Task_B__c = task5.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        
        // Task 2 depends on Task 6 (closed - should not block)
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = task2.Id,
            Task_B__c = task6.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        
        // Task 2 depends on Task 7 (in review - should not block)
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = task2.Id,
            Task_B__c = task7.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        
        // Task 2 depends on Task 8 (removed - should not block)
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = task2.Id,
            Task_B__c = task8.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        
        insert relationships;
    }
    
    @isTest
    static void testAssessDependencyRisk_BlockingDependency() {
        // Get tasks
        Project_Task__c blockingTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Name = 'Dependent Task 1' LIMIT 1];
        
        // Initially, dependent task should not be at risk (setup doesn't trigger the helper)
        // Update the blocking task to trigger assessment
        Test.startTest();
        blockingTask.Status__c = 'In Progress';
        update blockingTask;
        Test.stopTest();
        
        // Verify dependent task is marked as at risk
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should be at risk when blocking task is not completed');
    }
    
    @isTest
    static void testAssessDependencyRisk_CompletedDependency() {
        // Get tasks
        Project_Task__c blockingTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Name = 'Dependent Task 1' LIMIT 1];
        
        // Set blocking task to completed
        Test.startTest();
        blockingTask.Status__c = 'Completed';
        update blockingTask;
        Test.stopTest();
        
        // Verify dependent task is not at risk
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should not be at risk when blocking task is completed');
    }
    
    @isTest
    static void testAssessDependencyRisk_ClosedDependency() {
        // Get tasks
        Project_Task__c blockingTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Name = 'Dependent Task 1' LIMIT 1];
        
        // Set blocking task to closed
        Test.startTest();
        blockingTask.Status__c = 'Closed';
        update blockingTask;
        Test.stopTest();
        
        // Verify dependent task is not at risk
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should not be at risk when blocking task is closed');
    }
    
    @isTest
    static void testAssessDependencyRisk_InReviewDependency() {
        // Get tasks
        Project_Task__c blockingTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Name = 'Dependent Task 1' LIMIT 1];
        
        // Set blocking task to in review
        Test.startTest();
        blockingTask.Status__c = 'In Review';
        update blockingTask;
        Test.stopTest();
        
        // Verify dependent task is not at risk
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should not be at risk when blocking task is in review');
    }
    
    @isTest
    static void testAssessDependencyRisk_RemovedDependency() {
        // Get tasks
        Project_Task__c blockingTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Name = 'Dependent Task 1' LIMIT 1];
        
        // Set blocking task to removed
        Test.startTest();
        blockingTask.Status__c = 'Removed';
        update blockingTask;
        Test.stopTest();
        
        // Verify dependent task is not at risk
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should not be at risk when blocking task is removed');
    }
    
    @isTest
    static void testAssessDependencyRisk_IsBlockingField() {
        // Get task that has blocking dependencies on it
        Project_Task__c blockingTask = [SELECT Id, Status__c, Is_Blocking__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        
        // Update status to trigger Is_Blocking__c calculation
        Test.startTest();
        blockingTask.Status__c = 'In Progress';
        update blockingTask;
        Test.stopTest();
        
        // Verify Is_Blocking__c is set to true
        Project_Task__c updatedTask = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(true, updatedTask.Is_Blocking__c, 'Task should be marked as blocking when it has blocking dependencies and is not completed/closed/in review');
    }
    
    @isTest
    static void testAssessDependencyRisk_IsBlockingField_Completed() {
        // Get task that has blocking dependencies on it
        Project_Task__c blockingTask = [SELECT Id, Status__c, Is_Blocking__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        
        // Update status to completed
        Test.startTest();
        blockingTask.Status__c = 'Completed';
        update blockingTask;
        Test.stopTest();
        
        // Verify Is_Blocking__c is set to false
        Project_Task__c updatedTask = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(false, updatedTask.Is_Blocking__c, 'Task should not be marked as blocking when it is completed');
    }
    
    @isTest
    static void testAssessDependencyRisk_NoBlockingDependencies() {
        // Create a task with no blocking dependencies
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Project_Task__c standaloneTask = new Project_Task__c(
            Name = 'Standalone Task',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            At_Risk_Due_to_Dependencies__c = true // Initially set to true
        );
        insert standaloneTask;
        
        Test.startTest();
        // Update the task - should clear At_Risk_Due_to_Dependencies__c since it has no blocking dependencies
        standaloneTask.Status__c = 'In Progress';
        update standaloneTask;
        Test.stopTest();
        
        // Verify At_Risk_Due_to_Dependencies__c is cleared
        Project_Task__c updatedTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :standaloneTask.Id];
        System.assertEquals(false, updatedTask.At_Risk_Due_to_Dependencies__c, 'Task with no blocking dependencies should not be at risk');
    }
    
    @isTest
    static void testAssessDependencyRisk_ReverseDependency() {
        // Test when Task B (blocking task) status changes, Task A (dependent task) should be updated
        Project_Task__c blockingTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Blocking Task 2' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Name = 'Dependent Task 2' LIMIT 1];
        
        // Update blocking task status - this should trigger update of dependent task
        Test.startTest();
        blockingTask.Status__c = 'In Progress';
        update blockingTask;
        Test.stopTest();
        
        // Verify dependent task is marked as at risk
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should be at risk when blocking task status changes');
    }
    
    @isTest
    static void testAssessDependencyRisk_MultipleDependencies() {
        // Task 2 has multiple dependencies - one blocking (Task 1) and several non-blocking (completed, closed, etc.)
        // Task 1 is the only active blocking dependency
        Project_Task__c blockingTask1 = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Name = 'Dependent Task 1' LIMIT 1];
        
        // Set Task 1 to completed - Task 2 should no longer be at risk
        Test.startTest();
        blockingTask1.Status__c = 'Completed';
        update blockingTask1;
        Test.stopTest();
        
        // Verify dependent task is not at risk (all blocking dependencies are resolved)
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should not be at risk when all blocking dependencies are resolved');
    }
    
    @isTest
    static void testAssessDependencyRisk_EmptyTaskList() {
        // Test with empty list
        Test.startTest();
        TaskDependencyHelper.assessDependencyRisk(new List<Project_Task__c>());
        Test.stopTest();
        
        // Should not throw exception
        System.assert(true, 'Method should handle empty list without error');
    }
    
    @isTest
    static void testAssessDependencyRisk_NoRelationships() {
        // Create a task with no relationships
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Project_Task__c newTask = new Project_Task__c(
            Name = 'Task With No Relationships',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        
        Test.startTest();
        insert newTask;
        Test.stopTest();
        
        // Should not throw exception
        Project_Task__c insertedTask = [SELECT Id FROM Project_Task__c WHERE Id = :newTask.Id];
        System.assertNotEquals(null, insertedTask, 'Task should be created successfully');
    }
    
    @isTest
    static void testAssessDependencyRisk_IsBlockingField_Closed() {
        // Get task that has blocking dependencies on it
        Project_Task__c blockingTask = [SELECT Id, Status__c, Is_Blocking__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        
        // Update status to closed
        Test.startTest();
        blockingTask.Status__c = 'Closed';
        update blockingTask;
        Test.stopTest();
        
        // Verify Is_Blocking__c is set to false
        Project_Task__c updatedTask = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(false, updatedTask.Is_Blocking__c, 'Task should not be marked as blocking when it is closed');
    }
    
    @isTest
    static void testAssessDependencyRisk_IsBlockingField_InReview() {
        // Get task that has blocking dependencies on it
        Project_Task__c blockingTask = [SELECT Id, Status__c, Is_Blocking__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        
        // Update status to in review
        Test.startTest();
        blockingTask.Status__c = 'In Review';
        update blockingTask;
        Test.stopTest();
        
        // Verify Is_Blocking__c is set to false
        Project_Task__c updatedTask = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(false, updatedTask.Is_Blocking__c, 'Task should not be marked as blocking when it is in review');
    }
    
    @isTest
    static void testAssessDependencyRisk_IsBlockingField_Removed() {
        // Get task that has blocking dependencies on it
        Project_Task__c blockingTask = [SELECT Id, Status__c, Is_Blocking__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        
        // Update status to removed
        Test.startTest();
        blockingTask.Status__c = 'Removed';
        update blockingTask;
        Test.stopTest();
        
        // Verify Is_Blocking__c is set to false
        Project_Task__c updatedTask = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(false, updatedTask.Is_Blocking__c, 'Task should not be marked as blocking when it is removed');
    }
    
    @isTest
    static void testAssessDependencyRisk_ClearIsBlockingWhenNoDependencies() {
        // Create a task that is marked as blocking but has no dependencies
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Project_Task__c task = new Project_Task__c(
            Name = 'Task No Dependencies',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Is_Blocking__c = true // Initially set to true
        );
        insert task;
        
        Test.startTest();
        // Update the task - should clear Is_Blocking__c since it has no dependencies
        task.Status__c = 'Backlog';
        update task;
        Test.stopTest();
        
        // Verify Is_Blocking__c is cleared
        Project_Task__c updatedTask = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :task.Id];
        System.assertEquals(false, updatedTask.Is_Blocking__c, 'Task should not be blocking when it has no blocking dependencies');
    }
    
    @isTest
    static void testAssessDependencyRisk_DependentTaskNotInMap() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create blocking task
        Project_Task__c blockingTask = new Project_Task__c(
            Name = 'Blocking Task for Dependent',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert blockingTask;
        
        // Create dependent task
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Dependent Task Not In Map',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert dependentTask;
        
        // Create relationship
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship;
        
        // Update blocking task - this should trigger update of dependent task
        Test.startTest();
        blockingTask.Status__c = 'Completed';
        update blockingTask;
        Test.stopTest();
        
        // Verify dependent task is updated
        Project_Task__c updatedDependent = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, updatedDependent.At_Risk_Due_to_Dependencies__c, 'Dependent task should not be at risk when blocking task is completed');
    }
}

