public with sharing class CreateReleaseNoteQuickActionController {
  @AuraEnabled
  public static Id createReleaseNote(
    Id taskId,
    String releaseNotesText,
    Id releaseVersionId,
    Id releaseTagId
  ) {
    if (taskId == null) {
      throw new AuraHandledException(
        'A task Id is required to create a release note.'
      );
    }
    if (String.isBlank(releaseNotesText)) {
      throw new AuraHandledException('Release notes text is required.');
    }

    Project_Task__c task = [
      SELECT Id
      FROM Project_Task__c
      WHERE Id = :taskId
      LIMIT 1
    ];

    Release_Notes__c releaseNote = new Release_Notes__c(
      Release_Notes_Text__c = releaseNotesText,
      Release_Version__c = releaseVersionId,
      Release_Tag__c = releaseTagId
    );

    insert releaseNote;

    task.Release_Notes__c = releaseNote.Id;
    update task;

    return releaseNote.Id;
  }
}
