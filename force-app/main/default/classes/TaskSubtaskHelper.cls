/**
 * @description Helper class for managing subtask relationships and validations
 * 
 * Handles:
 * - Populating subtask client user from parent task (Client_User__c)
 * - Updating parent task status based on subtask status changes
 * - Validating that parent tasks cannot be closed if they have open subtasks
 * 
 * USAGE:
 * - Used in: ProjectTaskTrigger (before insert, before update, after update)
 * - Called by: TaskSubtaskHelper.populateSubtaskUsers()
 *              TaskSubtaskHelper.updateParentTaskStatus()
 *              TaskSubtaskHelper.validateParentCanBeClosed()
 */
public without sharing class TaskSubtaskHelper {
    
    /**
     * @description Populates Client_User__c from parent task when creating subtasks
     * @param tasks List of Project_Task__c records being inserted
     */
    public static void populateSubtaskUsers(List<Project_Task__c> tasks) {
        Set<Id> parentTaskIds = new Set<Id>();
        
        // Collect parent task IDs
        for (Project_Task__c task : tasks) {
            if (task.Parent_Task__c != null) {
                parentTaskIds.add(task.Parent_Task__c);
            }
        }
        
        if (parentTaskIds.isEmpty()) {
            return;
        }
        
        // Query parent tasks to get Client_User__c
        Map<Id, Project_Task__c> parentTasksMap = new Map<Id, Project_Task__c>([
            SELECT Id, Client_User__c
            FROM Project_Task__c
            WHERE Id IN :parentTaskIds
        ]);
        
        for (Project_Task__c task : tasks) {
            if (task.Parent_Task__c != null) {
                Project_Task__c parentTask = parentTasksMap.get(task.Parent_Task__c);
                if (parentTask != null) {
                    if (task.Client_User__c == null) {
                        task.Client_User__c = parentTask.Client_User__c;
                    }
                }
            }
        }
    }
    
    /**
     * @description Updates parent task status when subtask status changes
     * Updates parent to Pending if any subtask is Pending, or In Progress if any subtask is In Progress
     * Only updates if parent is in Backlog or Pending status
     * @param tasks List of Project_Task__c records being updated
     * @param oldTasksMap Map of old Project_Task__c records (Trigger.oldMap)
     */
    public static void updateParentTaskStatus(List<Project_Task__c> tasks, Map<Id, Project_Task__c> oldTasksMap) {
        Set<Id> parentTaskIds = new Set<Id>();
        List<Project_Task__c> relevantSubtasks = new List<Project_Task__c>();
        
        // Collect parent task IDs and identify relevant subtasks
        for (Project_Task__c task : tasks) {
            if (task.Parent_Task__c != null) {
                Project_Task__c oldTask = oldTasksMap.get(task.Id);
                // Only process if status changed and it's a relevant transition
                if (oldTask != null && task.Status__c != oldTask.Status__c) {
                    // Check if status changed from Backlog to Pending, or Pending to In Progress
                    if ((oldTask.Status__c == 'Backlog' && task.Status__c == 'Pending') ||
                        (oldTask.Status__c == 'Pending' && task.Status__c == 'In Progress')) {
                        parentTaskIds.add(task.Parent_Task__c);
                        relevantSubtasks.add(task);
                    }
                }
            }
        }
        
        if (parentTaskIds.isEmpty()) {
            return;
        }
        
        // Query parent tasks to check their current status
        Map<Id, Project_Task__c> parentTasksMap = new Map<Id, Project_Task__c>([
            SELECT Id, Status__c
            FROM Project_Task__c
            WHERE Id IN :parentTaskIds
        ]);
        
        // Query all subtasks for these parents to check their statuses
        List<Project_Task__c> allSubtasks = [
            SELECT Id, Parent_Task__c, Status__c
            FROM Project_Task__c
            WHERE Parent_Task__c IN :parentTaskIds
        ];
        
        // Group subtasks by parent
        Map<Id, List<Project_Task__c>> subtasksByParent = new Map<Id, List<Project_Task__c>>();
        for (Project_Task__c subtask : allSubtasks) {
            if (!subtasksByParent.containsKey(subtask.Parent_Task__c)) {
                subtasksByParent.put(subtask.Parent_Task__c, new List<Project_Task__c>());
            }
            subtasksByParent.get(subtask.Parent_Task__c).add(subtask);
        }
        
        List<Project_Task__c> parentsToUpdate = new List<Project_Task__c>();
        
        // Process each parent task
        for (Id parentId : parentTaskIds) {
            Project_Task__c parentTask = parentTasksMap.get(parentId);
            if (parentTask == null) {
                continue;
            }
            
            // Only update if parent is in Backlog or Pending
            if (parentTask.Status__c != 'Backlog' && parentTask.Status__c != 'Pending') {
                continue;
            }
            
            List<Project_Task__c> subtasks = subtasksByParent.get(parentId);
            if (subtasks == null || subtasks.isEmpty()) {
                continue;
            }
            
            // Check if any subtask is In Progress (takes priority)
            Boolean hasInProgressSubtask = false;
            Boolean hasPendingSubtask = false;
            
            for (Project_Task__c subtask : subtasks) {
                if (subtask.Status__c == 'In Progress') {
                    hasInProgressSubtask = true;
                    break;
                } else if (subtask.Status__c == 'Pending') {
                    hasPendingSubtask = true;
                }
            }
            
            // Update parent status based on subtask statuses
            if (hasInProgressSubtask && parentTask.Status__c != 'In Progress') {
                parentsToUpdate.add(new Project_Task__c(
                    Id = parentId,
                    Status__c = 'In Progress'
                ));
            } else if (hasPendingSubtask && !hasInProgressSubtask && parentTask.Status__c != 'Pending') {
                parentsToUpdate.add(new Project_Task__c(
                    Id = parentId,
                    Status__c = 'Pending'
                ));
            }
        }
        
        if (!parentsToUpdate.isEmpty()) {
            update parentsToUpdate;
        }
    }
    
    /**
     * @description Validates that a parent task cannot be closed if it has open subtasks
     * Open subtasks are those not in Closed, Removed, or Completed status
     * @param tasks List of Project_Task__c records being updated
     */
    public static void validateParentCanBeClosed(List<Project_Task__c> tasks) {
        Set<Id> parentTaskIds = new Set<Id>();
        
        // Collect parent task IDs that are being closed
        for (Project_Task__c task : tasks) {
            if (task.Parent_Task__c == null && task.Status__c == 'Closed') {
                parentTaskIds.add(task.Id);
            }
        }
        
        if (parentTaskIds.isEmpty()) {
            return;
        }
        
        // Query for open subtasks (not Closed, Removed, or Completed)
        List<Project_Task__c> openSubtasks = [
            SELECT Id, Parent_Task__c
            FROM Project_Task__c
            WHERE Parent_Task__c IN :parentTaskIds
            AND Status__c != 'Closed'
            AND Status__c != 'Removed'
            AND Status__c != 'Completed'
            LIMIT 1
        ];
        
        // Create map of parent IDs that have open subtasks
        Set<Id> parentsWithOpenSubtasks = new Set<Id>();
        for (Project_Task__c subtask : openSubtasks) {
            parentsWithOpenSubtasks.add(subtask.Parent_Task__c);
        }
        
        // Add error to parent tasks that have open subtasks
        for (Project_Task__c task : tasks) {
            if (task.Parent_Task__c == null && 
                task.Status__c == 'Closed' && 
                parentsWithOpenSubtasks.contains(task.Id)) {
                task.addError('Can\'t close this task as there are subtasks that are still open.');
            }
        }
    }
}

