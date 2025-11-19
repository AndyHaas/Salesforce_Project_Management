/**
 * @description Modal component for linking tasks together
 * Creates a Project_Task_Relationship__c record between two tasks
 */
import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createTaskRelationship from '@salesforce/apex/TaskContextController.createTaskRelationship';
import updateTaskRelationship from '@salesforce/apex/TaskContextController.updateTaskRelationship';
import getRelationshipDetails from '@salesforce/apex/TaskContextController.getRelationshipDetails';
import TASK_B_FIELD from '@salesforce/schema/Project_Task_Relationship__c.Task_B__c';

export default class LinkTaskModal extends LightningElement {
    @api recordId; // Primary Task ID (the current task)
    
    _isOpen = false;
    _isLoading = false;
    _relationshipId = null; // Relationship ID when editing
    _isEditMode = false;
    
    // Form fields
    taskBId = null; // Related Task ID
    relationshipType = 'Related';
    
    // Field references for lightning-input-field
    taskBField = TASK_B_FIELD;
    
    // Relationship type options
    get relationshipTypeOptions() {
        return [
            { label: 'Related', value: 'Related' },
            { label: 'Blocking Dependency', value: 'Blocking Dependency' },
            { label: 'Epic/Feature Parent', value: 'Epic/Feature Parent' }
        ];
    }
    
    /**
     * @description Open the modal for creating a new relationship
     */
    @api
    open() {
        this._isOpen = true;
        this._isEditMode = false;
        this._relationshipId = null;
        // Reset form
        this.taskBId = null;
        this.relationshipType = 'Related';
    }
    
    /**
     * @description Open the modal for editing an existing relationship
     * @param {string} relationshipId - The ID of the relationship to edit
     */
    @api
    async openForEdit(relationshipId) {
        if (!relationshipId) {
            this.showError('Relationship ID is required');
            return;
        }
        
        this._isOpen = true;
        this._isEditMode = true;
        this._relationshipId = relationshipId;
        this._isLoading = true;
        
        try {
            const details = await getRelationshipDetails({ relationshipId });
            this.taskBId = details.taskBId;
            this.relationshipType = details.relationshipType || 'Related';
        } catch (error) {
            console.error('Error loading relationship details:', error);
            this.showError(error.body?.message || error.message || 'An error occurred while loading the relationship');
            this.close();
        } finally {
            this._isLoading = false;
        }
    }
    
    /**
     * @description Close the modal
     */
    close() {
        this._isOpen = false;
        this._isEditMode = false;
        this._relationshipId = null;
        this.taskBId = null;
        this.relationshipType = 'Related';
        // Reset form fields
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form) {
            form.reset();
        }
    }
    
    /**
     * @description Getter for modal title
     */
    get modalTitle() {
        return this._isEditMode ? 'Edit Relationship' : 'Link Task';
    }
    
    /**
     * @description Getter for submit button label
     */
    get submitButtonLabel() {
        return this._isEditMode ? 'Save Changes' : 'Link Task';
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
     * @description Handle Related Task field change
     */
    handleTaskBChange(event) {
        // lightning-input-field for lookup fields can return the value as an array
        // Extract the first ID if it's an array, otherwise use the value directly
        const value = event.detail.value;
        if (Array.isArray(value) && value.length > 0) {
            this.taskBId = value[0];
        } else if (value) {
            this.taskBId = value;
        } else {
            this.taskBId = null;
        }
    }
    
    /**
     * @description Handle relationship type field change
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
        this._isLoading = true;
        
        try {
            if (this._isEditMode) {
                // Update existing relationship
                if (!this._relationshipId) {
                    this.showError('Relationship ID is required');
                    return;
                }
                
                await updateTaskRelationship({
                    relationshipId: this._relationshipId,
                    relationshipType: String(this.relationshipType || 'Related').trim()
                });
                
                this.showSuccess('Relationship updated successfully');
                
                // Dispatch event to notify parent component to refresh
                this.dispatchEvent(new CustomEvent('relationshipupdated', {
                    detail: { relationshipId: this._relationshipId }
                }));
            } else {
                // Create new relationship
                const taskBIdString = String(this.taskBId || '').trim();
                
                if (!taskBIdString) {
                    this.showError('Please select a related task to link');
                    return;
                }
                
                if (taskBIdString === this.recordId) {
                    this.showError('A task cannot be linked to itself');
                    return;
                }
                
                const relationshipId = await createTaskRelationship({
                    taskAId: String(this.recordId || '').trim(),
                    taskBId: taskBIdString,
                    relationshipType: String(this.relationshipType || 'Related').trim()
                });
                
                this.showSuccess('Task relationship created successfully');
                
                // Dispatch event to notify parent component to refresh
                this.dispatchEvent(new CustomEvent('relationshipcreated', {
                    detail: { relationshipId }
                }));
            }
            
            // Close modal after a short delay
            setTimeout(() => {
                this.close();
            }, 500);
            
        } catch (error) {
            console.error('Error saving relationship:', error);
            this.showError(error.body?.message || error.message || 'An error occurred while saving the relationship');
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

