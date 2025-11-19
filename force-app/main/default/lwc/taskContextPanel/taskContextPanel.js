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
 * 
 * USAGE:
 * - Used in: Project_Task_Record_Page.flexipage (sidebar region)
 * - Apex Controller: ProjectTaskDashboardController.getDependencyData() (includes subtask progress)
 */
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import { refreshApex } from '@salesforce/apex';
import { getRecord } from 'lightning/uiRecordApi';
import getDependencyData from '@salesforce/apex/ProjectTaskDashboardController.getDependencyData';
import DASHBOARD_REFRESH_MESSAGE_CHANNEL from '@salesforce/messageChannel/DashboardRefresh__c';
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
    
    // Dependency data (includes progress)
    _dependencyData = null;
    _isLoading = true;
    _error = null;
    
    // UI state
    _subtasksExpanded = false;
    _dependentTasksExpanded = true;
    _dependenciesExpanded = true; // Default to expanded
    _showCompleted = false; // Default to hiding completed tasks
    
    // Wire service results for refresh capability
    _wiredDependencyDataResult;
    
    // Message subscription
    _refreshSubscription = null;
    
    /**
     * @description Wire service to fetch dependency data from Apex (includes subtask progress)
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
    
    // Track if we've completed initial load
    _recordWireInitialized = false;
    
    /**
     * @description Get progress percentage from the record itself if no subtasks
     * Also listens for record updates via Lightning Data Service
     * When the record page refreshes (e.g., after quick actions), this wire service
     * is re-evaluated by Salesforce, which we use as a signal to refresh dependency data
     */
    @wire(getRecord, { 
        recordId: '$recordId', 
        fields: [PROGRESS_PERCENTAGE_FIELD] 
    })
    wiredRecord({ error, data }) {
        if (data && this._dependencyData && !this.hasSubtasks) {
            // Only use record progress if there are no subtasks
            if (!this._dependencyData.subtaskProgress?.hasSubtasks) {
                // This will be handled by the progress getters
            }
        } else if (error) {
            console.error('Error loading record:', error);
        }
        
        // When record wire service fires after initial load, refresh dependency data
        // This happens when the record page refreshes after quick actions complete
        // Even if the record data itself hasn't changed, the wire service re-evaluation
        // indicates the page has refreshed, so we should refresh our Apex data
        if (data && this._recordWireInitialized && this._dependencyData) {
            // Small delay to ensure related record creation has completed
            setTimeout(() => {
                this._refreshDependencyData();
            }, 300);
        }
        
        // Mark wire service as initialized after first successful data load
        if (data) {
            this._recordWireInitialized = true;
        }
    }
    
    // Progress getters (from dependency data)
    get progressPercentage() {
        return this._dependencyData?.subtaskProgress?.progressPercentage || 0;
    }
    
    get progressStyle() {
        return `width: ${this.progressPercentage}%`;
    }

    get progressDisplayText() {
        const progressInfo = this._dependencyData?.subtaskProgress;
        if (progressInfo?.hasSubtasks && progressInfo.totalCount > 0) {
            return `${progressInfo.completedCount} of ${progressInfo.totalCount} subtasks completed`;
        }
        return `${Math.round(this.progressPercentage)}%`;
    }
    
    get shouldShowProgress() {
        return this._dependencyData?.subtaskProgress?.hasSubtasks || false;
    }
    
    get progressTitle() {
        return this.shouldShowProgress ? 'Subtask Progress' : 'Progress';
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
    
    get hasDependencies() {
        const tasks = this._dependencyData?.dependencies;
        return Array.isArray(tasks) && tasks.length > 0;
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
        return this.hasParentTask || this.hasDependencies || this.hasDependentTasks || this.hasSubtasks;
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
    
    get dependencies() {
        const tasks = this._dependencyData?.dependencies;
        if (!Array.isArray(tasks)) {
            return [];
        }
        if (this._showCompleted) {
            return tasks;
        }
        // Filter out completed tasks
        return tasks.filter(task => {
            const status = String(task?.status || '').toLowerCase();
            return status !== 'completed' && status !== 'closed';
        });
    }
    
    get dependentTasks() {
        const tasks = this._dependencyData?.dependentTasks;
        return Array.isArray(tasks) ? tasks : [];
    }
    
    get subtasks() {
        const tasks = this._dependencyData?.subtasks;
        if (!Array.isArray(tasks)) {
            return [];
        }
        if (this._showCompleted) {
            return tasks;
        }
        // Filter out completed tasks
        return tasks.filter(task => {
            const status = String(task?.status || '').toLowerCase();
            return status !== 'completed' && status !== 'closed';
        });
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
    
    get dependenciesExpanded() {
        return this._dependenciesExpanded;
    }
    
    get dependenciesToggleIcon() {
        return this._dependenciesExpanded ? 'utility:chevronup' : 'utility:chevrondown';
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
    
    
    /**
     * @description Process wire service data into a plain object
     */
    _processWireData(wireData) {
        if (!wireData) {
            return this._createEmptyDependencyData();
        }
        
        const isAtRisk = Boolean(wireData.isAtRisk);
        const isBlocking = Boolean(wireData.isBlocking);
        
        const parentTask = this._extractTaskObject(wireData.parentTask);
        
        // Support both new dependencies array and legacy relatedTask for backward compatibility
        // Handle case where dependencies might be null, undefined, or an array
        let dependencies = [];
        if (wireData.dependencies && Array.isArray(wireData.dependencies)) {
            dependencies = this._extractTaskArray(wireData.dependencies);
        } else if (wireData.relatedTask) {
            // Fallback to legacy relatedTask if dependencies is not available
            dependencies = this._extractTaskArray([wireData.relatedTask]);
        }
        
        const dependentTasks = this._extractTaskArray(wireData.dependentTasks || []);
        const subtasks = this._extractTaskArray(wireData.subtasks || []);
        
        // Include subtask progress info
        const subtaskProgress = wireData.subtaskProgress ? {
            progressPercentage: wireData.subtaskProgress.progressPercentage || 0,
            completedCount: wireData.subtaskProgress.completedCount || 0,
            totalCount: wireData.subtaskProgress.totalCount || 0,
            hasSubtasks: Boolean(wireData.subtaskProgress.hasSubtasks)
        } : null;
        
        return {
            parentTask,
            dependencies,
            dependentTasks,
            subtasks,
            isAtRisk,
            isBlocking,
            subtaskProgress
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
            dependencies: [],
            dependentTasks: [],
            subtasks: [],
            isAtRisk: false,
            isBlocking: false,
            subtaskProgress: {
                progressPercentage: 0,
                completedCount: 0,
                totalCount: 0,
                hasSubtasks: false
            }
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
     * Matches the color pattern used in other components (groupedTaskList)
     */
    getStatusBadgeClassForStatus(status) {
        if (!status) {
            return 'status-badge status-badge-default';
        }
        
        const statusStr = String(status);
        const normalizedStatus = statusStr.toLowerCase().replace(/\s+/g, '-');
        
        const statusClasses = {
            'Backlog': 'status-badge status-badge-backlog',
            'backlog': 'status-badge status-badge-backlog',
            'Pending': 'status-badge status-badge-pending',
            'pending': 'status-badge status-badge-pending',
            'In Progress': 'status-badge status-badge-in-progress',
            'in progress': 'status-badge status-badge-in-progress',
            'in-progress': 'status-badge status-badge-in-progress',
            'In Review': 'status-badge status-badge-in-review',
            'in review': 'status-badge status-badge-in-review',
            'in-review': 'status-badge status-badge-in-review',
            'Blocked': 'status-badge status-badge-blocked',
            'blocked': 'status-badge status-badge-blocked',
            'Completed': 'status-badge status-badge-completed',
            'completed': 'status-badge status-badge-completed',
            'Removed': 'status-badge status-badge-removed',
            'removed': 'status-badge status-badge-removed',
            'Closed': 'status-badge status-badge-closed',
            'closed': 'status-badge status-badge-closed',
            'Not Started': 'status-badge status-badge-not-started',
            'not started': 'status-badge status-badge-not-started',
            'not-started': 'status-badge status-badge-not-started',
            'On Hold': 'status-badge status-badge-on-hold',
            'on hold': 'status-badge status-badge-on-hold',
            'on-hold': 'status-badge status-badge-on-hold',
            'Cancelled': 'status-badge status-badge-cancelled',
            'cancelled': 'status-badge status-badge-cancelled',
            'Deferred': 'status-badge status-badge-deferred',
            'deferred': 'status-badge status-badge-deferred'
        };
        
        return statusClasses[statusStr] || statusClasses[normalizedStatus] || 'status-badge status-badge-default';
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
     * @description Toggle dependencies section expand/collapse state
     */
    toggleDependencies() {
        this._dependenciesExpanded = !this._dependenciesExpanded;
    }
    
    /**
     * @description Get all dependencies (unfiltered) for counting
     */
    get allDependencies() {
        const tasks = this._dependencyData?.dependencies;
        return Array.isArray(tasks) ? tasks : [];
    }
    
    /**
     * @description Get all subtasks (unfiltered) for counting
     */
    get allSubtasks() {
        const tasks = this._dependencyData?.subtasks;
        return Array.isArray(tasks) ? tasks : [];
    }
    
    /**
     * @description Count completed dependencies
     */
    get completedDependenciesCount() {
        return this.allDependencies.filter(task => {
            const status = String(task?.status || '').toLowerCase();
            return status === 'completed' || status === 'closed';
        }).length;
    }
    
    /**
     * @description Count completed subtasks
     */
    get completedSubtasksCount() {
        return this.allSubtasks.filter(task => {
            const status = String(task?.status || '').toLowerCase();
            return status === 'completed' || status === 'closed';
        }).length;
    }
    
    /**
     * @description Total count of completed items (dependencies + subtasks)
     */
    get totalCompletedCount() {
        return this.completedDependenciesCount + this.completedSubtasksCount;
    }
    
    /**
     * @description Toggle showing/hiding completed tasks
     */
    toggleShowCompleted() {
        this._showCompleted = !this._showCompleted;
    }
    
    /**
     * @description Getter for show completed state
     */
    get showCompleted() {
        return this._showCompleted;
    }
    
    /**
     * @description Get button label for show/hide completed toggle
     */
    get showCompletedButtonLabel() {
        if (this._showCompleted) {
            return `Hide ${this.totalCompletedCount} Completed`;
        }
        return `Show ${this.totalCompletedCount} Completed`;
    }
    
    /**
     * @description Get button icon for show/hide completed toggle
     */
    get showCompletedButtonIcon() {
        return this._showCompleted ? 'utility:hide' : 'utility:preview';
    }
    
    /**
     * @description Lifecycle hook - component is inserted into the DOM
     */
    connectedCallback() {
        // Subscribe to Lightning Message Service for manual refresh triggers
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
     * @description Refresh dependency data using refreshApex
     */
    _refreshDependencyData() {
        if (this._wiredDependencyDataResult) {
            refreshApex(this._wiredDependencyDataResult).catch(error => {
                console.error('Error refreshing dependency data:', error);
            });
        }
    }
    
    /**
     * @description Handle refresh message from LMS
     */
    handleRefresh(message) {
        if (message && message.refreshTimestamp) {
            this._refreshDependencyData();
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

