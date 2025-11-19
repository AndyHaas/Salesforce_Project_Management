/**
 * @description Trigger handler for Project_Task__c object
 * 
 * This trigger manages all automated business logic for Project Tasks including:
 * - Subtask user population and parent-child relationship management
 * - Parent task status updates based on subtask changes
 * - Progress calculation for parent tasks
 * - Dependency risk assessment and blocking status
 * - Validation rules to prevent invalid state changes
 * 
 * TRIGGER CONTEXTS:
 * - before insert: Populates subtask fields from parent before save
 * - before update: Validates parent tasks cannot be closed with open subtasks
 * - after insert: Calculates progress and assesses dependency risk
 * - after update: Updates parent status, recalculates progress, and reassesses dependencies
 * - after delete: Recalculates parent progress when subtasks are deleted
 * 
 * EXECUTION ORDER:
 * 
 * BEFORE INSERT:
 * 1. TaskSubtaskHelper.populateSubtaskUsers()
 *    - When creating a subtask (Parent_Task__c is populated)
 *    - Automatically copies OwnerId and Client_User__c from parent task
 *    - Only populates if fields are null (preserves manual assignments)
 * 
 * BEFORE UPDATE:
 * 1. TaskSubtaskHelper.validateParentCanBeClosed()
 *    - Prevents closing a parent task if it has open subtasks
 *    - Open subtasks = Status not in (Closed, Removed, Completed)
 *    - Throws validation error: "Can't close this task as there are subtasks that are still open."
 * 
 * AFTER INSERT:
 * 1. TaskProgressCalculator.calculateProgress()
 *    - Recalculates parent task progress when new subtasks are created
 *    - Updates Progress_Percentage__c, Total_Estimated_Hours__c, Total_Actual_Hours__c
 *    - Based on subtask completion status and hours
 * 
 * 2. TaskDependencyHelper.assessDependencyRisk()
 *    - Evaluates blocking dependencies for newly created tasks
 *    - Updates At_Risk_Due_to_Dependencies__c field
 *    - Updates Is_Blocking__c field for tasks that block others
 * 
 * AFTER UPDATE:
 * 1. TaskProgressCalculator.calculateProgress()
 *    - Recalculates parent task progress when subtasks are updated
 *    - Updates progress percentage and hour totals
 * 
 * 2. TaskDependencyHelper.assessDependencyRisk()
 *    - Reassesses dependency risk when task status changes
 *    - Updates dependent tasks' At_Risk_Due_to_Dependencies__c field
 *    - Updates Is_Blocking__c for tasks that have blocking dependencies
 * 
 * 3. TaskSubtaskHelper.updateParentTaskStatus()
 *    - Updates parent task status based on subtask status changes
 *    - If any subtask moves Backlog → Pending: Parent becomes Pending (if parent is Backlog/Pending)
 *    - If any subtask moves Pending → In Progress: Parent becomes In Progress (if parent is Backlog/Pending)
 *    - Only updates if parent is in Backlog or Pending status
 *    - In Progress takes priority over Pending
 * 
 * AFTER DELETE:
 * 1. TaskProgressCalculator.calculateProgress()
 *    - Recalculates parent task progress when subtasks are deleted
 *    - Updates progress percentage and hour totals based on remaining subtasks
 * 
 * DEPENDENCIES:
 * - TaskSubtaskHelper: Handles subtask-specific logic
 * - TaskProgressCalculator: Handles progress calculation
 * - TaskDependencyHelper: Handles dependency risk assessment
 * 
 * NOTE: All helper classes use "with sharing" to respect sharing rules.
 * 
 * @author Milestone Consulting
 * @date Created: November 19, 2025
 */
trigger ProjectTaskTrigger on Project_Task__c (before insert, before update, after insert, after update, after delete) {
    
    // ============================================
    // BEFORE TRIGGER CONTEXTS
    // ============================================
    // Execute before records are saved to database
    // Use for field population and validation
    
    if (Trigger.isBefore) {
        
        // BEFORE INSERT: Populate subtask fields from parent
        if (Trigger.isInsert) {
            // Populates OwnerId and Client_User__c from parent task when creating subtasks
            // Only runs if Parent_Task__c is populated
            TaskSubtaskHelper.populateSubtaskUsers(Trigger.new);
        }
        
        // BEFORE UPDATE: Validate parent cannot be closed with open subtasks
        if (Trigger.isUpdate) {
            // Prevents closing parent tasks that have open subtasks
            // Throws validation error if validation fails
            TaskSubtaskHelper.validateParentCanBeClosed(Trigger.new);
        }
    }
    
    // ============================================
    // AFTER TRIGGER CONTEXTS
    // ============================================
    // Execute after records are saved to database
    // Use for calculations, updates to related records, and cascading changes
    
    if (Trigger.isAfter) {
        
        // AFTER INSERT/UPDATE: Calculate progress and assess dependencies
        if (Trigger.isInsert || Trigger.isUpdate) {
            // Recalculate parent task progress based on subtask completion
            // Updates Progress_Percentage__c, Total_Estimated_Hours__c, Total_Actual_Hours__c
            TaskProgressCalculator.calculateProgress(Trigger.new);
            
            // Assess dependency risk and update At_Risk_Due_to_Dependencies__c
            // Updates Is_Blocking__c for tasks that block others
            if (Trigger.isUpdate) {
                TaskDependencyHelper.assessDependencyRisk(Trigger.new, Trigger.oldMap);
            } else {
                TaskDependencyHelper.assessDependencyRisk(Trigger.new);
            }
        }
        
        // AFTER UPDATE: Update parent task status based on subtask changes
        if (Trigger.isUpdate) {
            // Updates parent task status when subtask status changes
            // Only updates if parent is in Backlog or Pending status
            // Requires Trigger.oldMap to detect status changes
            TaskSubtaskHelper.updateParentTaskStatus(Trigger.new, Trigger.oldMap);
        }
        
        // AFTER DELETE: Recalculate parent progress when subtasks are deleted
        if (Trigger.isDelete) {
            // Recalculate parent task progress after subtask deletion
            // Updates progress percentage and hour totals based on remaining subtasks
            TaskProgressCalculator.calculateProgress(Trigger.old);
        }
    }
}

