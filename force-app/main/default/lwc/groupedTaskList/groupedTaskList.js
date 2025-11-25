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
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import getGroupedTasksWithSubtasks from '@salesforce/apex/ProjectTaskDashboardController.getGroupedTasksWithSubtasks';
import getAccounts from '@salesforce/apex/ProjectTaskDashboardController.getAccounts';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';
import USER_ID from '@salesforce/user/Id';

export default class GroupedTaskList extends NavigationMixin(LightningElement) {
    @api recordId; // Automatically populated when on a record page (Account)
    @api accountId; // Can be set manually for App/Home pages
    @api showAccountFilter; // Show/hide the account filter dropdown
    
    @wire(MessageContext)
    messageContext;
    
    statusGroups = [];
    filteredStatusGroups = []; // Filtered tasks based on "Me" mode and other toggles
    expandedTasks = new Set(); // Track which tasks have expanded subtasks
    collapsedStatuses = new Set(); // Track collapsed status groups
    subscription = null;
    _filteredAccountIds = [];
    showMyTasksOnly = false; // "Me" mode toggle
    showCompletedTasks = false; // Toggle Completed status visibility (default hidden)
    currentUserId = USER_ID; // Current user ID
    error;
    summaryFieldDefinitions = [];
    summaryFieldDefinitionMap = {};
    
    // Account filter dropdown
    accounts = [];
    selectedAccountId = null; // Selected account from dropdown
    
    // Responsive button handling
    useCompactMode = false; // When true, show buttons in menu
    resizeObserver = null;
    
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
    
    get effectiveAccountIds() {
        // Priority: 1. Message channel filter, 2. recordId (from Account page), 3. selectedAccountId (from dropdown), 4. accountId property
        let accountIds = [];
        
        if (this._filteredAccountIds.length > 0) {
            accountIds = this._filteredAccountIds;
        } else if (this.recordId) {
            accountIds = [this.recordId];
        } else if (this.selectedAccountId) {
            accountIds = [this.selectedAccountId];
        } else if (this.accountId) {
            accountIds = [this.accountId];
        }
        
        // Filter out empty strings and null values
        return accountIds.filter(id => id != null && (typeof id === 'string' ? id.trim().length > 0 : true));
    }
    
    get isFilteredByAccount() {
        return this.effectiveAccountIds.length > 0;
    }
    
    get shouldShowAccountFilter() {
        // Don't show filter on Account record pages (already filtered by recordId)
        // Default to true if not explicitly set to false
        const showFilter = this.showAccountFilter !== false;
        return showFilter && !this.recordId;
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
        
        // Set up resize observer for responsive button handling
        this.setupResizeObserver();
    }
    
    renderedCallback() {
        // Check container width after render
        this.checkContainerWidth();
    }
    
    disconnectedCallback() {
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
            case 'expandCollapseAll':
                this.handleExpandCollapseAll();
                break;
        }
    }
    
    @wire(getGroupedTasksWithSubtasks, { accountIds: '$effectiveAccountIds' })
    wiredGroupedTasks({ error, data }) {
        if (data) {
            this.summaryFieldDefinitions = data.summaryFieldDefinitions || [];
            this.updateSummaryFieldDefinitionMap();
            // Add status header style to each status group and icon info to each task
            this.statusGroups = (data.statusGroups || []).map(statusGroup => {
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
                        return this.decorateTaskRecord({
                            ...subtask,
                            formattedDueDate: subtask.dueDate ? this.formatDate(subtask.dueDate) : '',
                            formattedEstimatedHours: subtask.estimatedHours ? this.formatHours(subtask.estimatedHours) : ''
                        });
                    });
                    
                    return this.decorateTaskRecord({
                        ...task,
                        isExpanded: isExpanded,
                        iconName: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                        iconAltText: isExpanded ? 'Collapse' : 'Expand',
                        subtaskLabel: task.subtaskCount === 1 ? 'subtask' : 'subtasks',
                        formattedDueDate: task.dueDate ? this.formatDate(task.dueDate) : '',
                        formattedEstimatedHours: task.estimatedHours ? this.formatHours(task.estimatedHours) : '',
                        subtasks: subtasks
                    });
                });
                
                return {
                    ...statusGroup,
                    statusClass: this.getStatusClass(statusGroup.status),
                    headerStyle: this.getStatusHeaderStyle(statusGroup.status),
                    totalEstimatedHours: totalEstimatedHours,
                    formattedTotalEstimatedHours: this.formatHours(totalEstimatedHours),
                    tasks: tasks
                };
            });
            this.refreshFilteredStatusGroups();
            this.error = undefined;
        } else if (error) {
            console.error('Error loading grouped tasks:', error);
            this.error = error;
            this.statusGroups = [];
            this.filteredStatusGroups = [];
            this.summaryFieldDefinitions = [];
            this.updateSummaryFieldDefinitionMap();
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
                return {
                    ...task,
                    isExpanded: isExpanded,
                    iconName: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                    iconAltText: isExpanded ? 'Collapse' : 'Expand',
                    subtaskLabel: task.subtaskCount === 1 ? 'subtask' : 'subtasks'
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
    
    handleTaskClick(event) {
        const taskId = event.currentTarget.dataset.taskId;
        if (taskId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: taskId,
                    actionName: 'view'
                }
            });
        }
    }
    
    getStatusClass(status) {
        // Keep for backward compatibility if needed
        return '';
    }
    
    getStatusHeaderStyle(status) {
        const statusColors = {
            'Backlog': 'background-color: #e5e5e5; color: #080707;', // Light gray
            'Pending': 'background-color: #ffb75d; color: #080707;', // Orange/Warning
            'In Progress': 'background-color: #0176d3; color: #ffffff;', // Blue
            'In Review': 'background-color: #5B21B6; color: #ffffff;', // Deep purple/dark blue
            'Blocked': 'background-color: #c23934; color: #ffffff;', // Red
            'Completed': 'background-color: #2e844a; color: #ffffff;', // Green
            'Removed': 'background-color: #706e6b; color: #ffffff;', // Gray
            'Closed': 'background-color: #2e844a; color: #ffffff;' // Green
        };
        return statusColors[status] || 'background-color: #f3f3f3; color: #080707;';
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
        // Check if current user is assigned as Owner, Developer, or Client User
        // Handle undefined, null, and empty string values
        const ownerId = task.ownerId || '';
        const developerId = task.developerId || '';
        const clientUserId = task.clientUserId || '';
        
        return ownerId === this.currentUserId ||
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
            'Removed': 'slds-badge slds-badge_offline',
            'Closed': 'slds-badge slds-badge_success'
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
            return {
                ...field,
                displayValue: hasValue ? displayValue : ''
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
            return {
                ...group,
                isCollapsed,
                statusToggleIconName: isCollapsed ? 'utility:chevronright' : 'utility:chevrondown',
                statusToggleAltText: isCollapsed ? 'Expand status group' : 'Collapse status group'
            };
        });
    }
    
    isStatusCollapsed(status) {
        return this.collapsedStatuses.has(status);
    }
}

