/**
 * @fileoverview Task Due Date Metrics Component
 * 
 * Displays metrics related to task due dates including overdue tasks,
 * tasks due today, tasks due this week, and overdue percentage.
 * 
 * @author Milestone Consulting
 * @since API Version 65.0
 * 
 * USAGE:
 * - Used in: projectTaskDashboard component (dynamically rendered)
 * - Apex Controller: ProjectTaskDashboardController.getDueDateMetrics()
 */

import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import getDueDateMetrics from '@salesforce/apex/ProjectTaskDashboardController.getDueDateMetrics';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';
import DASHBOARD_REFRESH_MESSAGE_CHANNEL from '@salesforce/messageChannel/DashboardRefresh__c';

/**
 * @description Task Due Date Metrics component
 * 
 * Displays key metrics about task due dates including:
 * - Overdue tasks count
 * - Tasks due today
 * - Tasks due this week
 * - Overdue percentage
 * - Tasks with/without due dates
 */
export default class TaskDueDateMetrics extends NavigationMixin(LightningElement) {
    /**
     * @description Account ID from parent component (for backward compatibility)
     * @type {string}
     */
    @api accountId;
    
    /**
     * @description Message context for LMS subscription
     * @type {MessageContext}
     */
    @wire(MessageContext)
    messageContext;
    
    /**
     * @description Due date metrics data from Apex
     * @type {Object|null}
     */
    dueDateData = null;
    
    /**
     * @description Subscription to account filter messages
     * @type {Object|null}
     */
    subscription = null;
    
    /**
     * @description Subscription to refresh messages
     * @type {Object|null}
     */
    refreshSubscription = null;
    
    /**
     * @description Account IDs from LMS filter
     * @type {Array<string>}
     */
    _filteredAccountIds = [];
    
    /**
     * @description Component lifecycle hook - subscribe to account filter messages
     */
    connectedCallback() {
        if (this.messageContext) {
            this.subscription = subscribe(
                this.messageContext,
                ACCOUNT_FILTER_MESSAGE_CHANNEL,
                (message) => this.handleAccountFilterChange(message),
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
    
    /**
     * @description Component lifecycle hook - unsubscribe from messages
     */
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
    
    /**
     * @description Handle account filter change from LMS
     * @param {Object} message - Message payload with accountIds or accountId
     * @private
     */
    handleAccountFilterChange(message) {
        if (message) {
            if (message.accountIds !== undefined) {
                // New multi-select format
                this._filteredAccountIds = Array.isArray(message.accountIds) ? message.accountIds : [];
            } else if (message.accountId !== undefined) {
                // Backward compatibility - single account ID
                this._filteredAccountIds = message.accountId ? [message.accountId] : [];
            }
        }
    }
    
    /**
     * @description Getter for effective account IDs (LMS filter takes precedence)
     * @returns {Array<string>} Account IDs to use for filtering
     */
    get effectiveAccountIds() {
        // LMS filter takes precedence, fall back to @api property
        if (this._filteredAccountIds.length > 0) {
            return this._filteredAccountIds;
        }
        return this.accountId ? [this.accountId] : [];
    }
    
    /**
     * @description Wire service to fetch due date metrics from Apex
     * @param {Object} result - Wire result object
     * @param {Object} result.data - Due date metrics data
     * @param {Error} result.error - Error object if wire failed
     */
    @wire(getDueDateMetrics, { accountIds: '$effectiveAccountIds' })
    wiredDueDateMetrics({ error, data }) {
        if (data) {
            this.dueDateData = data;
        } else if (error) {
            console.error('Error loading due date metrics:', error);
            this.dueDateData = null;
        }
    }
    
    /**
     * @description Check if component has data to display
     * @returns {boolean} True if data is available
     */
    get hasData() {
        return this.dueDateData !== null;
    }
    
    /**
     * @description Get overdue count with null safety
     * @returns {number} Overdue task count
     */
    get overdueCount() {
        return this.dueDateData?.overdueCount || 0;
    }
    
    /**
     * @description Get tasks due today count with null safety
     * @returns {number} Tasks due today count
     */
    get dueTodayCount() {
        return this.dueDateData?.dueTodayCount || 0;
    }
    
    /**
     * @description Get tasks due this week count with null safety
     * @returns {number} Tasks due this week count
     */
    get dueThisWeekCount() {
        return this.dueDateData?.dueThisWeekCount || 0;
    }
    
    /**
     * @description Get tasks with due date count with null safety
     * @returns {number} Tasks with due date count
     */
    get tasksWithDueDate() {
        return this.dueDateData?.tasksWithDueDate || 0;
    }
    
    /**
     * @description Get tasks without due date count with null safety
     * @returns {number} Tasks without due date count
     */
    get tasksWithoutDueDate() {
        return this.dueDateData?.tasksWithoutDueDate || 0;
    }
    
    /**
     * @description Get overdue percentage rounded to 1 decimal place
     * @returns {string} Overdue percentage as formatted string
     */
    get overduePercentage() {
        if (!this.dueDateData || !this.dueDateData.overduePercentage) {
            return '0.0';
        }
        return Number(this.dueDateData.overduePercentage).toFixed(1);
    }
    
    /**
     * @description Get CSS class for overdue count based on value
     * @returns {string} CSS class name
     */
    get overdueClass() {
        return this.overdueCount > 0 ? 'metric-value alert-value' : 'metric-value success-value';
    }
    
    /**
     * @description Navigate to Overdue Tasks list view
     * @private
     */
    handleOverdueClick() {
        this.navigateToListView('Overdue_Tasks');
    }
    
    /**
     * @description Navigate to Tasks Due Today list view
     * @private
     */
    handleDueTodayClick() {
        this.navigateToListView('Tasks_Due_Today');
    }
    
    /**
     * @description Navigate to Tasks Due This Week list view
     * @private
     */
    handleDueThisWeekClick() {
        this.navigateToListView('Tasks_Due_This_Week');
    }
    
    /**
     * @description Navigate to Tasks Due This Week list view (for Tasks Without Due Date card)
     * @private
     */
    handleTasksWithoutDueDateClick() {
        this.navigateToListView('Tasks_Due_This_Week');
    }
    
    /**
     * @description Navigate to a list view with optional account filtering
     * 
     * When on an Account record page, automatically filters the list view to that account
     * by passing the account ID via URL state parameters.
     * 
     * @param {string} listViewApiName - API name of the list view to navigate to
     * @private
     */
    navigateToListView(listViewApiName) {
        // Build navigation state with list view and optional account filter
        const navigationState = {
            filterName: listViewApiName
        };
        
        // If we have an account filter (from LMS or @api property), add it to URL
        const accountIdToFilter = this.effectiveAccountIds.length > 0 
            ? this.effectiveAccountIds[0] 
            : null;
        
        if (accountIdToFilter) {
            // Pass account ID via URL state parameter
            navigationState.c__accountId = accountIdToFilter;
        }
        
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Project_Task__c',
                actionName: 'list'
            },
            state: navigationState
        });
    }
}


