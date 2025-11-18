import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import getTaskList from '@salesforce/apex/ProjectTaskDashboardController.getTaskList';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';

export default class TaskListComponent extends NavigationMixin(LightningElement) {
    @api accountId;
    
    @wire(MessageContext)
    messageContext;
    
    tasks = [];
    subscription = null;
    _filteredAccountIds = [];
    
    get effectiveAccountIds() {
        if (this._filteredAccountIds.length > 0) {
            return this._filteredAccountIds;
        }
        return this.accountId ? [this.accountId] : [];
    }
    
    connectedCallback() {
        if (this.messageContext) {
            this.subscription = subscribe(
                this.messageContext,
                ACCOUNT_FILTER_MESSAGE_CHANNEL,
                (message) => {
                    if (message) {
                        if (message.accountIds !== undefined) {
                            this._filteredAccountIds = Array.isArray(message.accountIds) ? message.accountIds : [];
                        } else if (message.accountId !== undefined) {
                            this._filteredAccountIds = message.accountId ? [message.accountId] : [];
                        }
                    }
                },
                { scope: APPLICATION_SCOPE }
            );
        }
    }
    
    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }
    
    columns = [
        {
            label: 'Task Name',
            fieldName: 'taskUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_blank'
            }
        },
        {
            label: 'Status',
            fieldName: 'Status__c',
            type: 'text',
            cellAttributes: {
                class: { fieldName: 'statusClass' }
            }
        },
        {
            label: 'Priority',
            fieldName: 'Priority__c',
            type: 'text'
        },
        {
            label: 'Estimated Hours',
            fieldName: 'Estimated_Hours__c',
            type: 'number',
            cellAttributes: {
                alignment: 'right'
            }
        },
        {
            label: 'Actual Hours',
            fieldName: 'Actual_Hours__c',
            type: 'number',
            cellAttributes: {
                alignment: 'right'
            }
        },
        {
            label: 'Progress %',
            fieldName: 'Progress_Percentage__c',
            type: 'percent',
            cellAttributes: {
                alignment: 'right'
            }
        },
        {
            label: 'Owner',
            fieldName: 'Owner.Name',
            type: 'text'
        },
        {
            label: 'Created Date',
            fieldName: 'CreatedDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            }
        }
    ];
    
    totalRecords = 0;
    pageSize = 10;
    pageNumber = 1;
    totalPages = 0;
    
    @wire(getTaskList, { 
        accountIds: '$effectiveAccountIds',
        pageSize: '$pageSize',
        pageNumber: '$pageNumber'
    })
    wiredTaskList({ error, data }) {
        if (data) {
            this.tasks = data.tasks.map(task => {
                return {
                    ...task,
                    Name: task.Name,
                    taskUrl: '/' + task.Id,
                    Status__c: task.Status__c,
                    Priority__c: task.Priority__c,
                    Estimated_Hours__c: task.Estimated_Hours__c,
                    Actual_Hours__c: task.Actual_Hours__c,
                    Progress_Percentage__c: task.Progress_Percentage__c ? task.Progress_Percentage__c / 100 : null,
                    'Owner.Name': task.Owner?.Name || '',
                    CreatedDate: task.CreatedDate,
                    statusClass: this.getStatusClass(task.Status__c)
                };
            });
            this.totalRecords = data.totalRecords;
            this.totalPages = data.totalPages;
        } else if (error) {
            console.error('Error loading task list:', error);
            this.tasks = [];
        }
    }
    
    getStatusClass(status) {
        const statusClasses = {
            'Backlog': 'slds-badge slds-badge_lightest',
            'Pending': 'slds-badge slds-badge_warning',
            'In Progress': 'slds-badge slds-badge_info',
            'In Review': 'slds-badge slds-badge_inverse',
            'Blocked': 'slds-badge slds-badge_error',
            'Completed': 'slds-badge slds-badge_success',
            'Removed': 'slds-badge slds-badge_offline',
            'Closed': 'slds-badge slds-badge_success'
        };
        return statusClasses[status] || 'slds-badge';
    }
    
    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        
        if (action.name === 'view') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.Id,
                    actionName: 'view'
                }
            });
        } else if (action.name === 'edit') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.Id,
                    actionName: 'edit'
                }
            });
        }
    }
    
    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber = this.pageNumber - 1;
        }
    }
    
    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber = this.pageNumber + 1;
        }
    }
    
    get isFirstPage() {
        return this.pageNumber === 1;
    }
    
    get isLastPage() {
        return this.pageNumber >= this.totalPages;
    }
    
    get rowActions() {
        return [
            { label: 'View', name: 'view' },
            { label: 'Edit', name: 'edit' }
        ];
    }
    
    get hasData() {
        return this.tasks && this.tasks.length > 0;
    }
}

