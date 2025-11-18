import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import getStatusBreakdown from '@salesforce/apex/ProjectTaskDashboardController.getStatusBreakdown';
import { loadScript } from 'lightning/platformResourceLoader';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';

export default class TaskStatusBreakdown extends NavigationMixin(LightningElement) {
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
    
    statusData = {};
    totalTasks = 0;
    chartInitialized = false;
    chart;
    chartjsInitialized = false;
    subscription = null;
    _filteredAccountIds = []; // Account IDs from LMS filter
    
    /**
     * @description Handle account filter change from LMS
     * @param {Object} message - Message payload with accountIds or accountId
     * @private
     */
    handleAccountFilterChange(message) {
        console.log('StatusBreakdown received LMS message:', message);
        if (message) {
            if (message.accountIds !== undefined) {
                // New multi-select format
                this._filteredAccountIds = Array.isArray(message.accountIds) ? message.accountIds : [];
            } else if (message.accountId !== undefined) {
                // Backward compatibility - single account ID
                this._filteredAccountIds = message.accountId ? [message.accountId] : [];
            }
            console.log('StatusBreakdown filteredAccountIds:', this._filteredAccountIds);
        }
    }
    
    /**
     * @description Getter for effective account IDs (LMS filter takes precedence)
     * @returns {Array} Account IDs to use for filtering
     */
    get effectiveAccountIds() {
        // LMS filter takes precedence, fall back to @api property
        if (this._filteredAccountIds.length > 0) {
            return this._filteredAccountIds;
        }
        return this.accountId ? [this.accountId] : [];
    }
    
    @wire(getStatusBreakdown, { accountIds: '$effectiveAccountIds' })
    wiredStatusBreakdown({ error, data }) {
        if (data) {
            this.statusData = data.statusCounts || {};
            this.totalTasks = data.totalTasks || 0;
            // Wait for next render cycle to ensure canvas elements are in DOM
            setTimeout(() => {
                this.renderChart();
            }, 0);
        } else if (error) {
            console.error('Error loading status breakdown:', error);
        }
    }
    
    renderedCallback() {
        if (this.chartjsInitialized) {
            return;
        }
        
        // Load Chart.js only once
        loadScript(this, 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js')
            .then(() => {
                this.chartjsInitialized = true;
                // Render chart if data is already available
                if (this.statusData && Object.keys(this.statusData).length > 0) {
                    setTimeout(() => {
                        this.renderChart();
                        this.setupResizeObserver();
                    }, 0);
                }
            })
            .catch(error => {
                console.error('Error loading Chart.js:', error);
            });
    }
    
    connectedCallback() {
        // Subscribe to account filter messages
        if (this.messageContext) {
            this.subscription = subscribe(
                this.messageContext,
                ACCOUNT_FILTER_MESSAGE_CHANNEL,
                (message) => this.handleAccountFilterChange(message),
                { scope: APPLICATION_SCOPE }
            );
        }
        
        // Listen for window resize events
        this.resizeHandler = () => {
            if (this.chart) {
                this.chart.resize();
            }
        };
        window.addEventListener('resize', this.resizeHandler);
    }
    
    disconnectedCallback() {
        // Unsubscribe from LMS
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
        
        if (this.resizeHandler) {
            window.removeEventListener('resize', this.resizeHandler);
        }
        if (this.resizeObserver) {
            this.resizeObserver.disconnect();
        }
    }
    
    setupResizeObserver() {
        const chartContainer = this.template.querySelector('.chart-container');
        if (chartContainer && window.ResizeObserver) {
            this.resizeObserver = new ResizeObserver(() => {
                if (this.chart) {
                    this.chart.resize();
                }
            });
            this.resizeObserver.observe(chartContainer);
        }
    }
    
    renderChart() {
        if (!this.chartjsInitialized || !window.Chart || !this.statusData || Object.keys(this.statusData).length === 0) {
            return;
        }
        
        const canvas = this.template.querySelector('canvas.statusChart');
        if (!canvas) {
            console.warn('Canvas element not found, retrying...');
            setTimeout(() => {
                this.renderChart();
            }, 100);
            return;
        }
        
        const ctx = canvas.getContext('2d');
        
        // Destroy existing chart if it exists
        if (this.chart) {
            this.chart.destroy();
        }
        
        // Status order matching the picklist order
        const statusOrder = {
            'Backlog': 1,
            'Pending': 2,
            'In Progress': 3,
            'In Review': 4,
            'Blocked': 5,
            'Completed': 6,
            'Removed': 7,
            'Closed': 8
        };
        
        // Sort status labels by picklist order
        const statusLabels = Object.keys(this.statusData).sort((a, b) => {
            const orderA = statusOrder[a] || 99;
            const orderB = statusOrder[b] || 99;
            return orderA - orderB;
        });
        
        const statusCounts = statusLabels.map(status => this.statusData[status] || 0);
        
        // Status colors matching the Status_Color_Indicator__c formula
        const statusColors = {
            'Backlog': '#808080',
            'Pending': '#FFD700',
            'In Progress': '#FF8C00',
            'In Review': '#4169E1',
            'Blocked': '#FF0000',
            'Completed': '#32CD32',
            'Removed': '#000000',
            'Closed': '#32CD32'
        };
        
        const backgroundColors = statusLabels.map(status => statusColors[status] || '#CCCCCC');
        
        // Store reference for onClick handler
        const self = this;
        
        this.chart = new window.Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: statusLabels,
                datasets: [{
                    data: statusCounts,
                    backgroundColor: backgroundColors
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                resizeDelay: 0,
                onClick: (event, elements) => {
                    if (elements.length > 0) {
                        const element = elements[0];
                        const statusIndex = element.index;
                        const status = statusLabels[statusIndex];
                        self.navigateToStatusListView(status);
                    }
                },
                plugins: {
                    legend: {
                        position: 'right',
                        labels: {
                            boxWidth: 12,
                            padding: 8,
                            font: {
                                size: 11
                            }
                        }
                    },
                    tooltip: {
                        callbacks: {
                            label: (context) => {
                                const label = context.label || '';
                                const value = context.parsed || 0;
                                const percentage = this.totalTasks > 0 
                                    ? ((value / this.totalTasks) * 100).toFixed(1) 
                                    : 0;
                                return `${label}: ${value} (${percentage}%)`;
                            }
                        }
                    }
                }
            }
        });
    }
    
    get hasData() {
        return this.totalTasks > 0 && Object.keys(this.statusData).length > 0;
    }
    
    get statusCards() {
        if (!this.hasData) {
            return [];
        }
        
        const statusLabels = Object.keys(this.statusData);
        const statusColors = {
            'Backlog': '#808080',
            'Pending': '#FFD700',
            'In Progress': '#FF8C00',
            'In Review': '#4169E1',
            'Blocked': '#FF0000',
            'Completed': '#32CD32',
            'Removed': '#000000',
            'Closed': '#32CD32'
        };
        
        // Status order matching the picklist order
        const statusOrder = {
            'Backlog': 1,
            'Pending': 2,
            'In Progress': 3,
            'In Review': 4,
            'Blocked': 5,
            'Completed': 6,
            'Removed': 7,
            'Closed': 8
        };
        
        return statusLabels.map(status => ({
            status: status,
            count: this.statusData[status] || 0,
            percentage: this.totalTasks > 0 
                ? ((this.statusData[status] / this.totalTasks) * 100).toFixed(1) 
                : 0,
            color: statusColors[status] || '#CCCCCC',
            indicatorStyle: `background-color: ${statusColors[status] || '#CCCCCC'}`,
            tooltip: `Click to view ${status} tasks`,
            order: statusOrder[status] || 99
        })).sort((a, b) => a.order - b.order);
    }
    
    handleStatusCardClick(event) {
        const status = event.currentTarget.dataset.status;
        if (status) {
            this.navigateToStatusListView(status);
        }
    }
    
    /**
     * @description Navigate to a status-specific list view with optional account filtering
     * 
     * When on an Account record page, automatically filters the list view to that account
     * by passing the account ID via URL state parameters.
     * 
     * @param {string} status - Task status (e.g., 'Backlog', 'Pending', 'In Progress')
     * @private
     */
    navigateToStatusListView(status) {
        // Map status to list view API name
        const statusToListView = {
            'Backlog': 'Backlog_Tasks',
            'Pending': 'Pending_Tasks',
            'In Progress': 'In_Progress_Tasks',
            'In Review': 'In_Review_Tasks',
            'Blocked': 'Blocked_Tasks',
            'Completed': 'Completed_Tasks',
            'Removed': 'Removed_Tasks',
            'Closed': 'Closed_Tasks'
        };
        
        const listViewApiName = statusToListView[status];
        if (!listViewApiName) {
            return;
        }
        
        // Build navigation state with list view and optional account filter
        const navigationState = {
            filterName: listViewApiName
        };
        
        // If we have an account filter (from LMS or @api property), add it to URL
        // Use c__ prefix for custom parameters that can be read by list views
        const accountIdToFilter = this.effectiveAccountIds.length > 0 
            ? this.effectiveAccountIds[0] 
            : null;
        
        if (accountIdToFilter) {
            // Pass account ID via URL state parameter
            // List views can read this via URL parameters or we can use it in a custom component
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

