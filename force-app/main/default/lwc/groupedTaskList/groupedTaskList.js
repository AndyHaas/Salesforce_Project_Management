/**
 * @description Grouped Task List Component
 * 
 * Displays tasks grouped by status with expandable subtasks, hover field details,
 * and "Me" mode filtering. Shows latest Chatter comments for each task.
 * 
 * USAGE:
 * - Used in: Standalone component, can be placed on any Lightning page
 * - Apex Controller: ProjectTaskDashboardController.getGroupedTasksWithSubtasks(), getAccounts()
 */
import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import { deleteRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord } from 'lightning/uiRecordApi';
import PROJECT_TASK_OBJECT from '@salesforce/schema/Project_Task__c';
import getGroupedTasksWithSubtasks from '@salesforce/apex/ProjectTaskDashboardController.getGroupedTasksWithSubtasks';
import getGroupedTasksWithSubtasksByProject from '@salesforce/apex/ProjectTaskDashboardController.getGroupedTasksWithSubtasksByProject';
import getAccounts from '@salesforce/apex/ProjectTaskDashboardController.getAccounts';
import getStatusColors from '@salesforce/apex/ProjectTaskDashboardController.getStatusColors';
import getCurrentUserAccountId from '@salesforce/apex/ProjectTaskDashboardController.getCurrentUserAccountId';
import getDisplayDensity from '@salesforce/apex/DisplayDensityController.getDisplayDensity';
import { refreshApex } from '@salesforce/apex';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';
import USER_ID from '@salesforce/user/Id';

export default class GroupedTaskList extends NavigationMixin(LightningElement) {
    @api recordId; // Automatically populated when on a record page (Account)
    @api accountId; // Can be set manually for App/Home pages
    @api projectId; // Optional project filter
    @api showAccountFilter; // Show/hide the account filter dropdown
    @api useCurrentUserAccount = false; // When true, default to current user's account if none supplied (for portal use)
    @api context = 'portal'; // DEPRECATED: Use isSalesforceContext instead. Kept for backward compatibility.
    @api isSalesforceContext = false; // When true, uses Salesforce navigation and shows account filter; when false (default), uses portal navigation
    
    @wire(MessageContext)
    messageContext;
    
    isExperienceSite = false; // Detect Experience Cloud context to adjust defaults (fallback if context not set)
    statusGroups = [];
    filteredStatusGroups = []; // Filtered tasks based on "Me" mode and other toggles
    isLoading = true; // Show spinner while fetching tasks
    expandedTasks = new Set(); // Track which tasks have expanded subtasks
    collapsedStatuses = new Set(); // Track collapsed status groups
    subscription = null;
    _filteredAccountIds = [];
    refreshInterval = null; // Interval ID for periodic refresh
    showMyTasksOnly = false; // "Me" mode toggle
    showCompletedTasks = false; // Toggle Completed status visibility (default hidden)
    showRemovedTasks = false; // Toggle Removed status visibility (default hidden)
    currentUserId = USER_ID; // Current user ID
    error;
    summaryFieldDefinitions = [];
    summaryFieldDefinitionMap = {};
    @track editingTaskId = null; // Track which task is being edited inline
    @track editingTaskName = ''; // Store the task name being edited
    @track editingField = null; // Track which field is being edited: { taskId, fieldApiName, fieldValue }
    objectPermissions = { canEdit: false, canDelete: false }; // Object-level permissions
    statusColors = {}; // Status colors from field metadata (loaded from Apex)
    recordTypes = []; // Available record types for Project_Task__c
    defaultRecordTypeId = null; // Default record type ID
    
    // Account filter dropdown
    accounts = [];
    selectedAccountId = null; // Selected account from dropdown
    currentUserAccountId = null; // Account associated to the logged-in user (Experience Cloud)
    
    // Responsive button handling
    useCompactMode = false; // When true, show buttons in menu
    resizeObserver = null;
    
    // Density mode: 'comfy' (default) or 'compact' - loaded from user's Salesforce preference
    @track density = 'comfy';
    
    @wire(getAccounts)
    wiredAccounts({ error, data }) {
        if (data) {
            this.accounts = [
                { label: 'All Accounts', value: '' },
                ...data.map(acc => ({
                    label: acc.Name,
                    value: acc.Id
                }))
            ];
        } else if (error) {
            console.error('Error loading accounts:', error);
        }
    }
    
    @wire(getCurrentUserAccountId)
    wiredUserAccount({ error, data }) {
        if (data) {
            this.currentUserAccountId = data;
            // If no other filters are set and useCurrentUserAccount is enabled, apply the user account immediately
            if (this.useCurrentUserAccount) {
                this.refreshFilteredStatusGroups();
            }
        } else if (error) {
            console.warn('Error loading current user account:', error);
        }
    }
    
    @wire(getDisplayDensity)
    wiredDisplayDensity({ error, data }) {
        if (data) {
            // Set density from user's Salesforce preference
            this.density = data === 'compact' ? 'compact' : 'comfy';
            // If data is already loaded, update row classes
            if (this.statusGroups && this.statusGroups.length > 0) {
                this.updateTaskRowClasses();
                this.refreshFilteredStatusGroups();
            }
        } else if (error) {
            console.warn('Error loading display density preference:', error);
            // Default to 'comfy' if we can't load the preference
            this.density = 'comfy';
        }
    }
    
    get effectiveAccountIds() {
        if (this.projectId) {
            return [];
        }
        // Portal: force current user's account (or none) to avoid showing all accounts
        if (this.isExperienceSite) {
            return this.currentUserAccountId ? [this.currentUserAccountId] : [];
        }

        // Priority (internal): 1. message channel filter, 2. recordId, 3. selectedAccountId, 4. accountId, 5. currentUserAccountId (when enabled)
        let accountIds = [];
        
        if (this._filteredAccountIds.length > 0) {
            accountIds = this._filteredAccountIds;
        } else if (this.recordId) {
            accountIds = [this.recordId];
        } else if (this.selectedAccountId) {
            accountIds = [this.selectedAccountId];
        } else if (this.accountId) {
            accountIds = [this.accountId];
        } else if (this.useCurrentUserAccount && this.currentUserAccountId) {
            accountIds = [this.currentUserAccountId];
        }
        
        // Filter out empty strings and null values
        return accountIds.filter(id => id != null && (typeof id === 'string' ? id.trim().length > 0 : true));
    }
    
    get isFilteredByAccount() {
        return this.effectiveAccountIds.length > 0;
    }

    get isPortalMode() {
        // If on a record page (Account record page), always use Salesforce navigation
        if (this.recordId) {
            return false;
        }
        // Use isSalesforceContext property if explicitly set (preferred)
        if (this.isSalesforceContext === true) {
            return false;
        }
        // Fallback to deprecated context property for backward compatibility
        if (this.context === 'salesforce') {
            return false;
        }
        // Fallback to auto-detection if not explicitly set
        return this.isExperienceSite === true;
    }
    
    get shouldShowAccountFilter() {
        // Hide account filter in portal mode or when on a record page
        if (this.isPortalMode) {
            return false;
        }
        // Hide on Account record pages (recordId is set)
        if (this.recordId) {
            return false;
        }
        const showFilter = this.showAccountFilter !== false;
        return showFilter;
    }
    
    connectedCallback() {
        // Status colors will be loaded via wire service
        // Initialize with empty object - will be populated by getStatusColors wire
        // Detect Experience Cloud / community context to hide account filter by default
        try {
            const host = window?.location?.hostname || '';
            this.isExperienceSite = /force\.com|live-preview|site\.com/i.test(host);
        } catch (e) {
            this.isExperienceSite = false;
        }
        
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
        
        // Set up resize observer for responsive button handling
        this.setupResizeObserver();
    }
    
    renderedCallback() {
        // Check container width after render
        this.checkContainerWidth();
    }
    
    setupResizeObserver() {
        // Use requestAnimationFrame to ensure DOM is ready
        requestAnimationFrame(() => {
            const container = this.template.querySelector('.actions-container');
            if (container && window.ResizeObserver) {
                this.resizeObserver = new ResizeObserver(() => {
                    // Use requestAnimationFrame to avoid multiple rapid checks
                    requestAnimationFrame(() => {
                        this.checkContainerWidth();
                    });
                });
                this.resizeObserver.observe(container);
                // Initial check
                this.checkContainerWidth();
            } else if (container) {
                // Fallback if ResizeObserver not available
                this.checkContainerWidth();
            }
        });
    }
    
    checkContainerWidth() {
        const container = this.template.querySelector('.actions-container');
        if (!container) {
            // If container not found, default to non-compact mode
            if (this.useCompactMode) {
                this.useCompactMode = false;
            }
            return;
        }
        
        // Get the actual available width for buttons
        // Account for badge if present
        const badge = this.template.querySelector('lightning-badge');
        const badgeWidth = badge && badge.offsetParent !== null ? (badge.offsetWidth || 0) + 16 : 0; // 16px for margin
        
        // Get container's available width - use getBoundingClientRect for accurate measurement
        const containerRect = container.getBoundingClientRect();
        let containerWidth = containerRect.width;
        
        // Fallback: if width is 0 or very small, try offsetWidth
        if (!containerWidth || containerWidth < 10) {
            containerWidth = container.offsetWidth || 0;
        }
        
        // If still no width, check parent card
        if (!containerWidth || containerWidth < 10) {
            const card = this.template.querySelector('lightning-card');
            if (card) {
                const cardRect = card.getBoundingClientRect();
                containerWidth = cardRect.width || card.offsetWidth || 0;
            }
        }
        
        // Available width for buttons = container width - badge width - padding
        const availableWidth = containerWidth - badgeWidth - 32; // 32px for padding/margins
        
        // Threshold: if available width is less than 500px, use compact mode
        // This accounts for button widths (approx 120px each for 3 buttons = 360px + spacing)
        const threshold = 500;
        const shouldUseCompactMode = availableWidth < threshold;
        
        if (shouldUseCompactMode !== this.useCompactMode) {
            this.useCompactMode = shouldUseCompactMode;
        }
    }
    
    handleMenuSelect(event) {
        const selectedValue = event.detail.value;
        
        switch(selectedValue) {
            case 'myTasks':
                this.handleMeModeToggle();
                break;
            case 'showCompleted':
                this.handleCompletedToggle();
                break;
            case 'showRemoved':
                this.handleRemovedToggle();
                break;
            case 'expandCollapseAll':
                this.handleExpandCollapseAll();
                break;
        }
    }
    
    updateTaskRowClasses() {
        // No longer needed - table structure handles alignment automatically
        // This method is kept for backward compatibility but does nothing
    }
    
    get densityClass() {
        return this.density === 'compact' ? 'density-compact' : 'density-comfy';
    }
    
    // Removed grid-related getters - now using HTML table structure
    
    wiredGroupedTasksResult;
    
    @wire(getGroupedTasksWithSubtasks, { accountIds: '$effectiveAccountIds' })
    wiredGroupedTasks(result) {
        if (this.projectId) {
            return;
        }
        this.wiredGroupedTasksResult = result;
        const { error, data } = result;
        this.isLoading = !data && !error;
        if (data) {
            try {
                const statusGroupsData = Array.isArray(data.statusGroups) ? data.statusGroups : [];
                this.summaryFieldDefinitions = Array.isArray(data.summaryFieldDefinitions) ? data.summaryFieldDefinitions : [];
            this.updateSummaryFieldDefinitionMap();
            // Update header classes after definitions are loaded
            this.updateSummaryFieldHeaderClasses();
            
            // Set up periodic refresh for auto-refresh on task changes
            if (!this.refreshInterval) {
                this.setupPeriodicRefresh();
            }
            
            // Add status header style to each status group and icon info to each task
                this.statusGroups = statusGroupsData.map(statusGroup => {
                // Calculate total estimated hours for this status group
                let totalEstimatedHours = 0;
                const tasks = (statusGroup.tasks || []).map(task => {
                    const isExpanded = this.isTaskExpanded(task.id);
                    
                    // Add parent task hours
                    const parentHours = task.estimatedHours || 0;
                    totalEstimatedHours += parentHours;
                    
                    // Add subtask hours
                    const subtasks = (task.subtasks || []).map(subtask => {
                        const subtaskHours = subtask.estimatedHours || 0;
                        totalEstimatedHours += subtaskHours;
                        const subtaskPermissions = this.getTaskPermissions(subtask.id);
                        const subtaskHasMenu = subtaskPermissions.canEdit || subtaskPermissions.canDelete;
                        const decoratedSubtask = this.decorateTaskRecord({
                            ...subtask,
                            formattedDueDate: subtask.dueDate ? this.formatDate(subtask.dueDate) : '',
                            formattedEstimatedHours: subtask.estimatedHours ? this.formatHours(subtask.estimatedHours) : '',
                            isEditing: this.editingTaskId === subtask.id,
                            canEdit: subtaskPermissions.canEdit,
                            canDelete: subtaskPermissions.canDelete,
                            showMenu: subtaskHasMenu
                        });
                        // Update field editing state and computed properties
                        if (decoratedSubtask.summaryFields) {
                            decoratedSubtask.summaryFields = decoratedSubtask.summaryFields.map(field => {
                                const dataTypeUpper = (field.dataType || '').toUpperCase();
                                const isEditing = this.isFieldEditing(subtask.id, field.apiName);
                                const isEditable = subtaskPermissions.canEdit && !field.isReference; // Editable if user can edit and field is not a reference
                                let inputValue = '';
                                let inputType = 'text';
                                
                                if (isEditing && this.editingField) {
                                    if (dataTypeUpper === 'BOOLEAN') {
                                        inputValue = this.editingField.fieldValue === 'true' || this.editingField.fieldValue === true;
                                    } else {
                                        inputValue = this.editingField.fieldValue || '';
                                    }
                                    
                                    if (dataTypeUpper === 'DATE') {
                                        inputType = 'date';
                                    } else if (dataTypeUpper === 'DATETIME') {
                                        inputType = 'datetime-local';
                                    } else if (dataTypeUpper === 'DOUBLE' || dataTypeUpper === 'CURRENCY' || dataTypeUpper === 'PERCENT' || dataTypeUpper === 'INTEGER') {
                                        inputType = 'number';
                                    } else if (dataTypeUpper === 'BOOLEAN') {
                                        inputType = 'checkbox';
                                    }
                                } else {
                                    // Use raw value when not editing
                                    if (dataTypeUpper === 'BOOLEAN') {
                                        inputValue = field.rawValue === 'true' || field.rawValue === true;
                                    } else {
                                        inputValue = field.rawValue || '';
                                    }
                                }
                                
                                return {
                                    ...field,
                                    isEditing: isEditing,
                                    hasDataType: !!field.dataType,
                                    isBoolean: dataTypeUpper === 'BOOLEAN',
                                    inputValue: inputValue,
                                    inputType: inputType,
                                    isEditable: isEditable
                                };
                            });
                        }
                        return decoratedSubtask;
                    });
                    
                    const permissions = this.getTaskPermissions(task.id);
                    const hasMenu = permissions.canEdit || permissions.canDelete;
                    const decoratedTask = this.decorateTaskRecord({
                        ...task,
                        isExpanded: isExpanded,
                        iconName: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                        iconAltText: isExpanded ? 'Collapse' : 'Expand',
                        subtaskLabel: task.subtaskCount === 1 ? 'subtask' : 'subtasks',
                        formattedDueDate: task.dueDate ? this.formatDate(task.dueDate) : '',
                        formattedEstimatedHours: task.estimatedHours ? this.formatHours(task.estimatedHours) : '',
                        subtasks: subtasks,
                        isEditing: this.editingTaskId === task.id,
                        canEdit: permissions.canEdit,
                        canDelete: permissions.canDelete,
                        showMenu: hasMenu
                    });
                    // Update field editing state and computed properties
                    if (decoratedTask.summaryFields) {
                        decoratedTask.summaryFields = decoratedTask.summaryFields.map(field => {
                            const dataTypeUpper = (field.dataType || '').toUpperCase();
                            const isEditing = this.isFieldEditing(task.id, field.apiName);
                            const isEditable = permissions.canEdit && !field.isReference; // Editable if user can edit and field is not a reference
                            let inputValue = '';
                            let inputType = 'text';
                            
                            if (isEditing && this.editingField) {
                                if (dataTypeUpper === 'BOOLEAN') {
                                    inputValue = this.editingField.fieldValue === 'true' || this.editingField.fieldValue === true;
                                } else {
                                    inputValue = this.editingField.fieldValue || '';
                                }
                                
                                if (dataTypeUpper === 'DATE') {
                                    inputType = 'date';
                                } else if (dataTypeUpper === 'DATETIME') {
                                    inputType = 'datetime-local';
                                } else if (dataTypeUpper === 'DOUBLE' || dataTypeUpper === 'CURRENCY' || dataTypeUpper === 'PERCENT' || dataTypeUpper === 'INTEGER') {
                                    inputType = 'number';
                                } else if (dataTypeUpper === 'BOOLEAN') {
                                    inputType = 'checkbox';
                                }
                            } else {
                                // Use raw value when not editing
                                if (dataTypeUpper === 'BOOLEAN') {
                                    inputValue = field.rawValue === 'true' || field.rawValue === true;
                                } else {
                                    inputValue = field.rawValue || '';
                                }
                            }
                            
                            return {
                                ...field,
                                isEditing: isEditing,
                                hasDataType: !!field.dataType,
                                isBoolean: dataTypeUpper === 'BOOLEAN',
                                inputValue: inputValue,
                                inputType: inputType,
                                isEditable: isEditable
                            };
                        });
                    }
                    return decoratedTask;
                });
                
                return {
                    ...statusGroup,
                    statusClass: this.getStatusClass(statusGroup.status),
                    headerStyle: this.getStatusHeaderStyle(statusGroup.status),
                    headerClass: `status-header slds-border_bottom ${this.density === 'comfy' ? 'status-header-comfy' : ''} ${this.density === 'compact' ? 'status-header-compact' : ''}`.trim(),
                    totalEstimatedHours: totalEstimatedHours,
                    formattedTotalEstimatedHours: this.formatHours(totalEstimatedHours),
                    tasks: tasks
                };
            });
            this.refreshFilteredStatusGroups();
            this.error = undefined;
                this.isLoading = false;
            } catch (e) {
                console.error('Error processing grouped tasks response:', e);
                this.error = e;
                this.statusGroups = [];
                this.filteredStatusGroups = [];
                this.summaryFieldDefinitions = [];
                this.updateSummaryFieldDefinitionMap();
                this.isLoading = false;
            }
        } else if (error) {
            console.error('Error loading grouped tasks:', error);
            this.error = error;
            this.statusGroups = [];
            this.filteredStatusGroups = [];
            this.summaryFieldDefinitions = [];
            this.updateSummaryFieldDefinitionMap();
            this.isLoading = false;
        }
    }

    @wire(getGroupedTasksWithSubtasksByProject, { projectId: '$projectId' })
    wiredGroupedTasksByProject(result) {
        if (!this.projectId) {
            return;
        }
        this.wiredGroupedTasksResult = result;
        const { error, data } = result;
        this.isLoading = !data && !error;
        if (data) {
            this.statusGroups = Array.isArray(data.statusGroups) ? data.statusGroups : [];
            this.summaryFieldDefinitions = Array.isArray(data.summaryFieldDefinitions) ? data.summaryFieldDefinitions : [];
            this.filteredStatusGroups = this.filterStatusGroups(this.statusGroups);
            this.error = undefined;
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Error loading grouped tasks by project:', error);
            this.error = { message: this.getErrorMessage(error) };
        }
    }
    
    handleToggleSubtasks(event) {
        const taskId = event.currentTarget.dataset.taskId;
        if (this.expandedTasks.has(taskId)) {
            this.expandedTasks.delete(taskId);
        } else {
            this.expandedTasks.add(taskId);
        }
        // Force re-render by creating a new Set
        this.expandedTasks = new Set(this.expandedTasks);
        
        // Update icon info for all tasks
        this.updateTaskIcons();
    }
    
    updateTaskIcons() {
        this.statusGroups = this.statusGroups.map(statusGroup => ({
            ...statusGroup,
            tasks: statusGroup.tasks.map(task => {
                const isExpanded = this.isTaskExpanded(task.id);
                const permissions = this.getTaskPermissions(task.id);
                return {
                    ...task,
                    isExpanded: isExpanded,
                    iconName: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                    iconAltText: isExpanded ? 'Collapse' : 'Expand',
                    subtaskLabel: task.subtaskCount === 1 ? 'subtask' : 'subtasks',
                    isEditing: this.editingTaskId === task.id,
                    canEdit: permissions.canEdit,
                    canDelete: permissions.canDelete,
                    showMenu: permissions.canEdit || permissions.canDelete
                };
            })
        }));
        // Reapply filter after updating icons
        this.refreshFilteredStatusGroups();
    }
    
    isTaskExpanded(taskId) {
        return this.expandedTasks.has(taskId);
    }
    
    getTaskToggleTitle(taskId) {
        return this.isTaskExpanded(taskId) ? 'Collapse subtasks' : 'Expand subtasks';
    }
    
    getTaskIconName(taskId) {
        return this.isTaskExpanded(taskId) ? 'utility:chevrondown' : 'utility:chevronright';
    }
    
    getTaskIconAltText(taskId) {
        return this.isTaskExpanded(taskId) ? 'Collapse' : 'Expand';
    }
    
    getPortalTaskUrl(taskId) {
        return `/project-task/${taskId}`;
    }
    
    navigateToTask(taskId) {
        if (!taskId) return;
        if (this.isPortalMode) {
            // Use Experience Cloud-friendly URL
            window.location.assign(this.getPortalTaskUrl(taskId));
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
    
    handleTaskClick(event) {
        const taskId = event.currentTarget.dataset.taskId;
        this.navigateToTask(taskId);
    }
    
    getStatusClass(status) {
        // Keep for backward compatibility if needed
        return '';
    }
    
    getStatusHeaderStyle(status) {
        // Use colors from Apex (which reads from field metadata)
        // If not loaded yet, use default colors
        const backgroundColor = this.statusColors[status] || this.getDefaultStatusColors()[status] || '#F3F3F3';
        
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
    
    formatDate(dateValue) {
        if (!dateValue) return '';
        const date = new Date(dateValue);
        return date.toLocaleDateString('en-US', { 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric' 
        });
    }
    
    formatHours(hours) {
        if (!hours && hours !== 0) return '';
        if (hours >= 1) {
            const wholeHours = Math.floor(hours);
            const minutes = Math.round((hours - wholeHours) * 60);
            if (minutes > 0) {
                return `${wholeHours}h ${minutes}m`;
            }
            return `${wholeHours}h`;
        }
        const minutes = Math.round(hours * 60);
        return `${minutes}m`;
    }
    
    isTaskAssignedToMe(task) {
        // Check if current user is assigned as Project Manager, Developer, or Client User
        // Handle undefined, null, and empty string values
        const projectManagerId = task.projectManagerId || '';
        const developerId = task.developerId || '';
        const clientUserId = task.clientUserId || '';
        
        return projectManagerId === this.currentUserId ||
               developerId === this.currentUserId ||
               clientUserId === this.currentUserId;
    }
    
    getStatusBadgeClass(status) {
        const statusClasses = {
            'Backlog': 'slds-badge slds-badge_lightest',
            'Pending': 'slds-badge slds-badge_warning',
            'In Progress': 'slds-badge slds-badge_info',
            'In Review': 'slds-badge slds-badge_inverse',
            'Blocked': 'slds-badge slds-badge_error',
            'Completed': 'slds-badge slds-badge_success',
            'Removed': 'slds-badge slds-badge_offline'
        };
        return statusClasses[status] || 'slds-badge';
    }
    
    decorateTaskRecord(record) {
        // Note: hoverFields decoration is now handled by taskHoverCard component
        // Only decorate summaryFields here
        
        const summaryFields = (record.summaryFields || []).map(field => {
            const definition = this.summaryFieldDefinitionMap[field.apiName] || {};
            const rawValue = field.rawValue;
            let displayValue = field.displayValue;
            const dataType = (definition.dataType || '').toUpperCase();
            
            if (rawValue) {
                if (dataType === 'DATE' || dataType === 'DATETIME') {
                    displayValue = this.formatDate(rawValue);
                } else if (dataType === 'PERCENT') {
                    const percentValue = parseFloat(rawValue);
                    if (!isNaN(percentValue)) {
                        displayValue = `${percentValue.toFixed(2)}%`;
                    }
                }
            }
            
            if (field.apiName && field.apiName.endsWith('_Hours__c') && rawValue) {
                const hoursValue = parseFloat(rawValue);
                if (!isNaN(hoursValue)) {
                    displayValue = this.formatHours(hoursValue);
                }
            }
            
            const hasValue = displayValue !== null && displayValue !== undefined && (!(typeof displayValue === 'string') || displayValue.trim().length > 0);
            const dataTypeUpper = (definition.dataType || '').toUpperCase();
            return {
                ...field,
                displayValue: hasValue ? displayValue : '',
                // Add field definition info for inline editing
                dataType: definition.dataType,
                isReference: definition.isReference,
                label: definition.label || field.label,
                // Add computed properties for template (will be updated in wiredGroupedTasks)
                isEditing: false,
                hasDataType: !!definition.dataType,
                isBoolean: dataTypeUpper === 'BOOLEAN'
            };
        });
        
        return {
            ...record,
            // hoverFields passed as-is to taskHoverCard component
            summaryFields
        };
    }
    
    updateSummaryFieldDefinitionMap() {
        this.summaryFieldDefinitionMap = (this.summaryFieldDefinitions || []).reduce((acc, definition) => {
            if (definition && definition.apiName) {
                acc[definition.apiName] = definition;
            }
            return acc;
        }, {});
    }
    
    get hasData() {
        return this.filteredStatusGroups && this.filteredStatusGroups.length > 0;
    }
    
    get hasSummaryFields() {
        return this.summaryFieldDefinitions && this.summaryFieldDefinitions.length > 0;
    }
    
    // Removed grid-related getters - now using HTML table structure which handles alignment automatically
    
    get isFilteredByAccount() {
        return this.effectiveAccountIds && this.effectiveAccountIds.length > 0;
    }
    
    get displayStatusGroups() {
        return this.filteredStatusGroups;
    }
    
    get meModeButtonLabel() {
        return this.showMyTasksOnly ? 'Show All' : 'My Tasks';
    }
    
    get meModeButtonTitle() {
        return this.showMyTasksOnly 
            ? 'Show all tasks' 
            : 'Show only tasks where you are the Owner, Developer, or Client User';
    }
    
    get meModeButtonVariant() {
        return this.showMyTasksOnly ? 'brand' : 'neutral';
    }
    
    get meModeButtonIcon() {
        return this.showMyTasksOnly ? 'utility:user' : 'utility:user';
    }
    
    get completedToggleLabel() {
        return this.showCompletedTasks ? 'Hide Completed' : 'Show Completed';
    }
    
    get completedToggleTitle() {
        return this.showCompletedTasks
            ? 'Hide tasks that are currently in the Completed status'
            : 'Show tasks that are currently in the Completed status';
    }
    
    get completedToggleIcon() {
        return this.showCompletedTasks ? 'utility:hide' : 'utility:success';
    }
    
    get removedToggleLabel() {
        return this.showRemovedTasks ? 'Hide Removed' : 'Show Removed';
    }
    
    get removedToggleTitle() {
        return this.showRemovedTasks
            ? 'Hide tasks that are currently in the Removed status'
            : 'Show tasks that are currently in the Removed status';
    }
    
    get removedToggleIcon() {
        return this.showRemovedTasks ? 'utility:hide' : 'utility:delete';
    }
    
    get expandCollapseAllLabel() {
        return this.areAllStatusesCollapsed ? 'Expand All' : 'Collapse All';
    }
    
    get expandCollapseAllTitle() {
        return this.areAllStatusesCollapsed
            ? 'Expand all visible status groups'
            : 'Collapse all visible status groups';
    }
    
    get expandCollapseAllIcon() {
        return this.areAllStatusesCollapsed ? 'utility:chevrondown' : 'utility:chevronup';
    }
    
    get expandCollapseAllDisabled() {
        return !this.hasData;
    }
    
    get areAllStatusesCollapsed() {
        if (!this.filteredStatusGroups || this.filteredStatusGroups.length === 0) {
            return false;
        }
        return this.filteredStatusGroups.every(group => this.isStatusCollapsed(group.status));
    }
    
    handleMeModeToggle() {
        this.showMyTasksOnly = !this.showMyTasksOnly;
        this.refreshFilteredStatusGroups();
    }
    
    handleCompletedToggle() {
        this.showCompletedTasks = !this.showCompletedTasks;
        this.refreshFilteredStatusGroups();
    }
    
    handleRemovedToggle() {
        this.showRemovedTasks = !this.showRemovedTasks;
        this.refreshFilteredStatusGroups();
    }
    
    handleStatusToggle(event) {
        const status = event.currentTarget?.dataset?.status;
        if (!status) {
            return;
        }
        const newSet = new Set(this.collapsedStatuses);
        if (newSet.has(status)) {
            newSet.delete(status);
        } else {
            newSet.add(status);
        }
        this.collapsedStatuses = new Set(newSet);
        this.refreshFilteredStatusGroups();
    }
    
    handleExpandCollapseAll() {
        const shouldCollapse = !this.areAllStatusesCollapsed;
        const visibleStatuses = (this.filteredStatusGroups || []).map(group => group.status);
        const updatedSet = new Set(this.collapsedStatuses);
        
        if (shouldCollapse) {
            visibleStatuses.forEach(status => updatedSet.add(status));
        } else {
            visibleStatuses.forEach(status => updatedSet.delete(status));
        }
        
        this.collapsedStatuses = new Set(updatedSet);
        this.refreshFilteredStatusGroups();
    }
    
    handleAccountChange(event) {
        this.selectedAccountId = event.detail.value || null;
        // The wire will automatically refresh when effectiveAccountIds changes
    }
    
    refreshFilteredStatusGroups() {
        if (!this.statusGroups || this.statusGroups.length === 0) {
            this.filteredStatusGroups = [];
            return;
        }
        
        let groups = [...this.statusGroups];
        
        // Always respect the showCompletedTasks toggle, regardless of "My Tasks" mode
        if (!this.showCompletedTasks) {
            groups = groups.filter(group => group.status !== 'Completed');
        }
        
        // Always respect the showRemovedTasks toggle, regardless of "My Tasks" mode
        if (!this.showRemovedTasks) {
            groups = groups.filter(group => group.status !== 'Removed');
        }
        
        if (this.showMyTasksOnly) {
            groups = this.filterGroupsForCurrentUser(groups);
        }
        
        this.filteredStatusGroups = this.decorateStatusGroupsForDisplay(groups);
    }
    
    filterGroupsForCurrentUser(groups) {
        return groups
            .map(statusGroup => {
                const filteredTasks = statusGroup.tasks
                    .map(task => {
                        const isMyTask = this.isTaskAssignedToMe(task);
                        
                        if (isMyTask) {
                            const mySubtasks = (task.subtasks || []).filter(
                                subtask => this.isTaskAssignedToMe(subtask)
                            );
                            return {
                                ...task,
                                subtasks: mySubtasks,
                                subtaskCount: mySubtasks.length,
                                hasSubtasks: mySubtasks.length > 0
                            };
                        }
                        
                        if (task.subtasks && task.subtasks.length > 0) {
                            const mySubtasks = task.subtasks.filter(
                                subtask => this.isTaskAssignedToMe(subtask)
                            );
                            if (mySubtasks.length > 0) {
                                return {
                                    ...task,
                                    subtasks: mySubtasks,
                                    subtaskCount: mySubtasks.length,
                                    hasSubtasks: true
                                };
                            }
                        }
                        return null;
                    })
                    .filter(task => task !== null)
                    .map(task => {
                        const isExpanded = this.isTaskExpanded(task.id);
                        return {
                            ...task,
                            isExpanded: isExpanded,
                            iconName: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                            iconAltText: isExpanded ? 'Collapse' : 'Expand',
                            subtaskLabel: task.subtaskCount === 1 ? 'subtask' : 'subtasks'
                        };
                    });
                
                if (filteredTasks.length > 0) {
                    let totalEstimatedHours = 0;
                    filteredTasks.forEach(task => {
                        if (task.estimatedHours) {
                            totalEstimatedHours += task.estimatedHours;
                        }
                        if (task.subtasks) {
                            task.subtasks.forEach(subtask => {
                                if (subtask.estimatedHours) {
                                    totalEstimatedHours += subtask.estimatedHours;
                                }
                            });
                        }
                    });
                    
                    return {
                        ...statusGroup,
                        tasks: filteredTasks,
                        taskCount: filteredTasks.length,
                        totalEstimatedHours: totalEstimatedHours,
                        formattedTotalEstimatedHours: this.formatHours(totalEstimatedHours)
                    };
                }
                return null;
            })
            .filter(group => group !== null);
    }
    
    decorateStatusGroupsForDisplay(groups) {
        return groups.map(group => {
            const isCollapsed = this.isStatusCollapsed(group.status);
            // Update field editing state for all tasks and subtasks
            const tasks = (group.tasks || []).map(task => {
                const updatedTask = { ...task };
                const taskPermissions = this.getTaskPermissions(task.id);
                // Update field editing state for task fields
                if (updatedTask.summaryFields) {
                    updatedTask.summaryFields = updatedTask.summaryFields.map(field => {
                        const dataTypeUpper = (field.dataType || '').toUpperCase();
                        const isEditing = this.isFieldEditing(task.id, field.apiName);
                        const isEditable = taskPermissions.canEdit && !field.isReference; // Editable if user can edit and field is not a reference
                        let inputValue = '';
                        let inputType = 'text';
                        
                        if (isEditing && this.editingField) {
                            if (dataTypeUpper === 'BOOLEAN') {
                                inputValue = this.editingField.fieldValue === 'true' || this.editingField.fieldValue === true;
                            } else {
                                inputValue = this.editingField.fieldValue || '';
                            }
                            
                            if (dataTypeUpper === 'DATE') {
                                inputType = 'date';
                            } else if (dataTypeUpper === 'DATETIME') {
                                inputType = 'datetime-local';
                            } else if (dataTypeUpper === 'DOUBLE' || dataTypeUpper === 'CURRENCY' || dataTypeUpper === 'PERCENT' || dataTypeUpper === 'INTEGER') {
                                inputType = 'number';
                            } else if (dataTypeUpper === 'BOOLEAN') {
                                inputType = 'checkbox';
                            }
                        } else {
                            // Use raw value when not editing
                            if (dataTypeUpper === 'BOOLEAN') {
                                inputValue = field.rawValue === 'true' || field.rawValue === true;
                            } else {
                                inputValue = field.rawValue || '';
                            }
                        }
                        
                        return {
                            ...field,
                            isEditing: isEditing,
                            hasDataType: !!field.dataType,
                            isBoolean: dataTypeUpper === 'BOOLEAN',
                            inputValue: inputValue,
                            inputType: inputType,
                            isEditable: isEditable
                        };
                    });
                }
                // Update field editing state for subtask fields
                if (updatedTask.subtasks) {
                    updatedTask.subtasks = updatedTask.subtasks.map(subtask => {
                        const updatedSubtask = { ...subtask };
                        const subtaskPermissions = this.getTaskPermissions(subtask.id);
                        if (updatedSubtask.summaryFields) {
                            updatedSubtask.summaryFields = updatedSubtask.summaryFields.map(field => {
                                const dataTypeUpper = (field.dataType || '').toUpperCase();
                                const isEditing = this.isFieldEditing(subtask.id, field.apiName);
                                const isEditable = subtaskPermissions.canEdit && !field.isReference; // Editable if user can edit and field is not a reference
                                let inputValue = '';
                                let inputType = 'text';
                                
                                if (isEditing && this.editingField) {
                                    if (dataTypeUpper === 'BOOLEAN') {
                                        inputValue = this.editingField.fieldValue === 'true' || this.editingField.fieldValue === true;
                                    } else {
                                        inputValue = this.editingField.fieldValue || '';
                                    }
                                    
                                    if (dataTypeUpper === 'DATE') {
                                        inputType = 'date';
                                    } else if (dataTypeUpper === 'DATETIME') {
                                        inputType = 'datetime-local';
                                    } else if (dataTypeUpper === 'DOUBLE' || dataTypeUpper === 'CURRENCY' || dataTypeUpper === 'PERCENT' || dataTypeUpper === 'INTEGER') {
                                        inputType = 'number';
                                    } else if (dataTypeUpper === 'BOOLEAN') {
                                        inputType = 'checkbox';
                                    }
                                } else {
                                    // Use raw value when not editing
                                    if (dataTypeUpper === 'BOOLEAN') {
                                        inputValue = field.rawValue === 'true' || field.rawValue === true;
                                    } else {
                                        inputValue = field.rawValue || '';
                                    }
                                }
                                
                                return {
                                    ...field,
                                    isEditing: isEditing,
                                    hasDataType: !!field.dataType,
                                    isBoolean: dataTypeUpper === 'BOOLEAN',
                                    inputValue: inputValue,
                                    inputType: inputType,
                                    isEditable: isEditable
                                };
                            });
                        }
                        return updatedSubtask;
                    });
                }
                return updatedTask;
            });
            return {
                ...group,
                tasks: tasks,
                isCollapsed,
                statusToggleIconName: isCollapsed ? 'utility:chevronright' : 'utility:chevrondown',
                statusToggleAltText: isCollapsed ? 'Expand status group' : 'Collapse status group'
            };
        });
    }
    
    isStatusCollapsed(status) {
        return this.collapsedStatuses.has(status);
    }
    
    // Wire service to get status colors from Apex
    @wire(getStatusColors)
    wiredStatusColors({ error, data }) {
        if (data) {
            // Convert the map from Apex to a JavaScript object
            this.statusColors = data || {};
        } else if (error) {
            console.error('Error loading status colors:', error);
            // Fall back to default colors
            this.statusColors = this.getDefaultStatusColors();
        }
    }
    
    // Check object-level permissions using wire adapter
    @wire(getObjectInfo, { objectApiName: PROJECT_TASK_OBJECT })
    wiredObjectInfo({ error, data }) {
        if (data) {
            this.objectPermissions = {
                canEdit: data.updateable || false,
                canDelete: data.deletable || false
            };
            
            // Extract record types
            if (data.recordTypeInfos) {
                const recordTypeEntries = Object.entries(data.recordTypeInfos);
                this.recordTypes = recordTypeEntries
                    .filter(([key, value]) => !value.master) // Exclude master record type
                    .map(([key, value]) => ({
                        label: value.name,
                        value: key
                    }))
                    .sort((a, b) => a.label.localeCompare(b.label));
                
                // Set default record type (first available or master)
                if (this.recordTypes.length > 0) {
                    this.defaultRecordTypeId = this.recordTypes[0].value;
                } else if (data.defaultRecordTypeId) {
                    this.defaultRecordTypeId = data.defaultRecordTypeId;
                }
            }
            
            // Update summaryFieldDefinitions header classes when permissions are loaded
            this.updateSummaryFieldHeaderClasses();
        } else if (error) {
            console.error('Error loading object info:', error);
            this.objectPermissions = { canEdit: false, canDelete: false };
            this.updateSummaryFieldHeaderClasses();
        }
    }
    
    /**
     * @description Get default status colors (fallback)
     * These match the colors in Status__c.field-meta.xml
     */
    getDefaultStatusColors() {
        return {
            'Backlog': '#E5E5E5',
            'Pending': '#FFB75D',
            'In Progress': '#0176D3',
            'In Review': '#5B21B6',
            'Blocked': '#C23934',
            'Completed': '#2E844A',
            'Removed': '#706E6B'
        };
    }
    
    updateSummaryFieldHeaderClasses() {
        // Update header classes for summary field definitions based on editability
        if (this.summaryFieldDefinitions && this.summaryFieldDefinitions.length > 0) {
            this.summaryFieldDefinitions = this.summaryFieldDefinitions.map(field => {
                const isEditable = !this.isPortalMode && this.isFieldEditable(field.apiName);
                return {
                    ...field,
                    headerClass: `summary-header${isEditable ? ' summary-header-editable' : ''}`
                };
            });
        }
    }
    
    getTaskPermissions(taskId) {
        // In portal mode, disable edit/delete
        if (this.isPortalMode) {
            return { canEdit: false, canDelete: false };
        }
        // Use object-level permissions for all tasks
        // Record-level permissions will be enforced by Salesforce when actions are attempted
        return this.objectPermissions;
    }
    
    hasAnyPermission(taskId) {
        const perms = this.getTaskPermissions(taskId);
        return perms.canEdit || perms.canDelete;
    }
    
    isFieldEditable(fieldApiName) {
        // A field is editable if user has edit permissions and field is not a reference
        if (!this.objectPermissions.canEdit) {
            return false;
        }
        const definition = this.summaryFieldDefinitionMap[fieldApiName];
        if (!definition) {
            return false;
        }
        return !definition.isReference;
    }
    
    // Inline editing handlers
    handleTaskNameClick(event) {
        const taskId = event.currentTarget.dataset.taskId;
        if (!taskId) {
            return;
        }
        
        // Navigate with portal-aware routing
        event.preventDefault();
        event.stopPropagation();
        this.navigateToTask(taskId);
    }
    
    handleTaskNameChange(event) {
        this.editingTaskName = event.target.value;
    }
    
    async handleTaskNameSave(event) {
        const taskId = this.editingTaskId;
        if (!taskId || !this.editingTaskName || this.editingTaskName.trim() === '') {
            this.cancelEdit();
            return;
        }
        
        try {
            const fields = {
                Id: taskId,
                Name: this.editingTaskName.trim()
            };
            
            await updateRecord({ fields });
            
            // Update the task in our local data
            this.updateTaskName(taskId, this.editingTaskName.trim());
            
            this.showToast('Success', 'Task name updated successfully', 'success');
            this.cancelEdit();
        } catch (error) {
            console.error('Error updating task name:', error);
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }
    
    handleTaskNameKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleTaskNameSave(event);
        } else if (event.key === 'Escape') {
            event.preventDefault();
            this.cancelEdit();
        }
    }
    
    cancelEdit() {
        this.editingTaskId = null;
        this.editingTaskName = '';
        this.editingField = null;
        // Trigger reactive update to hide edit mode
        this.refreshFilteredStatusGroups();
    }
    
    // Inline field editing handlers
    isFieldEditing(taskId, fieldApiName) {
        return this.editingField && 
               this.editingField.taskId === taskId && 
               this.editingField.fieldApiName === fieldApiName;
    }
    
    handleFieldHover(event) {
        const taskId = event.currentTarget.dataset.taskId;
        const fieldApiName = event.currentTarget.dataset.fieldApiName;
        
        if (!taskId || !fieldApiName) {
            return;
        }
        
        const permissions = this.getTaskPermissions(taskId);
        if (!permissions.canEdit) {
            return; // Don't show edit on hover if user can't edit
        }
        
        // Find the field to check if it's a reference field
        const task = this.findTaskById(taskId);
        if (task) {
            const field = (task.summaryFields || []).find(f => f.apiName === fieldApiName);
            if (field && field.isReference) {
                return; // Don't show edit on hover for reference fields
            }
        }
        
        // Add hover class for visual feedback (pencil icon will show via CSS)
        event.currentTarget.classList.add('field-hover');
    }
    
    handleFieldLeave(event) {
        // Only remove hover class if not editing
        if (!this.editingField || 
            this.editingField.taskId !== event.currentTarget.dataset.taskId ||
            this.editingField.fieldApiName !== event.currentTarget.dataset.fieldApiName) {
            event.currentTarget.classList.remove('field-hover');
        }
    }
    
    handleFieldClick(event) {
        // Prevent event from bubbling up (e.g., to task row click handlers)
        event.preventDefault();
        event.stopPropagation();
        
        // Get taskId and fieldApiName from the clicked element or its parent
        let taskId = event.currentTarget.dataset.taskId;
        let fieldApiName = event.currentTarget.dataset.fieldApiName;
        
        // If clicked on icon or child element, get from parent
        if (!taskId || !fieldApiName) {
            const parent = event.currentTarget.closest('[data-task-id]');
            if (parent) {
                taskId = parent.dataset.taskId;
                fieldApiName = parent.dataset.fieldApiName;
            }
        }
        
        if (!taskId || !fieldApiName) {
            return;
        }
        
        const permissions = this.getTaskPermissions(taskId);
        if (!permissions.canEdit) {
            return; // Don't allow editing if user can't edit
        }
        
        // Find the field value
        const task = this.findTaskById(taskId);
        if (!task) {
            return;
        }
        
        const field = (task.summaryFields || []).find(f => f.apiName === fieldApiName);
        if (!field) {
            return;
        }
        
        // Don't allow editing reference fields (like OwnerId) - they need lookup components
        if (field.isReference) {
            return;
        }
        
            // Open modal for editing
            const modal = this.template.querySelector('c-field-edit-modal');
            if (modal) {
                const definition = this.summaryFieldDefinitionMap[fieldApiName] || {};
                const picklistOptions = definition.picklistValues || [];
                
                modal.open(
                    taskId,
                    fieldApiName,
                    field.label || fieldApiName,
                    field.rawValue || '',
                    field.dataType || definition.dataType || 'STRING',
                    picklistOptions
                );
            }
    }
    
    async handleFieldSaveFromModal(event) {
        const { recordId, fieldApiName, newValue } = event.detail;
        
        // Update the local data immediately for responsive UI
        this.updateFieldValue(recordId, fieldApiName, newValue, this.getFieldDataType(fieldApiName));
        
        // Refresh the wire to get latest data from server
        try {
            await refreshApex(this.wiredGroupedTasksResult);
        } catch (error) {
            console.warn('Error refreshing data after save:', error);
            // Continue with local update even if refresh fails
        }
    }
    
    getFieldDataType(fieldApiName) {
        const definition = this.summaryFieldDefinitionMap[fieldApiName];
        return definition?.dataType || 'STRING';
    }
    
    handleFieldValueChange(event) {
        if (this.editingField) {
            // For checkboxes, use checked property; for other inputs, use value
            if (event.target.type === 'checkbox') {
                this.editingField.fieldValue = event.target.checked;
                // Auto-save boolean fields on change
                this.handleFieldSave(event);
                return;
            } else {
                this.editingField.fieldValue = event.target.value;
            }
            // Create a new object to trigger reactivity
            this.editingField = { ...this.editingField };
            // Trigger reactive update
            this.refreshFilteredStatusGroups();
        }
    }
    
    async handleFieldSave(event) {
        if (!this.editingField) {
            return;
        }
        
        const { taskId, fieldApiName, fieldValue, dataType } = this.editingField;
        
        try {
            const fields = {
                Id: taskId
            };
            
            // Convert value based on field type
            const dataTypeUpper = (dataType || '').toUpperCase();
            if (dataTypeUpper === 'DATE') {
                // For date fields, ensure proper format
                fields[fieldApiName] = fieldValue || null;
            } else if (dataTypeUpper === 'DATETIME') {
                // For datetime fields, ensure proper format
                fields[fieldApiName] = fieldValue || null;
            } else if (dataTypeUpper === 'DOUBLE' || dataTypeUpper === 'CURRENCY' || dataTypeUpper === 'PERCENT') {
                const numValue = fieldValue ? parseFloat(fieldValue) : null;
                fields[fieldApiName] = isNaN(numValue) ? null : numValue;
            } else if (dataTypeUpper === 'INTEGER') {
                const intValue = fieldValue ? parseInt(fieldValue, 10) : null;
                fields[fieldApiName] = isNaN(intValue) ? null : intValue;
            } else if (dataTypeUpper === 'BOOLEAN') {
                // Handle boolean values - can be true, false, 'true', 'false', or null
                if (fieldValue === null || fieldValue === undefined || fieldValue === '') {
                    fields[fieldApiName] = false;
                } else {
                    fields[fieldApiName] = fieldValue === 'true' || fieldValue === true;
                }
            } else {
                // STRING, TEXTAREA, etc.
                fields[fieldApiName] = fieldValue || null;
            }
            
            await updateRecord({ fields });
            
            // Update the field in our local data
            this.updateFieldValue(taskId, fieldApiName, fieldValue, dataType);
            
            this.showToast('Success', 'Field updated successfully', 'success');
            this.cancelEdit();
        } catch (error) {
            console.error('Error updating field:', error);
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }
    
    handleFieldKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleFieldSave(event);
        } else if (event.key === 'Escape') {
            event.preventDefault();
            this.cancelEdit();
        }
    }
    
    getFieldInputType(field) {
        if (!field || !field.dataType) {
            return 'text';
        }
        
        const dataType = field.dataType.toUpperCase();
        
        if (dataType === 'DATE') {
            return 'date';
        } else if (dataType === 'DATETIME') {
            return 'datetime-local';
        } else if (dataType === 'DOUBLE' || dataType === 'CURRENCY' || dataType === 'PERCENT' || dataType === 'INTEGER') {
            return 'number';
        } else if (dataType === 'BOOLEAN') {
            return 'checkbox';
        } else {
            return 'text';
        }
    }
    
    getFieldInputValue(field) {
        if (!this.editingField) {
            return '';
        }
        
        const dataType = (field.dataType || '').toUpperCase();
        if (dataType === 'BOOLEAN') {
            return this.editingField.fieldValue === 'true' || this.editingField.fieldValue === true;
        }
        
        return this.editingField.fieldValue || '';
    }
    
    isBooleanField(field) {
        if (!field || !field.dataType) {
            return false;
        }
        return (field.dataType || '').toUpperCase() === 'BOOLEAN';
    }
    
    hasDataType(field) {
        return field && field.dataType;
    }
    
    findTaskById(taskId) {
        for (const statusGroup of this.statusGroups) {
            for (const task of statusGroup.tasks) {
                if (task.id === taskId) {
                    return task;
                }
                if (task.subtasks) {
                    for (const subtask of task.subtasks) {
                        if (subtask.id === taskId) {
                            return subtask;
                        }
                    }
                }
            }
        }
        return null;
    }
    
    updateFieldValue(taskId, fieldApiName, newValue, dataType) {
        // Update field value in statusGroups
        for (const statusGroup of this.statusGroups) {
            for (const task of statusGroup.tasks) {
                if (task.id === taskId) {
                    const field = (task.summaryFields || []).find(f => f.apiName === fieldApiName);
                    if (field) {
                        // Update rawValue
                        field.rawValue = newValue;
                        // Format displayValue based on data type
                        field.displayValue = this.formatFieldDisplayValue(fieldApiName, newValue, dataType);
                        // Re-decorate the entire task to ensure all computed properties are updated
                        const decorated = this.decorateTaskRecord(task);
                        // Update the task with decorated properties
                        Object.assign(task, decorated);
                        // Force reactive update
                        this.statusGroups = [...this.statusGroups];
                        this.refreshFilteredStatusGroups();
                        return;
                    }
                }
                if (task.subtasks) {
                    for (const subtask of task.subtasks) {
                        if (subtask.id === taskId) {
                            const field = (subtask.summaryFields || []).find(f => f.apiName === fieldApiName);
                            if (field) {
                                // Update rawValue
                                field.rawValue = newValue;
                                // Format displayValue based on data type
                                field.displayValue = this.formatFieldDisplayValue(fieldApiName, newValue, dataType);
                                // Re-decorate the entire subtask to ensure all computed properties are updated
                                const decorated = this.decorateTaskRecord(subtask);
                                // Update the subtask with decorated properties
                                Object.assign(subtask, decorated);
                                // Force reactive update
                                this.statusGroups = [...this.statusGroups];
                                this.refreshFilteredStatusGroups();
                                return;
                            }
                        }
                    }
                }
            }
        }
    }
    
    formatFieldDisplayValue(fieldApiName, rawValue, dataType) {
        if (!rawValue && rawValue !== 0 && rawValue !== false) {
            return '';
        }
        
        const dataTypeUpper = (dataType || '').toUpperCase();
        
        // Format based on data type
        if (dataTypeUpper === 'DATE' || dataTypeUpper === 'DATETIME') {
            return this.formatDate(rawValue);
        } else if (dataTypeUpper === 'PERCENT') {
            const percentValue = parseFloat(rawValue);
            if (!isNaN(percentValue)) {
                return `${percentValue.toFixed(2)}%`;
            }
        } else if (dataTypeUpper === 'BOOLEAN') {
            return rawValue === true || rawValue === 'true' ? 'Yes' : 'No';
        } else if (fieldApiName && fieldApiName.endsWith('_Hours__c')) {
            const hoursValue = parseFloat(rawValue);
            if (!isNaN(hoursValue)) {
                return this.formatHours(hoursValue);
            }
        }
        
        // For picklist fields, return the raw value (it's already the label from the server)
        // For other types, return as string
        return String(rawValue);
    }
    
    updateTaskName(taskId, newName) {
        this.statusGroups = this.statusGroups.map(statusGroup => ({
            ...statusGroup,
            tasks: statusGroup.tasks.map(task => {
                if (task.id === taskId) {
                    const permissions = this.getTaskPermissions(taskId);
                    return { 
                        ...task, 
                        name: newName,
                        isEditing: false,
                        canEdit: permissions.canEdit,
                        canDelete: permissions.canDelete,
                        showMenu: permissions.canEdit || permissions.canDelete
                    };
                }
                if (task.subtasks) {
                    return {
                        ...task,
                        subtasks: task.subtasks.map(subtask => {
                            if (subtask.id === taskId) {
                                const subtaskPermissions = this.getTaskPermissions(taskId);
                                return { 
                                    ...subtask, 
                                    name: newName,
                                    isEditing: false,
                                    canEdit: subtaskPermissions.canEdit,
                                    canDelete: subtaskPermissions.canDelete,
                                    showMenu: subtaskPermissions.canEdit || subtaskPermissions.canDelete
                                };
                            }
                            return subtask;
                        })
                    };
                }
                return task;
            })
        }));
        this.refreshFilteredStatusGroups();
    }
    
    isEditingTask(taskId) {
        return this.editingTaskId === taskId;
    }
    
    // Helper methods for template expressions (LWC doesn't allow function calls in templates)
    getEditingTaskId() {
        return this.editingTaskId;
    }
    
    getEditingTaskName() {
        return this.editingTaskName;
    }
    
    getObjectPermissions() {
        return this.objectPermissions;
    }
    
    // Menu handlers
    handleMenuAction(event) {
        const action = event.detail.value;
        const taskId = event.currentTarget.dataset.taskId;
        
        if (action === 'edit') {
            this.handleEditTask(taskId);
        } else if (action === 'delete') {
            this.handleDeleteTask(taskId);
        }
    }
    
    handleEditTask(taskId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: taskId,
                actionName: 'edit'
            }
        });
    }
    
    handleCreateNewTask() {
        // Build navigation state with record type selection
        const state = {};
        
        // Add URL parameters to force record type selection dialog
        state.nooverride = '1';
        state.useRecordTypeCheck = '1';
        
        // If there are multiple record types, don't pass recordTypeId to show the picker
        // If there's only one record type, use it directly
        if (this.recordTypes.length === 1 && this.defaultRecordTypeId) {
            // Single record type - use it directly
            state.recordTypeId = this.defaultRecordTypeId;
        } else if (this.recordTypes.length > 1) {
            // Multiple record types - don't pass recordTypeId so Salesforce shows the picker
            // Optionally, we can pre-select the default if desired
            // For now, we'll let Salesforce show the picker by not setting recordTypeId
        } else if (this.defaultRecordTypeId) {
            // Fallback: use default if available
            state.recordTypeId = this.defaultRecordTypeId;
        }
        
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Project_Task__c',
                actionName: 'new'
            },
            state: state
        });
    }
    
    async handleDeleteTask(taskId) {
        // Note: In a production environment, you might want to add a confirmation modal
        // For now, we'll proceed with delete and show appropriate toast messages
        
        try {
            await deleteRecord(taskId);
            this.showToast('Success', 'Task deleted successfully', 'success');
            
            // Remove task from local data
            this.removeTaskFromData(taskId);
        } catch (error) {
            console.error('Error deleting task:', error);
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }
    
    removeTaskFromData(taskId) {
        this.statusGroups = this.statusGroups.map(statusGroup => {
            const filteredTasks = statusGroup.tasks.filter(task => task.id !== taskId);
            
            // Also check subtasks
            const tasksWithFilteredSubtasks = filteredTasks.map(task => {
                if (task.subtasks) {
                    const filteredSubtasks = task.subtasks.filter(subtask => subtask.id !== taskId);
                    return {
                        ...task,
                        subtasks: filteredSubtasks,
                        subtaskCount: filteredSubtasks.length,
                        hasSubtasks: filteredSubtasks.length > 0
                    };
                }
                return task;
            });
            
            // Remove status group if no tasks remain
            if (tasksWithFilteredSubtasks.length === 0) {
                return null;
            }
            
            return {
                ...statusGroup,
                tasks: tasksWithFilteredSubtasks,
                taskCount: tasksWithFilteredSubtasks.length
            };
        }).filter(group => group !== null);
        
        this.refreshFilteredStatusGroups();
    }
    
    getErrorMessage(error) {
        if (error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map(e => e.message).join(', ');
            } else if (error.body.message) {
                return error.body.message;
            } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            }
        }
        return error.message || 'An unexpected error occurred';
    }
    
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }
    
    /**
     * @description Set up periodic refresh check for task changes
     * This provides auto-refresh functionality to catch task changes (CDC)
     * The wire service will also automatically refresh when reactive parameters change
     * @private
     */
    setupPeriodicRefresh() {
        // Clear any existing interval
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }
        
        // Check for changes every 30 seconds to catch task updates
        // This ensures the list stays up-to-date when tasks are created or modified
        this.refreshInterval = setInterval(() => {
            if (this.wiredGroupedTasksResult && this.wiredGroupedTasksResult.data) {
                // Refresh the wire service to get latest data
                refreshApex(this.wiredGroupedTasksResult).catch(error => {
                    console.warn('Error during periodic refresh:', error);
                });
            }
        }, 30000); // 30 seconds
    }
    
    /**
     * @description Handle manual refresh button click
     * Refreshes the task list data immediately
     * @private
     */
    async handleManualRefresh() {
        if (this.wiredGroupedTasksResult) {
            try {
                await refreshApex(this.wiredGroupedTasksResult);
                this.showToast('Success', 'Task list refreshed', 'success');
            } catch (error) {
                console.error('Error refreshing task list:', error);
                this.showToast('Error', 'Failed to refresh task list', 'error');
            }
        }
    }
    
    disconnectedCallback() {
        // Clean up periodic refresh interval
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
        
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
        
        // Clean up resize observer
        if (this.resizeObserver) {
            this.resizeObserver.disconnect();
            this.resizeObserver = null;
        }
    }
}

