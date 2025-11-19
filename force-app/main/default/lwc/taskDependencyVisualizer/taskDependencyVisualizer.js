/**
 * @description Task Dependency Visualizer Component
 * 
 * Displays task dependencies including:
 * - Parent task (if this is a subtask)
 * - Related task/dependency (if this task depends on another)
 * - Tasks that depend on this task (reverse dependencies)
 * 
 * Shows blocking status, risk indicators, and allows navigation to related tasks.
 * 
 * @component
 * @author Salesforce LWC
 */
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDependencyData from '@salesforce/apex/ProjectTaskDashboardController.getDependencyData';

export default class TaskDependencyVisualizer extends NavigationMixin(LightningElement) {
    /**
     * @description Record ID of the Project Task to display dependencies for
     * @type {string}
     */
    @api recordId;
    
    /**
     * @description Processed dependency data object
     * @type {Object|null}
     * @private
     */
    _dependencyData = null;
    
    /**
     * @description Loading state indicator
     * @type {boolean}
     * @private
     */
    _isLoading = true;
    
    /**
     * @description Error message if data loading fails
     * @type {string|null}
     * @private
     */
    _error = null;
    
    /**
     * @description State for expanded/collapsed sub tasks section
     * @type {boolean}
     * @private
     */
    _subtasksExpanded = false;
    
    /**
     * @description Wire service to fetch dependency data from Apex
     * 
     * Note: Wire service returns a proxy object. We must never mutate it directly.
     * Always create new objects/arrays when processing wire data.
     * 
     * @param {Object} params - Wire service parameters
     * @param {string} params.taskId - The task ID to fetch dependencies for
     * @param {Object} params.error - Error object if request fails
     * @param {Object} params.data - Response data (proxy object)
     */
    @wire(getDependencyData, { taskId: '$recordId' })
    wiredDependencyData({ error, data }) {
        // Reset loading state
        this._isLoading = false;
        
        // Handle error case first
        if (error) {
            this._handleError(error);
            return;
        }
        
        // Handle null/undefined data
        if (!data) {
            this._dependencyData = this._createEmptyDependencyData();
            this._error = null;
            return;
        }
        
        // Process wire data safely (wire data is a proxy - never mutate directly)
        try {
            this._dependencyData = this._processWireData(data);
            this._error = null;
        } catch (processingError) {
            console.error('Error processing dependency data:', processingError);
            this._handleError('Failed to process dependency data');
        }
    }
    
    /**
     * @description Getter for dependency data (exposed to template)
     * @returns {Object|null} Processed dependency data
     */
    get dependencyData() {
        return this._dependencyData;
    }
    
    /**
     * @description Getter for loading state (exposed to template)
     * @returns {boolean} True if data is loading
     */
    get isLoading() {
        return this._isLoading;
    }
    
    /**
     * @description Getter for error state (exposed to template)
     * @returns {string|null} Error message or null
     */
    get error() {
        return this._error;
    }
    
    /**
     * @description Check if parent task exists
     * @returns {boolean} True if parent task exists
     */
    get hasParentTask() {
        return this._dependencyData?.parentTask != null;
    }
    
    /**
     * @description Check if related task (dependency) exists
     * @returns {boolean} True if related task exists
     */
    get hasRelatedTask() {
        return this._dependencyData?.relatedTask != null;
    }
    
    /**
     * @description Check if any dependent tasks exist
     * @returns {boolean} True if dependent tasks exist
     */
    get hasDependentTasks() {
        const tasks = this._dependencyData?.dependentTasks;
        return Array.isArray(tasks) && tasks.length > 0;
    }
    
    /**
     * @description Check if any sub tasks exist
     * @returns {boolean} True if sub tasks exist
     */
    get hasSubtasks() {
        const tasks = this._dependencyData?.subtasks;
        return Array.isArray(tasks) && tasks.length > 0;
    }
    
    /**
     * @description Check if any dependencies exist at all
     * @returns {boolean} True if any dependency exists
     */
    get hasAnyDependencies() {
        return this.hasParentTask || this.hasRelatedTask || this.hasDependentTasks || this.hasSubtasks;
    }
    
    /**
     * @description Check if current task is at risk due to dependencies
     * @returns {boolean} True if task is at risk
     */
    get isAtRisk() {
        return this._dependencyData?.isAtRisk === true;
    }
    
    /**
     * @description Check if current task is blocking other tasks
     * @returns {boolean} True if task is blocking others
     */
    get isBlocking() {
        return this._dependencyData?.isBlocking === true;
    }
    
    /**
     * @description Get parent task object
     * @returns {Object|null} Parent task or null
     */
    get parentTask() {
        return this._dependencyData?.parentTask || null;
    }
    
    /**
     * @description Get related task object
     * @returns {Object|null} Related task or null
     */
    get relatedTask() {
        return this._dependencyData?.relatedTask || null;
    }
    
    /**
     * @description Get dependent tasks array
     * @returns {Array} Array of dependent tasks (empty array if none)
     */
    get dependentTasks() {
        const tasks = this._dependencyData?.dependentTasks;
        return Array.isArray(tasks) ? tasks : [];
    }
    
    /**
     * @description Get sub tasks array
     * @returns {Array} Array of sub tasks (empty array if none)
     */
    get subtasks() {
        const tasks = this._dependencyData?.subtasks;
        return Array.isArray(tasks) ? tasks : [];
    }
    
    /**
     * @description Get expanded state for sub tasks section
     * @returns {boolean} True if sub tasks section is expanded
     */
    get subtasksExpanded() {
        return this._subtasksExpanded;
    }
    
    /**
     * @description Get icon name for sub tasks expand/collapse button
     * @returns {string} Icon name
     */
    get subtasksToggleIcon() {
        return this._subtasksExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }
    
    /**
     * @description Get CSS class for parent task status badge
     * @returns {string} CSS class name
     */
    get parentTaskStatusBadgeClass() {
        if (!this.parentTask?.status) {
            return 'slds-badge slds-badge_lightest';
        }
        return this.getStatusBadgeClassForStatus(this.parentTask.status);
    }
    
    /**
     * @description Get CSS class for parent task priority badge
     * @returns {string} CSS class name
     */
    get parentTaskPriorityBadgeClass() {
        if (!this.parentTask?.priority) {
            return 'slds-badge slds-badge_lightest';
        }
        return this.getPriorityBadgeClassForPriority(this.parentTask.priority);
    }
    
    /**
     * @description Get CSS class for related task status badge
     * @returns {string} CSS class name
     */
    get relatedTaskStatusBadgeClass() {
        if (!this.relatedTask?.status) {
            return 'slds-badge slds-badge_lightest';
        }
        return this.getStatusBadgeClassForStatus(this.relatedTask.status);
    }
    
    /**
     * @description Get CSS class for related task priority badge
     * @returns {string} CSS class name
     */
    get relatedTaskPriorityBadgeClass() {
        if (!this.relatedTask?.priority) {
            return 'slds-badge slds-badge_lightest';
        }
        return this.getPriorityBadgeClassForPriority(this.relatedTask.priority);
    }
    
    /**
     * @description Process wire service data into a plain object
     * 
     * IMPORTANT: Wire service returns a proxy object. We must extract values
     * without mutating the proxy. Create new objects/arrays for all nested data.
     * 
     * @param {Object} wireData - Data from wire service (proxy object)
     * @returns {Object} Plain object with processed dependency data
     * @private
     */
    _processWireData(wireData) {
        // Extract primitive values first (safe to read from proxy)
        const isAtRisk = Boolean(wireData.isAtRisk);
        const isBlocking = Boolean(wireData.isBlocking);
        
        // Extract nested objects (create new objects, don't reference proxy)
        const parentTask = this._extractTaskObject(wireData.parentTask);
        const relatedTask = this._extractTaskObject(wireData.relatedTask);
        const dependentTasks = this._extractTaskArray(wireData.dependentTasks);
        const subtasks = this._extractTaskArray(wireData.subtasks);
        
        // Return new plain object
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
     * 
     * Creates a new plain object from proxy data. Handles null/undefined safely.
     * 
     * @param {Object|null|undefined} taskProxy - Task object from wire service (may be proxy)
     * @returns {Object|null} Plain task object or null
     * @private
     */
    _extractTaskObject(taskProxy) {
        // Handle null/undefined
        if (!taskProxy) {
            return null;
        }
        
        // Extract primitive values (safe to read from proxy)
        // Create new object with extracted values
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
     * 
     * Creates a new array with new objects. Handles null/undefined/empty arrays safely.
     * Adds computed properties (badge classes) to each task.
     * 
     * @param {Array|null|undefined} tasksProxy - Tasks array from wire service (may be proxy)
     * @returns {Array} Array of plain task objects (empty array if none)
     * @private
     */
    _extractTaskArray(tasksProxy) {
        // Handle null/undefined
        if (!tasksProxy) {
            return [];
        }
        
        // Verify it's an array-like object
        // Note: Proxy arrays are still arrays, but we need to be careful
        if (!Array.isArray(tasksProxy)) {
            return [];
        }
        
        // Handle empty array
        if (tasksProxy.length === 0) {
            return [];
        }
        
        // Map each task to a new object with computed properties
        // Filter out any null/undefined entries
        return tasksProxy
            .map((taskProxy, index) => {
                // Skip null/undefined entries
                if (!taskProxy) {
                    return null;
                }
                
                // Extract base task object
                const task = this._extractTaskObject(taskProxy);
                
                // Add computed properties (badge classes)
                if (task) {
                    task.statusBadgeClass = this.getStatusBadgeClassForStatus(task.status);
                    task.priorityBadgeClass = this.getPriorityBadgeClassForPriority(task.priority);
                }
                
                return task;
            })
            .filter(task => task !== null); // Remove null entries
    }
    
    /**
     * @description Create empty dependency data structure
     * @returns {Object} Empty dependency data object
     * @private
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
     * @param {Object|string} error - Error object or error message
     * @private
     */
    _handleError(error) {
        this._error = typeof error === 'string' ? error : 'An error occurred loading dependency data';
        this._dependencyData = this._createEmptyDependencyData();
        console.error('Dependency Visualizer Error:', error);
    }
    
    /**
     * @description Get CSS class for status badge based on status value
     * @param {string} status - Task status
     * @returns {string} CSS class name for badge
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
     * @param {string} priority - Task priority
     * @returns {string} CSS class name for badge
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
     * @description Navigate to a task record page
     * 
     * Handles click events from dependency items to navigate to task records.
     * 
     * @param {Event} event - Click event from template
     */
    navigateToTask(event) {
        const taskId = event?.currentTarget?.dataset?.id;
        
        if (!taskId) {
            console.warn('No task ID found in click event');
            return;
        }
        
        // Navigate to task record page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: taskId,
                actionName: 'view'
            }
        });
    }
}
