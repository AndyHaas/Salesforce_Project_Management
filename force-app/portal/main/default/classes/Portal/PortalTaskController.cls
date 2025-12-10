/**
 * @description Apex controller for Task Detail component
 * Provides task detail data for portal users
 * Uses without sharing to allow portal users to create file records
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
        // Check access via Project's Account (Master-Detail relationship)
        // Tasks are linked to Projects, and Projects are linked to Accounts
        List<Project_Task__c> tasks = [
            SELECT 
                Id, Name, Description__c, Status__c, Priority__c,
                Start_Date__c, Due_Date__c, Is_Overdue__c,
                At_Risk_Due_to_Dependencies__c, Progress_Percentage__c,
                Review_Status_Icons__c,
                Estimated_Hours__c, Actual_Hours__c,
                Total_Estimated_Hours__c, Total_Actual_Hours__c,
                Project__c, Project__r.Name, Project__r.Id, Project__r.Account__c,
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
            AND (Project__r.Account__c IN :accountIds OR Account__c IN :accountIds)
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
     * @description Link recently uploaded files to a task (fallback method)
     * Links files uploaded by the current user in the last few minutes
     * @param taskId The Project Task ID
     * @return List of linked file IDs
     */
    @AuraEnabled
    public static List<String> linkRecentFilesToTask(String taskId) {
        if (String.isBlank(taskId)) {
            throw new AuraHandledException('Task ID is required');
        }
        
        try {
            Id currentUserId = UserInfo.getUserId();
            DateTime fiveMinutesAgo = DateTime.now().addMinutes(-5);
            
            // Find ContentVersions created by current user in last 5 minutes
            List<ContentVersion> recentVersions = [
                SELECT ContentDocumentId, CreatedDate
                FROM ContentVersion
                WHERE CreatedBy.Id = :currentUserId
                AND CreatedDate >= :fiveMinutesAgo
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
            
            if (recentVersions.isEmpty()) {
                return new List<String>();
            }
            
            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentVersion cv : recentVersions) {
                if (cv.ContentDocumentId != null) {
                    contentDocumentIds.add(cv.ContentDocumentId);
                }
            }
            
            // Check which ones are already linked to this task
            List<ContentDocumentLink> existingLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :taskId
                AND ContentDocumentId IN :contentDocumentIds
            ];
            
            Set<Id> existingContentDocumentIds = new Set<Id>();
            for (ContentDocumentLink link : existingLinks) {
                existingContentDocumentIds.add(link.ContentDocumentId);
            }
            
            // Create new links
            List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
            List<String> linkedFileIds = new List<String>();
            
            for (Id docId : contentDocumentIds) {
                if (!existingContentDocumentIds.contains(docId)) {
                    ContentDocumentLink link = new ContentDocumentLink();
                    link.LinkedEntityId = taskId;
                    link.ContentDocumentId = docId;
                    link.ShareType = 'V';
                    link.Visibility = 'AllUsers';
                    newLinks.add(link);
                    linkedFileIds.add(docId);
                }
            }
            
            if (!newLinks.isEmpty()) {
                insert newLinks;
            }
            
            return linkedFileIds;
        } catch (Exception e) {
            throw new AuraHandledException('Error linking recent files: ' + e.getMessage());
        }
    }
    
    /**
     * @description Link uploaded files to a task
     * @param taskId The Project Task ID
     * @param contentVersionIds List of ContentVersion IDs to link
     * @return Boolean indicating success
     */
    @AuraEnabled
    public static Boolean linkFilesToTask(String taskId, List<String> contentVersionIds) {
        if (String.isBlank(taskId) || contentVersionIds == null || contentVersionIds.isEmpty()) {
            throw new AuraHandledException('Task ID and content version IDs are required');
        }
        
        try {
            // Get ContentDocument IDs from ContentVersion IDs
            List<ContentVersion> contentVersions = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id IN :contentVersionIds
            ];
            
            if (contentVersions.isEmpty()) {
                throw new AuraHandledException('No content versions found for the provided IDs');
            }
            
            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentVersion cv : contentVersions) {
                if (cv.ContentDocumentId != null) {
                    contentDocumentIds.add(cv.ContentDocumentId);
                }
            }
            
            if (contentDocumentIds.isEmpty()) {
                throw new AuraHandledException('No content documents found');
            }
            
            // Check if links already exist
            List<ContentDocumentLink> existingLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :taskId
                AND ContentDocumentId IN :contentDocumentIds
            ];
            
            Set<Id> existingContentDocumentIds = new Set<Id>();
            for (ContentDocumentLink link : existingLinks) {
                existingContentDocumentIds.add(link.ContentDocumentId);
            }
            
            // Create new links for documents that aren't already linked
            List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
            for (Id docId : contentDocumentIds) {
                if (!existingContentDocumentIds.contains(docId)) {
                    ContentDocumentLink link = new ContentDocumentLink();
                    link.LinkedEntityId = taskId;
                    link.ContentDocumentId = docId;
                    link.ShareType = 'V'; // Viewer access
                    link.Visibility = 'AllUsers';
                    newLinks.add(link);
                }
            }
            
            if (!newLinks.isEmpty()) {
                insert newLinks;
            }
            
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error linking files to task: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get files linked to a task
     * @param taskId The Project Task ID
     * @return List of FileInfo with file details
     */
    @AuraEnabled(cacheable=true)
    public static List<FileInfo> getTaskFiles(String taskId) {
        if (String.isBlank(taskId)) {
            return new List<FileInfo>();
        }
        
        List<FileInfo> files = new List<FileInfo>();
        
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension,
                   ContentDocument.ContentSize, ContentDocument.CreatedDate, ContentDocument.CreatedBy.Name,
                   ContentDocument.CreatedBy.Id, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :taskId
            ORDER BY ContentDocument.CreatedDate DESC
        ];
        
        Id currentUserId = UserInfo.getUserId();
        
        for (ContentDocumentLink link : links) {
            FileInfo file = new FileInfo();
            file.id = link.ContentDocumentId;
            file.title = link.ContentDocument.Title;
            file.extension = link.ContentDocument.FileExtension;
            file.size = link.ContentDocument.ContentSize;
            file.createdDate = link.ContentDocument.CreatedDate;
            file.createdBy = link.ContentDocument.CreatedBy?.Name;
            file.createdById = link.ContentDocument.CreatedBy?.Id;
            file.versionId = link.ContentDocument.LatestPublishedVersionId;
            file.canDelete = (link.ContentDocument.CreatedBy?.Id == currentUserId);
            files.add(file);
        }
        
        return files;
    }
    
    /**
     * @description Wrapper class for task detail data
     */
    public class TaskDetailData {
        @AuraEnabled public Project_Task__c task;
    }
    
    /**
     * @description Delete a file if it was uploaded by the current user
     * @param contentDocumentId The ContentDocument ID to delete
     * @return Boolean indicating success
     */
    @AuraEnabled
    public static Boolean deleteFile(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) {
            throw new AuraHandledException('File ID is required');
        }
        
        try {
            Id currentUserId = UserInfo.getUserId();
            
            // Check if the file was created by the current user
            List<ContentDocument> documents = [
                SELECT Id, CreatedBy.Id
                FROM ContentDocument
                WHERE Id = :contentDocumentId
                LIMIT 1
            ];
            
            if (documents.isEmpty()) {
                throw new AuraHandledException('File not found');
            }
            
            ContentDocument doc = documents[0];
            if (doc.CreatedBy.Id != currentUserId) {
                throw new AuraHandledException('You can only delete files that you uploaded');
            }
            
            // Delete the ContentDocument (this will cascade delete ContentDocumentLinks)
            delete doc;
            
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting file: ' + e.getMessage());
        }
    }
    
    /**
     * @description Wrapper class for file information
     */
    public class FileInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String extension;
        @AuraEnabled public Long size;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String createdBy;
        @AuraEnabled public String createdById;
        @AuraEnabled public String versionId;
        @AuraEnabled public Boolean canDelete;
    }
}
