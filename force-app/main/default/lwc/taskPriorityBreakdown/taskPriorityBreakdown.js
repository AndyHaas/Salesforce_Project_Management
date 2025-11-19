/**
 * @description Task Priority Breakdown Component
 * 
 * Displays a breakdown of Project Tasks by priority (High, Medium, Low)
 * with Chart.js doughnut chart visualization and clickable priority cards.
 * 
 * USAGE:
 * - Used in: projectTaskDashboard component (dynamically rendered)
 * - Apex Controller: ProjectTaskDashboardController.getPriorityBreakdown()
 */
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import getPriorityBreakdown from '@salesforce/apex/ProjectTaskDashboardController.getPriorityBreakdown';
import { loadScript } from 'lightning/platformResourceLoader';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';
import DASHBOARD_REFRESH_MESSAGE_CHANNEL from '@salesforce/messageChannel/DashboardRefresh__c';

export default class TaskPriorityBreakdown extends NavigationMixin(LightningElement) {
    @api accountId;
    
    @wire(MessageContext)
    messageContext;
    
    priorityData = {};
    totalTasks = 0;
    chart;
    chartjsInitialized = false;
    subscription = null;
    refreshSubscription = null;
    _filteredAccountIds = [];
    
    get effectiveAccountIds() {
        if (this._filteredAccountIds.length > 0) {
            return this._filteredAccountIds;
        }
        return this.accountId ? [this.accountId] : [];
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
            
            // Subscribe to refresh messages
            this.refreshSubscription = subscribe(
                this.messageContext,
                DASHBOARD_REFRESH_MESSAGE_CHANNEL,
                (message) => this.handleRefresh(message),
                { scope: APPLICATION_SCOPE }
            );
        }
        
        // Set up resize handler for chart
        this.resizeHandler = () => {
            if (this.chart) {
                this.chart.resize();
            }
        };
        window.addEventListener('resize', this.resizeHandler);
    }
    
    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
        
        if (this.refreshSubscription) {
            unsubscribe(this.refreshSubscription);
            this.refreshSubscription = null;
        }
        
        if (this.resizeHandler) {
            window.removeEventListener('resize', this.resizeHandler);
        }
        if (this.resizeObserver) {
            this.resizeObserver.disconnect();
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
    
    @wire(getPriorityBreakdown, { accountIds: '$effectiveAccountIds' })
    wiredPriorityBreakdown({ error, data }) {
        if (data) {
            this.priorityData = data.priorityCounts || {};
            this.totalTasks = data.totalTasks || 0;
            // Wait for next render cycle to ensure canvas elements are in DOM
            setTimeout(() => {
                this.renderChart();
            }, 0);
        } else if (error) {
            console.error('Error loading priority breakdown:', error);
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
                if (this.priorityData && Object.keys(this.priorityData).length > 0) {
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
        if (!this.chartjsInitialized || !window.Chart || !this.priorityData || Object.keys(this.priorityData).length === 0) {
            return;
        }
        
        const canvas = this.template.querySelector('canvas.priorityChart');
        if (!canvas) {
            console.warn('Canvas element not found, retrying...');
            setTimeout(() => {
                this.renderChart();
            }, 100);
            return;
        }
        
        const ctx = canvas.getContext('2d');
        
        if (this.chart) {
            this.chart.destroy();
        }
        
        const priorities = Object.keys(this.priorityData);
        const counts = priorities.map(priority => this.priorityData[priority] || 0);
        
        const priorityColors = {
            'High': '#FF0000',
            'Medium': '#FFD700',
            'Low': '#32CD32'
        };
        
        const backgroundColors = priorities.map(priority => priorityColors[priority] || '#CCCCCC');
        
        // Store reference for onClick handler
        const self = this;
        
        this.chart = new window.Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: priorities,
                datasets: [{
                    data: counts,
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
                        const priorityIndex = element.index;
                        const priority = priorities[priorityIndex];
                        self.navigateToPriorityListView(priority);
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
    
    get priorityCards() {
        const priorities = Object.keys(this.priorityData);
        const priorityColors = {
            'High': '#FF0000',
            'Medium': '#FFD700',
            'Low': '#32CD32'
        };
        
        return priorities.map(priority => ({
            priority: priority,
            count: this.priorityData[priority] || 0,
            percentage: this.totalTasks > 0 
                ? ((this.priorityData[priority] / this.totalTasks) * 100).toFixed(1) 
                : 0,
            color: priorityColors[priority] || '#CCCCCC',
            indicatorStyle: `background-color: ${priorityColors[priority] || '#CCCCCC'}`,
            tooltip: `Click to view ${priority} priority tasks`
        })).sort((a, b) => {
            const order = { 'High': 1, 'Medium': 2, 'Low': 3 };
            return (order[a.priority] || 99) - (order[b.priority] || 99);
        });
    }
    
    get hasData() {
        return this.totalTasks > 0 && Object.keys(this.priorityData).length > 0;
    }
    
    handlePriorityCardClick(event) {
        const priority = event.currentTarget.dataset.priority;
        if (priority) {
            this.navigateToPriorityListView(priority);
        }
    }
    
    /**
     * @description Navigate to a priority-specific list view with optional account filtering
     * 
     * When on an Account record page, automatically filters the list view to that account
     * by passing the account ID via URL state parameters.
     * 
     * @param {string} priority - Task priority (e.g., 'High', 'Medium', 'Low')
     * @private
     */
    navigateToPriorityListView(priority) {
        // Map priority to list view API name
        const priorityToListView = {
            'High': 'High_Priority_Tasks',
            'Medium': 'Medium_Priority_Tasks',
            'Low': 'Low_Priority_Tasks'
        };
        
        const listViewApiName = priorityToListView[priority];
        if (!listViewApiName) {
            return;
        }
        
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

