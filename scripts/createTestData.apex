// Anonymous Apex Script to Create Test Data
// Creates Customer Accounts, Project Tasks, Subtasks, and Related Tasks

// Create Customer Accounts
List<Account> accounts = new List<Account>();
for (Integer i = 1; i <= 5; i++) {
    Account acc = new Account(
        Name = 'Test Customer ' + i,
        Type = 'Customer',
        Active__c = true
    );
    accounts.add(acc);
}
insert accounts;
System.debug('Created ' + accounts.size() + ' accounts');

// Get a user for assignment (use current user or first available)
User devUser;
try {
    devUser = [SELECT Id FROM User WHERE IsActive = true AND Profile.Name LIKE '%Developer%' LIMIT 1];
} catch (Exception e) {
    // No developer profile found, try any active user
}
if (devUser == null) {
    try {
        devUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
    } catch (Exception e) {
        // Use current user
        devUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    }
}

// Create Project Tasks (all initially in Backlog or Pending to allow subtasks)
List<Project_Task__c> tasks = new List<Project_Task__c>();

// Task 1: Backlog - No subtasks, no related
tasks.add(new Project_Task__c(
    Name = 'Setup Development Environment',
    Account__c = accounts[0].Id,
    Status__c = 'Backlog',
    Priority__c = 'High',
    Estimated_Hours__c = 8,
    Actual_Hours__c = 0,
    Progress_Percentage__c = 0,
    Developer__c = devUser.Id,
    Ready_for_Client_Review__c = false
));

// Task 2: Will be Pending - With subtasks (create as Pending first)
tasks.add(new Project_Task__c(
    Name = 'Implement User Authentication',
    Account__c = accounts[0].Id,
    Status__c = 'Pending',
    Priority__c = 'High',
    Estimated_Hours__c = 40,
    Actual_Hours__c = 5,
    Progress_Percentage__c = 10,
    Developer__c = devUser.Id,
    Client_Approved_for_Development__c = true
));

// Task 3: Will be In Progress - With subtasks (create as Pending first)
tasks.add(new Project_Task__c(
    Name = 'Build Dashboard Components',
    Account__c = accounts[1].Id,
    Status__c = 'Pending',
    Priority__c = 'Medium',
    Estimated_Hours__c = 60,
    Actual_Hours__c = 35,
    Progress_Percentage__c = 55,
    Developer__c = devUser.Id,
    Client_Approved_for_Development__c = true
));

// Task 4: In Review - PM approved, waiting for client
tasks.add(new Project_Task__c(
    Name = 'API Integration Module',
    Account__c = accounts[1].Id,
    Status__c = 'In Review',
    Priority__c = 'High',
    Estimated_Hours__c = 32,
    Actual_Hours__c = 30,
    Progress_Percentage__c = 100,
    Developer__c = devUser.Id,
    Reviewed_by_PM_Code_Reviewer__c = true,
    Client_Approved_for_Completion__c = false
));

// Task 5: Blocked - Related to another task
tasks.add(new Project_Task__c(
    Name = 'Database Migration Script',
    Account__c = accounts[2].Id,
    Status__c = 'Blocked',
    Priority__c = 'High',
    Estimated_Hours__c = 24,
    Actual_Hours__c = 8,
    Progress_Percentage__c = 30,
    Developer__c = devUser.Id,
    At_Risk_Due_to_Dependencies__c = true
));

// Task 6: Will be Completed - With subtasks (create as In Progress first)
tasks.add(new Project_Task__c(
    Name = 'User Interface Design',
    Account__c = accounts[2].Id,
    Status__c = 'In Progress',
    Priority__c = 'Medium',
    Estimated_Hours__c = 20,
    Actual_Hours__c = 18,
    Progress_Percentage__c = 90,
    Developer__c = devUser.Id
));

// Task 7: In Progress - No subtasks, high progress
tasks.add(new Project_Task__c(
    Name = 'Performance Optimization',
    Account__c = accounts[3].Id,
    Status__c = 'In Progress',
    Priority__c = 'Medium',
    Estimated_Hours__c = 16,
    Actual_Hours__c = 12,
    Progress_Percentage__c = 75,
    Developer__c = devUser.Id
));

// Task 8: Backlog - Ready for client review
tasks.add(new Project_Task__c(
    Name = 'Security Audit Implementation',
    Account__c = accounts[3].Id,
    Status__c = 'Backlog',
    Priority__c = 'High',
    Estimated_Hours__c = 48,
    Actual_Hours__c = 0,
    Progress_Percentage__c = 0,
    Developer__c = devUser.Id,
    Ready_for_Client_Review__c = true,
    Client_Approved_for_Development__c = false
));

// Task 9: In Review - PM pending
tasks.add(new Project_Task__c(
    Name = 'Mobile App Features',
    Account__c = accounts[4].Id,
    Status__c = 'In Review',
    Priority__c = 'Low',
    Estimated_Hours__c = 28,
    Actual_Hours__c = 25,
    Progress_Percentage__c = 100,
    Developer__c = devUser.Id,
    Reviewed_by_PM_Code_Reviewer__c = false,
    Client_Approved_for_Completion__c = false
));

// Task 10: Pending - With related task dependency
tasks.add(new Project_Task__c(
    Name = 'Data Export Functionality',
    Account__c = accounts[4].Id,
    Status__c = 'Pending',
    Priority__c = 'Medium',
    Estimated_Hours__c = 12,
    Actual_Hours__c = 0,
    Progress_Percentage__c = 0,
    Developer__c = devUser.Id,
    Client_Approved_for_Development__c = true
));

insert tasks;
System.debug('Created ' + tasks.size() + ' project tasks');

// Create Subtasks for Task 2 (Implement User Authentication)
List<Project_Task__c> subtasks1 = new List<Project_Task__c>();
subtasks1.add(new Project_Task__c(
    Name = 'Setup OAuth Provider',
    Account__c = accounts[0].Id,
    Parent_Task__c = tasks[1].Id,
    Status__c = 'Completed',
    Priority__c = 'High',
    Estimated_Hours__c = 8,
    Actual_Hours__c = 7,
    Progress_Percentage__c = 100,
    Developer__c = devUser.Id
));
subtasks1.add(new Project_Task__c(
    Name = 'Implement Login Flow',
    Account__c = accounts[0].Id,
    Parent_Task__c = tasks[1].Id,
    Status__c = 'In Progress',
    Priority__c = 'High',
    Estimated_Hours__c = 16,
    Actual_Hours__c = 5,
    Progress_Percentage__c = 30,
    Developer__c = devUser.Id
));
subtasks1.add(new Project_Task__c(
    Name = 'Add Password Reset',
    Account__c = accounts[0].Id,
    Parent_Task__c = tasks[1].Id,
    Status__c = 'Pending',
    Priority__c = 'Medium',
    Estimated_Hours__c = 16,
    Actual_Hours__c = 0,
    Progress_Percentage__c = 0,
    Developer__c = devUser.Id
));
insert subtasks1;
System.debug('Created ' + subtasks1.size() + ' subtasks for Task 2');

// Create Subtasks for Task 3 (Build Dashboard Components)
List<Project_Task__c> subtasks2 = new List<Project_Task__c>();
subtasks2.add(new Project_Task__c(
    Name = 'Status Breakdown Component',
    Account__c = accounts[1].Id,
    Parent_Task__c = tasks[2].Id,
    Status__c = 'Completed',
    Priority__c = 'High',
    Estimated_Hours__c = 12,
    Actual_Hours__c = 10,
    Progress_Percentage__c = 100,
    Developer__c = devUser.Id
));
subtasks2.add(new Project_Task__c(
    Name = 'Hours Metrics Component',
    Account__c = accounts[1].Id,
    Parent_Task__c = tasks[2].Id,
    Status__c = 'Completed',
    Priority__c = 'High',
    Estimated_Hours__c = 10,
    Actual_Hours__c = 8,
    Progress_Percentage__c = 100,
    Developer__c = devUser.Id
));
subtasks2.add(new Project_Task__c(
    Name = 'Review Status Component',
    Account__c = accounts[1].Id,
    Parent_Task__c = tasks[2].Id,
    Status__c = 'In Progress',
    Priority__c = 'Medium',
    Estimated_Hours__c = 15,
    Actual_Hours__c = 10,
    Progress_Percentage__c = 65,
    Developer__c = devUser.Id
));
subtasks2.add(new Project_Task__c(
    Name = 'Progress Metrics Component',
    Account__c = accounts[1].Id,
    Parent_Task__c = tasks[2].Id,
    Status__c = 'Pending',
    Priority__c = 'Medium',
    Estimated_Hours__c = 12,
    Actual_Hours__c = 0,
    Progress_Percentage__c = 0,
    Developer__c = devUser.Id
));
subtasks2.add(new Project_Task__c(
    Name = 'Priority Breakdown Component',
    Account__c = accounts[1].Id,
    Parent_Task__c = tasks[2].Id,
    Status__c = 'Backlog',
    Priority__c = 'Low',
    Estimated_Hours__c = 8,
    Actual_Hours__c = 0,
    Progress_Percentage__c = 0,
    Developer__c = devUser.Id
));
insert subtasks2;
System.debug('Created ' + subtasks2.size() + ' subtasks for Task 3');

// Update Task 3 to In Progress now that subtasks are created
// Query the task first to get current values, then update status only
Project_Task__c task3 = [SELECT Id, Status__c, Client_Approved_for_Development__c FROM Project_Task__c WHERE Id = :tasks[2].Id];
task3.Status__c = 'In Progress';
task3.Client_Approved_for_Development__c = false;
update task3;

// Create Subtasks for Task 6 (User Interface Design)
List<Project_Task__c> subtasks3 = new List<Project_Task__c>();
subtasks3.add(new Project_Task__c(
    Name = 'Design Mockups',
    Account__c = accounts[2].Id,
    Parent_Task__c = tasks[5].Id,
    Status__c = 'Completed',
    Priority__c = 'High',
    Estimated_Hours__c = 8,
    Actual_Hours__c = 7,
    Progress_Percentage__c = 100,
    Developer__c = devUser.Id
));
subtasks3.add(new Project_Task__c(
    Name = 'Create Component Library',
    Account__c = accounts[2].Id,
    Parent_Task__c = tasks[5].Id,
    Status__c = 'Completed',
    Priority__c = 'Medium',
    Estimated_Hours__c = 12,
    Actual_Hours__c = 11,
    Progress_Percentage__c = 100,
    Developer__c = devUser.Id
));
insert subtasks3;
System.debug('Created ' + subtasks3.size() + ' subtasks for Task 6');

// Update Task 6 to Completed now that subtasks are created
Project_Task__c task6 = [SELECT Id, Status__c, Progress_Percentage__c FROM Project_Task__c WHERE Id = :tasks[5].Id];
task6.Status__c = 'Completed';
task6.Progress_Percentage__c = 100;
update task6;

// Create Related Tasks (Dependencies)
// Task 5 depends on Task 3 (Database Migration depends on Dashboard Components)
tasks[4].Related_Task__c = tasks[2].Id;
tasks[4].Relationship_Type__c = 'Blocking Dependency';

// Task 10 depends on Task 7 (Data Export depends on Performance Optimization)
tasks[9].Related_Task__c = tasks[6].Id;
tasks[9].Relationship_Type__c = 'Blocking Dependency';

// Create a task that Task 5 depends on (reverse dependency)
Project_Task__c blockingTask = new Project_Task__c(
    Name = 'Infrastructure Setup',
    Account__c = accounts[2].Id,
    Status__c = 'In Progress',
    Priority__c = 'High',
    Estimated_Hours__c = 40,
    Actual_Hours__c = 20,
    Progress_Percentage__c = 50,
    Developer__c = devUser.Id
);
insert blockingTask;

// Update Task 5 to depend on blockingTask
tasks[4].Related_Task__c = blockingTask.Id;
tasks[4].Relationship_Type__c = 'Blocking Dependency';

// Update tasks with relationships
update tasks[4];
update tasks[9];

System.debug('Created related task dependencies');

// Create a task that depends on Task 5 (reverse dependency - task that depends on Database Migration)
Project_Task__c dependentTask = new Project_Task__c(
    Name = 'Backup System Configuration',
    Account__c = accounts[2].Id,
    Status__c = 'Pending',
    Priority__c = 'Medium',
    Estimated_Hours__c = 16,
    Actual_Hours__c = 0,
    Progress_Percentage__c = 0,
    Developer__c = devUser.Id,
    Related_Task__c = tasks[4].Id,
    Relationship_Type__c = 'Blocking Dependency',
    At_Risk_Due_to_Dependencies__c = true
);
insert dependentTask;
System.debug('Created dependent task');

// Create a task with both subtask and related task (mix)
Project_Task__c mixedTask = new Project_Task__c(
    Name = 'Full Stack Feature Implementation',
    Account__c = accounts[0].Id,
    Status__c = 'Pending',
    Priority__c = 'High',
    Estimated_Hours__c = 50,
    Actual_Hours__c = 25,
    Progress_Percentage__c = 50,
    Developer__c = devUser.Id,
    Related_Task__c = tasks[2].Id,
    Relationship_Type__c = 'Blocking Dependency',
    Client_Approved_for_Development__c = true
);
insert mixedTask;

// Add subtasks to mixed task
List<Project_Task__c> mixedSubtasks = new List<Project_Task__c>();
mixedSubtasks.add(new Project_Task__c(
    Name = 'Backend API Development',
    Account__c = accounts[0].Id,
    Parent_Task__c = mixedTask.Id,
    Status__c = 'Completed',
    Priority__c = 'High',
    Estimated_Hours__c = 20,
    Actual_Hours__c = 18,
    Progress_Percentage__c = 100,
    Developer__c = devUser.Id
));
mixedSubtasks.add(new Project_Task__c(
    Name = 'Frontend Integration',
    Account__c = accounts[0].Id,
    Parent_Task__c = mixedTask.Id,
    Status__c = 'In Progress',
    Priority__c = 'High',
    Estimated_Hours__c = 20,
    Actual_Hours__c = 7,
    Progress_Percentage__c = 35,
    Developer__c = devUser.Id
));
mixedSubtasks.add(new Project_Task__c(
    Name = 'Testing and QA',
    Account__c = accounts[0].Id,
    Parent_Task__c = mixedTask.Id,
    Status__c = 'Pending',
    Priority__c = 'Medium',
    Estimated_Hours__c = 10,
    Actual_Hours__c = 0,
    Progress_Percentage__c = 0,
    Developer__c = devUser.Id
));
insert mixedSubtasks;

// Update mixed task to In Progress (it's already In Progress, but ensure it's saved)
// No update needed as it was created as In Progress

System.debug('Created mixed task with ' + mixedSubtasks.size() + ' subtasks and a related task');

System.debug('=== Test Data Creation Complete ===');
System.debug('Total Accounts: ' + accounts.size());
Integer totalTasks = tasks.size() + subtasks1.size() + subtasks2.size() + subtasks3.size() + 1 + 1 + mixedSubtasks.size() + 1;
System.debug('Total Tasks: ' + totalTasks);
System.debug('Parent Tasks: ' + (tasks.size() + 1 + 1));
System.debug('Subtasks: ' + (subtasks1.size() + subtasks2.size() + subtasks3.size() + mixedSubtasks.size()));
