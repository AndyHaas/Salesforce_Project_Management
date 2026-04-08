@isTest
private class CreateReleaseNoteQAControllerTest {
  @isTest
  static void testCreateReleaseNote() {
    Account account = new Account(Name = 'Test Account');
    insert account;

    Project__c project = new Project__c(Name = 'Test Project', Account__c = account.Id, Status__c = 'Not Started');
    insert project;

    Project_Task__c task = new Project_Task__c(
      Name = 'Parent Task',
      Status__c = 'Backlog',
      Account__c = account.Id,
      Project__c = project.Id
    );
    insert task;

    Test.startTest();
    Id releaseNoteId = CreateReleaseNoteQuickActionController.createReleaseNote(
      task.Id,
      'Release notes body',
      null,
      null
    );
    Test.stopTest();

    Project_Task__c refreshedTask = [
      SELECT Release_Notes__c
      FROM Project_Task__c
      WHERE Id = :task.Id
    ];
    Release_Notes__c releaseNote = [
      SELECT Id, Release_Notes_Text__c
      FROM Release_Notes__c
      WHERE Id = :releaseNoteId
    ];

    System.assertNotEquals(null, releaseNoteId, 'Release note Id should be returned');
    System.assertEquals('Release notes body', releaseNote.Release_Notes_Text__c, 'Release notes text should persist');
    System.assertEquals(releaseNoteId, refreshedTask.Release_Notes__c, 'Task should be linked to the new release note');
  }

  @IsTest
  static void createReleaseNote_nullTaskIdThrows() {
    Boolean threw = false;
    try {
      CreateReleaseNoteQuickActionController.createReleaseNote(null, 'body', null, null);
    } catch (AuraHandledException e) {
      threw = true;
    }
    System.assert(threw);
  }

  @IsTest
  static void createReleaseNote_blankTextThrows() {
    Account account = new Account(Name = 'RN Blank');
    insert account;
    Project__c project = new Project__c(Name = 'RN Blank Proj', Account__c = account.Id, Status__c = 'Not Started');
    insert project;
    Project_Task__c task = new Project_Task__c(
      Name = 'RN Blank Task',
      Status__c = 'Backlog',
      Account__c = account.Id,
      Project__c = project.Id
    );
    insert task;

    Boolean threw = false;
    try {
      CreateReleaseNoteQuickActionController.createReleaseNote(task.Id, '   ', null, null);
    } catch (AuraHandledException e) {
      threw = true;
    }
    System.assert(threw);
  }

  @IsTest
  static void createReleaseNote_missingTaskRecordThrows() {
    Account account = new Account(Name = 'RN Missing');
    insert account;

    Boolean threw = false;
    try {
      CreateReleaseNoteQuickActionController.createReleaseNote(account.Id, 'Some release text', null, null);
    } catch (Exception e) {
      threw = true;
    }
    System.assert(threw);
  }
}
