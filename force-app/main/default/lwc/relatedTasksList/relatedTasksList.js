import { LightningElement, api } from 'lwc';
import getRelatedTasks from '@salesforce/apex/RelatedTasksController.getRelatedTasks';

export default class RelatedTasksList extends LightningElement {
    @api recordId;
    relatedTasks = [];
    error;

    connectedCallback() {
        this.loadRelatedTasks();
    }

    loadRelatedTasks() {
        getRelatedTasks({ taskId: this.recordId })
            .then(result => {
                this.relatedTasks = result;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.relatedTasks = [];
            });
    }
}

