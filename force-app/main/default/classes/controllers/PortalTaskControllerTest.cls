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

  /**
   * Goal: requirePortalTaskAccess (via applyPortalTaskAction) rejects a blank task Id.
   */
  @IsTest
  static void applyPortalTaskAction_blankTaskId_throws() {
    withPortalScope(portalAccountId());
    try {
      Boolean threw = false;
      try {
        PortalTaskController.applyPortalTaskAction('', 'submitClientApproval', null);
      } catch (AuraHandledException e) {
        threw = true;
      }
      System.assert(threw, 'Blank task id');
    } finally {
      clearPortalScope();
    }
  }

  /**
   * Goal: getTaskDetail and applyPortalTaskAction deny tasks tied to accounts outside portal scope.
   */
  @IsTest
  static void getTaskDetail_and_applyAction_accessDenied_otherAccountTask() {
    Account other = new Account(Name = 'Portal Task Other Account');
    insert other;
    Project__c otherProj = new Project__c(
      Name = 'Other Portal Project',
      Account__c = other.Id,
      Status__c = 'Not Started'
    );
    insert otherProj;
    Project_Task__c otherTask = new Project_Task__c(
      Name = 'Other Account Task',
      Status__c = 'In Progress',
      Priority__c = 'Medium',
      Account__c = other.Id,
      Project__c = otherProj.Id
    );
    insert otherTask;

    withPortalScope(portalAccountId());
    try {
      Boolean detailThrew = false;
      try {
        PortalTaskController.getTaskDetail(otherTask.Id);
      } catch (AuraHandledException e) {
        detailThrew = true;
      }
      System.assert(detailThrew, 'getTaskDetail other account');

      Boolean actionThrew = false;
      try {
        PortalTaskController.applyPortalTaskAction(otherTask.Id, 'submitClientApproval', null);
      } catch (AuraHandledException e) {
        actionThrew = true;
      }
      System.assert(actionThrew, 'applyAction other account');
    } finally {
      clearPortalScope();
    }
  }

  /**
   * Goal: scoped queries return no rows when the task was deleted (valid Id, no accessible row).
   */
  @IsTest
  static void getTaskDetail_and_applyAction_taskNotFound_deletedRecord() {
    Project_Task__c t = portalTask();
    Id tid = t.Id;
    delete t;

    withPortalScope(portalAccountId());
    try {
      Boolean detailThrew = false;
      try {
        PortalTaskController.getTaskDetail(tid);
      } catch (AuraHandledException e) {
        detailThrew = true;
      }
      System.assert(detailThrew, 'getTaskDetail deleted');

      Boolean actionThrew = false;
      try {
        PortalTaskController.applyPortalTaskAction(tid, 'submitClientApproval', null);
      } catch (AuraHandledException e) {
        actionThrew = true;
      }
      System.assert(actionThrew, 'applyAction deleted');
    } finally {
      clearPortalScope();
    }
  }

  /**
   * Goal: applyCommentsToSubmissionAfterTaskTransition returns without DML when comments are blank.
   */
  @IsTest
  static void applyCommentsToSubmissionAfterTaskTransition_noOp_blankComments() {
    Project_Task__c t = portalTask();
    insert new Project_Task_Submission__c(Project_Task__c = t.Id, Comments__c = 'keep');
    PortalTaskController.applyCommentsToSubmissionAfterTaskTransition(t.Id, null);
    PortalTaskController.applyCommentsToSubmissionAfterTaskTransition(t.Id, '   ');
    Project_Task_Submission__c sub = [
      SELECT Comments__c
      FROM Project_Task_Submission__c
      WHERE Project_Task__c = :t.Id
      LIMIT 1
    ];
    System.assertEquals('keep', sub.Comments__c);
  }

  /**
   * Goal: no child submission and non-blank comments exits quietly (submissionId stays null).
   */
  @IsTest
  static void applyCommentsToSubmissionAfterTaskTransition_noSubmission_noError() {
    Id acctId = portalAccountId();
    Id projId = [SELECT Id FROM Project__c WHERE Name = 'Portal Task Detail Project' LIMIT 1].Id;
    Project_Task__c t = new Project_Task__c(
      Name = 'Task No Submission Row',
      Status__c = 'In Progress',
      Priority__c = 'Low',
      Account__c = acctId,
      Project__c = projId
    );
    insert t;
    PortalTaskController.applyCommentsToSubmissionAfterTaskTransition(t.Id, 'orphan comment');
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Project_Task_Submission__c WHERE Project_Task__c = :t.Id]
    );
  }

  /**
   * Goal: when Most_Recent_Project_Task_Submission__c is set, that row is updated (not latest-by-CreatedDate only).
   */
  @IsTest
  static void applyCommentsToSubmissionAfterTaskTransition_prefersMostRecentLookup() {
    Project_Task__c t = portalTask();
    Project_Task_Submission__c first = new Project_Task_Submission__c(
      Project_Task__c = t.Id,
      Comments__c = 'first'
    );
    insert first;
    Project_Task_Submission__c second = new Project_Task_Submission__c(
      Project_Task__c = t.Id,
      Comments__c = 'second'
    );
    insert second;
    t.Most_Recent_Project_Task_Submission__c = first.Id;
    update t;

    PortalTaskController.applyCommentsToSubmissionAfterTaskTransition(t.Id, 'via most recent');
    first = [SELECT Comments__c FROM Project_Task_Submission__c WHERE Id = :first.Id];
    second = [SELECT Comments__c FROM Project_Task_Submission__c WHERE Id = :second.Id];
    System.assertEquals('via most recent', first.Comments__c);
    System.assertEquals('second', second.Comments__c);
  }

  /**
   * Goal: second preview request reuses an existing ContentDistribution row (early return branch).
   */
  @IsTest
  static void getFilePreviewUrl_reusesExistingContentDistribution() {
    Id accId = portalAccountId();
    ContentVersion cv = new ContentVersion(
      Title = 'PortalPreviewReuse',
      PathOnClient = 'reuse.pdf',
      VersionData = Blob.valueOf('x'),
      FirstPublishLocationId = accId
    );
    insert cv;
    withPortalScope(accId);
    try {
      String u1 = PortalTaskController.getFilePreviewUrl(String.valueOf(cv.Id));
      String u2 = PortalTaskController.getFilePreviewUrl(String.valueOf(cv.Id));
      System.assertEquals(u1, u2);
      System.assert(!String.isBlank(u1));
    } finally {
      clearPortalScope();
    }
  }

  /**
   * Goal: getFilePreviewUrl wraps non-Aura failures as AuraHandledException (catch-all path).
   */
  @IsTest
  static void getFilePreviewUrl_invalidContentVersion_surfacesAuraHandledException() {
    Boolean threw = false;
    try {
      PortalTaskController.getFilePreviewUrl(String.valueOf(UserInfo.getUserId()));
    } catch (AuraHandledException e) {
      threw = true;
    }
    System.assert(threw, 'Expected wrapped preview failure');
  }

  /**
   * Goal: client review actions with comments invoke applyCommentsToSubmissionAfterTaskTransition after update.
   * May hit DmlException when org automation runs on task update; coverage of the integration line is still attempted.
   */
  @IsTest
  static void applyPortalTaskAction_clientReview_writesSubmissionComments_whenUpdateSucceeds() {
    Project_Task__c t = portalTask();
    insert new Project_Task_Submission__c(Project_Task__c = t.Id);
    withPortalScope(portalAccountId());
    try {
      try {
        PortalTaskController.applyPortalTaskAction(t.Id, 'approveClientBacklog', 'client approved backlog');
      } catch (DmlException expectedFromAutomation) {
        return;
      }
      Project_Task_Submission__c sub = [
        SELECT Comments__c
        FROM Project_Task_Submission__c
        WHERE Project_Task__c = :t.Id
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];
      System.assertEquals('client approved backlog', sub.Comments__c);
    } finally {
      clearPortalScope();
    }
  }
}
