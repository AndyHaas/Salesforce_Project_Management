/**
 * @description Apex controller for Home Page component
 * 
 * Provides @AuraEnabled methods for retrieving home page data including:
 * - User information
 * - Active Projects list
 * - Open Tasks list
 * - Tasks needing client review count
 */
public with sharing class HomePageController {
    
    /**
     * @description Get home page data including user info, projects, and tasks
     * @return HomePageData wrapper with all home page information
     */
    @AuraEnabled(cacheable=true)
    public static HomePageData getHomePageData() {
        HomePageData data = new HomePageData();
        
        // Get current user info
        User currentUser = [SELECT Id, FirstName, LastName FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        data.userFirstName = currentUser.FirstName;
        
        // Get user's account (assuming Contact is linked to Account)
        List<Contact> contacts = [
            SELECT Id, AccountId, Account.Name 
            FROM Contact 
            WHERE Id IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId())
            LIMIT 1
        ];
        
        Set<Id> accountIds = new Set<Id>();
        if (!contacts.isEmpty() && contacts[0].AccountId != null) {
            accountIds.add(contacts[0].AccountId);
        }
        
        // Get Active Projects (Invoiced__c = FALSE and Status__c NOT IN excluded statuses)
        List<Project__c> activeProjects = new List<Project__c>();
        if (!accountIds.isEmpty()) {
            activeProjects = [
                SELECT Id, Name, Account__c, Burn_Rate__c, Status__c
                FROM Project__c
                WHERE Account__c IN :accountIds
                AND Invoiced__c = FALSE
                AND Status__c NOT IN ('Not Started', 'R&D', 'Proposal', 'Deployed', 'Cancelled')
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
        }
        data.activeProjects = activeProjects;
        
        // Get Open Tasks (Status != 'Closed' and Status != 'Completed' and Status != 'Removed')
        List<Project_Task__c> openTasks = new List<Project_Task__c>();
        if (!accountIds.isEmpty()) {
            openTasks = [
                SELECT Id, Name, Status__c, Total_Actual_Hours__c, Account__c, Account__r.Name
                FROM Project_Task__c
                WHERE Account__c IN :accountIds
                AND Status__c != 'Closed'
                AND Status__c != 'Completed'
                AND Status__c != 'Removed'
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
        }
        data.openTasks = openTasks;
        
        // Get count of tasks needing client review
        Integer reviewCount = 0;
        if (!accountIds.isEmpty()) {
            List<AggregateResult> results = [
                SELECT COUNT(Id) cnt
                FROM Project_Task__c
                WHERE Account__c IN :accountIds
                AND Ready_for_Client_Review__c = true
            ];
            if (!results.isEmpty()) {
                reviewCount = (Integer)results[0].get('cnt');
            }
        }
        data.tasksNeedingReviewCount = reviewCount;
        
        return data;
    }
    
    /**
     * @description Wrapper class for home page data
     */
    public class HomePageData {
        @AuraEnabled public String userFirstName;
        @AuraEnabled public List<Project__c> activeProjects;
        @AuraEnabled public List<Project_Task__c> openTasks;
        @AuraEnabled public Integer tasksNeedingReviewCount;
    }
}

