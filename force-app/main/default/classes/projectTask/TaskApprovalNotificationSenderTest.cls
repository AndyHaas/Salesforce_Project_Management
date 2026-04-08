/**
 * @description Tests for ProjectTaskApprovalNotificationSender.
 */
@IsTest
private class TaskApprovalNotificationSenderTest {
  @IsTest
  static void sendNotifications_sendsEmailForBacklogClient() {
    Account a = new Account(Name = 'Acct Notify');
    insert a;
    Contact client = new Contact(LastName = 'Client', AccountId = a.Id, Email = 'client.notify@example.com');
    insert client;
    Project__c p = new Project__c(Name = 'Proj Notify', Account__c = a.Id, Status__c = 'Not Started');
    insert p;
    Project_Task__c t = new Project_Task__c(
      Name = 'Task Notify',
      Status__c = 'Backlog',
      Priority__c = 'High',
      Account__c = a.Id,
      Project__c = p.Id,
      Client_User__c = client.Id
    );
    insert t;

    ProjectTaskApprovalNotificationSender.Request req = new ProjectTaskApprovalNotificationSender.Request();
    req.projectTaskId = t.Id;
    req.approvalType = ProjectTaskApprovalNotificationSender.TYPE_BACKLOG_CLIENT;

    Test.startTest();
    ProjectTaskApprovalNotificationSender.sendEmailsInThisTest = true;
    try {
      ProjectTaskApprovalNotificationSender.sendNotifications(
        new List<ProjectTaskApprovalNotificationSender.Request>{ req }
      );
      System.assert(Limits.getEmailInvocations() >= 1, 'Expected at least one email');
    } finally {
      ProjectTaskApprovalNotificationSender.sendEmailsInThisTest = false;
    }
    Test.stopTest();
  }

  @IsTest
  static void sendNotifications_sendsEmailForPmReviewer() {
    Account a = new Account(Name = 'Acct PM');
    insert a;
    Contact pm = new Contact(LastName = 'PM', AccountId = a.Id, Email = 'pm.notify@example.com');
    insert pm;
    Project__c p = new Project__c(Name = 'Proj PM', Account__c = a.Id, Status__c = 'Not Started');
    insert p;
    Project_Task__c t = new Project_Task__c(
      Name = 'Task PM',
      Status__c = 'In Review',
      Priority__c = 'High',
      Account__c = a.Id,
      Project__c = p.Id,
      Project_Manager__c = pm.Id,
      Reviewed_by_PM_Code_Reviewer__c = false
    );
    insert t;

    ProjectTaskApprovalNotificationSender.Request req = new ProjectTaskApprovalNotificationSender.Request();
    req.projectTaskId = t.Id;
    req.approvalType = ProjectTaskApprovalNotificationSender.TYPE_PM_CODE_REVIEWER;

    Test.startTest();
    ProjectTaskApprovalNotificationSender.sendEmailsInThisTest = true;
    try {
      ProjectTaskApprovalNotificationSender.sendNotifications(
        new List<ProjectTaskApprovalNotificationSender.Request>{ req }
      );
      System.assert(Limits.getEmailInvocations() >= 1);
    } finally {
      ProjectTaskApprovalNotificationSender.sendEmailsInThisTest = false;
    }
    Test.stopTest();
  }

  @IsTest
  static void sendNotifications_unknownType_sendsNothing() {
    Account a = new Account(Name = 'Acct Skip');
    insert a;
    Contact c = new Contact(LastName = 'C', AccountId = a.Id, Email = 'skip@example.com');
    insert c;
    Project__c p = new Project__c(Name = 'Proj Skip', Account__c = a.Id, Status__c = 'Not Started');
    insert p;
    Project_Task__c t = new Project_Task__c(
      Name = 'Task Skip',
      Status__c = 'Backlog',
      Priority__c = 'Low',
      Account__c = a.Id,
      Project__c = p.Id,
      Client_User__c = c.Id
    );
    insert t;

    ProjectTaskApprovalNotificationSender.Request req = new ProjectTaskApprovalNotificationSender.Request();
    req.projectTaskId = t.Id;
    req.approvalType = 'INVALID';

    Test.startTest();
    ProjectTaskApprovalNotificationSender.sendEmailsInThisTest = true;
    try {
      ProjectTaskApprovalNotificationSender.sendNotifications(
        new List<ProjectTaskApprovalNotificationSender.Request>{ req }
      );
      System.assertEquals(0, Limits.getEmailInvocations());
    } finally {
      ProjectTaskApprovalNotificationSender.sendEmailsInThisTest = false;
    }
    Test.stopTest();
  }

  @IsTest
  static void sendNotifications_nullOrEmptyRequests_noOp() {
    Test.startTest();
    ProjectTaskApprovalNotificationSender.sendNotifications(null);
    ProjectTaskApprovalNotificationSender.sendNotifications(new List<ProjectTaskApprovalNotificationSender.Request>());
    Test.stopTest();
  }

  @IsTest
  static void sendNotifications_clientCompletion_sendsEmail() {
    Account a = new Account(Name = 'Acct Client Done');
    insert a;
    Contact client = new Contact(LastName = 'ClientDone', AccountId = a.Id, Email = 'client.done@example.com');
    insert client;
    Project__c p = new Project__c(Name = 'Proj Client Done', Account__c = a.Id, Status__c = 'Not Started');
    insert p;
    Project_Task__c t = new Project_Task__c(
      Name = 'Task Client Done',
      Status__c = 'In Progress',
      Priority__c = 'High',
      Account__c = a.Id,
      Project__c = p.Id,
      Client_User__c = client.Id
    );
    insert t;

    ProjectTaskApprovalNotificationSender.Request req = new ProjectTaskApprovalNotificationSender.Request();
    req.projectTaskId = t.Id;
    req.approvalType = ProjectTaskApprovalNotificationSender.TYPE_CLIENT_COMPLETION;

    Test.startTest();
    ProjectTaskApprovalNotificationSender.sendEmailsInThisTest = true;
    try {
      ProjectTaskApprovalNotificationSender.sendNotifications(
        new List<ProjectTaskApprovalNotificationSender.Request>{ req }
      );
      System.assert(Limits.getEmailInvocations() >= 1);
    } finally {
      ProjectTaskApprovalNotificationSender.sendEmailsInThisTest = false;
    }
    Test.stopTest();
  }
}
