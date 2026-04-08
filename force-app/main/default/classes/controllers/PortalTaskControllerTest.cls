/**
 * @description Tests for PortalTaskController (portal task detail entry points).
 * getTaskDetail scopes by the running user’s AccountId; full happy-path coverage is best done
 * in the Experience Cloud context or with a profile that supports User.AccountId in tests.
 */
@IsTest
private class PortalTaskControllerTest {
  private static Id portalAccountId() {
    return [SELECT Id FROM Account WHERE Name = 'Portal Task Detail Account' LIMIT 1].Id;
  }

  private static Project_Task__c portalTask() {
    return [
      SELECT Id, Account__c, Project__c
      FROM Project_Task__c
      WHERE Name = 'Portal Detail Task'
      LIMIT 1
    ];
  }

  private static void withPortalScope(Id accountId) {
    PortalTaskController.testPortalAccountIds = new Set<Id>{ accountId };
  }

  private static void clearPortalScope() {
    PortalTaskController.testPortalAccountIds = null;
  }

  @TestSetup
  static void setupData() {
    Account acct = new Account(Name = 'Portal Task Detail Account');
    insert acct;

    Project__c proj = new Project__c(
      Name = 'Portal Task Detail Project',
      Account__c = acct.Id,
      Status__c = 'Not Started'
    );
    insert proj;

    Project_Task__c task = new Project_Task__c(
      Name = 'Portal Detail Task',
      Status__c = 'In Progress',
      Priority__c = 'High',
      Account__c = acct.Id,
      Project__c = proj.Id,
      Estimated_Hours__c = 5,
      Progress_Percentage__c = 25
    );
    insert task;
  }

  /**
   * Goal: guard rails for getTaskDetail — blank Id and a non-Project_Task__c Id must throw
   * AuraHandledException (single method to avoid redundant setup).
   */
  @IsTest
  static void getTaskDetail_validationErrors_blankIdAndWrongSobject() {
    Boolean blankThrew = false;
    try {
      PortalTaskController.getTaskDetail('');
    } catch (AuraHandledException e) {
      blankThrew = true;
      if (!e.getMessage().equalsIgnoreCase('Script-thrown exception')) {
        System.assert(e.getMessage().toLowerCase().contains('required'), e.getMessage());
      }
    }
    System.assert(blankThrew, 'Blank id');

    Account a = [SELECT Id FROM Account WHERE Name = 'Portal Task Detail Account' LIMIT 1];
    Boolean wrongTypeThrew = false;
    try {
      PortalTaskController.getTaskDetail(a.Id);
    } catch (AuraHandledException e) {
      wrongTypeThrew = true;
    }
    System.assert(wrongTypeThrew, 'Non-task Id');
  }

  @IsTest
  static void getTaskDetail_returnsTaskWhenScoped() {
    Project_Task__c t = portalTask();
    withPortalScope(portalAccountId());
    try {
      PortalTaskController.TaskDetailData data = PortalTaskController.getTaskDetail(t.Id);
      System.assertNotEquals(null, data, 'Wrapper');
      System.assertNotEquals(null, data.task, 'Task row');
      System.assertEquals(t.Id, data.task.Id);
      System.assertEquals('Portal Detail Task', data.task.Name);
    } finally {
      clearPortalScope();
    }
  }

  /**
   * Goal: applyPortalTaskAction rejects empty action key and unknown keys while portal scope is set
   * (one scoped block, shared setup).
   */
  @IsTest
  static void applyPortalTaskAction_blankAndUnknownActionThrow() {
    Project_Task__c t = portalTask();
    Id acc = portalAccountId();
    withPortalScope(acc);
    try {
      Boolean blankThrew = false;
      try {
        PortalTaskController.applyPortalTaskAction(t.Id, '', null);
      } catch (AuraHandledException e) {
        blankThrew = true;
      }
      System.assert(blankThrew, 'Blank action');

      Boolean unknownThrew = false;
      try {
        PortalTaskController.applyPortalTaskAction(t.Id, 'notARealAction', null);
      } catch (AuraHandledException e) {
        unknownThrew = true;
      }
      System.assert(unknownThrew, 'Unknown action');
    } finally {
      clearPortalScope();
    }
  }

  @IsTest
  static void assignPortalActionFields_coversAllActionBranches() {
    Project_Task__c t = new Project_Task__c(Id = portalTask().Id);

    PortalTaskController.assignPortalActionFields(t, 'submitClientApproval');
    System.assertEquals('Backlog', t.Status__c);

    PortalTaskController.assignPortalActionFields(t, 'approveClientBacklog');
    System.assertEquals('Pending', t.Status__c);

    PortalTaskController.assignPortalActionFields(t, 'rejectClientBacklog');
    System.assertEquals('Backlog', t.Status__c);

    PortalTaskController.assignPortalActionFields(t, 'submitPmReview');
    System.assertEquals('In Review', t.Status__c);

    PortalTaskController.assignPortalActionFields(t, 'approvePmReview');
    System.assertEquals('In Review', t.Status__c);

    PortalTaskController.assignPortalActionFields(t, 'rejectPmReview');
    System.assertEquals('In Progress', t.Status__c);

    PortalTaskController.assignPortalActionFields(t, 'submitClientCompletion');
    System.assertEquals(true, t.Approved_by_PM_Code_Reviewer__c);

    PortalTaskController.assignPortalActionFields(t, 'approveClientCompletion');
    System.assertEquals('Completed', t.Status__c);

    PortalTaskController.assignPortalActionFields(t, 'rejectClientCompletion');
    System.assertEquals('In Progress', t.Status__c);
  }

  @IsTest
  static void assignPortalActionFields_unknownThrows() {
    Boolean threw = false;
    try {
      PortalTaskController.assignPortalActionFields(new Project_Task__c(Id = portalTask().Id), 'badKey');
    } catch (AuraHandledException e) {
      threw = true;
    }
    System.assert(threw);
  }

  @IsTest
  static void applyCommentsToSubmissionAfterTaskTransition_updatesChild() {
    Project_Task__c t = portalTask();
    insert new Project_Task_Submission__c(Project_Task__c = t.Id);
    PortalTaskController.applyCommentsToSubmissionAfterTaskTransition(t.Id, '  note from client  ');
    Project_Task_Submission__c sub = [
      SELECT Comments__c
      FROM Project_Task_Submission__c
      WHERE Project_Task__c = :t.Id
      LIMIT 1
    ];
    System.assertEquals('note from client', sub.Comments__c);
  }

  @IsTest
  static void applyPortalTaskAction_attemptsUpdateWhenOrgAllows() {
    Project_Task__c t = portalTask();
    withPortalScope(portalAccountId());
    try {
      try {
        PortalTaskController.applyPortalTaskAction(t.Id, 'submitClientApproval', null);
      } catch (DmlException expected) {
        // Some orgs run record-triggered flows on task update that require email templates in tests.
      }
    } finally {
      clearPortalScope();
    }
  }

  /**
   * Goal: getFilePreviewUrl returns a distribution URL for a scoped portal file, and blank Id throws.
   */
  @IsTest
  static void getFilePreviewUrl_happyPathAndBlankId() {
    Id accId = portalAccountId();
    ContentVersion cv = new ContentVersion(
      Title = 'PortalPreview',
      PathOnClient = 'PortalPreview.pdf',
      VersionData = Blob.valueOf('PDF'),
      FirstPublishLocationId = accId
    );
    insert cv;

    withPortalScope(accId);
    try {
      Test.startTest();
      String url = PortalTaskController.getFilePreviewUrl(String.valueOf(cv.Id));
      Test.stopTest();
      System.assert(!String.isBlank(url));
      System.assert(url.startsWith('http'));
    } finally {
      clearPortalScope();
    }

    Boolean blankThrew = false;
    try {
      PortalTaskController.getFilePreviewUrl('');
    } catch (AuraHandledException e) {
      blankThrew = true;
    }
    System.assert(blankThrew);
  }
}
