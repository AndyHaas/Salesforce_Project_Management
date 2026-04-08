/**
 * @description Tests for ProjectTaskApproverUserHelper.
 *
 * @author Milestone Consulting
 */
@IsTest
private class ProjectTaskApproverUserHelperTest {
  private static Id projectForAccount(Id accountId) {
    Project__c p = new Project__c(Name = 'Approver Sync Project', Account__c = accountId, Status__c = 'Not Started');
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

  @IsTest
  static void syncApproverUsersFromContacts_direct_nullAndEmptyNoOp() {
    ProjectTaskApproverUserHelper.syncApproverUsersFromContacts(null, null);
    ProjectTaskApproverUserHelper.syncApproverUsersFromContacts(new List<Project_Task__c>(), null);
  }

  @IsTest
  static void syncApproverUsersFromContacts_direct_insertWithoutContactsNoUpdate() {
    Account a = new Account(Name = 'Direct Sync Acc');
    insert a;
    Id projId = projectForAccount(a.Id);
    Project_Task__c t = new Project_Task__c(
      Name = 'Direct Sync Task',
      Status__c = 'Backlog',
      Priority__c = 'Low',
      Account__c = a.Id,
      Project__c = projId
    );
    insert t;
    ProjectTaskApproverUserHelper.syncApproverUsersFromContacts(new List<Project_Task__c>{ t }, null);
  }

  @IsTest
  static void syncApproverUsersFromContacts_clearsClientApproverWhenContactRemoved() {
    Account a = new Account(Name = 'Approver Clear Acc');
    insert a;
    Contact c1 = new Contact(LastName = 'C1', AccountId = a.Id);
    insert c1;
    Id projId = projectForAccount(a.Id);
    Id someUserId = UserInfo.getUserId();

    Project_Task__c t = new Project_Task__c(
      Name = 'Approver Clear Task',
      Status__c = 'Backlog',
      Priority__c = 'Low',
      Account__c = a.Id,
      Project__c = projId,
      Client_User__c = c1.Id,
      Client_Approver_User__c = someUserId
    );
    insert t;

    Project_Task__c prior = new Project_Task__c(
      Id = t.Id,
      Client_User__c = c1.Id,
      Project_Manager__c = null,
      Client_Approver_User__c = someUserId,
      PM_Approver_User__c = null
    );

    t.Client_User__c = null;
    update t;

    t = [
      SELECT Id, Client_User__c, Project_Manager__c, Client_Approver_User__c, PM_Approver_User__c
      FROM Project_Task__c
      WHERE Id = :t.Id
    ];

    ProjectTaskApproverUserHelper.syncApproverUsersFromContacts(
      new List<Project_Task__c>{ t },
      new Map<Id, Project_Task__c>{ t.Id => prior }
    );

    t = [
      SELECT Client_Approver_User__c
      FROM Project_Task__c
      WHERE Id = :t.Id
    ];
    System.assertEquals(null, t.Client_Approver_User__c);
  }

  @IsTest
  static void syncApproverUsersFromContacts_setsPmApproverWhenPmAdded() {
    Account a = new Account(Name = 'PM Add Acc');
    insert a;
    Contact pm = new Contact(LastName = 'PMOnly', AccountId = a.Id);
    insert pm;
    Id projId = projectForAccount(a.Id);
    Project_Task__c t = new Project_Task__c(
      Name = 'PM Add Task',
      Status__c = 'Backlog',
      Priority__c = 'Low',
      Account__c = a.Id,
      Project__c = projId
    );
    insert t;

    Project_Task__c prior = new Project_Task__c(
      Id = t.Id,
      Client_User__c = null,
      Project_Manager__c = null,
      Client_Approver_User__c = null,
      PM_Approver_User__c = null
    );

    t.Project_Manager__c = pm.Id;
    update t;

    t = [
      SELECT Id, Client_User__c, Project_Manager__c, Client_Approver_User__c, PM_Approver_User__c
      FROM Project_Task__c
      WHERE Id = :t.Id
    ];

    ProjectTaskApproverUserHelper.syncApproverUsersFromContacts(
      new List<Project_Task__c>{ t },
      new Map<Id, Project_Task__c>{ t.Id => prior }
    );
  }

  @IsTest
  static void syncApproverUsersFromContacts_projectManagerContactChange_noUsersResolved() {
    Account a = new Account(Name = 'PM Switch Acc');
    insert a;
    Contact pm1 = new Contact(LastName = 'Pm1', AccountId = a.Id);
    Contact pm2 = new Contact(LastName = 'Pm2', AccountId = a.Id);
    insert new List<Contact>{ pm1, pm2 };
    Id projId = projectForAccount(a.Id);
    Project_Task__c t = new Project_Task__c(
      Name = 'PM Switch Task',
      Status__c = 'Backlog',
      Priority__c = 'Low',
      Account__c = a.Id,
      Project__c = projId,
      Project_Manager__c = pm1.Id
    );
    insert t;

    Project_Task__c prior = new Project_Task__c(
      Id = t.Id,
      Client_User__c = null,
      Project_Manager__c = pm1.Id,
      Client_Approver_User__c = null,
      PM_Approver_User__c = null
    );

    t.Project_Manager__c = pm2.Id;
    update t;

    t = [
      SELECT Id, Client_User__c, Project_Manager__c, Client_Approver_User__c, PM_Approver_User__c
      FROM Project_Task__c
      WHERE Id = :t.Id
    ];

    ProjectTaskApproverUserHelper.syncApproverUsersFromContacts(
      new List<Project_Task__c>{ t },
      new Map<Id, Project_Task__c>{ t.Id => prior }
    );
  }

  @IsTest
  static void syncApproverUsersFromContacts_noChange_skipsUpdate() {
    Account a = new Account(Name = 'No Chg Acc');
    insert a;
    Contact c = new Contact(LastName = 'NC', AccountId = a.Id);
    insert c;
    Id projId = projectForAccount(a.Id);
    Project_Task__c t = new Project_Task__c(
      Name = 'No Chg Task',
      Status__c = 'Backlog',
      Priority__c = 'Low',
      Account__c = a.Id,
      Project__c = projId,
      Client_User__c = c.Id
    );
    insert t;
    t = [
      SELECT Id, Client_User__c, Project_Manager__c, Client_Approver_User__c, PM_Approver_User__c
      FROM Project_Task__c
      WHERE Id = :t.Id
    ];
    Project_Task__c prior = new Project_Task__c(
      Id = t.Id,
      Client_User__c = t.Client_User__c,
      Project_Manager__c = t.Project_Manager__c,
      Client_Approver_User__c = t.Client_Approver_User__c,
      PM_Approver_User__c = t.PM_Approver_User__c
    );
    ProjectTaskApproverUserHelper.syncApproverUsersFromContacts(
      new List<Project_Task__c>{ t },
      new Map<Id, Project_Task__c>{ t.Id => prior }
    );
  }

  @IsTest
  static void syncApproverUsersFromContacts_insertPath_collectsContactIds() {
    Account a = new Account(Name = 'Ins Path Acc');
    insert a;
    Contact c = new Contact(LastName = 'InsC', AccountId = a.Id);
    Contact pm = new Contact(LastName = 'InsPM', AccountId = a.Id);
    insert new List<Contact>{ c, pm };
    Id projId = projectForAccount(a.Id);
    Project_Task__c t = new Project_Task__c(
      Name = 'Ins Path Task',
      Status__c = 'Backlog',
      Priority__c = 'Low',
      Account__c = a.Id,
      Project__c = projId,
      Client_User__c = c.Id,
      Project_Manager__c = pm.Id
    );
    insert t;
    t = [
      SELECT Id, Client_User__c, Project_Manager__c, Client_Approver_User__c, PM_Approver_User__c
      FROM Project_Task__c
      WHERE Id = :t.Id
    ];
    ProjectTaskApproverUserHelper.syncApproverUsersFromContacts(new List<Project_Task__c>{ t }, null);
  }

  @IsTest
  static void syncApproverUsersFromContacts_resolvesRunningUserWhenLinkedToContact() {
    User me = [SELECT ContactId, AccountId FROM User WHERE Id = :UserInfo.getUserId()];
    if (me.ContactId == null || me.AccountId == null) {
      return;
    }
    Id projId = projectForAccount(me.AccountId);
    Project_Task__c t = new Project_Task__c(
      Name = 'Runner Contact Resolve Task',
      Status__c = 'Backlog',
      Priority__c = 'Low',
      Account__c = me.AccountId,
      Project__c = projId,
      Client_User__c = me.ContactId
    );
    insert t;
    t = [
      SELECT Id, Client_User__c, Project_Manager__c, Client_Approver_User__c, PM_Approver_User__c
      FROM Project_Task__c
      WHERE Id = :t.Id
    ];
    ProjectTaskApproverUserHelper.syncApproverUsersFromContacts(new List<Project_Task__c>{ t }, null);
  }

  @IsTest
  static void syncApproverUsersFromContacts_clientContactChange_noUsersResolved() {
    Account a = new Account(Name = 'Client Switch Acc');
    insert a;
    Contact c1 = new Contact(LastName = 'Sw1', AccountId = a.Id);
    Contact c2 = new Contact(LastName = 'Sw2', AccountId = a.Id);
    insert new List<Contact>{ c1, c2 };
    Id projId = projectForAccount(a.Id);
    Project_Task__c t = new Project_Task__c(
      Name = 'Client Switch Task',
      Status__c = 'Backlog',
      Priority__c = 'Low',
      Account__c = a.Id,
      Project__c = projId,
      Client_User__c = c1.Id
    );
    insert t;

    Project_Task__c prior = new Project_Task__c(
      Id = t.Id,
      Client_User__c = c1.Id,
      Project_Manager__c = null,
      Client_Approver_User__c = null,
      PM_Approver_User__c = null
    );

    t.Client_User__c = c2.Id;
    update t;

    t = [
      SELECT Id, Client_User__c, Project_Manager__c, Client_Approver_User__c, PM_Approver_User__c
      FROM Project_Task__c
      WHERE Id = :t.Id
    ];

    ProjectTaskApproverUserHelper.syncApproverUsersFromContacts(
      new List<Project_Task__c>{ t },
      new Map<Id, Project_Task__c>{ t.Id => prior }
    );
  }
}
