import { LightningElement, api, wire } from 'lwc';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import getHoursMetrics from '@salesforce/apex/ProjectTaskDashboardController.getHoursMetrics';
import { loadScript } from 'lightning/platformResourceLoader';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';

export default class TaskHoursMetrics extends LightningElement {
    @api accountId;
    
    _showChart = true; // Internal storage for API property
    
    @api 
    get showChart() {
        return this._showChart;
    }
    
    set showChart(value) {
        this._showChart = value !== false;
        // Sync internal state if component is already initialized
        if (this._internalShowChart !== undefined) {
            this._internalShowChart = this._showChart;
        }
    }
    
    @wire(MessageContext)
    messageContext;
    
    hoursData = null;
    chartInitialized = false;
    chart;
    chartjsInitialized = false;
    subscription = null;
    _filteredAccountIds = [];
    _internalShowChart = true; // Internal state for checkbox
    
    connectedCallback() {
        // Initialize internal state from API property
        this._internalShowChart = this.showChart !== false;
        
        // Subscribe to account filter messages
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
        
        // Set up resize handler for chart
        this.resizeHandler = () => {
            if (this.chart) {
                this.chart.resize();
            }
        };
        window.addEventListener('resize', this.resizeHandler);
    }
    
    get effectiveAccountIds() {
        if (this._filteredAccountIds.length > 0) {
            return this._filteredAccountIds;
        }
        return this.accountId ? [this.accountId] : [];
    }
    
    
    disconnectedCallback() {
        // Unsubscribe from account filter messages
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
        
        // Remove resize handler
        if (this.resizeHandler) {
            window.removeEventListener('resize', this.resizeHandler);
        }
        
        // Disconnect resize observer
        if (this.resizeObserver) {
            this.resizeObserver.disconnect();
        }
    }
    
    @wire(getHoursMetrics, { accountIds: '$effectiveAccountIds' })
    wiredHoursMetrics({ error, data }) {
        if (data) {
            this.hoursData = data;
            // Wait for next render cycle to ensure canvas elements are in DOM
            if (this._internalShowChart) {
                setTimeout(() => {
                    this.renderChart();
                }, 0);
            }
        } else if (error) {
            console.error('Error loading hours metrics:', error);
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
                // Render chart if data is already available and chart should be shown
                if (this.hoursData && this._internalShowChart) {
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
        if (!this.chartjsInitialized || !window.Chart || !this.hoursData || !this._internalShowChart) {
            return;
        }
        
        // Check if we have data to display
        if (!this.hoursData.hoursByStatus || this.hoursData.hoursByStatus.length === 0) {
            return;
        }
        
        const canvas = this.template.querySelector('canvas.hoursChart');
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
        
        // Sort hoursByStatus by picklist order
        const sortedHoursByStatus = [...this.hoursData.hoursByStatus].sort((a, b) => {
            const orderA = statusOrder[a.status] || 99;
            const orderB = statusOrder[b.status] || 99;
            return orderA - orderB;
        });
        
        const statuses = sortedHoursByStatus.map(h => h.status);
        const estimated = sortedHoursByStatus.map(h => h.estimatedHours || 0);
        const actual = sortedHoursByStatus.map(h => h.actualHours || 0);
        
        this.chart = new window.Chart(ctx, {
            type: 'bar',
            data: {
                labels: statuses,
                datasets: [
                    {
                        label: 'Estimated Hours',
                        data: estimated,
                        backgroundColor: '#0176D3'
                    },
                    {
                        label: 'Actual Hours',
                        data: actual,
                        backgroundColor: '#FFB75D'
                    }
                ]
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
                            text: 'Hours'
                        }
                    },
                    x: {
                        ticks: {
                            maxRotation: 45,
                            minRotation: 0,
                            font: {
                                size: 10
                            }
                        }
                    }
                },
                plugins: {
                    legend: {
                        position: 'top',
                        labels: {
                            boxWidth: 12,
                            padding: 8,
                            font: {
                                size: 11
                            }
                        }
                    }
                }
            }
        });
    }
    
    get totalEstimated() {
        return this.hoursData?.totalEstimated || 0;
    }
    
    get totalActual() {
        return this.hoursData?.totalActual || 0;
    }
    
    get variance() {
        return this.hoursData?.variance || 0;
    }
    
    get variancePercentage() {
        const percentage = this.hoursData?.variancePercentage || 0;
        return Number(percentage).toFixed(2);
    }
    
    get varianceClass() {
        // Positive variance = favorable (estimated more than actual) = GREEN
        // Negative variance = unfavorable (estimated less than actual) = RED
        const varianceType = this.variance >= 0 ? 'variance-favorable' : 'variance-unfavorable';
        return `metric-value ${varianceType}`;
    }
    
    get totalEstimatedWithSubtasks() {
        return this.hoursData?.totalEstimatedWithSubtasks || 0;
    }
    
    get totalActualWithSubtasks() {
        return this.hoursData?.totalActualWithSubtasks || 0;
    }
    
    get hasData() {
        return this.hoursData && (
            (this.hoursData.hoursByStatus && this.hoursData.hoursByStatus.length > 0) ||
            this.totalEstimated > 0 ||
            this.totalActual > 0
        );
    }
    
    handleChartToggle(event) {
        this._internalShowChart = event.target.checked;
        // If hiding chart, destroy it to free resources
        if (!this._internalShowChart && this.chart) {
            this.chart.destroy();
            this.chart = null;
        } else if (this._internalShowChart && this.hoursData && this.chartjsInitialized) {
            // If showing chart and data is available, render it
            setTimeout(() => {
                this.renderChart();
                this.setupResizeObserver();
            }, 0);
        }
    }
    
    get currentShowChart() {
        return this._internalShowChart;
    }
}

