/**
 * @description Task Progress Metrics Component
 * 
 * Displays progress metrics including average progress, completion rate,
 * at-risk tasks, blocked tasks, and progress distribution by percentage ranges.
 * 
 * USAGE:
 * - Used in: projectTaskDashboard component (dynamically rendered)
 * - Apex Controller: ProjectTaskDashboardController.getProgressMetrics()
 */
import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import getProgressMetrics from '@salesforce/apex/ProjectTaskDashboardController.getProgressMetrics';
import { loadScript } from 'lightning/platformResourceLoader';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';
import DASHBOARD_REFRESH_MESSAGE_CHANNEL from '@salesforce/messageChannel/DashboardRefresh__c';

export default class TaskProgressMetrics extends NavigationMixin(LightningElement) {
    @api accountId;
    
    @wire(MessageContext)
    messageContext;
    
    progressData = null;
    chart;
    chartjsInitialized = false;
    resizeObserver;
    resizeHandler;
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
    
    @wire(getProgressMetrics, { accountIds: '$effectiveAccountIds' })
    wiredProgressMetrics({ error, data }) {
        if (data) {
            this.progressData = data;
            setTimeout(() => {
                this.renderChart();
            }, 0);
        } else if (error) {
            console.error('Error loading progress metrics:', error);
        }
    }
    
    renderedCallback() {
        if (this.chartjsInitialized) {
            return;
        }
        
        loadScript(this, 'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js')
            .then(() => {
                this.chartjsInitialized = true;
                if (this.progressData) {
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
        if (!this.chartjsInitialized || !window.Chart || !this.progressData || !this.progressDistribution) {
            return;
        }
        
        const canvas = this.template.querySelector('canvas.progressChart');
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
        
        const distribution = this.progressDistribution;
        const labels = Object.keys(distribution);
        const data = labels.map(label => distribution[label] || 0);
        
        const backgroundColors = [
            '#E0E0E0', // 0% - Gray
            '#FF6B6B', // 1-25% - Red
            '#FFD93D', // 26-50% - Yellow
            '#6BCF7F', // 51-75% - Light Green
            '#4ECDC4', // 76-99% - Teal
            '#32CD32'  // 100% - Green
        ];
        
        this.chart = new window.Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Tasks',
                    data: data,
                    backgroundColor: backgroundColors
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                resizeDelay: 0,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Number of Tasks'
                        },
                        ticks: {
                            stepSize: 1
                        }
                    },
                    x: {
                        title: {
                            display: true,
                            text: 'Progress Range'
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        callbacks: {
                            label: (context) => {
                                const value = context.parsed.y || 0;
                                const total = this.totalTasks || 1;
                                const percentage = ((value / total) * 100).toFixed(1);
                                return `${value} tasks (${percentage}%)`;
                            }
                        }
                    }
                }
            }
        });
    }
    
    get avgProgress() {
        return this.progressData?.avgProgress || 0;
    }
    
    get avgProgressRounded() {
        return Math.round(this.avgProgress);
    }
    
    get atRiskCount() {
        return this.progressData?.atRiskCount || 0;
    }
    
    get blockedCount() {
        return this.progressData?.blockedCount || 0;
    }
    
    get totalTasks() {
        return this.progressData?.totalTasks || 0;
    }
    
    get completedCount() {
        return this.progressData?.completedCount || 0;
    }
    
    get completionRate() {
        return this.progressData?.completionRate || 0;
    }
    
    get completionRateRounded() {
        return Number(this.completionRate).toFixed(1);
    }
    
    get tasksWithProgress() {
        return this.progressData?.tasksWithProgress || 0;
    }
    
    get tasksWithoutProgress() {
        return this.progressData?.tasksWithoutProgress || 0;
    }
    
    get nearingCompletionCount() {
        return this.progressData?.nearingCompletionCount || 0;
    }
    
    get progressDistribution() {
        return this.progressData?.progressDistribution || {};
    }
    
    get avgProgressByStatus() {
        return this.progressData?.avgProgressByStatus || {};
    }
    
    get progressStyle() {
        return `width: ${this.avgProgressRounded}%`;
    }
    
    get completionRateStyle() {
        return `width: ${this.completionRateRounded}%`;
    }
    
    get hasData() {
        return this.progressData && this.totalTasks > 0;
    }
    
    get progressDistributionItems() {
        const distribution = this.progressDistribution;
        const order = ['0%', '1-25%', '26-50%', '51-75%', '76-99%', '100%'];
        
        return order.map(label => ({
            label: label,
            count: distribution[label] || 0
        }));
    }
    
    get hasStatusProgress() {
        return this.avgProgressByStatus && Object.keys(this.avgProgressByStatus).length > 0;
    }
    
    get statusProgressItems() {
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
        
        const items = Object.keys(this.avgProgressByStatus).map(status => ({
            status: status,
            progress: this.avgProgressByStatus[status],
            order: statusOrder[status] || 99
        }));
        
        return items.sort((a, b) => a.order - b.order);
    }
    
    handleBlockedTasksClick() {
        this.navigateToListView('Blocked_Tasks');
    }
    
    handleTasksAtRiskClick() {
        this.navigateToListView('Tasks_at_Risk');
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
