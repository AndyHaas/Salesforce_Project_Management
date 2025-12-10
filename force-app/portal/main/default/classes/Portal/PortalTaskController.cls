/**
 * @description Apex controller for Task Detail component
 * Provides task detail data for portal users
 */
public without sharing class PortalTaskController {
    
    /**
     * @description Get task detail with all related information
     * @param taskId The Project Task ID
     * @return TaskDetailData wrapper with task and related information
     */
    @AuraEnabled(cacheable=true)
    public static TaskDetailData getTaskDetail(String taskId) {
        if (String.isBlank(taskId)) {
            throw new AuraHandledException('Task ID is required');
        }
        
        TaskDetailData data = new TaskDetailData();
        
        // Get current user's account
        User currentUser = [
            SELECT Id, AccountId, ContactId 
            FROM User 
            WHERE Id = :UserInfo.getUserId() 
            LIMIT 1
        ];
        
        Set<Id> accountIds = new Set<Id>();
        if (currentUser.AccountId != null) {
            accountIds.add(currentUser.AccountId);
        }
        
        // Query task with all necessary fields
        List<Project_Task__c> tasks = [
            SELECT 
                Id, Name, Description__c, Status__c, Priority__c,
                Start_Date__c, Due_Date__c, Is_Overdue__c,
                At_Risk_Due_to_Dependencies__c, Progress_Percentage__c,
                Review_Status_Icons__c,
                Estimated_Hours__c, Actual_Hours__c,
                Total_Estimated_Hours__c, Total_Actual_Hours__c,
                Project__c, Project__r.Name, Project__r.Id,
                Account__c, Account__r.Name,
                Project_Manager__c, Project_Manager__r.Name,
                Developer__c, Developer__r.Name,
                Client_User__c, Client_User__r.Name,
                Parent_Task__c, Parent_Task__r.Name, Parent_Task__r.Id,
                Parent_Task__r.Status__c, Parent_Task__r.Priority__c, Parent_Task__r.Description__c,
                Release_Notes__c, Release_Notes__r.Release_Tag__r.Name,
                Release_Notes__r.Release_Version__r.Name, Release_Notes__r.Release_Notes_Text__c,
                CreatedDate
            FROM Project_Task__c
            WHERE Id = :taskId
            AND Account__c IN :accountIds
            LIMIT 1
        ];
        
        if (tasks.isEmpty()) {
            throw new AuraHandledException('Task not found or access denied');
        }
        
        Project_Task__c task = tasks[0];
        data.task = task;
        
        return data;
    }
    
    /**
     * @description Wrapper class for task detail data
     */
    public class TaskDetailData {
        @AuraEnabled public Project_Task__c task;
    }
}
