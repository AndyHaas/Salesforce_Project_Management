/**
 * @description Modal component for linking tasks together
 * Creates a Project_Task_Relationship__c record between two tasks
 */
import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createTaskRelationship from '@salesforce/apex/ProjectTaskDashboardController.createTaskRelationship';
import TASK_B_FIELD from '@salesforce/schema/Project_Task_Relationship__c.Task_B__c';
import RELATIONSHIP_TYPE_FIELD from '@salesforce/schema/Project_Task_Relationship__c.Relationship_Type__c';

export default class LinkTaskModal extends LightningElement {
    @api recordId; // Primary Task ID (the current task)
    
    _isOpen = false;
    _isLoading = false;
    
    // Form fields
    taskBId = null; // Related Task ID
    relationshipType = 'Related';
    
    // Field references for lightning-record-edit-form
    taskBField = TASK_B_FIELD;
    relationshipTypeField = RELATIONSHIP_TYPE_FIELD;
    
    // Relationship type options
    get relationshipTypeOptions() {
        return [
            { label: 'Related', value: 'Related' },
            { label: 'Blocking Dependency', value: 'Blocking Dependency' },
            { label: 'Epic/Feature Parent', value: 'Epic/Feature Parent' }
        ];
    }
    
    /**
     * @description Open the modal
     */
    @api
    open() {
        this._isOpen = true;
        // Reset form
        this.taskBId = null;
        this.relationshipType = 'Related';
    }
    
    /**
     * @description Close the modal
     */
    close() {
        this._isOpen = false;
        this.taskBId = null;
        this.relationshipType = 'Related';
    }
    
    /**
     * @description Getter for modal open state
     */
    get isOpen() {
        return this._isOpen;
    }
    
    /**
     * @description Handle cancel button click
     */
    handleCancel() {
        this.close();
    }
    
    /**
     * @description Handle Related Task selection change
     */
    handleTaskBChange(event) {
        this.taskBId = event.detail.value;
    }
    
    /**
     * @description Handle relationship type change
     */
    handleRelationshipTypeChange(event) {
        this.relationshipType = event.detail.value;
    }
    
    /**
     * @description Handle form submit (prevent default form submission)
     */
    handleFormSubmit(event) {
        event.preventDefault();
        this.handleSubmit();
    }
    
    /**
     * @description Handle form submit
     */
    async handleSubmit() {
        if (!this.taskBId) {
            this.showError('Please select a related task to link');
            return;
        }
        
        if (this.taskBId === this.recordId) {
            this.showError('A task cannot be linked to itself');
            return;
        }
        
        this._isLoading = true;
        
        try {
            const relationshipId = await createTaskRelationship({
                taskAId: this.recordId,
                taskBId: this.taskBId,
                relationshipType: this.relationshipType
            });
            
            this.showSuccess('Task relationship created successfully');
            
            // Dispatch event to notify parent component to refresh
            this.dispatchEvent(new CustomEvent('relationshipcreated', {
                detail: { relationshipId }
            }));
            
            // Close modal after a short delay
            setTimeout(() => {
                this.close();
            }, 500);
            
        } catch (error) {
            console.error('Error creating task relationship:', error);
            this.showError(error.body?.message || error.message || 'An error occurred while creating the relationship');
        } finally {
            this._isLoading = false;
        }
    }
    
    /**
     * @description Show success toast
     */
    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success'
        }));
    }
    
    /**
     * @description Show error toast
     */
    showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }
}

