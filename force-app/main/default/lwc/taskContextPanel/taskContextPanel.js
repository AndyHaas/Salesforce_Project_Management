/**
 * @description Task Context Panel Component
 * 
 * Unified component that displays:
 * - Task progress (subtask progress bar for parent tasks)
 * - Task relationships (parent, dependencies, dependents, subtasks)
 * - Risk indicators and blocking status
 * 
 * @component
 * @author Salesforce LWC
 */
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import { refreshApex } from '@salesforce/apex';
import { getRecord } from 'lightning/uiRecordApi';
import getSubtaskProgress from '@salesforce/apex/ProjectTaskDashboardController.getSubtaskProgress';
import getDependencyData from '@salesforce/apex/ProjectTaskDashboardController.getDependencyData';
import DASHBOARD_REFRESH_MESSAGE_CHANNEL from '@salesforce/messageChannel/DashboardRefresh__c';
import PROJECT_TASK_OBJECT from '@salesforce/schema/Project_Task__c';
import PROGRESS_PERCENTAGE_FIELD from '@salesforce/schema/Project_Task__c.Progress_Percentage__c';

export default class TaskContextPanel extends NavigationMixin(LightningElement) {
    /**
     * @description Record ID of the Project Task to display context for
     * @type {string}
     */
    @api recordId;
    
    /**
     * @description Message context for Lightning Message Service
     * @type {Object}
     */
    @wire(MessageContext)
    messageContext;
    
    // Progress data
    _progressData = null;
    _progressPercentage = 0;
    _completedCount = 0;
    _totalCount = 0;
    _hasSubtasks = false;
    
    // Dependency data
    _dependencyData = null;
    _isLoading = true;
    _error = null;
    
    // UI state
    _subtasksExpanded = false;
    _dependentTasksExpanded = true;
    
    // Wire service results for refresh capability
    _wiredDependencyDataResult;
    _wiredSubtaskProgressResult;
    
    // Message subscription
    _refreshSubscription = null;
    
    /**
     * @description Wire service to fetch subtask progress
     */
    @wire(getSubtaskProgress, { taskId: '$recordId' })
    wiredSubtaskProgress(result) {
        this._wiredSubtaskProgressResult = result;
        const { error, data } = result;
        
        if (data) {
            this._progressData = data;
            this._progressPercentage = data.progressPercentage || 0;
            this._completedCount = data.completedCount || 0;
            this._totalCount = data.totalCount || 0;
            this._hasSubtasks = data.hasSubtasks || false;
        } else if (error) {
            console.error('Error loading subtask progress:', error);
            this._hasSubtasks = false;
        } else {
            this._hasSubtasks = false;
        }
    }
    
    /**
     * @description Fallback: Get progress percentage from the record itself
     */
    @wire(getRecord, { 
        recordId: '$recordId', 
        fields: [PROGRESS_PERCENTAGE_FIELD] 
    })
    wiredRecord({ error, data }) {
        if (data && !this._hasSubtasks) {
            this._progressPercentage = data.fields.Progress_Percentage__c?.value || 0;
        } else if (error) {
            console.error('Error loading record:', error);
        }
    }
    
    /**
     * @description Wire service to fetch dependency data from Apex
     */
    @wire(getDependencyData, { taskId: '$recordId' })
    wiredDependencyData(result) {
        this._wiredDependencyDataResult = result;
        const { error, data } = result;
        
        this._isLoading = false;
        
        if (error) {
            this._handleError(error);
            return;
        }
        
        if (!data) {
            this._dependencyData = this._createEmptyDependencyData();
            this._error = null;
            return;
        }
        
        try {
            this._dependencyData = this._processWireData(data);
            this._error = null;
        } catch (processingError) {
            console.error('Error processing dependency data:', processingError);
            this._handleError('Failed to process dependency data');
        }
    }
    
    // Progress getters
    get progressStyle() {
        return `width: ${this._progressPercentage || 0}%`;
    }

    get progressDisplayText() {
        if (this._hasSubtasks && this._totalCount > 0) {
            return `${this._completedCount} of ${this._totalCount} subtasks completed`;
        }
        return `${Math.round(this._progressPercentage)}%`;
    }
    
    get shouldShowProgress() {
        return this._hasSubtasks;
    }
    
    get progressTitle() {
        return this._hasSubtasks ? 'Subtask Progress' : 'Progress';
    }
    
    // Dependency getters
    get dependencyData() {
        return this._dependencyData;
    }
    
    get isLoading() {
        return this._isLoading;
    }
    
    get error() {
        return this._error;
    }
    
    get hasParentTask() {
        return this._dependencyData?.parentTask != null;
    }
    
    get hasRelatedTask() {
        return this._dependencyData?.relatedTask != null;
    }
    
    get hasDependentTasks() {
        const tasks = this._dependencyData?.dependentTasks;
        return Array.isArray(tasks) && tasks.length > 0;
    }
    
    get hasSubtasks() {
        const tasks = this._dependencyData?.subtasks;
        return Array.isArray(tasks) && tasks.length > 0;
    }
    
    get hasAnyDependencies() {
        return this.hasParentTask || this.hasRelatedTask || this.hasDependentTasks || this.hasSubtasks;
    }
    
    get isAtRisk() {
        return this._dependencyData?.isAtRisk === true;
    }
    
    get isBlocking() {
        return this._dependencyData?.isBlocking === true;
    }
    
    get parentTask() {
        return this._dependencyData?.parentTask || null;
    }
    
    get relatedTask() {
        return this._dependencyData?.relatedTask || null;
    }
    
    get dependentTasks() {
        const tasks = this._dependencyData?.dependentTasks;
        return Array.isArray(tasks) ? tasks : [];
    }
    
    get subtasks() {
        const tasks = this._dependencyData?.subtasks;
        return Array.isArray(tasks) ? tasks : [];
    }
    
    get subtasksExpanded() {
        return this._subtasksExpanded;
    }
    
    get subtasksToggleIcon() {
        return this._subtasksExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }
    
    get dependentTasksExpanded() {
        return this._dependentTasksExpanded;
    }
    
    get dependentTasksToggleIcon() {
        return this._dependentTasksExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }
    
    get parentTaskStatusBadgeClass() {
        if (!this.parentTask?.status) {
            return 'slds-badge slds-badge_lightest';
        }
        return this.getStatusBadgeClassForStatus(this.parentTask.status);
    }
    
    get parentTaskPriorityBadgeClass() {
        if (!this.parentTask?.priority) {
            return 'slds-badge slds-badge_lightest';
        }
        return this.getPriorityBadgeClassForPriority(this.parentTask.priority);
    }
    
    get relatedTaskStatusBadgeClass() {
        if (!this.relatedTask?.status) {
            return 'slds-badge slds-badge_lightest';
        }
        return this.getStatusBadgeClassForStatus(this.relatedTask.status);
    }
    
    get relatedTaskPriorityBadgeClass() {
        if (!this.relatedTask?.priority) {
            return 'slds-badge slds-badge_lightest';
        }
        return this.getPriorityBadgeClassForPriority(this.relatedTask.priority);
    }
    
    /**
     * @description Process wire service data into a plain object
     */
    _processWireData(wireData) {
        const isAtRisk = Boolean(wireData.isAtRisk);
        const isBlocking = Boolean(wireData.isBlocking);
        
        const parentTask = this._extractTaskObject(wireData.parentTask);
        const relatedTask = this._extractTaskObject(wireData.relatedTask);
        const dependentTasks = this._extractTaskArray(wireData.dependentTasks);
        const subtasks = this._extractTaskArray(wireData.subtasks);
        
        return {
            parentTask,
            relatedTask,
            dependentTasks,
            subtasks,
            isAtRisk,
            isBlocking
        };
    }
    
    /**
     * @description Extract a single task object from wire data
     */
    _extractTaskObject(taskProxy) {
        if (!taskProxy) {
            return null;
        }
        
        return {
            id: String(taskProxy.id || ''),
            name: String(taskProxy.name || ''),
            status: String(taskProxy.status || ''),
            priority: String(taskProxy.priority || ''),
            type: String(taskProxy.type || ''),
            isBlocking: Boolean(taskProxy.isBlocking),
            isAtRisk: Boolean(taskProxy.isAtRisk)
        };
    }
    
    /**
     * @description Extract array of task objects from wire data
     */
    _extractTaskArray(tasksProxy) {
        if (!tasksProxy || !Array.isArray(tasksProxy) || tasksProxy.length === 0) {
            return [];
        }
        
        return tasksProxy
            .map((taskProxy) => {
                if (!taskProxy) {
                    return null;
                }
                
                const task = this._extractTaskObject(taskProxy);
                
                if (task) {
                    task.statusBadgeClass = this.getStatusBadgeClassForStatus(task.status);
                    task.priorityBadgeClass = this.getPriorityBadgeClassForPriority(task.priority);
                }
                
                return task;
            })
            .filter(task => task !== null);
    }
    
    /**
     * @description Create empty dependency data structure
     */
    _createEmptyDependencyData() {
        return {
            parentTask: null,
            relatedTask: null,
            dependentTasks: [],
            subtasks: [],
            isAtRisk: false,
            isBlocking: false
        };
    }
    
    /**
     * @description Handle error state
     */
    _handleError(error) {
        this._error = typeof error === 'string' ? error : 'An error occurred loading task context';
        this._dependencyData = this._createEmptyDependencyData();
        console.error('Task Context Panel Error:', error);
    }
    
    /**
     * @description Get CSS class for status badge based on status value
     */
    getStatusBadgeClassForStatus(status) {
        if (!status) {
            return 'slds-badge slds-badge_lightest';
        }
        
        const normalizedStatus = String(status).toLowerCase();
        
        if (normalizedStatus === 'completed' || normalizedStatus === 'closed') {
            return 'slds-badge slds-badge_success';
        }
        if (normalizedStatus === 'blocked') {
            return 'slds-badge slds-badge_error';
        }
        if (normalizedStatus === 'in progress') {
            return 'slds-badge slds-badge_info';
        }
        
        return 'slds-badge slds-badge_lightest';
    }
    
    /**
     * @description Get CSS class for priority badge based on priority value
     */
    getPriorityBadgeClassForPriority(priority) {
        if (!priority) {
            return 'slds-badge slds-badge_lightest';
        }
        
        const normalizedPriority = String(priority).toLowerCase();
        
        if (normalizedPriority === 'high') {
            return 'slds-badge slds-badge_error';
        }
        if (normalizedPriority === 'medium') {
            return 'slds-badge slds-badge_warning';
        }
        if (normalizedPriority === 'low') {
            return 'slds-badge slds-badge_success';
        }
        
        return 'slds-badge slds-badge_lightest';
    }
    
    /**
     * @description Toggle sub tasks section expand/collapse state
     */
    toggleSubtasks() {
        this._subtasksExpanded = !this._subtasksExpanded;
    }
    
    /**
     * @description Toggle dependent tasks section expand/collapse state
     */
    toggleDependentTasks() {
        this._dependentTasksExpanded = !this._dependentTasksExpanded;
    }
    
    /**
     * @description Lifecycle hook - component is inserted into the DOM
     */
    connectedCallback() {
        if (this.messageContext) {
            this._refreshSubscription = subscribe(
                this.messageContext,
                DASHBOARD_REFRESH_MESSAGE_CHANNEL,
                (message) => this.handleRefresh(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }
    
    /**
     * @description Lifecycle hook - component is removed from the DOM
     */
    disconnectedCallback() {
        if (this._refreshSubscription) {
            unsubscribe(this._refreshSubscription);
            this._refreshSubscription = null;
        }
    }
    
    /**
     * @description Handle refresh message from LMS
     */
    handleRefresh(message) {
        if (message && message.refreshTimestamp) {
            if (this._wiredDependencyDataResult) {
                refreshApex(this._wiredDependencyDataResult).catch(error => {
                    console.error('Error refreshing dependency data:', error);
                });
            }
            if (this._wiredSubtaskProgressResult) {
                refreshApex(this._wiredSubtaskProgressResult).catch(error => {
                    console.error('Error refreshing progress data:', error);
                });
            }
        }
    }
    
    /**
     * @description Navigate to a task record page
     */
    navigateToTask(event) {
        const taskId = event?.currentTarget?.dataset?.id;
        
        if (!taskId) {
            console.warn('No task ID found in click event');
            return;
        }
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: taskId,
                actionName: 'view'
            }
        });
    }
}

