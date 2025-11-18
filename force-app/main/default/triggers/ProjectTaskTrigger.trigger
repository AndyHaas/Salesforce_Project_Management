trigger ProjectTaskTrigger on Project_Task__c (after insert, after update, after delete) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            TaskProgressCalculator.calculateProgress(Trigger.new);
            TaskDependencyHelper.assessDependencyRisk(Trigger.new);
        }
        if (Trigger.isDelete) {
            TaskProgressCalculator.calculateProgress(Trigger.old);
        }
    }
}

