import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createReleaseNote from '@salesforce/apex/CreateReleaseNoteQuickActionController.createReleaseNote';

export default class CreateReleaseNoteQuickAction extends LightningElement {
    @api recordId;

    isSubmitting = false;

    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        this.isSubmitting = true;

        createReleaseNote({
            taskId: this.recordId,
            releaseNotesText: fields.Release_Notes_Text__c,
            releaseVersionId: fields.Release_Version__c,
            releaseTagId: fields.Release_Tag__c
        })
            .then(() => {
                this.showToast('Success', 'Release note created and linked to the task.', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch((error) => {
                const message = error?.body?.message || 'Unexpected error creating the release note.';
                this.showToast('Error', message, 'error');
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}