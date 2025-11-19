/**
 * @description Apex controller for Task Context Panel component
 * 
 * Provides @AuraEnabled methods for retrieving task relationships, dependencies,
 * and managing task relationships (create, update, delete).
 * 
 * USAGE:
 * - Used by LWC components:
 *   - taskContextPanel: getDependencyData()
 *   - linkTaskModal: createTaskRelationship(), updateTaskRelationship(), getRelationshipDetails()
 *   - taskContextPanel: deleteTaskRelationship()
 */
public with sharing class TaskContextController {
    
    private static final String TASK_HOVER_FIELD_SET = 'Task_Hover_Fields';
    
    /**
     * @description Get dependency data for a task including parent, dependencies, dependents, and subtasks
     * @param taskId The ID of the Project Task
     * @return DependencyDataResult with all relationship data
     */
    @AuraEnabled(cacheable=true)
    public static DependencyDataResult getDependencyData(String taskId) {
        if (taskId == null || taskId == '') {
            return null;
        }
        
        Project_Task__c currentTask = [
            SELECT Id, Parent_Task__c, Parent_Task__r.Name, Parent_Task__r.Status__c, Parent_Task__r.Priority__c,
                   Parent_Task__r.Total_Estimated_Hours__c, Parent_Task__r.Description__c,
                   At_Risk_Due_to_Dependencies__c, Is_Blocking__c,
                   (SELECT Id, Name, Status__c, Priority__c, Is_Blocking__c, At_Risk_Due_to_Dependencies__c,
                           Total_Estimated_Hours__c, Description__c
                    FROM Subtasks__r
                    ORDER BY CreatedDate ASC)
            FROM Project_Task__c
            WHERE Id = :taskId
            LIMIT 1
        ];
        
        // Get hover field set for building hover cards
        Schema.FieldSet hoverFieldSet = Schema.SObjectType.Project_Task__c.fieldSets.getMap().get(TASK_HOVER_FIELD_SET);
        List<Schema.FieldSetMember> hoverFieldMembers = hoverFieldSet != null ? hoverFieldSet.getFields() : new List<Schema.FieldSetMember>();
        Map<String, Schema.SObjectField> describeFieldMap = Schema.SObjectType.Project_Task__c.fields.getMap();
        
        // Get relationships where this task is Task A (so Task_B is the related/dependency task)
        List<Project_Task_Relationship__c> relatedRelationships = [
            SELECT Id, Task_B__c, Task_B__r.Name, Task_B__r.Status__c, Task_B__r.Priority__c, Task_B__r.Is_Blocking__c,
                   Task_B__r.At_Risk_Due_to_Dependencies__c, Task_B__r.Total_Estimated_Hours__c, Task_B__r.Description__c,
                   Relationship_Type__c
            FROM Project_Task_Relationship__c
            WHERE Task_A__c = :taskId
            ORDER BY CreatedDate DESC
        ];
        
        // Get relationships where this task is Task B (so Task A is the dependent task)
        List<Project_Task_Relationship__c> dependentRelationships = [
            SELECT Id, Task_A__c, Task_A__r.Name, Task_A__r.Status__c, Task_A__r.Priority__c, Task_A__r.Is_Blocking__c,
                   Task_A__r.At_Risk_Due_to_Dependencies__c, Task_A__r.Total_Estimated_Hours__c, Task_A__r.Description__c,
                   Relationship_Type__c
            FROM Project_Task_Relationship__c
            WHERE Task_B__c = :taskId
            ORDER BY CreatedDate DESC
        ];
        
        DependencyDataResult result = new DependencyDataResult();
        result.isBlocking = currentTask.Is_Blocking__c != null && currentTask.Is_Blocking__c == true;
        
        // Parent Task
        if (currentTask.Parent_Task__c != null) {
            result.parentTask = new DependencyTask();
            result.parentTask.id = currentTask.Parent_Task__c;
            result.parentTask.name = currentTask.Parent_Task__r.Name;
            result.parentTask.status = currentTask.Parent_Task__r.Status__c;
            result.parentTask.priority = currentTask.Parent_Task__r.Priority__c;
            result.parentTask.type = 'Parent Task';
            result.parentTask.isBlocking = false;
            // Build hover fields for parent task
            Project_Task__c parentTaskRecord = new Project_Task__c(
                Id = currentTask.Parent_Task__c,
                Status__c = currentTask.Parent_Task__r.Status__c,
                Priority__c = currentTask.Parent_Task__r.Priority__c,
                Total_Estimated_Hours__c = currentTask.Parent_Task__r.Total_Estimated_Hours__c,
                Description__c = currentTask.Parent_Task__r.Description__c
            );
            result.parentTask.hoverFields = ProjectTaskDashboardController.buildHoverFieldValues(parentTaskRecord, hoverFieldMembers, describeFieldMap);
        }
        
        // Dependencies (tasks this task depends on) - Get all relationships where this task is Task A
        // In the junction object, Task A depends on Task B
        result.dependencies = new List<DependencyTask>();
        for (Project_Task_Relationship__c rel : relatedRelationships) {
            DependencyTask dep = new DependencyTask();
            dep.id = rel.Task_B__c;
            dep.name = rel.Task_B__r.Name;
            dep.status = rel.Task_B__r.Status__c;
            dep.priority = rel.Task_B__r.Priority__c;
            dep.type = String.isBlank(rel.Relationship_Type__c) ? 'Related' : rel.Relationship_Type__c;
            // A task is blocking if Relationship Type is "Blocking Dependency" AND the related task is actually blocking
            dep.isBlocking = rel.Relationship_Type__c == 'Blocking Dependency' 
                && rel.Task_B__r.Is_Blocking__c == true;
            dep.isAtRisk = rel.Task_B__r.At_Risk_Due_to_Dependencies__c != null && rel.Task_B__r.At_Risk_Due_to_Dependencies__c == true;
            dep.relationshipId = rel.Id; // Include relationship ID for deletion
            // Build hover fields for dependency task
            Project_Task__c depTaskRecord = new Project_Task__c(
                Id = rel.Task_B__c,
                Status__c = rel.Task_B__r.Status__c,
                Priority__c = rel.Task_B__r.Priority__c,
                Total_Estimated_Hours__c = rel.Task_B__r.Total_Estimated_Hours__c,
                Description__c = rel.Task_B__r.Description__c
            );
            dep.hoverFields = ProjectTaskDashboardController.buildHoverFieldValues(depTaskRecord, hoverFieldMembers, describeFieldMap);
            result.dependencies.add(dep);
        }
        
        // Set isAtRisk if there are any dependencies and the task is at risk
        if (!result.dependencies.isEmpty()) {
            result.isAtRisk = currentTask.At_Risk_Due_to_Dependencies__c != null && currentTask.At_Risk_Due_to_Dependencies__c == true;
        }
        
        // Tasks that depend on this task (where this task is Task B, so Task A depends on this task)
        result.dependentTasks = new List<DependencyTask>();
        for (Project_Task_Relationship__c rel : dependentRelationships) {
            DependencyTask dt = new DependencyTask();
            dt.id = rel.Task_A__c;
            dt.name = rel.Task_A__r.Name;
            dt.status = rel.Task_A__r.Status__c;
            dt.priority = rel.Task_A__r.Priority__c;
            dt.type = String.isBlank(rel.Relationship_Type__c) ? 'Related' : rel.Relationship_Type__c;
            // A task is blocking if Relationship Type is "Blocking Dependency" AND the task is actually blocking
            dt.isBlocking = rel.Relationship_Type__c == 'Blocking Dependency' 
                && rel.Task_A__r.Is_Blocking__c == true;
            dt.isAtRisk = rel.Task_A__r.At_Risk_Due_to_Dependencies__c != null && rel.Task_A__r.At_Risk_Due_to_Dependencies__c == true;
            dt.relationshipId = rel.Id; // Include relationship ID for deletion
            // Build hover fields for dependent task
            Project_Task__c dtTaskRecord = new Project_Task__c(
                Id = rel.Task_A__c,
                Status__c = rel.Task_A__r.Status__c,
                Priority__c = rel.Task_A__r.Priority__c,
                Total_Estimated_Hours__c = rel.Task_A__r.Total_Estimated_Hours__c,
                Description__c = rel.Task_A__r.Description__c
            );
            dt.hoverFields = ProjectTaskDashboardController.buildHoverFieldValues(dtTaskRecord, hoverFieldMembers, describeFieldMap);
            result.dependentTasks.add(dt);
        }
        
        // Sub tasks and progress calculation
        result.subtasks = new List<DependencyTask>();
        Integer totalSubtaskCount = 0;
        Integer completedSubtaskCount = 0;
        Integer removedSubtaskCount = 0;
        
        if (currentTask.Subtasks__r != null && !currentTask.Subtasks__r.isEmpty()) {
            totalSubtaskCount = currentTask.Subtasks__r.size();
            
            for (Project_Task__c subtask : currentTask.Subtasks__r) {
                DependencyTask st = new DependencyTask();
                st.id = subtask.Id;
                st.name = subtask.Name;
                st.status = subtask.Status__c;
                st.priority = subtask.Priority__c;
                st.type = 'Sub Task';
                st.isBlocking = subtask.Is_Blocking__c != null && subtask.Is_Blocking__c == true;
                st.isAtRisk = subtask.At_Risk_Due_to_Dependencies__c != null && subtask.At_Risk_Due_to_Dependencies__c == true;
                // Build hover fields for subtask
                st.hoverFields = ProjectTaskDashboardController.buildHoverFieldValues(subtask, hoverFieldMembers, describeFieldMap);
                result.subtasks.add(st);
                
                // Calculate progress
                if (subtask.Status__c == 'Completed' || subtask.Status__c == 'Closed') {
                    completedSubtaskCount++;
                } else if (subtask.Status__c == 'Removed') {
                    removedSubtaskCount++;
                }
            }
        }
        
        // Calculate subtask progress
        Integer validSubtaskTotal = totalSubtaskCount - removedSubtaskCount;
        Decimal progressPercentage = validSubtaskTotal > 0 
            ? (Decimal.valueOf(completedSubtaskCount) / Decimal.valueOf(validSubtaskTotal)) * 100 
            : 0;
        
        result.subtaskProgress = new SubtaskProgressInfo();
        result.subtaskProgress.progressPercentage = progressPercentage.setScale(2);
        result.subtaskProgress.completedCount = completedSubtaskCount;
        result.subtaskProgress.totalCount = validSubtaskTotal;
        result.subtaskProgress.hasSubtasks = totalSubtaskCount > 0;
        
        return result;
    }
    
    /**
     * @description Create a task relationship between two tasks
     * @param taskAId The ID of the primary Task (the task that depends on the Related Task)
     * @param taskBId The ID of the Related Task (the task that the primary Task depends on)
     * @param relationshipType The type of relationship (Related, Blocking Dependency, Epic/Feature Parent)
     * @return The created Project_Task_Relationship__c record ID
     */
    @AuraEnabled
    public static String createTaskRelationship(String taskAId, String taskBId, String relationshipType) {
        if (String.isBlank(taskAId) || String.isBlank(taskBId)) {
            throw new AuraHandledException('Both Task and Related Task are required');
        }
        
        if (taskAId == taskBId) {
            throw new AuraHandledException('A task cannot be related to itself');
        }
        
        // Check if relationship already exists in either direction
        // Check Task -> Related Task (or reverse)
        List<Project_Task_Relationship__c> existingRelationships = [
            SELECT Id
            FROM Project_Task_Relationship__c
            WHERE (Task_A__c = :taskAId AND Task_B__c = :taskBId)
               OR (Task_A__c = :taskBId AND Task_B__c = :taskAId)
            LIMIT 1
        ];
        
        if (!existingRelationships.isEmpty()) {
            throw new AuraHandledException('A relationship between these tasks already exists');
        }
        
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = taskAId,
            Task_B__c = taskBId,
            Relationship_Type__c = String.isNotBlank(relationshipType) ? relationshipType : 'Related'
        );
        
        try {
            insert relationship;
            return relationship.Id;
        } catch (DmlException e) {
            throw new AuraHandledException('Error creating relationship: ' + e.getMessage());
        }
    }
    
    /**
     * @description Search for tasks by name (for lookup functionality)
     * @param searchTerm The search term to match against task names
     * @param excludeTaskId Optional task ID to exclude from results (e.g., current task)
     * @return List of tasks matching the search term
     */
    @AuraEnabled(cacheable=true)
    public static List<TaskSearchResult> searchTasks(String searchTerm, String excludeTaskId) {
        List<TaskSearchResult> results = new List<TaskSearchResult>();
        
        if (String.isBlank(searchTerm)) {
            return results;
        }
        
        String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        String query = 'SELECT Id, Name FROM Project_Task__c WHERE Name LIKE :searchPattern';
        
        if (String.isNotBlank(excludeTaskId)) {
            query += ' AND Id != :excludeTaskId';
        }
        
        query += ' ORDER BY Name LIMIT 50';
        
        List<Project_Task__c> tasks = Database.query(query);
        
        for (Project_Task__c task : tasks) {
            TaskSearchResult result = new TaskSearchResult();
            result.id = task.Id;
            result.name = task.Name;
            results.add(result);
        }
        
        return results;
    }
    
    /**
     * @description Delete a task relationship
     * @param relationshipId The ID of the Project_Task_Relationship__c record to delete
     * @return Success message
     */
    @AuraEnabled
    public static String deleteTaskRelationship(String relationshipId) {
        if (String.isBlank(relationshipId)) {
            throw new AuraHandledException('Relationship ID is required');
        }
        
        try {
            Project_Task_Relationship__c relationship = [
                SELECT Id
                FROM Project_Task_Relationship__c
                WHERE Id = :relationshipId
                LIMIT 1
            ];
            
            delete relationship;
            return 'Relationship deleted successfully';
        } catch (QueryException e) {
            throw new AuraHandledException('Relationship not found: ' + e.getMessage());
        } catch (DmlException e) {
            throw new AuraHandledException('Error deleting relationship: ' + e.getMessage());
        }
    }
    
    /**
     * @description Update an existing task relationship
     * @param relationshipId The ID of the Project_Task_Relationship__c record to update
     * @param relationshipType The new relationship type
     * @return Success message
     */
    @AuraEnabled
    public static String updateTaskRelationship(String relationshipId, String relationshipType) {
        if (String.isBlank(relationshipId)) {
            throw new AuraHandledException('Relationship ID is required');
        }
        
        try {
            Project_Task_Relationship__c relationship = [
                SELECT Id, Relationship_Type__c
                FROM Project_Task_Relationship__c
                WHERE Id = :relationshipId
                LIMIT 1
            ];
            
            relationship.Relationship_Type__c = String.isNotBlank(relationshipType) ? relationshipType : 'Related';
            
            update relationship;
            return 'Relationship updated successfully';
        } catch (QueryException e) {
            throw new AuraHandledException('Relationship not found: ' + e.getMessage());
        } catch (DmlException e) {
            throw new AuraHandledException('Error updating relationship: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get relationship details for editing
     * @param relationshipId The ID of the Project_Task_Relationship__c record
     * @return Relationship details including Task_B__c and Relationship_Type__c
     */
    @AuraEnabled(cacheable=true)
    public static RelationshipDetails getRelationshipDetails(String relationshipId) {
        if (String.isBlank(relationshipId)) {
            throw new AuraHandledException('Relationship ID is required');
        }
        
        try {
            Project_Task_Relationship__c relationship = [
                SELECT Id, Task_B__c, Relationship_Type__c
                FROM Project_Task_Relationship__c
                WHERE Id = :relationshipId
                LIMIT 1
            ];
            
            RelationshipDetails details = new RelationshipDetails();
            details.taskBId = relationship.Task_B__c;
            details.relationshipType = String.isBlank(relationship.Relationship_Type__c) ? 'Related' : relationship.Relationship_Type__c;
            
            return details;
        } catch (QueryException e) {
            throw new AuraHandledException('Relationship not found: ' + e.getMessage());
        }
    }
    
    // ============================================================================
    // INNER CLASSES
    // ============================================================================
    
    public class DependencyDataResult {
        @AuraEnabled public DependencyTask parentTask;
        @AuraEnabled public DependencyTask relatedTask; // Kept for backward compatibility, but deprecated - use dependencies instead
        @AuraEnabled public List<DependencyTask> dependencies; // List of tasks this task depends on
        @AuraEnabled public List<DependencyTask> dependentTasks;
        @AuraEnabled public List<DependencyTask> subtasks;
        @AuraEnabled public Boolean isAtRisk;
        @AuraEnabled public Boolean isBlocking;
        @AuraEnabled public SubtaskProgressInfo subtaskProgress;
    }
    
    public class SubtaskProgressInfo {
        @AuraEnabled public Decimal progressPercentage;
        @AuraEnabled public Integer completedCount;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Boolean hasSubtasks;
    }
    
    public class DependencyTask {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean isBlocking;
        @AuraEnabled public Boolean isAtRisk;
        @AuraEnabled public String relationshipId; // ID of the Project_Task_Relationship__c record (null for parent/child relationships)
        @AuraEnabled public List<ProjectTaskDashboardController.HoverFieldValue> hoverFields;
    }
    
    public class TaskSearchResult {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
    }
    
    public class RelationshipDetails {
        @AuraEnabled public String taskBId;
        @AuraEnabled public String relationshipType;
    }
}

