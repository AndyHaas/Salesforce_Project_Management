/**
 * @description Tests for PortalTaskController (portal task detail entry points).
 * getTaskDetail scopes by the running user’s AccountId; full happy-path coverage is best done
 * in the Experience Cloud context or with a profile that supports User.AccountId in tests.
 */
@IsTest
private class PortalTaskControllerTest {
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

  @IsTest
  static void getTaskDetail_throwsWhenBlankId() {
    Boolean threw = false;
    try {
      PortalTaskController.getTaskDetail('');
    } catch (AuraHandledException e) {
      threw = true;
      // Package-version / managed context may mask AuraHandledException message as "Script-thrown exception"
      if (!e.getMessage().equalsIgnoreCase('Script-thrown exception')) {
        System.assert(e.getMessage().toLowerCase().contains('required'), e.getMessage());
      }
    }
    System.assert(threw, 'Expected AuraHandledException');
  }

  @IsTest
  static void getTaskDetail_throwsWhenRecordIsNotProjectTask() {
    Account a = [SELECT Id FROM Account WHERE Name = 'Portal Task Detail Account' LIMIT 1];
    Boolean threw = false;
    try {
      PortalTaskController.getTaskDetail(a.Id);
    } catch (AuraHandledException e) {
      threw = true;
    }
    System.assert(threw, 'Expected AuraHandledException when Id is not a visible task');
  }
}
