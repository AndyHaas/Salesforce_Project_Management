public with sharing class TaskProgressCalculator {
    public static void calculateProgress(List<Project_Task__c> tasks) {
        Set<Id> parentTaskIds = new Set<Id>();
        
        for (Project_Task__c task : tasks) {
            if (task.Parent_Task__c != null) {
                parentTaskIds.add(task.Parent_Task__c);
            }
        }
        
        if (parentTaskIds.isEmpty()) {
            return;
        }
        
        Map<Id, Project_Task__c> parentTasksMap = new Map<Id, Project_Task__c>([
            SELECT Id, Account__c, Priority__c FROM Project_Task__c WHERE Id IN :parentTaskIds
        ]);
        
        List<Project_Task__c> subtasks = [
            SELECT Id, Parent_Task__c, Status__c, Estimated_Hours__c, Actual_Hours__c
            FROM Project_Task__c
            WHERE Parent_Task__c IN :parentTaskIds
        ];
        
        Map<Id, List<Project_Task__c>> subtasksByParent = new Map<Id, List<Project_Task__c>>();
        for (Project_Task__c subtask : subtasks) {
            if (!subtasksByParent.containsKey(subtask.Parent_Task__c)) {
                subtasksByParent.put(subtask.Parent_Task__c, new List<Project_Task__c>());
            }
            subtasksByParent.get(subtask.Parent_Task__c).add(subtask);
        }
        
        List<Project_Task__c> tasksToUpdate = new List<Project_Task__c>();
        
        for (Id parentId : parentTaskIds) {
            List<Project_Task__c> parentSubtasks = subtasksByParent.get(parentId);
            if (parentSubtasks == null || parentSubtasks.isEmpty()) {
                continue;
            }
            
            Project_Task__c parentTask = parentTasksMap.get(parentId);
            if (parentTask == null) {
                continue;
            }
            
            // Skip updating if required fields are missing
            if (parentTask.Account__c == null || parentTask.Priority__c == null) {
                continue;
            }
            
            Integer totalCount = parentSubtasks.size();
            Integer completedCount = 0;
            Integer removedCount = 0;
            Decimal totalEstimatedHours = 0;
            Decimal totalActualHours = 0;
            
            for (Project_Task__c subtask : parentSubtasks) {
                if (subtask.Status__c == 'Completed' || subtask.Status__c == 'Closed') {
                    completedCount++;
                } else if (subtask.Status__c == 'Removed') {
                    removedCount++;
                }
                
                // Sum hours (including removed tasks for accurate totals)
                if (subtask.Estimated_Hours__c != null) {
                    totalEstimatedHours += subtask.Estimated_Hours__c;
                }
                if (subtask.Actual_Hours__c != null) {
                    totalActualHours += subtask.Actual_Hours__c;
                }
            }
            
            Integer validTotal = totalCount - removedCount;
            Decimal progressPercentage = validTotal > 0 
                ? (Decimal.valueOf(completedCount) / Decimal.valueOf(validTotal)) * 100 
                : 0;
            
            parentTask.Progress_Percentage__c = progressPercentage.setScale(2);
            parentTask.Total_Estimated_Hours__c = totalEstimatedHours.setScale(2);
            parentTask.Total_Actual_Hours__c = totalActualHours.setScale(2);
            tasksToUpdate.add(parentTask);
        }
        
        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }
    }
}

