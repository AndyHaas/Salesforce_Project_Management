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
    
    @isTest
    static void testAssessDependencyRisk_UpdateBlockingTaskNonStatusField() {
        // Test that updating a blocking task's non-status field (e.g., priority) 
        // still triggers re-assessment of dependent tasks
        Project_Task__c blockingTask = [SELECT Id, Status__c, Priority__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Name = 'Dependent Task 1' LIMIT 1];
        
        // Ensure blocking task is in a blocking status
        blockingTask.Status__c = 'In Progress';
        update blockingTask;
        
        // Verify dependent task is at risk
        Project_Task__c checkTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, checkTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should be at risk initially');
        
        // Now update only the priority (non-status field) of the blocking task
        Test.startTest();
        blockingTask.Priority__c = 'Low';
        update blockingTask;
        Test.stopTest();
        
        // Verify dependent task is still at risk (re-assessment should have occurred)
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should remain at risk after non-status field update on blocking task');
    }
    
    @isTest
    static void testAssessDependencyRisk_UpdateDependentTaskNonStatusField() {
        // Test that updating a dependent task's non-status field (e.g., priority)
        // still triggers re-assessment of its own risk
        Project_Task__c blockingTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c, Priority__c FROM Project_Task__c WHERE Name = 'Dependent Task 1' LIMIT 1];
        
        // Ensure blocking task is in a blocking status
        blockingTask.Status__c = 'In Progress';
        update blockingTask;
        
        // Verify dependent task is at risk
        Project_Task__c checkTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, checkTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should be at risk initially');
        
        // Now update only the priority (non-status field) of the dependent task
        Test.startTest();
        dependentTask.Priority__c = 'Low';
        update dependentTask;
        Test.stopTest();
        
        // Verify dependent task is still at risk (re-assessment should have occurred)
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should remain at risk after non-status field update');
    }
    
    @isTest
    static void testAssessDependencyRisk_UpdateBlockingTaskClearsRisk() {
        // Test that updating a blocking task from blocking status to completed
        // clears the risk on dependent tasks
        Project_Task__c blockingTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Blocking Task 1' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Name = 'Dependent Task 1' LIMIT 1];
        
        // Set blocking task to In Progress (blocking status)
        blockingTask.Status__c = 'In Progress';
        update blockingTask;
        
        // Verify dependent task is at risk
        Project_Task__c checkTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, checkTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should be at risk when blocking task is In Progress');
        
        // Update blocking task to Completed
        Test.startTest();
        blockingTask.Status__c = 'Completed';
        update blockingTask;
        Test.stopTest();
        
        // Verify dependent task is no longer at risk
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should not be at risk when blocking task is completed');
    }
    
    @isTest
    static void testAssessDependencyRisk_UpdateDependentTaskReassessesRisk() {
        // Test that updating a dependent task re-assesses its risk based on current blocking task status
        Project_Task__c blockingTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Blocking Task 2' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c, Priority__c FROM Project_Task__c WHERE Name = 'Dependent Task 2' LIMIT 1];
        
        // Set blocking task to Completed (non-blocking status)
        blockingTask.Status__c = 'Completed';
        update blockingTask;
        
        // Verify dependent task is not at risk (should have been cleared by trigger)
        Project_Task__c checkTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, checkTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should not be at risk when blocking task is completed');
        
        // Update dependent task (non-status field) - should trigger re-assessment
        // This verifies that any update triggers re-assessment, even when status hasn't changed
        Test.startTest();
        dependentTask.Priority__c = 'Low';
        update dependentTask;
        Test.stopTest();
        
        // Verify dependent task is still not at risk (re-assessment confirms it)
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should remain not at risk after re-assessment when blocking task is completed');
    }
    
    @isTest
    static void testAssessDependencyRisk_UpdateBlockingTaskSetsRisk() {
        // Test that updating a blocking task from completed to blocking status
        // sets the risk on dependent tasks
        Project_Task__c blockingTask = [SELECT Id, Status__c FROM Project_Task__c WHERE Name = 'Blocking Task 2' LIMIT 1];
        Project_Task__c dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Name = 'Dependent Task 2' LIMIT 1];
        
        // Set blocking task to Completed (non-blocking status)
        blockingTask.Status__c = 'Completed';
        update blockingTask;
        
        // Verify dependent task is not at risk
        Project_Task__c checkTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, checkTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should not be at risk when blocking task is completed');
        
        // Update blocking task to In Progress (blocking status)
        Test.startTest();
        blockingTask.Status__c = 'In Progress';
        update blockingTask;
        Test.stopTest();
        
        // Verify dependent task is now at risk
        Project_Task__c updatedDependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, updatedDependentTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should be at risk when blocking task changes to blocking status');
    }
    
    // ============================================
    // Additional Tests for At Risk Due to Dependencies
    // ============================================
    
    @isTest
    static void testAtRiskDueToDependencies_BlockedStatus() {
        // Test that Blocked status is considered a blocking status
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create blocking task with Blocked status
        Project_Task__c blockingTask = new Project_Task__c(
            Name = 'Blocked Task',
            Status__c = 'Blocked',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert blockingTask;
        
        // Create dependent task
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Dependent on Blocked',
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
        
        Test.startTest();
        // Update dependent task to trigger assessment
        dependentTask.Status__c = 'Pending';
        update dependentTask;
        Test.stopTest();
        
        // Verify dependent task is at risk
        Project_Task__c updatedTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, updatedTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should be at risk when blocking task is Blocked');
    }
    
    @isTest
    static void testAtRiskDueToDependencies_BacklogStatus() {
        // Test that Backlog status is considered a blocking status
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create blocking task with Backlog status
        Project_Task__c blockingTask = new Project_Task__c(
            Name = 'Backlog Blocking Task',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert blockingTask;
        
        // Create dependent task
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Dependent on Backlog',
            Status__c = 'Pending',
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
        
        Test.startTest();
        // Update dependent task to trigger assessment
        dependentTask.Status__c = 'In Progress';
        update dependentTask;
        Test.stopTest();
        
        // Verify dependent task is at risk
        Project_Task__c updatedTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, updatedTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should be at risk when blocking task is Backlog');
    }
    
    @isTest
    static void testAtRiskDueToDependencies_MultipleBlockingDependencies() {
        // Test task with multiple blocking dependencies where some are blocking and some are not
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create multiple blocking tasks
        Project_Task__c blockingTask1 = new Project_Task__c(
            Name = 'Blocking Task 1 - In Progress',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        Project_Task__c blockingTask2 = new Project_Task__c(
            Name = 'Blocking Task 2 - Completed',
            Status__c = 'Completed',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        Project_Task__c blockingTask3 = new Project_Task__c(
            Name = 'Blocking Task 3 - Pending',
            Status__c = 'Pending',
            Account__c = testAccount.Id,
            Priority__c = 'Low'
        );
        insert new List<Project_Task__c>{blockingTask1, blockingTask2, blockingTask3};
        
        // Create dependent task
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Dependent on Multiple',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert dependentTask;
        
        // Create relationships - task depends on all three
        List<Project_Task_Relationship__c> relationships = new List<Project_Task_Relationship__c>();
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask1.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask2.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask3.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        insert relationships;
        
        Test.startTest();
        // Update dependent task to trigger assessment
        dependentTask.Status__c = 'Pending';
        update dependentTask;
        Test.stopTest();
        
        // Verify dependent task is at risk (because Task 1 and Task 3 are blocking)
        Project_Task__c updatedTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, updatedTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should be at risk when at least one blocking dependency is not completed');
    }
    
    @isTest
    static void testAtRiskDueToDependencies_AllDependenciesCompleted() {
        // Test task with multiple dependencies where all are completed/closed/in review
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create multiple non-blocking tasks
        Project_Task__c blockingTask1 = new Project_Task__c(
            Name = 'Completed Task 1',
            Status__c = 'Completed',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        Project_Task__c blockingTask2 = new Project_Task__c(
            Name = 'Closed Task 1',
            Status__c = 'Closed',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        Project_Task__c blockingTask3 = new Project_Task__c(
            Name = 'In Review Task 1',
            Status__c = 'In Review',
            Account__c = testAccount.Id,
            Priority__c = 'Low'
        );
        insert new List<Project_Task__c>{blockingTask1, blockingTask2, blockingTask3};
        
        // Create dependent task
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Dependent on All Completed',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            At_Risk_Due_to_Dependencies__c = true // Initially set to true
        );
        insert dependentTask;
        
        // Create relationships
        List<Project_Task_Relationship__c> relationships = new List<Project_Task_Relationship__c>();
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask1.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask2.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask3.Id,
            Relationship_Type__c = 'Blocking Dependency'
        ));
        insert relationships;
        
        Test.startTest();
        // Update dependent task to trigger assessment
        dependentTask.Status__c = 'Pending';
        update dependentTask;
        Test.stopTest();
        
        // Verify dependent task is NOT at risk (all dependencies are non-blocking)
        Project_Task__c updatedTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, updatedTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should not be at risk when all blocking dependencies are completed/closed/in review');
    }
    
    @isTest
    static void testAtRiskDueToDependencies_DependencyAdded() {
        // Test that adding a dependency relationship triggers re-assessment
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create blocking task
        Project_Task__c blockingTask = new Project_Task__c(
            Name = 'New Blocking Task',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert blockingTask;
        
        // Create dependent task (initially no dependencies)
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Task Without Dependency',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            At_Risk_Due_to_Dependencies__c = false
        );
        insert dependentTask;
        
        // Verify task is not at risk initially
        Project_Task__c checkTask1 = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, checkTask1.At_Risk_Due_to_Dependencies__c, 'Task should not be at risk initially');
        
        // Create relationship
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship;
        
        Test.startTest();
        // Update dependent task to trigger assessment after relationship is added
        dependentTask.Status__c = 'Pending';
        update dependentTask;
        Test.stopTest();
        
        // Verify dependent task is now at risk
        Project_Task__c updatedTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, updatedTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should be at risk after dependency relationship is added');
    }
    
    @isTest
    static void testAtRiskDueToDependencies_DependencyRemoved() {
        // Test that when a task has no blocking dependencies, it should not be at risk
        // This simulates the scenario where a dependency relationship is removed
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create a task that initially has no dependencies but is marked as at risk
        // (simulating stale data after a relationship was deleted)
        Project_Task__c task = new Project_Task__c(
            Name = 'Task With No Dependencies',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            At_Risk_Due_to_Dependencies__c = true // Manually set to true (simulating stale state)
        );
        insert task;
        
        // Verify task is initially at risk
        Project_Task__c checkTask1 = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :task.Id];
        System.assertEquals(true, checkTask1.At_Risk_Due_to_Dependencies__c, 'Task should be at risk initially');
        
        Test.startTest();
        // Update task to trigger assessment - should find no blocking dependencies and clear the risk
        task.Status__c = 'Pending';
        update task;
        Test.stopTest();
        
        // Verify task is no longer at risk (no blocking dependencies exist)
        Project_Task__c updatedTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :task.Id];
        System.assertEquals(false, updatedTask.At_Risk_Due_to_Dependencies__c, 'Task should not be at risk when it has no blocking dependencies');
    }
    
    @isTest
    static void testAtRiskDueToDependencies_StatusTransitionSequence() {
        // Test task going through multiple status transitions with blocking dependency
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create blocking task
        Project_Task__c blockingTask = new Project_Task__c(
            Name = 'Blocking Task for Transitions',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert blockingTask;
        
        // Create dependent task
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Task With Status Transitions',
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
        
        Test.startTest();
        // Transition 1: Backlog -> Pending (should be at risk)
        dependentTask.Status__c = 'Pending';
        update dependentTask;
        Project_Task__c check1 = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, check1.At_Risk_Due_to_Dependencies__c, 'Task should be at risk when blocking task is In Progress');
        
        // Transition 2: Pending -> In Progress (should still be at risk)
        dependentTask.Status__c = 'In Progress';
        update dependentTask;
        Project_Task__c check2 = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, check2.At_Risk_Due_to_Dependencies__c, 'Task should remain at risk');
        
        // Transition 3: Blocking task -> Completed (should clear risk)
        blockingTask.Status__c = 'Completed';
        update blockingTask;
        Project_Task__c check3 = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(false, check3.At_Risk_Due_to_Dependencies__c, 'Task should not be at risk when blocking task is completed');
        
        // Transition 4: Blocking task -> In Progress (should set risk again)
        blockingTask.Status__c = 'In Progress';
        update blockingTask;
        Project_Task__c check4 = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        System.assertEquals(true, check4.At_Risk_Due_to_Dependencies__c, 'Task should be at risk again when blocking task returns to In Progress');
        Test.stopTest();
    }
    
    @isTest
    static void testAtRiskDueToDependencies_FirstBlockingDependencyTakesPrecedence() {
        // Test that if ANY blocking dependency is not completed, the task is at risk
        // The code checks all dependencies and sets risk if ANY are blocking
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create two blocking tasks - one completed, one not
        Project_Task__c blockingTask1 = new Project_Task__c(
            Name = 'Completed Blocking Task',
            Status__c = 'Completed',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        Project_Task__c blockingTask2 = new Project_Task__c(
            Name = 'In Progress Blocking Task',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert new List<Project_Task__c>{blockingTask1, blockingTask2};
        
        // Create dependent task
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Dependent on Multiple',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert dependentTask;
        
        // Create relationships - order matters for this test
        // Add completed one first, then the blocking one
        List<Project_Task_Relationship__c> relationships = new List<Project_Task_Relationship__c>();
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask1.Id, // Completed - non-blocking
            Relationship_Type__c = 'Blocking Dependency'
        ));
        relationships.add(new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask2.Id, // In Progress - blocking
            Relationship_Type__c = 'Blocking Dependency'
        ));
        insert relationships;
        
        Test.startTest();
        // Update dependent task to trigger assessment
        dependentTask.Status__c = 'Pending';
        update dependentTask;
        Test.stopTest();
        
        // Verify dependent task is at risk (because at least one dependency is blocking)
        // Note: The code processes relationships in order and breaks after first one,
        // but it should still find the blocking one if it's in the list
        Project_Task__c updatedTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :dependentTask.Id];
        // The task should be at risk because blockingTask2 is blocking
        System.assertEquals(true, updatedTask.At_Risk_Due_to_Dependencies__c, 'Dependent task should be at risk when at least one blocking dependency is not completed');
    }
    
    // ============================================
    // Tests that verify Is_Blocking is actually set
    // ============================================
    
    @isTest
    static void testIsBlocking_VerifySetWhenDependencyAdded() {
        // Test that Is_Blocking is set to true when a dependency relationship is added
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create task that will become blocking
        Project_Task__c blockingTask = new Project_Task__c(
            Name = 'Task That Will Block',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Is_Blocking__c = false // Initially false
        );
        insert blockingTask;
        
        // Verify Is_Blocking is false initially
        Project_Task__c checkBefore = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(false, checkBefore.Is_Blocking__c, 'Task should not be blocking before dependency is added');
        
        // Create dependent task
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Dependent Task',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert dependentTask;
        
        Test.startTest();
        // Create dependency relationship
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship;
        
        // Update blocking task to trigger Is_Blocking calculation
        blockingTask.Status__c = 'Pending';
        update blockingTask;
        Test.stopTest();
        
        // Verify Is_Blocking is now set to true
        Project_Task__c checkAfter = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(true, checkAfter.Is_Blocking__c, 'Is_Blocking must be set to true when dependency relationship is added and task is in blocking status');
    }
    
    @isTest
    static void testIsBlocking_VerifyClearedWhenDependencyRemoved() {
        // Test that Is_Blocking is cleared when all dependency relationships are removed
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create blocking task with dependency
        Project_Task__c blockingTask = new Project_Task__c(
            Name = 'Task That Blocks',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert blockingTask;
        
        // Create dependent task
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Dependent Task',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert dependentTask;
        
        // Create dependency relationship
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship;
        
        // Update blocking task to set Is_Blocking to true
        blockingTask.Status__c = 'Pending';
        update blockingTask;
        
        // Verify Is_Blocking is true
        Project_Task__c checkBefore = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(true, checkBefore.Is_Blocking__c, 'Task should be blocking with dependency relationship');
        
        Test.startTest();
        // Delete dependency relationship
        delete relationship;
        
        // Verify relationship is deleted
        List<Project_Task_Relationship__c> remainingRelationships = [
            SELECT Id FROM Project_Task_Relationship__c 
            WHERE Task_A__c = :dependentTask.Id AND Task_B__c = :blockingTask.Id
        ];
        System.assertEquals(0, remainingRelationships.size(), 'Relationship must be deleted');
        
        // Update blocking task to trigger Is_Blocking recalculation
        // The code should find no dependencies and clear Is_Blocking
        blockingTask.Status__c = 'In Progress';
        update blockingTask;
        Test.stopTest();
        
        // Verify Is_Blocking is now set to false
        Project_Task__c checkAfter = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(false, checkAfter.Is_Blocking__c, 'Is_Blocking must be set to false when all dependency relationships are removed');
    }
    
    @isTest
    static void testIsBlocking_VerifySetForAllBlockingStatuses() {
        // Test that Is_Blocking is set to true for all blocking statuses
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        List<String> blockingStatuses = new List<String>{'Backlog', 'Pending', 'In Progress', 'Blocked'};
        
        Test.startTest();
        for (String status : blockingStatuses) {
            // Create blocking task
            Project_Task__c blockingTask = new Project_Task__c(
                Name = 'Blocking Task ' + status,
                Status__c = status,
                Account__c = testAccount.Id,
                Priority__c = 'High',
                Is_Blocking__c = false
            );
            insert blockingTask;
            
            // Create dependent task
            Project_Task__c dependentTask = new Project_Task__c(
                Name = 'Dependent Task ' + status,
                Status__c = 'Backlog',
                Account__c = testAccount.Id,
                Priority__c = 'Medium'
            );
            insert dependentTask;
            
            // Create dependency relationship
            Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
                Task_A__c = dependentTask.Id,
                Task_B__c = blockingTask.Id,
                Relationship_Type__c = 'Blocking Dependency'
            );
            insert relationship;
            
            // Update blocking task to trigger Is_Blocking calculation
            blockingTask.Status__c = status; // Ensure status is set
            update blockingTask;
            
            // Verify Is_Blocking is set to true for this blocking status
            Project_Task__c updatedTask = [SELECT Id, Status__c, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
            System.assertEquals(true, updatedTask.Is_Blocking__c, 
                'Is_Blocking must be set to true for status: ' + status + '. Actual status: ' + updatedTask.Status__c);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testIsBlocking_VerifyClearedForAllNonBlockingStatuses() {
        // Test that Is_Blocking is cleared for all non-blocking statuses
        // Test one status at a time to avoid SOQL limit issues
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Test Completed status
        Test.startTest();
        Project_Task__c blockingTask1 = new Project_Task__c(
            Name = 'Non-Blocking Task Completed',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert blockingTask1;
        
        Project_Task__c dependentTask1 = new Project_Task__c(
            Name = 'Dependent Task Completed',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert dependentTask1;
        
        Project_Task_Relationship__c relationship1 = new Project_Task_Relationship__c(
            Task_A__c = dependentTask1.Id,
            Task_B__c = blockingTask1.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship1;
        
        blockingTask1.Status__c = 'In Progress';
        update blockingTask1;
        
        Project_Task__c checkBefore1 = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask1.Id];
        System.assertEquals(true, checkBefore1.Is_Blocking__c, 'Task should be blocking before status change to Completed');
        
        blockingTask1.Status__c = 'Completed';
        update blockingTask1;
        
        Project_Task__c updatedTask1 = [SELECT Id, Status__c, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask1.Id];
        System.assertEquals(false, updatedTask1.Is_Blocking__c, 'Is_Blocking must be set to false for Completed status');
        Test.stopTest();
        
        // Test Closed status (outside Test.startTest to avoid SOQL limits)
        Project_Task__c blockingTask2 = new Project_Task__c(
            Name = 'Non-Blocking Task Closed',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert blockingTask2;
        
        Project_Task__c dependentTask2 = new Project_Task__c(
            Name = 'Dependent Task Closed',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert dependentTask2;
        
        Project_Task_Relationship__c relationship2 = new Project_Task_Relationship__c(
            Task_A__c = dependentTask2.Id,
            Task_B__c = blockingTask2.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship2;
        
        blockingTask2.Status__c = 'In Progress';
        update blockingTask2;
        
        blockingTask2.Status__c = 'Closed';
        update blockingTask2;
        
        Project_Task__c updatedTask2 = [SELECT Id, Status__c, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask2.Id];
        System.assertEquals(false, updatedTask2.Is_Blocking__c, 'Is_Blocking must be set to false for Closed status');
        
        // Test In Review status
        Project_Task__c blockingTask3 = new Project_Task__c(
            Name = 'Non-Blocking Task In Review',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert blockingTask3;
        
        Project_Task__c dependentTask3 = new Project_Task__c(
            Name = 'Dependent Task In Review',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert dependentTask3;
        
        Project_Task_Relationship__c relationship3 = new Project_Task_Relationship__c(
            Task_A__c = dependentTask3.Id,
            Task_B__c = blockingTask3.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship3;
        
        blockingTask3.Status__c = 'In Progress';
        update blockingTask3;
        
        blockingTask3.Status__c = 'In Review';
        update blockingTask3;
        
        Project_Task__c updatedTask3 = [SELECT Id, Status__c, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask3.Id];
        System.assertEquals(false, updatedTask3.Is_Blocking__c, 'Is_Blocking must be set to false for In Review status');
        
        // Test Removed status
        Project_Task__c blockingTask4 = new Project_Task__c(
            Name = 'Non-Blocking Task Removed',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High'
        );
        insert blockingTask4;
        
        Project_Task__c dependentTask4 = new Project_Task__c(
            Name = 'Dependent Task Removed',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert dependentTask4;
        
        Project_Task_Relationship__c relationship4 = new Project_Task_Relationship__c(
            Task_A__c = dependentTask4.Id,
            Task_B__c = blockingTask4.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship4;
        
        blockingTask4.Status__c = 'In Progress';
        update blockingTask4;
        
        blockingTask4.Status__c = 'Removed';
        update blockingTask4;
        
        Project_Task__c updatedTask4 = [SELECT Id, Status__c, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask4.Id];
        System.assertEquals(false, updatedTask4.Is_Blocking__c, 'Is_Blocking must be set to false for Removed status');
    }
    
    @isTest
    static void testIsBlocking_VerifyExactValueSet() {
        // Test that Is_Blocking is set to the exact correct value based on status and dependencies
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create task that will have dependencies
        Project_Task__c blockingTask = new Project_Task__c(
            Name = 'Task For Exact Value Test',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Is_Blocking__c = false // Start with false
        );
        insert blockingTask;
        
        // Create dependent task
        Project_Task__c dependentTask = new Project_Task__c(
            Name = 'Dependent For Exact Value',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        );
        insert dependentTask;
        
        // Create dependency relationship
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = dependentTask.Id,
            Task_B__c = blockingTask.Id,
            Relationship_Type__c = 'Blocking Dependency'
        );
        insert relationship;
        
        Test.startTest();
        // Test 1: In Progress status with dependency -> Is_Blocking should be true
        blockingTask.Status__c = 'In Progress';
        update blockingTask;
        Project_Task__c check1 = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(true, check1.Is_Blocking__c, 'Is_Blocking must be exactly true for In Progress with dependency');
        
        // Test 2: Completed status with dependency -> Is_Blocking should be false
        blockingTask.Status__c = 'Completed';
        update blockingTask;
        Project_Task__c check2 = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(false, check2.Is_Blocking__c, 'Is_Blocking must be exactly false for Completed with dependency');
        
        // Test 3: Backlog status with dependency -> Is_Blocking should be true
        blockingTask.Status__c = 'Backlog';
        update blockingTask;
        Project_Task__c check3 = [SELECT Id, Is_Blocking__c FROM Project_Task__c WHERE Id = :blockingTask.Id];
        System.assertEquals(true, check3.Is_Blocking__c, 'Is_Blocking must be exactly true for Backlog with dependency');
        Test.stopTest();
    }
}

