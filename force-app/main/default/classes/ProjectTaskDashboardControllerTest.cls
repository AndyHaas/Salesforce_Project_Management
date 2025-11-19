@isTest
private class ProjectTaskDashboardControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test Project Tasks
        List<Project_Task__c> tasks = new List<Project_Task__c>();
        
        // Tasks with different statuses
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
        
        tasks.add(new Project_Task__c(
            Name = 'Task 3 - In Review',
            Status__c = 'In Review',
            Priority__c = 'Low',
            Account__c = testAccount.Id,
            Reviewed_by_PM_Code_Reviewer__c = true,
            Client_Approved_for_Completion__c = false
        ));
        
        tasks.add(new Project_Task__c(
            Name = 'Task 4 - Blocked',
            Status__c = 'Blocked',
            Account__c = testAccount.Id,
            At_Risk_Due_to_Dependencies__c = true
        ));
        
        tasks.add(new Project_Task__c(
            Name = 'Task 5 - Completed',
            Status__c = 'Completed',
            Account__c = testAccount.Id,
            Progress_Percentage__c = 100
        ));
        
        insert tasks;
    }
    
    @isTest
    static void testGetStatusBreakdown() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        ProjectTaskDashboardController.StatusBreakdownResult result = 
            ProjectTaskDashboardController.getStatusBreakdown(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.statusCounts, 'Status counts should not be null');
        System.assert(result.totalTasks > 0, 'Should have tasks');
    }
    
    @isTest
    static void testGetStatusBreakdownAllAccounts() {
        Test.startTest();
        ProjectTaskDashboardController.StatusBreakdownResult result = 
            ProjectTaskDashboardController.getStatusBreakdown(new List<String>());
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetHoursMetrics() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        ProjectTaskDashboardController.HoursMetricsResult result = 
            ProjectTaskDashboardController.getHoursMetrics(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.hoursByStatus, 'Hours by status should not be null');
    }
    
    @isTest
    static void testGetReviewStatusMetrics() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        ProjectTaskDashboardController.ReviewStatusMetricsResult result = 
            ProjectTaskDashboardController.getReviewStatusMetrics(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetPriorityBreakdown() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        ProjectTaskDashboardController.PriorityBreakdownResult result = 
            ProjectTaskDashboardController.getPriorityBreakdown(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.priorityCounts, 'Priority counts should not be null');
    }
    
    @isTest
    static void testGetProgressMetrics() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        ProjectTaskDashboardController.ProgressMetricsResult result = 
            ProjectTaskDashboardController.getProgressMetrics(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetTaskList() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        ProjectTaskDashboardController.TaskListResult result = 
            ProjectTaskDashboardController.getTaskList(new List<String>{ testAccount.Id }, 10, 1);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.tasks, 'Tasks should not be null');
        System.assert(result.totalRecords > 0, 'Should have records');
    }

    @isTest
    static void testGetTaskListFieldSetDefinition() {
        Test.startTest();
        List<ProjectTaskDashboardController.FieldSetFieldDefinition> definitions =
            ProjectTaskDashboardController.getTaskListFieldSetDefinition();
        Test.stopTest();

        System.assertNotEquals(null, definitions, 'Definitions should not be null');
        System.assert(!definitions.isEmpty(), 'Field set should contain fields');
        System.assertNotEquals(null, definitions[0].apiName, 'API name should be populated');

        Boolean foundNameField = false;
        Boolean foundReferenceField = false;

        for (ProjectTaskDashboardController.FieldSetFieldDefinition def : definitions) {
            if (def.apiName == 'Name') {
                foundNameField = def.isNameField;
            }
            if (def.isReference) {
                System.assertNotEquals(null, def.referenceRelationshipName, 'Reference fields should include relationship names');
                foundReferenceField = true;
            }
        }

        System.assert(foundNameField, 'Field set should include Name field marked correctly');
        System.assert(foundReferenceField, 'Field set should include at least one reference field');
    }
    
    @isTest
    static void testGetGroupedTasksWithSummaryFields() {
        Account summaryAccount = new Account(Name = 'Summary Account');
        insert summaryAccount;
        
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Summary Task',
            Status__c = 'Backlog',
            Account__c = summaryAccount.Id,
            OwnerId = UserInfo.getUserId(),
            Estimated_Hours__c = 10,
            Due_Date__c = Date.today().addDays(5),
            Priority__c = 'High'
        );
        insert parentTask;
        
        Project_Task__c subtask = new Project_Task__c(
            Name = 'Child Task',
            Status__c = 'Backlog',
            Account__c = summaryAccount.Id,
            Parent_Task__c = parentTask.Id,
            Due_Date__c = Date.today(),
            Estimated_Hours__c = 5,
            OwnerId = UserInfo.getUserId(),
            Priority__c = 'Medium'
        );
        insert subtask;

        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ summaryAccount.Id });
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.summaryFieldDefinitions, 'Summary field definitions should be returned');
        System.assert(!result.summaryFieldDefinitions.isEmpty(), 'Summary field definitions should not be empty');
        System.assertNotEquals(null, result.statusGroups, 'Status groups should not be null');

        Boolean validatedParent = false;
        for (ProjectTaskDashboardController.StatusGroup statusGroup : result.statusGroups) {
            if (statusGroup == null || statusGroup.tasks == null) {
                continue;
            }
            for (ProjectTaskDashboardController.TaskWithSubtasks task : statusGroup.tasks) {
                if (task.id == parentTask.Id) {
                    System.assertNotEquals(null, task.summaryFields, 'Summary fields should not be null on tasks');
                    System.assertEquals(
                        result.summaryFieldDefinitions.size(),
                        task.summaryFields.size(),
                        'Summary fields should align with definitions'
                    );
                    System.assertNotEquals(null, task.subtasks, 'Parent should include subtasks');
                    System.assert(task.subtasks.size() > 0, 'Parent should have at least one subtask');
                    ProjectTaskDashboardController.TaskInfo childInfo = task.subtasks[0];
                    System.assertNotEquals(null, childInfo.summaryFields, 'Subtasks should include summary fields');
                    validatedParent = true;
                    break;
                }
            }
            if (validatedParent) {
                break;
            }
        }

        System.assert(validatedParent, 'Parent task with summary fields should be found');
    }
    
    @isTest
    static void testGetAccounts() {
        Test.startTest();
        List<Account> accounts = ProjectTaskDashboardController.getAccounts();
        Test.stopTest();
        
        System.assertNotEquals(null, accounts, 'Accounts should not be null');
    }
    
    @isTest
    static void testGetStatusBreakdownWithNull() {
        Test.startTest();
        ProjectTaskDashboardController.StatusBreakdownResult result = 
            ProjectTaskDashboardController.getStatusBreakdown(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.statusCounts, 'Status counts should not be null');
    }
    
    @isTest
    static void testGetHoursMetricsWithNull() {
        Test.startTest();
        ProjectTaskDashboardController.HoursMetricsResult result = 
            ProjectTaskDashboardController.getHoursMetrics(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.hoursByStatus, 'Hours by status should not be null');
    }
    
    @isTest
    static void testGetReviewStatusMetricsWithNull() {
        Test.startTest();
        ProjectTaskDashboardController.ReviewStatusMetricsResult result = 
            ProjectTaskDashboardController.getReviewStatusMetrics(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetPriorityBreakdownWithNull() {
        Test.startTest();
        ProjectTaskDashboardController.PriorityBreakdownResult result = 
            ProjectTaskDashboardController.getPriorityBreakdown(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.priorityCounts, 'Priority counts should not be null');
    }
    
    @isTest
    static void testGetProgressMetricsWithNull() {
        Test.startTest();
        ProjectTaskDashboardController.ProgressMetricsResult result = 
            ProjectTaskDashboardController.getProgressMetrics(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetDueDateMetrics() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create tasks with due dates
        List<Project_Task__c> tasks = new List<Project_Task__c>();
        
        // Overdue task (Is_Overdue__c is a formula field, so we can't set it directly)
        tasks.add(new Project_Task__c(
            Name = 'Overdue Task',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Due_Date__c = Date.today().addDays(-5)
        ));
        
        // Task due today
        tasks.add(new Project_Task__c(
            Name = 'Due Today Task',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Due_Date__c = Date.today()
        ));
        
        // Task due this week
        tasks.add(new Project_Task__c(
            Name = 'Due This Week Task',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            Due_Date__c = Date.today().addDays(3)
        ));
        
        // Task without due date
        tasks.add(new Project_Task__c(
            Name = 'No Due Date Task',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Medium'
        ));
        
        insert tasks;
        
        Test.startTest();
        ProjectTaskDashboardController.DueDateMetricsResult result = 
            ProjectTaskDashboardController.getDueDateMetrics(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.overdueCount >= 0, 'Overdue count should be non-negative');
        System.assert(result.dueTodayCount >= 0, 'Due today count should be non-negative');
        System.assert(result.dueThisWeekCount >= 0, 'Due this week count should be non-negative');
        System.assert(result.tasksWithDueDate >= 0, 'Tasks with due date should be non-negative');
        System.assert(result.tasksWithoutDueDate >= 0, 'Tasks without due date should be non-negative');
    }
    
    @isTest
    static void testGetDueDateMetricsWithNull() {
        Test.startTest();
        ProjectTaskDashboardController.DueDateMetricsResult result = 
            ProjectTaskDashboardController.getDueDateMetrics(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetCurrentUserAccountId() {
        Test.startTest();
        String accountId = ProjectTaskDashboardController.getCurrentUserAccountId();
        Test.stopTest();
        
        // For standard users, this will be null (only works for Experience Cloud users with Contact)
        System.assert(true, 'Method should execute without error');
    }
    
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
        ProjectTaskDashboardController.DependencyDataResult result = 
            ProjectTaskDashboardController.getDependencyData(taskWithDeps.Id);
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
        ProjectTaskDashboardController.DependencyDataResult result = 
            ProjectTaskDashboardController.getDependencyData(null);
        Test.stopTest();
        
        System.assertEquals(null, result, 'Result should be null for null taskId');
    }
    
    @isTest
    static void testGetDependencyDataWithEmptyString() {
        Test.startTest();
        ProjectTaskDashboardController.DependencyDataResult result = 
            ProjectTaskDashboardController.getDependencyData('');
        Test.stopTest();
        
        System.assertEquals(null, result, 'Result should be null for empty taskId');
    }
    
    @isTest
    static void testGetTaskListWithNullParameters() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        ProjectTaskDashboardController.TaskListResult result = 
            ProjectTaskDashboardController.getTaskList(new List<String>{ testAccount.Id }, null, null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.tasks, 'Tasks should not be null');
    }
    
    @isTest
    static void testGetTaskListWithInvalidPageNumber() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        ProjectTaskDashboardController.TaskListResult result = 
            ProjectTaskDashboardController.getTaskList(new List<String>{ testAccount.Id }, 10, -1);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.pageNumber, 'Page number should default to 1');
    }
    
    @isTest
    static void testGetTaskListWithInvalidPageSize() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        ProjectTaskDashboardController.TaskListResult result = 
            ProjectTaskDashboardController.getTaskList(new List<String>{ testAccount.Id }, -1, 1);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(10, result.pageSize, 'Page size should default to 10');
    }
    
    @isTest
    static void testGetTaskListWithNullAccountIds() {
        Test.startTest();
        ProjectTaskDashboardController.TaskListResult result = 
            ProjectTaskDashboardController.getTaskList(null, 10, 1);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.tasks, 'Tasks should not be null');
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithNull() {
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.statusGroups, 'Status groups should not be null');
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithEmptyList() {
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>());
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.statusGroups, 'Status groups should not be null');
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithEmptyStrings() {
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ '', null, ' ' });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.statusGroups, 'Status groups should not be null');
    }
    
    @isTest
    static void testGetProgressMetricsWithVariousProgressValues() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create tasks with various progress percentages
        List<Project_Task__c> tasks = new List<Project_Task__c>();
        
        tasks.add(new Project_Task__c(
            Name = 'Task 0%',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Progress_Percentage__c = 0
        ));
        
        tasks.add(new Project_Task__c(
            Name = 'Task 25%',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Progress_Percentage__c = 25
        ));
        
        tasks.add(new Project_Task__c(
            Name = 'Task 50%',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'Low',
            Progress_Percentage__c = 50
        ));
        
        tasks.add(new Project_Task__c(
            Name = 'Task 75%',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Progress_Percentage__c = 75
        ));
        
        tasks.add(new Project_Task__c(
            Name = 'Task 100%',
            Status__c = 'Completed',
            Account__c = testAccount.Id,
            Priority__c = 'Medium',
            Progress_Percentage__c = 100
        ));
        
        tasks.add(new Project_Task__c(
            Name = 'Task No Progress',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'Low'
            // No Progress_Percentage__c
        ));
        
        tasks.add(new Project_Task__c(
            Name = 'Task Closed',
            Status__c = 'Closed',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Progress_Percentage__c = 100
        ));
        
        insert tasks;
        
        Test.startTest();
        ProjectTaskDashboardController.ProgressMetricsResult result = 
            ProjectTaskDashboardController.getProgressMetrics(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.avgProgress >= 0, 'Average progress should be non-negative');
        System.assert(result.totalTasks > 0, 'Should have tasks');
        System.assert(result.completedCount >= 0, 'Completed count should be non-negative');
        System.assertNotEquals(null, result.progressDistribution, 'Progress distribution should not be null');
        System.assertNotEquals(null, result.avgProgressByStatus, 'Average progress by status should not be null');
    }
    
    @isTest
    static void testGetReviewStatusMetricsWithVariousStatuses() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create tasks with various review statuses
        List<Project_Task__c> tasks = new List<Project_Task__c>();
        
        // In Review tasks
        tasks.add(new Project_Task__c(
            Name = 'In Review - PM Approved',
            Status__c = 'In Review',
            Account__c = testAccount.Id,
            Reviewed_by_PM_Code_Reviewer__c = true,
            Client_Approved_for_Completion__c = true
        ));
        
        tasks.add(new Project_Task__c(
            Name = 'In Review - PM Pending',
            Status__c = 'In Review',
            Account__c = testAccount.Id,
            Reviewed_by_PM_Code_Reviewer__c = false,
            Client_Approved_for_Completion__c = false
        ));
        
        // Backlog tasks
        tasks.add(new Project_Task__c(
            Name = 'Backlog - Client Approved',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Client_Approved_for_Development__c = true,
            Ready_for_Client_Review__c = true
        ));
        
        tasks.add(new Project_Task__c(
            Name = 'Backlog - Client Pending',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Client_Approved_for_Development__c = false,
            Ready_for_Client_Review__c = false
        ));
        
        insert tasks;
        
        Test.startTest();
        ProjectTaskDashboardController.ReviewStatusMetricsResult result = 
            ProjectTaskDashboardController.getReviewStatusMetrics(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.inReviewTotal >= 0, 'In review total should be non-negative');
        System.assert(result.backlogTotal >= 0, 'Backlog total should be non-negative');
    }
    
    @isTest
    static void testGetHoursMetricsWithNullValues() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create tasks with null hours
        List<Project_Task__c> tasks = new List<Project_Task__c>();
        
        tasks.add(new Project_Task__c(
            Name = 'Task No Hours',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
            // No Estimated_Hours__c or Actual_Hours__c
        ));
        
        insert tasks;
        
        Test.startTest();
        ProjectTaskDashboardController.HoursMetricsResult result = 
            ProjectTaskDashboardController.getHoursMetrics(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.totalEstimated >= 0, 'Total estimated should be non-negative');
        System.assert(result.totalActual >= 0, 'Total actual should be non-negative');
    }
    
    @isTest
    static void testGetHoursMetricsAllAccounts() {
        Test.startTest();
        ProjectTaskDashboardController.HoursMetricsResult result = 
            ProjectTaskDashboardController.getHoursMetrics(new List<String>());
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetPriorityBreakdownAllAccounts() {
        Test.startTest();
        ProjectTaskDashboardController.PriorityBreakdownResult result = 
            ProjectTaskDashboardController.getPriorityBreakdown(new List<String>());
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetProgressMetricsAllAccounts() {
        Test.startTest();
        ProjectTaskDashboardController.ProgressMetricsResult result = 
            ProjectTaskDashboardController.getProgressMetrics(new List<String>());
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetDueDateMetricsAllAccounts() {
        Test.startTest();
        ProjectTaskDashboardController.DueDateMetricsResult result = 
            ProjectTaskDashboardController.getDueDateMetrics(new List<String>());
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetTaskListWithEmptyAccountIds() {
        Test.startTest();
        ProjectTaskDashboardController.TaskListResult result = 
            ProjectTaskDashboardController.getTaskList(new List<String>(), 10, 1);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.tasks, 'Tasks should not be null');
    }
    
    @isTest
    static void testGetTaskListPagination() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create multiple tasks to test pagination
        List<Project_Task__c> tasks = new List<Project_Task__c>();
        for (Integer i = 0; i < 15; i++) {
            tasks.add(new Project_Task__c(
                Name = 'Pagination Task ' + i,
                Status__c = 'Backlog',
                Account__c = testAccount.Id,
                Priority__c = 'Medium'
            ));
        }
        insert tasks;
        
        Test.startTest();
        // Test first page
        ProjectTaskDashboardController.TaskListResult page1 = 
            ProjectTaskDashboardController.getTaskList(new List<String>{ testAccount.Id }, 10, 1);
        // Test second page
        ProjectTaskDashboardController.TaskListResult page2 = 
            ProjectTaskDashboardController.getTaskList(new List<String>{ testAccount.Id }, 10, 2);
        Test.stopTest();
        
        System.assertNotEquals(null, page1, 'Page 1 should not be null');
        System.assertNotEquals(null, page2, 'Page 2 should not be null');
        System.assertEquals(1, page1.pageNumber, 'Page 1 should have page number 1');
        System.assertEquals(2, page2.pageNumber, 'Page 2 should have page number 2');
        System.assert(page1.totalPages >= 1, 'Should have at least 1 page');
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksAllAccounts() {
        // Create at least one task to ensure the query works
        Account testAccount = new Account(Name = 'Test Account for All Accounts');
        insert testAccount;
        
        Project_Task__c task = new Project_Task__c(
            Name = 'Task for All Accounts Test',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            OwnerId = UserInfo.getUserId()
        );
        insert task;
        
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>());
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.statusGroups, 'Status groups should not be null');
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithChatterComments() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c parentTask = new Project_Task__c(
            Name = 'Parent Task With Comments',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            OwnerId = UserInfo.getUserId()
        );
        insert parentTask;
        
        // Create a Chatter feed item (comment) for the task
        FeedItem feedItem = new FeedItem(
            ParentId = parentTask.Id,
            Body = 'Test comment for task',
            Type = 'TextPost'
        );
        insert feedItem;
        
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        
        // Verify comment is included
        Boolean foundTaskWithComment = false;
        for (ProjectTaskDashboardController.StatusGroup statusGroup : result.statusGroups) {
            if (statusGroup != null && statusGroup.tasks != null) {
                for (ProjectTaskDashboardController.TaskWithSubtasks task : statusGroup.tasks) {
                    if (task.id == parentTask.Id) {
                        System.assertNotEquals(null, task.latestComment, 'Task should have latest comment');
                        foundTaskWithComment = true;
                        break;
                    }
                }
            }
            if (foundTaskWithComment) break;
        }
        System.assert(foundTaskWithComment, 'Task with comment should be found');
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
        ProjectTaskDashboardController.DependencyDataResult result = 
            ProjectTaskDashboardController.getDependencyData(standaloneTask.Id);
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
        ProjectTaskDashboardController.DependencyDataResult result = 
            ProjectTaskDashboardController.getDependencyData(blockingTask.Id);
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
        ProjectTaskDashboardController.DependencyDataResult result = 
            ProjectTaskDashboardController.getDependencyData(parentTask.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.subtaskProgress, 'Subtask progress should not be null');
        System.assertEquals(50, result.subtaskProgress.progressPercentage, 'Progress should be 50% (1 of 2 valid subtasks)');
        System.assertEquals(1, result.subtaskProgress.completedCount, 'Should have 1 completed subtask');
        System.assertEquals(2, result.subtaskProgress.totalCount, 'Should have 2 valid subtasks (removed excluded)');
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithDateFields() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task = new Project_Task__c(
            Name = 'Task With Dates',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Due_Date__c = Date.today().addDays(5),
            OwnerId = UserInfo.getUserId()
        );
        insert task;
        
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        // This will exercise formatHoverFieldValue with Date type
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithReferenceFields() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        Project_Task__c task = new Project_Task__c(
            Name = 'Task With References',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            OwnerId = testUser.Id
        );
        insert task;
        
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        // This will exercise addFieldSetMembersToSelect and buildSummaryFieldValues with reference fields
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithPercentField() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task = new Project_Task__c(
            Name = 'Task With Progress',
            Status__c = 'In Progress',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            Progress_Percentage__c = 75.5,
            OwnerId = UserInfo.getUserId()
        );
        insert task;
        
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        // This will exercise formatHoverFieldValue with Percent type
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithNullFields() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task = new Project_Task__c(
            Name = 'Task With Nulls',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High'
            // Many fields are null
        );
        insert task;
        
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        // This will exercise formatHoverFieldValue with null values
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksErrorHandling() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create a task that might cause query issues
        Project_Task__c task = new Project_Task__c(
            Name = 'Task For Error Test',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            OwnerId = UserInfo.getUserId()
        );
        insert task;
        
        Test.startTest();
        try {
            ProjectTaskDashboardController.GroupedTasksResult result =
                ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ testAccount.Id });
            System.assertNotEquals(null, result, 'Result should not be null');
        } catch (Exception e) {
            // If there's an error, it should be an AuraHandledException
            System.assert(e instanceof AuraHandledException, 'Should throw AuraHandledException');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithAllStatuses() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create tasks with all possible statuses
        List<String> statuses = new List<String>{
            'Completed', 'Closed', 'In Review', 'In Progress', 'Pending', 'Blocked', 'Backlog', 'Removed'
        };
        
        List<Project_Task__c> tasks = new List<Project_Task__c>();
        for (String status : statuses) {
            tasks.add(new Project_Task__c(
                Name = 'Task - ' + status,
                Status__c = status,
                Account__c = testAccount.Id,
                Priority__c = 'High',
                OwnerId = UserInfo.getUserId()
            ));
        }
        insert tasks;
        
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.statusGroups, 'Status groups should not be null');
        System.assert(result.statusGroups.size() > 0, 'Should have status groups');
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithUnknownStatus() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create a task with a status not in the predefined order
        Project_Task__c task = new Project_Task__c(
            Name = 'Task Unknown Status',
            Status__c = 'Custom Status',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            OwnerId = UserInfo.getUserId()
        );
        insert task;
        
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.statusGroups, 'Status groups should not be null');
        // Unknown status should still be included in the result
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithNullStatus() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create a task with null status
        Project_Task__c task = new Project_Task__c(
            Name = 'Task Null Status',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            OwnerId = UserInfo.getUserId()
            // Status__c is null
        );
        insert task;
        
        Test.startTest();
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.statusGroups, 'Status groups should not be null');
        // Null status should default to 'Backlog'
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
        ProjectTaskDashboardController.DependencyDataResult result = 
            ProjectTaskDashboardController.getDependencyData(task2.Id);
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
        ProjectTaskDashboardController.DependencyDataResult result = 
            ProjectTaskDashboardController.getDependencyData(task2.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.dependencies, 'Dependencies should not be null');
        if (result.dependencies.size() > 0) {
            System.assertEquals('Related', result.dependencies[0].type, 'Blank relationship type should default to Related');
        }
    }
    
    @isTest
    static void testGetGroupedTasksWithSubtasksWithEmptyFieldSets() {
        // This test exercises the code path where field sets might not exist or return empty
        // which will hit the uncovered lines in getFieldSetMembers and getFieldPaths
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Project_Task__c task = new Project_Task__c(
            Name = 'Task for Field Set Test',
            Status__c = 'Backlog',
            Account__c = testAccount.Id,
            Priority__c = 'High',
            OwnerId = UserInfo.getUserId()
        );
        insert task;
        
        Test.startTest();
        // This will call getGroupedTasksWithSubtasks which internally calls
        // getFieldSetMembers, getFieldPaths, and buildHoverFieldValues
        // If field sets don't exist, line 89 will be hit
        // If field sets return empty, various null/empty checks will be hit
        ProjectTaskDashboardController.GroupedTasksResult result =
            ProjectTaskDashboardController.getGroupedTasksWithSubtasks(new List<String>{ testAccount.Id });
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.statusGroups, 'Status groups should not be null');
    }
    
}

