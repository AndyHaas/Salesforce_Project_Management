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
    static void testGetAccounts() {
        Test.startTest();
        List<Account> accounts = ProjectTaskDashboardController.getAccounts();
        Test.stopTest();
        
        System.assertNotEquals(null, accounts, 'Accounts should not be null');
    }
}

