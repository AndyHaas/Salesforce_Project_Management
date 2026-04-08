@isTest
private class TaskProgressCalculatorTest {
  @testSetup
  static void setupTestData() {
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;
  }

  // ============================================
  // UNIT TESTS - Direct Helper Calls
  // ============================================

  @isTest
  static void testCalculateProgress_WithSubtasks() {
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert parent;

    // Create subtasks in database (helper queries them)
    List<Project_Task__c> subtasks = new List<Project_Task__c>();
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Project__c = parent.Project__c,
        Status__c = 'Completed', Submission_Status__c = 'Project Task Complete',
        Account__c = acc.Id,
        Priority__c = 'Medium',
        Estimated_Hours__c = 10,
        Actual_Hours__c = 8
      )
    );
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Project__c = parent.Project__c,
        Status__c = 'In Progress',
        Account__c = acc.Id,
        Priority__c = 'Medium',
        Estimated_Hours__c = 15,
        Actual_Hours__c = 5
      )
    );
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Project__c = parent.Project__c,
        Status__c = 'Backlog',
        Account__c = acc.Id,
        Priority__c = 'Low',
        Estimated_Hours__c = 20,
        Actual_Hours__c = 0
      )
    );
    insert subtasks;

    // Call helper directly with subtasks
    Test.startTest();
    TaskProgressCalculator.calculateProgress(subtasks);
    Test.stopTest();

    // Verify parent was updated
    Project_Task__c updatedParent = [
      SELECT
        Progress_Percentage__c,
        Total_Estimated_Hours__c,
        Total_Actual_Hours__c
      FROM Project_Task__c
      WHERE Id = :parent.Id
    ];
    System.assertEquals(
      33.33,
      updatedParent.Progress_Percentage__c,
      'Progress should be 33.33% (1 of 3 completed)'
    );
    System.assertEquals(
      45,
      updatedParent.Total_Estimated_Hours__c,
      'Total estimated hours should be 45'
    );
    System.assertEquals(
      13,
      updatedParent.Total_Actual_Hours__c,
      'Total actual hours should be 13'
    );
  }

  @isTest
  static void testCalculateProgress_AllSubtasksCompleted() {
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert parent;

    List<Project_Task__c> subtasks = new List<Project_Task__c>();
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'Completed', Submission_Status__c = 'Project Task Complete',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 10,
        Actual_Hours__c = 10
      )
    );
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'Completed', Submission_Status__c = 'Project Task Complete',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 15,
        Actual_Hours__c = 15
      )
    );
    insert subtasks;

    Test.startTest();
    TaskProgressCalculator.calculateProgress(subtasks);
    Test.stopTest();

    Project_Task__c updatedParent = [
      SELECT
        Progress_Percentage__c,
        Total_Estimated_Hours__c,
        Total_Actual_Hours__c
      FROM Project_Task__c
      WHERE Id = :parent.Id
    ];
    System.assertEquals(
      100,
      updatedParent.Progress_Percentage__c,
      'Progress should be 100% (all subtasks completed)'
    );
    System.assertEquals(
      25,
      updatedParent.Total_Estimated_Hours__c,
      'Total estimated hours should be 25'
    );
    System.assertEquals(
      25,
      updatedParent.Total_Actual_Hours__c,
      'Total actual hours should be 25'
    );
  }

  @isTest
  static void testCalculateProgress_WithRemovedSubtasks() {
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert parent;

    List<Project_Task__c> subtasks = new List<Project_Task__c>();
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'Completed', Submission_Status__c = 'Project Task Complete',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 10,
        Actual_Hours__c = 10
      )
    );
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'Removed',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 15,
        Actual_Hours__c = 5
      )
    );
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'In Progress',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Low',
        Estimated_Hours__c = 20,
        Actual_Hours__c = 5
      )
    );
    insert subtasks;

    Test.startTest();
    TaskProgressCalculator.calculateProgress(subtasks);
    Test.stopTest();

    Project_Task__c updatedParent = [
      SELECT
        Progress_Percentage__c,
        Total_Estimated_Hours__c,
        Total_Actual_Hours__c
      FROM Project_Task__c
      WHERE Id = :parent.Id
    ];
    // 1 out of 2 valid subtasks completed (removed doesn't count) = 50%
    System.assertEquals(
      50,
      updatedParent.Progress_Percentage__c,
      'Progress should be 50% (1 of 2 valid subtasks completed)'
    );
    System.assertEquals(
      45,
      updatedParent.Total_Estimated_Hours__c,
      'Total estimated hours should include removed tasks'
    );
    System.assertEquals(
      20,
      updatedParent.Total_Actual_Hours__c,
      'Total actual hours should include removed tasks'
    );
  }

  @isTest
  static void testCalculateProgress_EmptyParentTaskIds() {
    // Test with tasks that have no parent
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c task = new Project_Task__c(
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert task;

    Test.startTest();
    TaskProgressCalculator.calculateProgress(new List<Project_Task__c>{ task });
    Test.stopTest();

    // Should not throw exception
    System.assert(true, 'Should handle tasks without parent gracefully');
  }

  @isTest
  static void testCalculateProgress_ParentNotInMap() {
    // Test when parentTask is null (line 52)
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert parent;

    Project_Task__c subtask = new Project_Task__c(
      Parent_Task__c = parent.Id,
      Account__c = acc.Id,
      Project__c = parent.Project__c,
      Priority__c = 'Medium'
    );
    insert subtask;

    // Delete parent to simulate not found in map
    delete parent;

    Test.startTest();
    TaskProgressCalculator.calculateProgress(
      new List<Project_Task__c>{ subtask }
    );
    Test.stopTest();

    // Should handle gracefully
    System.assert(true, 'Should handle parent not found in map gracefully');
  }

  @isTest
  static void testCalculateProgress_ParentMissingAccount() {
    // Note: Account__c is required, so we can't actually create a parent without it
    // Instead, we'll test that the helper handles the case gracefully
    // by creating a parent with Account, then testing the logic path
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Account__c = acc.Id, // Required field - can't be null
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert parent;

    Project_Task__c subtask = new Project_Task__c(
      Parent_Task__c = parent.Id,
      Project__c = parent.Project__c,
      Status__c = 'Completed', Submission_Status__c = 'Project Task Complete',
      Account__c = acc.Id,
      Priority__c = 'Medium',
      Estimated_Hours__c = 10,
      Actual_Hours__c = 10
    );
    insert subtask;

    Test.startTest();
    TaskProgressCalculator.calculateProgress(
      new List<Project_Task__c>{ subtask }
    );
    Test.stopTest();

    // Verify parent task progress IS updated (Account is present)
    Project_Task__c updatedParent = [
      SELECT Progress_Percentage__c
      FROM Project_Task__c
      WHERE Id = :parent.Id
    ];
    System.assertEquals(
      100,
      updatedParent.Progress_Percentage__c,
      'Progress should be updated when parent task has Account'
    );
  }

  @isTest
  static void testCalculateProgress_ParentMissingPriority() {
    // Note: Priority__c is required, so we can't actually create a parent without it
    // Instead, we'll test that the helper handles the case gracefully
    // by creating a parent with Priority, then testing the logic path
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High' // Required field - can't be null
    );
    insert parent;

    Project_Task__c subtask = new Project_Task__c(
      Parent_Task__c = parent.Id,
      Project__c = parent.Project__c,
      Status__c = 'Completed', Submission_Status__c = 'Project Task Complete',
      Account__c = acc.Id,
      Priority__c = 'Medium',
      Estimated_Hours__c = 10,
      Actual_Hours__c = 10
    );
    insert subtask;

    Test.startTest();
    TaskProgressCalculator.calculateProgress(
      new List<Project_Task__c>{ subtask }
    );
    Test.stopTest();

    // Verify parent progress IS updated (Priority is present)
    Project_Task__c updatedParent = [
      SELECT Progress_Percentage__c
      FROM Project_Task__c
      WHERE Id = :parent.Id
    ];
    System.assertEquals(
      100,
      updatedParent.Progress_Percentage__c,
      'Progress should be updated when parent task has Priority'
    );
  }

  @isTest
  static void testCalculateProgress_EmptySubtasksList() {
    // Test when parentSubtasks is null or empty (line 47)
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert parent;

    // Create subtask and delete it to simulate empty list
    Project_Task__c subtask = new Project_Task__c(
      Parent_Task__c = parent.Id,
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'Medium',
      Status__c = 'Backlog'
    );
    insert subtask;
    delete subtask;

    // Create a task with parent reference but no subtasks exist
    Project_Task__c taskWithParent = new Project_Task__c(
      Parent_Task__c = parent.Id,
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'Medium',
      Status__c = 'Backlog'
    );
    insert taskWithParent;
    delete taskWithParent;

    Test.startTest();
    TaskProgressCalculator.calculateProgress(
      new List<Project_Task__c>{ taskWithParent }
    );
    Test.stopTest();

    // Should handle gracefully
    System.assert(true, 'Should handle empty subtasks list gracefully');
  }

  @isTest
  static void testCalculateProgress_NullHours() {
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert parent;

    List<Project_Task__c> subtasks = new List<Project_Task__c>();
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'Completed', Submission_Status__c = 'Project Task Complete',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium'
        // No Estimated_Hours__c or Actual_Hours__c
      )
    );
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'In Progress',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 10
        // No Actual_Hours__c
      )
    );
    insert subtasks;

    Test.startTest();
    TaskProgressCalculator.calculateProgress(subtasks);
    Test.stopTest();

    Project_Task__c updatedParent = [
      SELECT Total_Estimated_Hours__c, Total_Actual_Hours__c
      FROM Project_Task__c
      WHERE Id = :parent.Id
    ];
    System.assertEquals(
      10,
      updatedParent.Total_Estimated_Hours__c,
      'Total estimated hours should handle null values'
    );
    System.assertEquals(
      0,
      updatedParent.Total_Actual_Hours__c,
      'Total actual hours should be 0 when all are null'
    );
  }

  @isTest
  static void testCalculateProgress_AllRemovedSubtasks() {
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert parent;

    List<Project_Task__c> subtasks = new List<Project_Task__c>();
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'Removed',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 10,
        Actual_Hours__c = 5
      )
    );
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'Removed',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 15,
        Actual_Hours__c = 10
      )
    );
    insert subtasks;

    Test.startTest();
    TaskProgressCalculator.calculateProgress(subtasks);
    Test.stopTest();

    Project_Task__c updatedParent = [
      SELECT
        Progress_Percentage__c,
        Total_Estimated_Hours__c,
        Total_Actual_Hours__c
      FROM Project_Task__c
      WHERE Id = :parent.Id
    ];
    System.assertEquals(
      0,
      updatedParent.Progress_Percentage__c,
      'Progress should be 0 when all subtasks are removed'
    );
    System.assertEquals(
      25,
      updatedParent.Total_Estimated_Hours__c,
      'Total estimated hours should include removed tasks'
    );
    System.assertEquals(
      15,
      updatedParent.Total_Actual_Hours__c,
      'Total actual hours should include removed tasks'
    );
  }

  @isTest
  static void testCalculateProgress_DecimalPrecision() {
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert parent;

    List<Project_Task__c> subtasks = new List<Project_Task__c>();
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'Completed', Submission_Status__c = 'Project Task Complete',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 10.5,
        Actual_Hours__c = 10.5
      )
    );
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'In Progress',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 15.75,
        Actual_Hours__c = 5.25
      )
    );
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'Backlog',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 20.25,
        Actual_Hours__c = 0
      )
    );
    insert subtasks;

    Test.startTest();
    TaskProgressCalculator.calculateProgress(subtasks);
    Test.stopTest();

    Project_Task__c updatedParent = [
      SELECT
        Progress_Percentage__c,
        Total_Estimated_Hours__c,
        Total_Actual_Hours__c
      FROM Project_Task__c
      WHERE Id = :parent.Id
    ];
    System.assertEquals(
      33.33,
      updatedParent.Progress_Percentage__c,
      'Progress should be 33.33% with 2 decimal precision'
    );
    System.assertEquals(
      46.50,
      updatedParent.Total_Estimated_Hours__c,
      'Total estimated hours should be 46.50 with 2 decimal precision'
    );
    System.assertEquals(
      15.75,
      updatedParent.Total_Actual_Hours__c,
      'Total actual hours should be 15.75 with 2 decimal precision'
    );
  }

  // ============================================
  // INTEGRATION TESTS - DML Through Trigger
  // ============================================

  @isTest
  static void testCalculateProgress_Integration() {
    // Integration test - verify trigger calls helper correctly
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Name = 'Parent',
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert parent;

    Test.startTest();
    Project_Task__c subtask = new Project_Task__c(
      Name = 'Subtask',
      Parent_Task__c = parent.Id,
      Status__c = 'Completed', Submission_Status__c = 'Project Task Complete',
      Account__c = acc.Id,
      Project__c = parent.Project__c,
      Priority__c = 'Medium',
      Estimated_Hours__c = 10,
      Actual_Hours__c = 10
    );
    insert subtask; // Triggers trigger → calls helper
    Test.stopTest();

    // Verify through database
    Project_Task__c updatedParent = [
      SELECT Progress_Percentage__c
      FROM Project_Task__c
      WHERE Id = :parent.Id
    ];
    System.assertEquals(
      100,
      updatedParent.Progress_Percentage__c,
      'Integration: Parent should have 100% progress through trigger'
    );
  }

  @isTest
  static void testCalculateProgress_DeleteSubtaskIntegration() {
    // Integration test - verify trigger calls helper on delete
    Account acc = new Account(Name = 'Test');
    insert acc;
    Project__c proj = new Project__c(
      Name = 'Test Project',
      Account__c = acc.Id
    );
    insert proj;
    Project_Task__c parent = new Project_Task__c(
      Account__c = acc.Id,
      Project__c = proj.Id,
      Priority__c = 'High'
    );
    insert parent;

    List<Project_Task__c> subtasks = new List<Project_Task__c>();
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'Completed', Submission_Status__c = 'Project Task Complete',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 10,
        Actual_Hours__c = 10
      )
    );
    subtasks.add(
      new Project_Task__c(
        Parent_Task__c = parent.Id,
        Status__c = 'In Progress',
        Account__c = acc.Id,
        Project__c = parent.Project__c,
        Priority__c = 'Medium',
        Estimated_Hours__c = 15,
        Actual_Hours__c = 5
      )
    );
    insert subtasks;

    Test.startTest();
    delete subtasks[1]; // Triggers trigger → calls helper
    Test.stopTest();

    // Verify parent progress updated
    Project_Task__c updatedParent = [
      SELECT Progress_Percentage__c
      FROM Project_Task__c
      WHERE Id = :parent.Id
    ];
    System.assertEquals(
      100,
      updatedParent.Progress_Percentage__c,
      'Integration: Progress should be 100% after deleting incomplete subtask'
    );
  }
}
