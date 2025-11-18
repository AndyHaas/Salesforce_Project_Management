public with sharing class TaskDependencyHelper {
    public static void assessDependencyRisk(List<Project_Task__c> tasks) {
        Set<Id> taskIds = new Set<Id>();
        Set<Id> relatedTaskIds = new Set<Id>();
        
        // Collect task IDs and related task IDs
        for (Project_Task__c task : tasks) {
            taskIds.add(task.Id);
            if (task.Related_Task__c != null && task.Relationship_Type__c == 'Blocking Dependency') {
                relatedTaskIds.add(task.Related_Task__c);
            }
        }
        
        // Also check for tasks that depend on the tasks being updated
        // (reverse dependencies - if Task B depends on Task A, and Task A's status changes, Task B needs updating)
        List<Project_Task__c> dependentTasks = [
            SELECT Id, Related_Task__c, Relationship_Type__c, At_Risk_Due_to_Dependencies__c
            FROM Project_Task__c
            WHERE Related_Task__c IN :taskIds
            AND Relationship_Type__c = 'Blocking Dependency'
        ];
        
        if (relatedTaskIds.isEmpty() && dependentTasks.isEmpty()) {
            return;
        }
        
        // Query related tasks to check their status
        // For dependent tasks, the Related_Task__c is one of the tasks being updated (in taskIds)
        // So we need to query both relatedTaskIds and taskIds to get all statuses
        Set<Id> allStatusCheckIds = new Set<Id>(relatedTaskIds);
        allStatusCheckIds.addAll(taskIds);
        Map<Id, Project_Task__c> relatedTasksMap = new Map<Id, Project_Task__c>([
            SELECT Id, Status__c FROM Project_Task__c WHERE Id IN :allStatusCheckIds
        ]);
        
        // Also get all tasks that have blocking dependencies on the tasks being updated or related tasks
        // These are the tasks that might need their Is_Blocking__c field updated
        Set<Id> tasksThatMightBeBlocking = new Set<Id>(taskIds);
        tasksThatMightBeBlocking.addAll(relatedTaskIds); // Also check related tasks
        Map<Id, List<Project_Task__c>> blockingDependenciesMap = new Map<Id, List<Project_Task__c>>();
        List<Project_Task__c> tasksWithBlockingDeps = [
            SELECT Id, Related_Task__c, Relationship_Type__c
            FROM Project_Task__c
            WHERE Related_Task__c IN :tasksThatMightBeBlocking
            AND Relationship_Type__c = 'Blocking Dependency'
        ];
        for (Project_Task__c depTask : tasksWithBlockingDeps) {
            if (!blockingDependenciesMap.containsKey(depTask.Related_Task__c)) {
                blockingDependenciesMap.put(depTask.Related_Task__c, new List<Project_Task__c>());
            }
            blockingDependenciesMap.get(depTask.Related_Task__c).add(depTask);
        }
        
        List<Project_Task__c> tasksToUpdate = new List<Project_Task__c>();
        
        // Process tasks from Trigger.new
        for (Project_Task__c task : tasks) {
            if (task.Related_Task__c != null && task.Relationship_Type__c == 'Blocking Dependency') {
                Project_Task__c relatedTask = relatedTasksMap.get(task.Related_Task__c);
                if (relatedTask != null) {
                    // Task is at risk if the blocking dependency is not completed/closed/in review/removed
                    // In Review means work is done, just waiting for approval, so it's not blocking
                    // Removed tasks are no longer active, so they don't block
                    Boolean isAtRisk = relatedTask.Status__c != 'Completed' 
                        && relatedTask.Status__c != 'Closed' 
                        && relatedTask.Status__c != 'In Review'
                        && relatedTask.Status__c != 'Removed';
                    if (task.At_Risk_Due_to_Dependencies__c != isAtRisk) {
                        // Create new instance instead of modifying Trigger.new record
                        tasksToUpdate.add(new Project_Task__c(
                            Id = task.Id,
                            At_Risk_Due_to_Dependencies__c = isAtRisk
                        ));
                    }
                }
            } else if (task.At_Risk_Due_to_Dependencies__c == true) {
                // Create new instance instead of modifying Trigger.new record
                tasksToUpdate.add(new Project_Task__c(
                    Id = task.Id,
                    At_Risk_Due_to_Dependencies__c = false
                ));
            }
        }
        
        // Process dependent tasks (tasks that depend on the tasks being updated)
        // When Task A's status changes, we need to update Task B if Task B depends on Task A
        for (Project_Task__c depTask : dependentTasks) {
            Project_Task__c relatedTask = relatedTasksMap.get(depTask.Related_Task__c);
            if (relatedTask != null) {
                // Task is at risk if the blocking dependency is not completed/closed/in review/removed
                // In Review means work is done, just waiting for approval, so it's not blocking
                // Removed tasks are no longer active, so they don't block
                Boolean isAtRisk = relatedTask.Status__c != 'Completed' 
                    && relatedTask.Status__c != 'Closed' 
                    && relatedTask.Status__c != 'In Review'
                    && relatedTask.Status__c != 'Removed';
                if (depTask.At_Risk_Due_to_Dependencies__c != isAtRisk) {
                    tasksToUpdate.add(new Project_Task__c(
                        Id = depTask.Id,
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

