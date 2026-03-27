/**
 * @description Tests for ProjectTaskApproverUserHelper.
 *
 * @author Milestone Consulting
 */
@IsTest
private class ProjectTaskApproverUserHelperTest {
  private static Id projectForAccount(Id accountId) {
    Project__c p = new Project__c(
      Name = 'Approver Sync Project',
      Account__c = accountId,
      Status__c = 'Not Started'
    );
    insert p;
    return p.Id;
  }

  /**
   * @description Without a User row for the contacts, approver lookups stay null and no redundant DML is required.
   */
  @IsTest
  static void insert_withContactsButNoPortalUsers_leavesApproverLookupsNull() {
    Account a = new Account(Name = 'Acct Approver 1');
    insert a;
    Contact cClient = new Contact(LastName = 'Client C', AccountId = a.Id);
    Contact cPm = new Contact(LastName = 'PM C', AccountId = a.Id);
    insert new List<Contact>{ cClient, cPm };
    Id projId = projectForAccount(a.Id);

    Project_Task__c t = new Project_Task__c(
      Name = 'Task Approver 1',
      Status__c = 'Backlog',
      Priority__c = 'High',
      Account__c = a.Id,
      Project__c = projId,
      Client_User__c = cClient.Id,
      Project_Manager__c = cPm.Id
    );

    insert t;

    t = [
      SELECT Client_Approver_User__c, PM_Approver_User__c
      FROM Project_Task__c
      WHERE Id = :t.Id
    ];
    System.assertEquals(null, t.Client_Approver_User__c);
    System.assertEquals(null, t.PM_Approver_User__c);
  }

  /**
   * @description Clearing Project_Manager__c clears the PM approver User lookup when it was previously set.
   */
  @IsTest
  static void update_clearingProjectManager_clearsPmApproverUser() {
    Account a = new Account(Name = 'Acct Approver 2');
    insert a;
    Contact cPm = new Contact(LastName = 'PM Clear', AccountId = a.Id);
    insert cPm;
    Id projId = projectForAccount(a.Id);

    Project_Task__c t = new Project_Task__c(
      Name = 'Task Approver 2',
      Status__c = 'Backlog',
      Priority__c = 'High',
      Account__c = a.Id,
      Project__c = projId,
      Project_Manager__c = cPm.Id
    );
    insert t;

    t.PM_Approver_User__c = UserInfo.getUserId();
    update t;

    t.Project_Manager__c = null;
    update t;

    t = [SELECT PM_Approver_User__c FROM Project_Task__c WHERE Id = :t.Id];
    System.assertEquals(null, t.PM_Approver_User__c);
  }

  /**
   * @description Bulk safety: many inserts with overlapping contacts should complete.
   */
  @IsTest
  static void bulkInsert_completes() {
    Account a = new Account(Name = 'Acct Approver Bulk');
    insert a;
    List<Contact> contacts = new List<Contact>();
    for (Integer i = 0; i < 5; i++) {
      contacts.add(new Contact(LastName = 'BulkC' + i, AccountId = a.Id));
    }
    insert contacts;
    Id projId = projectForAccount(a.Id);

    List<Project_Task__c> tasks = new List<Project_Task__c>();
    for (Integer i = 0; i < 20; i++) {
      tasks.add(
        new Project_Task__c(
          Name = 'Bulk Task ' + i,
          Status__c = 'Backlog',
          Priority__c = 'Low',
          Account__c = a.Id,
          Project__c = projId,
          Client_User__c = contacts[Math.mod(i, 5)].Id,
          Project_Manager__c = contacts[Math.mod(i + 1, 5)].Id
        )
      );
    }

    Test.startTest();
    insert tasks;
    Test.stopTest();

    System.assertEquals(
      20,
      [
        SELECT COUNT()
        FROM Project_Task__c
        WHERE Project__c = :projId AND Name LIKE 'Bulk Task%'
      ]
    );
  }
}
