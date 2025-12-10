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
 * - Apex Controller: TaskContextController.getDependencyData() (includes subtask progress)
 */
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getRecordNotifyChange, NotifyChangeRecordIds, RecordChange } from 'lightning/uiRecordApi';
import getDependencyData from '@salesforce/apex/TaskContextController.getDependencyData';
import deleteTaskRelationship from '@salesforce/apex/TaskContextController.deleteTaskRelationship';
import getStatusColors from '@salesforce/apex/StatusColorController.getStatusColors';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import DASHBOARD_REFRESH_MESSAGE_CHANNEL from '@salesforce/messageChannel/DashboardRefresh__c';
import PROGRESS_PERCENTAGE_FIELD from '@salesforce/schema/Project_Task__c.Progress_Percentage__c';
import { ensureSitePath } from 'c/portalCommon';

export default class TaskContextPanel extends NavigationMixin(LightningElement) {
    /**
     * @description Record ID of the Project Task to display context for
     * @type {string}
     */
    @api recordId;
    
    /**
     * @description Whether to show the Link Task button. Defaults to true.
     * @type {boolean}
     */
    @api showLinkTaskButton;
    
    /**
     * @description Whether component is in portal/Experience Cloud context. When true, uses portal navigation.
     * @type {boolean}
     */
    @api isPortalMode = false;
    
    /**
     * @description Getter for showLinkTaskButton that defaults to true if not set
     * Hide in portal mode - portal users should not be able to link tasks
     * @returns {boolean}
     */
    get shouldShowLinkTaskButton() {
        // Hide in portal mode
        if (this.isPortalMode) {
            return false;
        }
        return this.showLinkTaskButton !== false;
    }
    
    /**
     * @description Getter to check if relationship actions (edit/delete) should be shown
     * Hide in portal mode - portal users should not be able to edit or delete relationships
     * @returns {boolean}
     */
    get shouldShowRelationshipActions() {
        return !this.isPortalMode;
    }
    
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
     * @description Status colors from field metadata (loaded from Apex)
     * @type {Object}
     */
    statusColors = {};
    
    // Wire service to get status colors from Apex
    @wire(getStatusColors)
    wiredStatusColors({ error, data }) {
        if (data) {
            this.statusColors = data || {};
        } else if (error) {
            console.error('Error loading status colors in taskContextPanel:', error);
        }
    }
    
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
    
    // Track if we've completed initial load
    _recordWireInitialized = false;
    // Track last refresh time to prevent excessive refreshes
    _lastRefreshTime = 0;
    // Debounce timeout ID
    _refreshTimeoutId = null;
    
    /**
     * @description Get progress percentage from the record itself if no subtasks
     * Also listens for record updates via Lightning Data Service
     * When the record page refreshes (e.g., after quick actions), this wire service
     * is re-evaluated by Salesforce, which we use as a signal to refresh dependency data
     * 
     * The @wire(getRecord) service automatically subscribes to record changes and will
     * fire when:
     * 1. The record itself is updated
     * 2. The record page refreshes (e.g., after quick actions complete)
     * 3. Related records are created/updated/deleted via standard UI (triggers page refresh)
     * 
     * This is the out-of-the-box LDS connection that automatically listens for changes.
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
        // This happens when:
        // 1. The record page refreshes after quick actions complete (creates child records)
        // 2. Related records are created/updated/deleted via standard UI
        // 3. The record itself is updated
        if (data && this._recordWireInitialized) {
            // Debounce refreshes to prevent excessive API calls
            // Clear any pending refresh
            if (this._refreshTimeoutId) {
                clearTimeout(this._refreshTimeoutId);
            }
            
            // Schedule a refresh with a delay to ensure related record creation has completed
            // This is especially important for quick actions that create child records
            const now = Date.now();
            const timeSinceLastRefresh = now - this._lastRefreshTime;
            const minRefreshInterval = 500; // Minimum 500ms between refreshes
            
            if (timeSinceLastRefresh >= minRefreshInterval) {
                // Refresh immediately if enough time has passed
                this._refreshTimeoutId = setTimeout(() => {
                    this._refreshDependencyData();
                    this._lastRefreshTime = Date.now();
                    this._refreshTimeoutId = null;
                }, 300);
            } else {
                // Wait a bit longer if we just refreshed
                this._refreshTimeoutId = setTimeout(() => {
                    this._refreshDependencyData();
                    this._lastRefreshTime = Date.now();
                    this._refreshTimeoutId = null;
                }, minRefreshInterval - timeSinceLastRefresh + 300);
            }
        }
        
        // Mark wire service as initialized after first successful data load
        if (data) {
            this._recordWireInitialized = true;
        }
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
        
        // Listen for record change events via Lightning Data Service
        // This will fire when the record or related records are modified via standard UI
        if (this.recordId) {
            this._subscribeToRecordChanges();
        }
    }
    
    /**
     * @description Subscribe to Lightning Data Service record change notifications
     * Uses the recordUpdated event which fires when the record is updated
     * Note: This will also fire when the record page refreshes after quick actions complete
     */
    _subscribeToRecordChanges() {
        // The @wire(getRecord) service automatically subscribes to record changes
        // When related records are created via standard UI (quick actions, related lists),
        // Salesforce automatically refreshes the record page, which triggers the wire service
        // We handle this in the wiredRecord method above
        
        // Additionally, we can listen for the recordUpdated event if needed
        // This is handled automatically by the @wire(getRecord) service
    }
    
    /**
     * @description Notify LDS that the record has changed
     * This can be called manually if needed to trigger a refresh
     * Salesforce automatically calls this for standard UI operations (quick actions, related lists, etc.)
     */
    _notifyRecordChange() {
        if (this.recordId) {
            const notifyChangeIds = new NotifyChangeRecordIds([this.recordId]);
            getRecordNotifyChange(notifyChangeIds).then(() => {
                // Notification sent - the wired services will automatically refresh
                console.log('Record change notification sent for:', this.recordId);
            }).catch(error => {
                console.error('Error notifying record change:', error);
            });
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
        return this._subtasksExpanded ? 'utility:chevrondown' : 'utility:chevronup';
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
    
    get parentTaskStatusBadgeStyle() {
        if (!this.parentTask?.status) {
            return '';
        }
        return this.getStatusBadgeStyle(this.parentTask.status);
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
        
        const task = {
            id: String(taskProxy.id || ''),
            name: String(taskProxy.name || ''),
            status: String(taskProxy.status || ''),
            priority: String(taskProxy.priority || ''),
            type: String(taskProxy.type || ''),
            isBlocking: Boolean(taskProxy.isBlocking),
            isAtRisk: Boolean(taskProxy.isAtRisk),
            relationshipId: taskProxy.relationshipId ? String(taskProxy.relationshipId) : null,
            hoverFields: taskProxy.hoverFields || [] // Pass raw hoverFields to taskHoverCard component
        };
        
        return task;
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
                    task.statusBadgeStyle = this.getStatusBadgeStyle(task.status);
                    task.priorityBadgeClass = this.getPriorityBadgeClassForPriority(task.priority);
                    // Add blocking classes
                    task.blockingContextItemClass = task.isBlocking 
                        ? 'context-item context-item-blocking slds-m-bottom_small'
                        : 'context-item slds-m-bottom_small';
                    // Badge styling: red for "Blocking", orange for "Blocking Dependency" type, light gray for others
                    if (task.isBlocking) {
                        task.blockingBadgeClass = 'slds-badge blocking-badge context-type-badge';
                    } else if (task.type === 'Blocking Dependency') {
                        task.blockingBadgeClass = 'slds-badge blocking-dependency-badge context-type-badge';
                    } else {
                        task.blockingBadgeClass = 'slds-badge slds-badge_lightest context-type-badge';
                    }
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
     * @description Get inline style for status badge using dynamic colors from field metadata
     * @param {String} status - Task status
     * @returns {String} Inline style string
     */
    getStatusBadgeStyle(status) {
        if (!status || !this.statusColors || Object.keys(this.statusColors).length === 0) {
            return '';
        }
        
        const backgroundColor = this.statusColors[status];
        if (!backgroundColor) {
            return '';
        }
        
        // Determine text color based on background brightness
        const textColor = this.getContrastTextColor(backgroundColor);
        
        return `background-color: ${backgroundColor}; color: ${textColor};`;
    }
    
    /**
     * @description Get contrasting text color (black or white) based on background color
     */
    getContrastTextColor(hexColor) {
        if (!hexColor) return '#080707';
        
        // Remove # if present
        const hex = hexColor.replace('#', '');
        
        // Convert to RGB
        const r = parseInt(hex.substr(0, 2), 16);
        const g = parseInt(hex.substr(2, 2), 16);
        const b = parseInt(hex.substr(4, 2), 16);
        
        // Calculate relative luminance
        const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
        
        // Return black for light colors, white for dark colors
        return luminance > 0.5 ? '#080707' : '#ffffff';
    }
    
    /**
     * @description Get CSS class for priority badge based on priority value
     * Uses custom CSS classes to ensure colors display correctly
     */
    getPriorityBadgeClassForPriority(priority) {
        if (!priority) {
            return 'slds-badge priority-badge priority-badge-none';
        }
        
        const normalizedPriority = String(priority).toLowerCase();
        
        if (normalizedPriority === 'high') {
            return 'slds-badge priority-badge priority-badge-high';
        }
        if (normalizedPriority === 'medium') {
            return 'slds-badge priority-badge priority-badge-medium';
        }
        if (normalizedPriority === 'low') {
            return 'slds-badge priority-badge priority-badge-low';
        }
        
        return 'slds-badge priority-badge priority-badge-none';
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
     * @description Get files for display
     */
    get files() {
        if (!this._files || this._files.length === 0) {
            return [];
        }
        
        return this._files.map(file => ({
            ...file,
            downloadUrl: `/sfc/servlet.shepherd/document/download/${file.versionId}`,
            formattedSize: this.formatFileSize(file.size),
            formattedDate: this.formatFileDate(file.createdDate)
        }));
    }
    
    get hasFiles() {
        return this._files && this._files.length > 0;
    }
    
    get filesCount() {
        return this._files ? this._files.length : 0;
    }
    
    /**
     * @description Format file size for display
     */
    formatFileSize(bytes) {
        if (!bytes || bytes === 0) {
            return '0 B';
        }
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
    }
    
    /**
     * @description Format file date for display
     */
    formatFileDate(dateValue) {
        if (!dateValue) {
            return '';
        }
        const date = new Date(dateValue);
        return date.toLocaleDateString('en-US', { 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric' 
        });
    }
    
    
    /**
     * @description Lifecycle hook - component is removed from the DOM
     */
    disconnectedCallback() {
        if (this._refreshSubscription) {
            unsubscribe(this._refreshSubscription);
            this._refreshSubscription = null;
        }
        
        // Clear any pending refresh timeout
        if (this._refreshTimeoutId) {
            clearTimeout(this._refreshTimeoutId);
            this._refreshTimeoutId = null;
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
     * Uses portal navigation if isPortalMode is true, otherwise uses standard Salesforce navigation
     */
    navigateToTask(event) {
        const taskId = event?.currentTarget?.dataset?.id;
        
        if (!taskId) {
            console.warn('No task ID found in click event');
            return;
        }
        
        // Use portal navigation if in portal mode
        if (this.isPortalMode) {
            // Portal URL format: /project-task/:recordId
            const taskUrl = `/project-task/${taskId}`;
            const targetUrl = ensureSitePath(taskUrl, { currentPathname: window.location.pathname });
            
            console.log('Navigating to task:', { taskId, taskUrl, targetUrl, currentPathname: window.location.pathname });
            
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: targetUrl
                }
            });
        } else {
            // Use standard Salesforce navigation
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: taskId,
                    actionName: 'view'
                }
            });
        }
    }
    
    /**
     * @description Open the link task modal
     */
    openLinkTaskModal() {
        const modal = this.template.querySelector('c-link-task-modal');
        if (modal) {
            modal.open();
        } else {
            console.error('Link Task Modal not found. Component may not be loaded.');
            this.showToast('Error', 'Unable to open Link Task modal. Please refresh the page.', 'error');
        }
    }
    
    /**
     * @description Show toast notification
     */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant || 'info'
        }));
    }
    
    /**
     * @description Handle relationship created event from modal
     * Refresh the dependency data to show the new relationship
     */
    handleRelationshipCreated() {
        // Refresh dependency data to show the new relationship
        this._refreshDependencyData();
    }
    
    /**
     * @description Handle delete relationship button click
     */
    /**
     * @description Handle menu selection (Edit or Delete)
     */
    handleMenuSelect(event) {
        event.stopPropagation(); // Prevent navigation when clicking menu
        
        const action = event.detail.value;
        
        // Find the relationship ID from the parent div
        let element = event.currentTarget;
        let relationshipId = null;
        
        // Traverse up the DOM to find the div with data-relationship-id
        while (element && !relationshipId) {
            relationshipId = element.dataset?.relationshipId;
            if (!relationshipId) {
                element = element.parentElement;
            }
        }
        
        if (!relationshipId) {
            this.showToast('Error', 'Relationship ID not found', 'error');
            return;
        }
        
        if (action === 'edit') {
            this.handleEditRelationship(relationshipId);
        } else if (action === 'delete') {
            this.handleDeleteRelationship(relationshipId);
        }
    }
    
    /**
     * @description Handle edit relationship action
     */
    async handleEditRelationship(relationshipId) {
        const modal = this.template.querySelector('c-link-task-modal');
        if (modal) {
            await modal.openForEdit(relationshipId);
        }
    }
    
    /**
     * @description Handle relationship updated event from modal
     */
    handleRelationshipUpdated() {
        this._refreshDependencyData();
    }
    
    async handleDeleteRelationship(relationshipId) {
        if (!relationshipId) {
            this.showToast('Error', 'Relationship ID not found', 'error');
            return;
        }
        
        // Confirm deletion
        if (!confirm('Are you sure you want to delete this relationship?')) {
            return;
        }
        
        try {
            await deleteTaskRelationship({ relationshipId });
            this.showToast('Success', 'Relationship deleted successfully', 'success');
            // Refresh dependency data to reflect the deletion
            this._refreshDependencyData();
        } catch (error) {
            console.error('Error deleting relationship:', error);
            const errorMessage = error.body?.message || error.message || 'An error occurred while deleting the relationship';
            this.showToast('Error', errorMessage, 'error');
        }
    }
    
    /**
     * @description Show toast notification
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}

