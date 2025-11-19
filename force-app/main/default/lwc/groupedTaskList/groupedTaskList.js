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
    filteredStatusGroups = []; // Filtered tasks based on "Me" mode
    expandedTasks = new Set(); // Track which tasks have expanded subtasks
    subscription = null;
    _filteredAccountIds = [];
    showMyTasksOnly = false; // "Me" mode toggle
    currentUserId = USER_ID; // Current user ID
    error;
    
    // Account filter dropdown
    accounts = [];
    selectedAccountId = null; // Selected account from dropdown
    
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
    }
    
    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }
    
    @wire(getGroupedTasksWithSubtasks, { accountIds: '$effectiveAccountIds' })
    wiredGroupedTasks({ error, data }) {
        if (data) {
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
            this.applyMeModeFilter();
            this.error = undefined;
        } else if (error) {
            console.error('Error loading grouped tasks:', error);
            this.error = error;
            this.statusGroups = [];
            this.filteredStatusGroups = [];
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
        this.applyMeModeFilter();
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
        const description = record.description ? record.description.trim() : '';
        const latestComment = record.latestComment ? record.latestComment.trim() : '';
        
        return {
            ...record,
            safeDescription: description && description.length > 0 ? description : 'No notes captured yet.',
            hasLatestComment: latestComment && latestComment.length > 0,
            latestCommentText: latestComment,
            latestCommentDateFormatted: record.latestCommentDate ? this.formatDate(record.latestCommentDate) : '',
            statusBadgeClass: this.getStatusBadgeClass(record.status)
        };
    }
    
    get hasData() {
        return this.filteredStatusGroups && this.filteredStatusGroups.length > 0;
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
    
    handleMeModeToggle() {
        this.showMyTasksOnly = !this.showMyTasksOnly;
        this.applyMeModeFilter();
    }
    
    handleAccountChange(event) {
        this.selectedAccountId = event.detail.value || null;
        // The wire will automatically refresh when effectiveAccountIds changes
    }
    
    applyMeModeFilter() {
        if (!this.statusGroups || this.statusGroups.length === 0) {
            this.filteredStatusGroups = [];
            return;
        }
        
        if (!this.showMyTasksOnly) {
            // Show all tasks
            this.filteredStatusGroups = this.statusGroups;
            return;
        }
        
        // Filter to show only tasks assigned to current user (Owner, Developer, or Client User)
        this.filteredStatusGroups = this.statusGroups
            .map(statusGroup => {
                // Filter parent tasks assigned to current user
                const filteredTasks = statusGroup.tasks
                    .map(task => {
                        // Check if task is assigned to current user in any role
                        const isMyTask = this.isTaskAssignedToMe(task);
                        
                        if (isMyTask) {
                            // Filter subtasks to only show those assigned to current user
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
                        // Show parent task if it has subtasks assigned to current user
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
                    .filter(task => task !== null) // Remove tasks that don't match filter
                    .map(task => {
                        // Update icon state for filtered tasks
                        const isExpanded = this.isTaskExpanded(task.id);
                        return {
                            ...task,
                            isExpanded: isExpanded,
                            iconName: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                            iconAltText: isExpanded ? 'Collapse' : 'Expand',
                            subtaskLabel: task.subtaskCount === 1 ? 'subtask' : 'subtasks'
                        };
                    });
                
                // Only include status groups that have tasks after filtering
                if (filteredTasks.length > 0) {
                    // Calculate total estimated hours for filtered tasks
                    let totalEstimatedHours = 0;
                    filteredTasks.forEach(task => {
                        // Add parent task hours
                        if (task.estimatedHours) {
                            totalEstimatedHours += task.estimatedHours;
                        }
                        // Add subtask hours
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
            .filter(group => group !== null); // Remove empty status groups
    }
}

