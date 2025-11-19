/**
 * @description Helper class for assessing task dependency risk and blocking status
 * 
 * Evaluates blocking dependencies and updates At_Risk_Due_to_Dependencies__c
 * and Is_Blocking__c fields on Project_Task__c records.
 * 
 * USAGE:
 * - Used in: ProjectTaskTrigger (after insert, after update)
 * - Called by: TaskDependencyHelper.assessDependencyRisk()
 */
public with sharing class TaskDependencyHelper {
    public static void assessDependencyRisk(List<Project_Task__c> tasks) {
        assessDependencyRisk(tasks, null);
    }
    
    public static void assessDependencyRisk(List<Project_Task__c> tasks, Map<Id, Project_Task__c> oldMap) {
        // Build map of tasks being updated for quick lookup
        Map<Id, Project_Task__c> tasksMap = new Map<Id, Project_Task__c>();
        for (Project_Task__c task : tasks) {
            tasksMap.put(task.Id, task);
        }
        Set<Id> taskIds = new Set<Id>();
        Set<Id> relatedTaskIds = new Set<Id>();
        
        // Collect task IDs
        for (Project_Task__c task : tasks) {
            taskIds.add(task.Id);
        }
        
        // Get all blocking relationships where these tasks are Task A (so Task B is the dependency)
        List<Project_Task_Relationship__c> blockingRelationships = [
            SELECT Task_A__c, Task_B__c, Relationship_Type__c
            FROM Project_Task_Relationship__c
            WHERE Task_A__c IN :taskIds
            AND Relationship_Type__c = 'Blocking Dependency'
        ];
        
        for (Project_Task_Relationship__c rel : blockingRelationships) {
            relatedTaskIds.add(rel.Task_B__c);
        }
        
        // Also check for tasks that depend on the tasks being updated
        // (reverse dependencies - if Task A depends on Task B, and Task B's status changes, Task A needs updating)
        // In junction object: Task A depends on Task B, so if Task B changes, we need to update Task A
        List<Project_Task_Relationship__c> dependentRelationships = [
            SELECT Task_A__c, Task_B__c, Relationship_Type__c
            FROM Project_Task_Relationship__c
            WHERE Task_B__c IN :taskIds
            AND Relationship_Type__c = 'Blocking Dependency'
        ];
        
        if (relatedTaskIds.isEmpty() && dependentRelationships.isEmpty()) {
            return;
        }
        
        // Query related tasks to check their status
        // For dependent tasks, Task_B__c is one of the tasks being updated (in taskIds)
        // So we need to query both relatedTaskIds and taskIds to get all statuses
        Set<Id> allStatusCheckIds = new Set<Id>(relatedTaskIds);
        allStatusCheckIds.addAll(taskIds);
        Map<Id, Project_Task__c> relatedTasksMap = new Map<Id, Project_Task__c>([
            SELECT Id, Status__c, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id IN :allStatusCheckIds
        ]);
        
        // Override with updated status from Trigger.new for tasks being updated in this transaction
        // This ensures we use the NEW status, not the OLD status from the database query
        for (Id taskId : taskIds) {
            if (tasksMap.containsKey(taskId) && relatedTasksMap.containsKey(taskId)) {
                // Update the status in the map to use the NEW status from Trigger.new
                relatedTasksMap.get(taskId).Status__c = tasksMap.get(taskId).Status__c;
            }
        }
        
        // Also get all tasks that have blocking dependencies on the tasks being updated or related tasks
        // These are the tasks that might need their Is_Blocking__c field updated
        Set<Id> tasksThatMightBeBlocking = new Set<Id>(taskIds);
        tasksThatMightBeBlocking.addAll(relatedTaskIds); // Also check related tasks
        Map<Id, List<Project_Task_Relationship__c>> blockingDependenciesMap = new Map<Id, List<Project_Task_Relationship__c>>();
        List<Project_Task_Relationship__c> relationshipsWithBlockingDeps = [
            SELECT Task_A__c, Task_B__c, Relationship_Type__c
            FROM Project_Task_Relationship__c
            WHERE Task_B__c IN :tasksThatMightBeBlocking
            AND Relationship_Type__c = 'Blocking Dependency'
        ];
        for (Project_Task_Relationship__c rel : relationshipsWithBlockingDeps) {
            if (!blockingDependenciesMap.containsKey(rel.Task_B__c)) {
                blockingDependenciesMap.put(rel.Task_B__c, new List<Project_Task_Relationship__c>());
            }
            blockingDependenciesMap.get(rel.Task_B__c).add(rel);
        }
        
        List<Project_Task__c> tasksToUpdate = new List<Project_Task__c>();
        
        // Process tasks from Trigger.new - check if they have blocking dependencies
        // Always recalculate risk for any task that is updated
        for (Project_Task__c task : tasks) {
            // Get current database value for comparison (may be different from Trigger.new)
            Project_Task__c currentTask = relatedTasksMap.get(task.Id);
            Boolean currentAtRiskValue = currentTask != null ? currentTask.At_Risk_Due_to_Dependencies__c : false;
            
            // Find relationships where this task is Task A (depends on Task B)
            Boolean hasBlockingDep = false;
            Boolean isAtRisk = false;
            
            for (Project_Task_Relationship__c rel : blockingRelationships) {
                if (rel.Task_A__c == task.Id) {
                    hasBlockingDep = true;
                    Project_Task__c relatedTask = relatedTasksMap.get(rel.Task_B__c);
                    if (relatedTask != null) {
                        // Task is at risk if the blocking dependency is not completed/closed/in review/removed
                        // In Review means work is done, just waiting for approval, so it's not blocking
                        // Removed tasks are no longer active, so they don't block
                        // Statuses that ARE blocking: Backlog, Pending, In Progress, Blocked
                        // Check ALL blocking dependencies - task is at risk if ANY are blocking
                        Boolean thisDependencyIsBlocking = relatedTask.Status__c != 'Completed' 
                            && relatedTask.Status__c != 'Closed' 
                            && relatedTask.Status__c != 'In Review'
                            && relatedTask.Status__c != 'Removed';
                        // If this dependency is blocking, task is at risk (don't need to check others)
                        if (thisDependencyIsBlocking) {
                            isAtRisk = true;
                            break; // Found a blocking dependency, no need to check others
                        }
                        // If this dependency is not blocking, continue checking other dependencies
                    }
                }
            }
            
            // Always update if the calculated value differs from current value
            // This ensures any update triggers a re-assessment
            if (hasBlockingDep) {
                if (currentAtRiskValue != isAtRisk) {
                    tasksToUpdate.add(new Project_Task__c(
                        Id = task.Id,
                        At_Risk_Due_to_Dependencies__c = isAtRisk
                    ));
                }
            } else if (currentAtRiskValue == true) {
                // Task has no blocking dependencies but is marked as at risk, clear it
                tasksToUpdate.add(new Project_Task__c(
                    Id = task.Id,
                    At_Risk_Due_to_Dependencies__c = false
                ));
            }
        }
        
        // Process dependent tasks (tasks that depend on the tasks being updated)
        // When Task B's status changes, we need to update Task A if Task A depends on Task B
        for (Project_Task_Relationship__c rel : dependentRelationships) {
            Project_Task__c relatedTask = relatedTasksMap.get(rel.Task_B__c);
            if (relatedTask != null) {
                // Get the dependent task (Task A)
                Project_Task__c dependentTask = relatedTasksMap.get(rel.Task_A__c);
                if (dependentTask == null) {
                    // Need to query it
                    dependentTask = [SELECT Id, At_Risk_Due_to_Dependencies__c FROM Project_Task__c WHERE Id = :rel.Task_A__c];
                }
                
                // Task is at risk if the blocking dependency is not completed/closed/in review/removed
                Boolean isAtRisk = relatedTask.Status__c != 'Completed' 
                    && relatedTask.Status__c != 'Closed' 
                    && relatedTask.Status__c != 'In Review'
                    && relatedTask.Status__c != 'Removed';
                
                // Always check and update if needed - don't skip based on status change
                // The field value might be out of sync, so we always recalculate
                if (dependentTask.At_Risk_Due_to_Dependencies__c != isAtRisk) {
                    tasksToUpdate.add(new Project_Task__c(
                        Id = dependentTask.Id,
                        At_Risk_Due_to_Dependencies__c = isAtRisk
                    ));
                }
            }
        }
        
        // Update Is_Blocking__c for tasks that have blocking dependencies on them
        // A task is blocking if it has blocking dependencies AND its status is not Completed/Closed/In Review
        // Query tasks that might need Is_Blocking__c updated
        if (!tasksThatMightBeBlocking.isEmpty()) {
            Map<Id, Project_Task__c> tasksToCheckBlocking = new Map<Id, Project_Task__c>([
                SELECT Id, Status__c, Is_Blocking__c
                FROM Project_Task__c
                WHERE Id IN :tasksThatMightBeBlocking
            ]);
            
            for (Id taskId : tasksThatMightBeBlocking) {
                Project_Task__c task = tasksToCheckBlocking.get(taskId);
                if (task != null && blockingDependenciesMap.containsKey(taskId)) {
                    // This task has blocking dependencies on it
                    // It's blocking if status is not Completed, Closed, In Review, or Removed
                    Boolean shouldBeBlocking = task.Status__c != 'Completed' 
                        && task.Status__c != 'Closed' 
                        && task.Status__c != 'In Review'
                        && task.Status__c != 'Removed';
                    
                    if (task.Is_Blocking__c != shouldBeBlocking) {
                        tasksToUpdate.add(new Project_Task__c(
                            Id = task.Id,
                            Is_Blocking__c = shouldBeBlocking
                        ));
                    }
                } else if (task != null && task.Is_Blocking__c == true) {
                    // No blocking dependencies on this task, so it shouldn't be blocking
                    tasksToUpdate.add(new Project_Task__c(
                        Id = task.Id,
                        Is_Blocking__c = false
                    ));
                }
            }
        }
        
        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }
    }
}

