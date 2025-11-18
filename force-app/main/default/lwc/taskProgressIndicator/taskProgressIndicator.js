import { LightningElement, api, wire } from 'lwc';
import getSubtaskProgress from '@salesforce/apex/ProjectTaskDashboardController.getSubtaskProgress';
import { getRecord } from 'lightning/uiRecordApi';
import PROJECT_TASK_OBJECT from '@salesforce/schema/Project_Task__c';
import PROGRESS_PERCENTAGE_FIELD from '@salesforce/schema/Project_Task__c.Progress_Percentage__c';

export default class TaskProgressIndicator extends LightningElement {
    @api recordId;
    
    progressData = null;
    progressPercentage = 0;
    completedCount = 0;
    totalCount = 0;
    hasSubtasks = false;
    
    // Try to get subtask progress first (for parent tasks)
    @wire(getSubtaskProgress, { taskId: '$recordId' })
    wiredSubtaskProgress({ error, data }) {
        if (data) {
            this.progressData = data;
            this.progressPercentage = data.progressPercentage || 0;
            this.completedCount = data.completedCount || 0;
            this.totalCount = data.totalCount || 0;
            this.hasSubtasks = data.hasSubtasks || false;
        } else if (error) {
            console.error('Error loading subtask progress:', error);
            this.hasSubtasks = false;
        } else {
            // No data means no subtasks
            this.hasSubtasks = false;
        }
    }
    
    // Fallback: Get progress percentage from the record itself
    @wire(getRecord, { 
        recordId: '$recordId', 
        fields: [PROGRESS_PERCENTAGE_FIELD] 
    })
    wiredRecord({ error, data }) {
        if (data && !this.hasSubtasks) {
            // If no subtasks, use the record's progress percentage
            this.progressPercentage = data.fields.Progress_Percentage__c?.value || 0;
        } else if (error) {
            console.error('Error loading record:', error);
        }
    }

    get progressStyle() {
        return `width: ${this.progressPercentage || 0}%`;
    }

    get displayText() {
        if (this.hasSubtasks && this.totalCount > 0) {
            return `${this.completedCount} of ${this.totalCount} subtasks completed`;
        }
        return `${Math.round(this.progressPercentage)}%`;
    }
    
    get shouldShow() {
        // Show if task has subtasks (parent task with subtasks)
        return this.hasSubtasks;
    }
    
    get progressTitle() {
        return this.hasSubtasks ? 'Subtask Progress' : 'Progress';
    }
}

