@isTest
private class CreateReleaseNoteQAControllerTest {
    @isTest
    static void testCreateReleaseNote() {
        Account account = new Account(Name = 'Test Account');
        insert account;

        Project_Task__c task = new Project_Task__c(
            Name = 'Parent Task',
            Status__c = 'Backlog',
            Account__c = account.Id
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

        Project_Task__c refreshedTask = [SELECT Release_Notes__c FROM Project_Task__c WHERE Id = :task.Id];
        Release_Notes__c releaseNote = [SELECT Id, Release_Notes_Text__c FROM Release_Notes__c WHERE Id = :releaseNoteId];

        System.assertNotEquals(null, releaseNoteId, 'Release note Id should be returned');
        System.assertEquals('Release notes body', releaseNote.Release_Notes_Text__c, 'Release notes text should persist');
        System.assertEquals(releaseNoteId, refreshedTask.Release_Notes__c, 'Task should be linked to the new release note');
    }
}