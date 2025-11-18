public with sharing class RelatedTasksController {
    @AuraEnabled(cacheable=true)
    public static List<Project_Task__c> getRelatedTasks(String taskId) {
        return [
            SELECT Id, Name, Status__c, Priority__c
            FROM Project_Task__c
            WHERE Related_Task__c = :taskId
            ORDER BY CreatedDate DESC
        ];
    }
}

