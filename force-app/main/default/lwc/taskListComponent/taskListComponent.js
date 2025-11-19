import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import getTaskList from '@salesforce/apex/ProjectTaskDashboardController.getTaskList';
import getTaskListFieldSetDefinition from '@salesforce/apex/ProjectTaskDashboardController.getTaskListFieldSetDefinition';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';
import DASHBOARD_REFRESH_MESSAGE_CHANNEL from '@salesforce/messageChannel/DashboardRefresh__c';

export default class TaskListComponent extends NavigationMixin(LightningElement) {
    @api accountId;
    
    @wire(MessageContext)
    messageContext;
    
    tasks = [];
    rawTaskData = [];
    fieldSetDefinitions = [];
    subscription = null;
    refreshSubscription = null;
    _filteredAccountIds = [];
    columns = [];
    
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
            
            // Subscribe to refresh messages
            this.refreshSubscription = subscribe(
                this.messageContext,
                DASHBOARD_REFRESH_MESSAGE_CHANNEL,
                (message) => this.handleRefresh(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }
    
    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
        
        if (this.refreshSubscription) {
            unsubscribe(this.refreshSubscription);
            this.refreshSubscription = null;
        }
    }
    
    /**
     * @description Handle refresh message from LMS
     * Forces a refresh of the wire service by temporarily clearing and restoring accountIds
     * @param {Object} message - Refresh message with timestamp
     * @private
     */
    handleRefresh(message) {
        if (message && message.refreshTimestamp) {
            // Force wire refresh by temporarily clearing and restoring accountIds
            const currentAccountIds = [...this._filteredAccountIds];
            this._filteredAccountIds = [];
            // Use setTimeout to ensure the wire service processes the change
            setTimeout(() => {
                this._filteredAccountIds = currentAccountIds;
            }, 0);
        }
    }
    
    totalRecords = 0;
    pageSize = 10;
    pageNumber = 1;
    totalPages = 0;
    
    @wire(getTaskListFieldSetDefinition)
    wiredFieldSetDefinition({ error, data }) {
        if (data) {
            this.fieldSetDefinitions = this.prepareFieldDefinitions(data);
            this.buildColumns();
            this.processTasks();
        } else if (error) {
            console.error('Error loading field set definition:', error);
        }
    }
    
    @wire(getTaskList, { 
        accountIds: '$effectiveAccountIds',
        pageSize: '$pageSize',
        pageNumber: '$pageNumber'
    })
    wiredTaskList({ error, data }) {
        if (data) {
            this.rawTaskData = data.tasks || [];
            this.totalRecords = data.totalRecords;
            this.totalPages = data.totalPages;
            this.pageNumber = data.pageNumber;
            this.pageSize = data.pageSize;
            this.processTasks();
        } else if (error) {
            console.error('Error loading task list:', error);
            this.rawTaskData = [];
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

    prepareFieldDefinitions(definitions) {
        if (!definitions || !definitions.length) {
            return [];
        }
        return definitions.map((definition) => ({
            ...definition,
            columnFieldName: this.getColumnFieldName(definition)
        }));
    }

    buildColumns() {
        if (!this.fieldSetDefinitions.length) {
            this.columns = [];
            return;
        }
        const dynamicColumns = this.fieldSetDefinitions.map((definition) => this.createColumnFromDefinition(definition));
        this.columns = dynamicColumns;
    }

    getColumnFieldName(definition) {
        if (definition.isNameField) {
            return 'taskUrl';
        }
        const sanitizedApiName = definition.apiName ? definition.apiName.replace(/\./g, '_') : 'field';
        return `display_${sanitizedApiName}`;
    }

    createColumnFromDefinition(definition) {
        if (definition.isNameField) {
            return {
                label: definition.label,
                fieldName: 'taskUrl',
                type: 'url',
                typeAttributes: {
                    label: { fieldName: 'Name' },
                    target: '_blank'
                }
            };
        }

        const column = {
            label: definition.label,
            fieldName: definition.columnFieldName,
            type: this.getColumnType(definition)
        };

        const typeAttributes = this.getColumnTypeAttributes(definition);
        if (typeAttributes) {
            column.typeAttributes = typeAttributes;
        }

        const cellAttributes = this.getCellAttributes(definition);
        if (cellAttributes) {
            column.cellAttributes = cellAttributes;
        }

        return column;
    }

    getColumnType(definition) {
        const dataType = definition.dataType ? definition.dataType.toUpperCase() : 'STRING';
        const typeMap = {
            STRING: 'text',
            PICKLIST: 'text',
            TEXTAREA: 'text',
            LONGTEXTAREA: 'text',
            DATE: 'date',
            DATETIME: 'date',
            DOUBLE: 'number',
            INTEGER: 'number',
            LONG: 'number',
            CURRENCY: 'currency',
            PERCENT: 'percent',
            BOOLEAN: 'boolean',
            EMAIL: 'email',
            PHONE: 'phone',
            URL: 'url'
        };
        if (definition.isReference) {
            return 'text';
        }
        return typeMap[dataType] || 'text';
    }

    getColumnTypeAttributes(definition) {
        const dataType = definition.dataType ? definition.dataType.toUpperCase() : 'STRING';
        if (dataType === 'DATE') {
            return { year: 'numeric', month: 'short', day: '2-digit' };
        }
        if (dataType === 'DATETIME') {
            return {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            };
        }
        if (dataType === 'PERCENT') {
            return {
                step: 0.01,
                minimumFractionDigits: 0,
                maximumFractionDigits: 2
            };
        }
        return null;
    }

    getCellAttributes(definition) {
        const attributes = {};
        const numericTypes = ['CURRENCY', 'DOUBLE', 'INTEGER', 'LONG', 'PERCENT'];
        if (numericTypes.includes((definition.dataType || '').toUpperCase())) {
            attributes.alignment = 'right';
        }
        if (definition.apiName === 'Status__c') {
            attributes.class = { fieldName: 'statusClass' };
        }
        return Object.keys(attributes).length ? attributes : null;
    }

    processTasks() {
        if (!this.rawTaskData || !this.rawTaskData.length) {
            this.tasks = [];
            return;
        }

        const processedTasks = this.rawTaskData.map((task) => {
            const row = {
                ...task,
                taskUrl: '/' + task.Id,
                statusClass: this.getStatusClass(task.Status__c)
            };

            if (this.fieldSetDefinitions.length) {
                this.fieldSetDefinitions.forEach((definition) => {
                    if (definition.isNameField) {
                        return;
                    }
                    row[definition.columnFieldName] = this.getFieldDisplayValue(task, definition);
                });
            }

            return row;
        });

        this.tasks = processedTasks;
    }

    getFieldDisplayValue(task, definition) {
        if (!task || !definition) {
            return null;
        }

        let value = this.getNestedFieldValue(task, definition.apiName);
        if (definition.isReference && definition.referenceRelationshipName) {
            const relationship = task[definition.referenceRelationshipName];
            value = relationship && relationship.Name ? relationship.Name : value;
        }

        if ((definition.dataType || '').toUpperCase() === 'PERCENT' && value !== null && value !== undefined) {
            return value / 100;
        }

        return value;
    }

    getNestedFieldValue(record, fieldPath) {
        if (!record || !fieldPath) {
            return null;
        }
        return fieldPath.split('.').reduce((value, segment) => {
            if (value === null || value === undefined) {
                return null;
            }
            return value[segment];
        }, record);
    }
}

