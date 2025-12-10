/**
 * @description Modal component for editing a single field on a Project Task
 */
import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord } from 'lightning/uiRecordApi';
import PROJECT_TASK_OBJECT from '@salesforce/schema/Project_Task__c';

export default class FieldEditModal extends LightningElement {
    @api recordId; // Task ID
    @api fieldApiName; // Field API name to edit
    @api fieldLabel; // Field label for display
    @api fieldValue; // Current field value
    @api fieldDataType; // Field data type (STRING, NUMBER, DATE, etc.)
    @api picklistOptions; // Picklist options for PICKLIST fields
    
    _isOpen = false;
    _isSaving = false;
    currentValue = '';
    
    /**
     * @description Open the modal
     */
    @api
    open(recordId, fieldApiName, fieldLabel, fieldValue, fieldDataType, picklistOptions) {
        this.recordId = recordId;
        this.fieldApiName = fieldApiName;
        this.fieldLabel = fieldLabel;
        this.fieldValue = fieldValue;
        this.fieldDataType = fieldDataType || 'STRING';
        this.picklistOptions = picklistOptions || [];
        this.currentValue = fieldValue || '';
        this._isOpen = true;
    }

    get computedLabel() {
        return this.fieldLabel || 'Field';
    }
    
    /**
     * @description Close the modal
     */
    close() {
        this._isOpen = false;
        this.currentValue = '';
        this._isSaving = false;
    }
    
    /**
     * @description Handle modal close button
     */
    handleClose() {
        this.close();
    }
    
    /**
     * @description Handle backdrop click
     */
    handleBackdropClick(event) {
        // Only close if clicking the backdrop, not the modal content
        if (event.target === event.currentTarget) {
            this.close();
        }
    }
    
    /**
     * @description Handle value change
     */
    handleValueChange(event) {
        if (event.target.type === 'checkbox') {
            this.currentValue = event.target.checked;
        } else {
            this.currentValue = event.target.value;
        }
    }
    
    /**
     * @description Handle combobox change
     */
    handleComboboxChange(event) {
        this.currentValue = event.detail.value;
    }
    
    /**
     * @description Handle save
     */
    async handleSave() {
        if (this._isSaving) {
            return;
        }
        
        this._isSaving = true;
        
        try {
            const fields = {
                Id: this.recordId
            };
            
            // Convert value based on field type
            const dataTypeUpper = (this.fieldDataType || '').toUpperCase();
            let convertedValue = this.currentValue;
            
            if (dataTypeUpper === 'DATE') {
                fields[this.fieldApiName] = convertedValue || null;
            } else if (dataTypeUpper === 'DATETIME') {
                fields[this.fieldApiName] = convertedValue || null;
            } else if (dataTypeUpper === 'DOUBLE' || dataTypeUpper === 'CURRENCY' || dataTypeUpper === 'PERCENT' || dataTypeUpper === 'INTEGER') {
                if (convertedValue === '' || convertedValue === null || convertedValue === undefined) {
                    fields[this.fieldApiName] = null;
                } else {
                    const numValue = parseFloat(convertedValue);
                    if (isNaN(numValue)) {
                        throw new Error('Invalid number format');
                    }
                    fields[this.fieldApiName] = numValue;
                }
            } else if (dataTypeUpper === 'BOOLEAN') {
                fields[this.fieldApiName] = convertedValue === true || convertedValue === 'true';
            } else {
                // STRING and other types
                fields[this.fieldApiName] = convertedValue || null;
            }
            
            const recordInput = {
                fields: fields
            };
            
            await updateRecord(recordInput);
            
            // Dispatch success event
            this.dispatchEvent(new CustomEvent('save', {
                detail: {
                    recordId: this.recordId,
                    fieldApiName: this.fieldApiName,
                    newValue: this.currentValue
                }
            }));
            
            this.showToast('Success', `${this.fieldLabel} updated successfully`, 'success');
            this.close();
        } catch (error) {
            console.error('Error updating field:', error);
            const errorMessage = this.getErrorMessage(error);
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this._isSaving = false;
        }
    }
    
    /**
     * @description Get user-friendly error message
     */
    getErrorMessage(error) {
        if (error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map(e => e.message).join(', ');
            } else if (error.body.message) {
                return error.body.message;
            } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            } else if (error.body.fieldErrors) {
                const fieldErrors = Object.values(error.body.fieldErrors);
                if (fieldErrors.length > 0 && fieldErrors[0].length > 0) {
                    return fieldErrors[0][0].message;
                }
            }
        }
        return error.message || 'An error occurred while updating the field';
    }
    
    /**
     * @description Show toast message
     */
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
    
    /**
     * @description Get input type based on data type
     */
    get inputType() {
        const dataTypeUpper = (this.fieldDataType || '').toUpperCase();
        if (dataTypeUpper === 'DATE') {
            return 'date';
        } else if (dataTypeUpper === 'DATETIME') {
            return 'datetime-local';
        } else if (dataTypeUpper === 'DOUBLE' || dataTypeUpper === 'CURRENCY' || dataTypeUpper === 'PERCENT' || dataTypeUpper === 'INTEGER') {
            return 'number';
        } else if (dataTypeUpper === 'BOOLEAN') {
            return 'checkbox';
        }
        return 'text';
    }
    
    /**
     * @description Check if field is boolean
     */
    get isBoolean() {
        return (this.fieldDataType || '').toUpperCase() === 'BOOLEAN';
    }
    
    /**
     * @description Check if field is picklist
     */
    get isPicklist() {
        const dataTypeUpper = (this.fieldDataType || '').toUpperCase();
        return (dataTypeUpper === 'PICKLIST' || dataTypeUpper === 'MULTIPICKLIST') && 
               this.picklistOptions && 
               this.picklistOptions.length > 0;
    }
    
    /**
     * @description Get picklist options formatted for lightning-combobox
     */
    get comboboxOptions() {
        if (!this.picklistOptions || this.picklistOptions.length === 0) {
            return [];
        }
        return this.picklistOptions.map(option => ({
            label: option.label || option.value,
            value: option.value
        }));
    }
    
    /**
     * @description Get display value for input
     */
    get inputValue() {
        if (this.isBoolean) {
            return this.currentValue === 'true' || this.currentValue === true;
        }
        return this.currentValue || '';
    }
    
    /**
     * @description Get modal class
     */
    get modalClass() {
        return this._isOpen ? 'slds-modal slds-fade-in-open' : 'slds-modal';
    }
    
    /**
     * @description Get backdrop class
     */
    get backdropClass() {
        return this._isOpen ? 'slds-backdrop slds-backdrop_open' : 'slds-backdrop';
    }
}

