/**
 * @fileoverview Project Task Dashboard Container Component
 * 
 * This component serves as the main container for the Project Task Dashboard system.
 * It dynamically renders child metric components in a configurable order and handles
 * account filtering via Lightning Message Service (LMS).
 * 
 * Features:
 * - Dynamic component rendering based on configuration
 * - Automatic account filtering when placed on Account record pages
 * - Configurable component visibility and ordering via Lightning App Builder
 * - Cross-component communication via LMS for account filtering
 * 
 * @author Milestone Consulting
 * @since API Version 65.0
 */

import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import { MessageContext, publish } from 'lightning/messageService';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';
import DASHBOARD_REFRESH_MESSAGE_CHANNEL from '@salesforce/messageChannel/DashboardRefresh__c';

/**
 * @description Project Task Dashboard container component
 * 
 * This component orchestrates the display of multiple metric components for Project Tasks.
 * It handles account filtering, component ordering, and visibility based on configuration
 * set in Lightning App Builder.
 * 
 * @example
 * <c-project-task-dashboard
 *     show-status-breakdown="true"
 *     status-breakdown-order="1"
 *     show-hours-metrics="true"
 *     hours-metrics-order="2">
 * </c-project-task-dashboard>
 */
export default class ProjectTaskDashboard extends NavigationMixin(LightningElement) {
    // ============================================================================
    // PUBLIC API PROPERTIES
    // ============================================================================

    /**
     * @description Record ID when component is placed on a record page
     * Automatically populated by Salesforce when on Account record pages
     * @type {string|null}
     */
    @api recordId;

    /**
     * @description Toggle visibility of Account Filter component
     * @type {boolean}
     * @default true
     */
    @api showAccountFilter;

    /**
     * @description Toggle visibility of Status Breakdown component
     * @type {boolean}
     * @default true
     */
    @api showStatusBreakdown;

    /**
     * @description Toggle visibility of Hours Metrics component
     * @type {boolean}
     * @default true
     */
    @api showHoursMetrics;

    /**
     * @description Toggle visibility of Hours Metrics chart (when false, shows metrics in grid layout)
     * @type {boolean}
     * @default true
     */
    @api showHoursMetricsChart;

    /**
     * @description Toggle visibility of Review Status Metrics component
     * @type {boolean}
     * @default true
     */
    @api showReviewStatusMetrics;

    /**
     * @description Toggle visibility of Priority Breakdown component
     * @type {boolean}
     * @default true
     */
    @api showPriorityBreakdown;

    /**
     * @description Toggle visibility of Progress Metrics component
     * @type {boolean}
     * @default true
     */
    @api showProgressMetrics;

    /**
     * @description Toggle visibility of Task List component
     * @type {boolean}
     * @default true
     */
    @api showTaskList;
    
    /**
     * @description Toggle visibility of Due Date Metrics component
     * @type {boolean}
     * @default true
     */
    @api showDueDateMetrics;
    
    /**
     * @description Display order for Account Filter component
     * Lower numbers appear first. Components with the same order maintain insertion order.
     * @type {number}
     * @default 0
     */
    @api accountFilterOrder;

    /**
     * @description Display order for Status Breakdown component
     * @type {number}
     * @default 1
     */
    @api statusBreakdownOrder;

    /**
     * @description Display order for Hours Metrics component
     * @type {number}
     * @default 2
     */
    @api hoursMetricsOrder;

    /**
     * @description Display order for Review Status Metrics component
     * @type {number}
     * @default 3
     */
    @api reviewStatusMetricsOrder;

    /**
     * @description Display order for Priority Breakdown component
     * @type {number}
     * @default 4
     */
    @api priorityBreakdownOrder;

    /**
     * @description Display order for Progress Metrics component
     * @type {number}
     * @default 5
     */
    @api progressMetricsOrder;

    /**
     * @description Display order for Task List component
     * @type {number}
     * @default 6
     */
    @api taskListOrder;
    
    /**
     * @description Display order for Due Date Metrics component
     * @type {number}
     * @default 7
     */
    @api dueDateMetricsOrder;
    
    // ============================================================================
    // PRIVATE PROPERTIES
    // ============================================================================

    /**
     * @description Current account ID for filtering (set when on Account record page)
     * @type {string|null}
     * @private
     */
    accountId = null;

    /**
     * @description Pending account IDs to publish when MessageContext becomes available
     * Used to handle timing issues where account filter needs to be published before
     * MessageContext is wired.
     * @type {Array<string>|null}
     * @private
     */
    _pendingAccountIds = null;

    /**
     * @description Effective record ID extracted from page reference
     * Used when @api recordId is not provided (e.g., when component is placed
     * on Account record page without explicit recordId binding)
     * @type {string|null}
     * @private
     */
    _effectiveRecordId = null;

    /**
     * @description Message context for Lightning Message Service
     * Used to publish account filter changes to child components
     * @type {MessageContext|null}
     * @private
     */
    _messageContext = null;

    /**
     * @description Refresh timestamp to trigger data refresh in child components
     * @type {number}
     * @private
     */
    _refreshTimestamp = Date.now();

    // ============================================================================
    // WIRE SERVICES
    // ============================================================================

    /**
     * @description Wire service for Lightning Message Service context
     * Provides the message context needed to publish messages to subscribed components
     * 
     * @param {Object} result - Wire result object
     * @param {MessageContext} result.data - Message context data (when available)
     * @param {Error} result.error - Error object (if wire failed)
     * @private
     */
    @wire(MessageContext)
    wiredMessageContext(result) {
        // Handle wire result - it might be undefined initially or have error/data
        if (result) {
            const { data, error } = result;
            
            // Store the message context for later use
            this._messageContext = data;
            
            // If we have pending account IDs and messageContext is now available,
            // publish them immediately
            if (data && this._pendingAccountIds !== null) {
                this.publishAccountFilter(this._pendingAccountIds);
                this._pendingAccountIds = null;
            }
        }
    }

    /**
     * @description Wire service to detect current page reference
     * Extracts record ID from page reference when component is placed on Account record page
     * This allows automatic account filtering without requiring explicit recordId binding
     * 
     * @param {Object} pageRef - Current page reference object
     * @param {string} pageRef.type - Page type (e.g., 'standard__recordPage')
     * @param {Object} pageRef.attributes - Page attributes
     * @param {string} pageRef.attributes.recordId - Record ID from page
     * @param {string} pageRef.attributes.objectApiName - Object API name (e.g., 'Account')
     * @private
     */
    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        if (!pageRef) {
            return;
        }

        // Extract record ID from page reference attributes
        // For standard record pages, recordId is in attributes.recordId
        const recordId = pageRef.attributes?.recordId;
        
        if (recordId) {
            // Verify this is an Account record page
            const objectApiName = pageRef.attributes?.objectApiName;
            
            if (objectApiName === 'Account') {
                // Store the effective record ID for use in getRecord wire
                this._effectiveRecordId = recordId;
                
                // Manually trigger account filtering since wire reactivity might not
                // fire immediately when _effectiveRecordId changes
                this.detectAndFilterAccount(recordId);
            }
        }
    }

    /**
     * @description Wire service to fetch Account record details
     * Used to verify Account record and get Account ID when on Account record page
     * This wire is reactive to effectiveRecordId changes
     * 
     * @param {Object} result - Wire result object
     * @param {Object} result.data - Account record data (when available)
     * @param {string} result.data.id - Account ID
     * @param {Error} result.error - Error object (if wire failed or not on Account page)
     * @private
     */
    @wire(getRecord, { recordId: '$effectiveRecordId', fields: [ACCOUNT_OBJECT.Id] })
    wiredAccount({ error, data }) {
        // If we successfully retrieved Account data, filter to that account
        if (data && data.id) {
            this.accountId = data.id;
            
            // Publish account filter via LMS with a small delay to ensure
            // all child components are subscribed and ready to receive messages
            setTimeout(() => {
                this.publishAccountFilter([data.id]);
            }, 200);
        } else if (error) {
            // Not on Account record page or error occurred
            // Only publish empty filter if we're not waiting for page reference
            // (page reference might set effectiveRecordId after this wire fires)
            if (this.effectiveRecordId === null) {
                this.accountId = null;
                setTimeout(() => {
                    this.publishAccountFilter([]);
                }, 200);
            }
        }
    }

    // ============================================================================
    // GETTERS
    // ============================================================================

    /**
     * @description Get effective record ID from @api property or page reference
     * Prioritizes @api recordId if provided, otherwise falls back to page reference
     * 
     * @returns {string|null} Record ID or null if not available
     * @readonly
     */
    get effectiveRecordId() {
        return this.recordId || this._effectiveRecordId;
    }

    /**
     * @description Determine if Account Filter component should be displayed
     * Account filter is automatically hidden on Account record pages since filtering
     * is handled automatically
     * 
     * @returns {boolean} True if Account Filter should be shown
     * @readonly
     */
    get shouldShowAccountFilter() {
        // Hide account filter on Account record pages (auto-filtered)
        if (this.recordId || this._effectiveRecordId) {
            return false;
        }
        
        // Otherwise respect the showAccountFilter property
        // Default to true if not explicitly set to false
        return this.showAccountFilter !== false;
    }

    /**
     * @description Determine if Status Breakdown component should be displayed
     * @returns {boolean} True if Status Breakdown should be shown
     * @readonly
     */
    get shouldShowStatusBreakdown() {
        return this.showStatusBreakdown !== false;
    }

    /**
     * @description Determine if Hours Metrics component should be displayed
     * @returns {boolean} True if Hours Metrics should be shown
     * @readonly
     */
    get shouldShowHoursMetrics() {
        return this.showHoursMetrics !== false;
    }

    /**
     * @description Determine if Review Status Metrics component should be displayed
     * @returns {boolean} True if Review Status Metrics should be shown
     * @readonly
     */
    get shouldShowReviewStatusMetrics() {
        return this.showReviewStatusMetrics !== false;
    }

    /**
     * @description Determine if Priority Breakdown component should be displayed
     * @returns {boolean} True if Priority Breakdown should be shown
     * @readonly
     */
    get shouldShowPriorityBreakdown() {
        return this.showPriorityBreakdown !== false;
    }

    /**
     * @description Determine if Progress Metrics component should be displayed
     * @returns {boolean} True if Progress Metrics should be shown
     * @readonly
     */
    get shouldShowProgressMetrics() {
        return this.showProgressMetrics !== false;
    }

    /**
     * @description Determine if Task List component should be displayed
     * @returns {boolean} True if Task List should be shown
     * @readonly
     */
    get shouldShowTaskList() {
        return this.showTaskList !== false;
    }
    
    get shouldShowDueDateMetrics() {
        return this.showDueDateMetrics !== false;
    }

    /**
     * @description Build ordered list of components to render
     * 
     * Creates an array of component configuration objects that includes:
     * - Component name (for key generation)
     * - Display order (for sorting)
     * - Component type flags (for conditional rendering)
     * 
     * Components are sorted by their order property (lower numbers appear first).
     * Components with the same order maintain their insertion order.
     * 
     * @returns {Array<Object>} Array of component configuration objects
     * @returns {string} returns[].name - Component name/identifier
     * @returns {number} returns[].order - Display order (lower = first)
     * @returns {boolean} returns[].isAccountFilter - True if this is Account Filter component
     * @returns {boolean} returns[].isStatusBreakdown - True if this is Status Breakdown component
     * @returns {boolean} returns[].isHoursMetrics - True if this is Hours Metrics component
     * @returns {boolean} returns[].isReviewStatusMetrics - True if this is Review Status Metrics component
     * @returns {boolean} returns[].isPriorityBreakdown - True if this is Priority Breakdown component
     * @returns {boolean} returns[].isProgressMetrics - True if this is Progress Metrics component
     * @returns {boolean} returns[].isTaskList - True if this is Task List component
     * @readonly
     */
    get orderedComponents() {
        const components = [];

        // Add Account Filter component if it should be shown
        if (this.shouldShowAccountFilter) {
            components.push({
                name: 'accountFilter',
                order: this.accountFilterOrder || 0,
                isAccountFilter: true
            });
        }

        // Add Status Breakdown component if it should be shown
        if (this.shouldShowStatusBreakdown) {
            components.push({
                name: 'statusBreakdown',
                order: this.statusBreakdownOrder || 1,
                isStatusBreakdown: true
            });
        }

        // Add Hours Metrics component if it should be shown
        if (this.shouldShowHoursMetrics) {
            components.push({
                name: 'hoursMetrics',
                order: this.hoursMetricsOrder || 2,
                isHoursMetrics: true
            });
        }

        // Add Review Status Metrics component if it should be shown
        if (this.shouldShowReviewStatusMetrics) {
            components.push({
                name: 'reviewStatusMetrics',
                order: this.reviewStatusMetricsOrder || 3,
                isReviewStatusMetrics: true
            });
        }

        // Add Priority Breakdown component if it should be shown
        if (this.shouldShowPriorityBreakdown) {
            components.push({
                name: 'priorityBreakdown',
                order: this.priorityBreakdownOrder || 4,
                isPriorityBreakdown: true
            });
        }

        // Add Progress Metrics component if it should be shown
        if (this.shouldShowProgressMetrics) {
            components.push({
                name: 'progressMetrics',
                order: this.progressMetricsOrder || 5,
                isProgressMetrics: true
            });
        }

        // Add Task List component if it should be shown
        if (this.shouldShowTaskList) {
            components.push({
                name: 'taskList',
                order: this.taskListOrder || 6,
                isTaskList: true
            });
        }
        
        if (this.shouldShowDueDateMetrics) {
            components.push({
                name: 'dueDateMetrics',
                order: this.dueDateMetricsOrder || 7,
                isDueDateMetrics: true
            });
        }
        
        // Sort components by order property (ascending)
        // Components with the same order maintain insertion order
        return components.sort((a, b) => a.order - b.order);
    }

    // ============================================================================
    // PRIVATE METHODS
    // ============================================================================

    /**
     * @description Manually detect Account record page and filter to that account
     * 
     * This method is called when the page reference detects an Account record page.
     * It sets the accountId and publishes the filter via LMS to notify all child
     * components to filter their data to this account.
     * 
     * @param {string} accountId - Account ID to filter to
     * @private
     */
    detectAndFilterAccount(accountId) {
        if (!accountId) {
            return;
        }

        // Store the account ID for passing to child components via property
        this.accountId = accountId;

        // Publish account filter via LMS with a small delay to ensure
        // all child components are subscribed and ready to receive messages
        setTimeout(() => {
            this.publishAccountFilter([accountId]);
        }, 200);
    }

    /**
     * @description Publish account filter via Lightning Message Service
     * 
     * Sends account filter information to all subscribed child components via LMS.
     * If MessageContext is not yet available, stores the account IDs to publish later.
     * 
     * Message format:
     * - accountIds: Array of Account IDs (supports multi-select filtering)
     * - accountId: Single Account ID (for backward compatibility with older components)
     * 
     * @param {Array<string>} accountIds - Array of Account IDs to filter by
     *   Empty array means "show all accounts" (no filter)
     * @private
     */
    publishAccountFilter(accountIds = []) {
        // Ensure accountIds is an array
        const accountIdArray = Array.isArray(accountIds) ? accountIds : [];

        // If MessageContext is available, publish immediately
        if (this._messageContext) {
            const message = {
                accountIds: accountIdArray,
                // Include single accountId for backward compatibility
                accountId: accountIdArray.length > 0 ? accountIdArray[0] : null
            };

            publish(this._messageContext, ACCOUNT_FILTER_MESSAGE_CHANNEL, message);
            
            // Clear any pending account IDs since we've published
            this._pendingAccountIds = null;
        } else {
            // MessageContext not yet available, store for later publication
            // This will be published when wiredMessageContext receives the context
            this._pendingAccountIds = accountIdArray;
        }
    }

    /**
     * @description Publish refresh message via Lightning Message Service
     * 
     * Sends a refresh message to all subscribed child components to trigger
     * data refresh without changing account filters.
     * 
     * @private
     */
    publishRefresh() {
        // Update refresh timestamp
        this._refreshTimestamp = Date.now();

        // If MessageContext is available, publish immediately
        if (this._messageContext) {
            const message = {
                refreshTimestamp: this._refreshTimestamp
            };

            publish(this._messageContext, DASHBOARD_REFRESH_MESSAGE_CHANNEL, message);
        }
    }

    /**
     * @description Handle refresh button click
     * Triggers a refresh of all child components
     * @private
     */
    handleRefresh() {
        this.publishRefresh();
    }

    /**
     * @description Component lifecycle hook - auto-refresh on load
     * Triggers an automatic refresh when the component is first loaded
     * Waits for MessageContext to be available before publishing
     */
    connectedCallback() {
        // Auto-refresh after a delay to ensure MessageContext and child components are ready
        // Check if MessageContext is available, if not wait and retry
        const attemptRefresh = () => {
            if (this._messageContext) {
                this.publishRefresh();
            } else {
                // Retry after a short delay if MessageContext not yet available
                setTimeout(attemptRefresh, 100);
            }
        };
        
        // Start attempting refresh after initial delay
        setTimeout(attemptRefresh, 500);
    }
}
