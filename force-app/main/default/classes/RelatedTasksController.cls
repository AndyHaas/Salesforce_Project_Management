public with sharing class RelatedTasksController {
    @AuraEnabled(cacheable=true)
    public static List<Project_Task__c> getRelatedTasks(String taskId) {
        // Get all relationships where this task is either Task A or Task B
        // Return the related task (the other task in the relationship)
        Set<Id> relatedTaskIds = new Set<Id>();
        
        // Get relationships where this task is Task A (so Task B is the related task)
        List<Project_Task_Relationship__c> relationshipsA = [
            SELECT Task_B__c
            FROM Project_Task_Relationship__c
            WHERE Task_A__c = :taskId
        ];
        for (Project_Task_Relationship__c rel : relationshipsA) {
            relatedTaskIds.add(rel.Task_B__c);
        }
        
        // Get relationships where this task is Task B (so Task A is the related task)
        List<Project_Task_Relationship__c> relationshipsB = [
            SELECT Task_A__c
            FROM Project_Task_Relationship__c
            WHERE Task_B__c = :taskId
        ];
        for (Project_Task_Relationship__c rel : relationshipsB) {
            relatedTaskIds.add(rel.Task_A__c);
        }
        
        if (relatedTaskIds.isEmpty()) {
            return new List<Project_Task__c>();
        }
        
        return [
            SELECT Id, Name, Status__c, Priority__c
            FROM Project_Task__c
            WHERE Id IN :relatedTaskIds
            ORDER BY CreatedDate DESC
        ];
    }
}

