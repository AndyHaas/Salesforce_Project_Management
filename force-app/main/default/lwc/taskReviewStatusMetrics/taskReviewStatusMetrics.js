import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import getReviewStatusMetrics from '@salesforce/apex/ProjectTaskDashboardController.getReviewStatusMetrics';
import { loadScript } from 'lightning/platformResourceLoader';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';

export default class TaskReviewStatusMetrics extends NavigationMixin(LightningElement) {
    @api accountId;
    
    @wire(MessageContext)
    messageContext;
    
    reviewData = null;
    pmChart;
    clientChart;
    clientDevChart;
    chartjsInitialized = false;
    subscription = null;
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
        }
    }
    
    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }
    
    @wire(getReviewStatusMetrics, { accountIds: '$effectiveAccountIds' })
    wiredReviewStatusMetrics({ error, data }) {
        if (data) {
            this.reviewData = data;
            // Debug logging
            console.log('Review Status Metrics Data:', JSON.stringify(data, null, 2));
            console.log('In Review Total:', data.inReviewTotal);
            console.log('PM Approved:', data.pmApprovedCount, 'PM Pending:', data.pmPendingCount);
            console.log('Client Approved:', data.clientCompletionApprovedCount, 'Client Pending:', data.clientCompletionPendingCount);
            // Wait for next render cycle to ensure canvas elements are in DOM
            setTimeout(() => {
                this.renderCharts();
            }, 0);
        } else if (error) {
            console.error('Error loading review status metrics:', error);
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
                // Render charts if data is already available
                if (this.reviewData) {
                    setTimeout(() => {
                        this.renderCharts();
                        this.setupResizeObserver();
                    }, 0);
                }
            })
            .catch(error => {
                console.error('Error loading Chart.js:', error);
            });
    }
    
    connectedCallback() {
        this.resizeHandler = () => {
            if (this.pmChart) this.pmChart.resize();
            if (this.clientChart) this.clientChart.resize();
            if (this.clientDevChart) this.clientDevChart.resize();
        };
        window.addEventListener('resize', this.resizeHandler);
    }
    
    disconnectedCallback() {
        if (this.resizeHandler) {
            window.removeEventListener('resize', this.resizeHandler);
        }
        if (this.resizeObserver) {
            this.resizeObserver.disconnect();
        }
    }
    
    setupResizeObserver() {
        const chartContainers = this.template.querySelectorAll('.chart-container');
        if (chartContainers.length > 0 && window.ResizeObserver) {
            this.resizeObserver = new ResizeObserver(() => {
                if (this.pmChart) this.pmChart.resize();
                if (this.clientChart) this.clientChart.resize();
                if (this.clientDevChart) this.clientDevChart.resize();
            });
            chartContainers.forEach(container => {
                this.resizeObserver.observe(container);
            });
        }
    }
    
    renderCharts() {
        if (!this.chartjsInitialized || !window.Chart || !this.reviewData) {
            return;
        }
        
        // Ensure canvas elements exist in DOM (at least one should exist)
        const pmCanvas = this.template.querySelector('canvas.pmChart');
        const clientCanvas = this.template.querySelector('canvas.clientChart');
        const clientDevCanvas = this.template.querySelector('canvas.clientDevChart');
        
        // Only retry if we have data but no canvas elements found
        if ((this.hasPMData && !pmCanvas) || (this.hasClientData && !clientCanvas) || (this.hasClientDevData && !clientDevCanvas)) {
            console.warn('Canvas elements not found, retrying...');
            setTimeout(() => {
                this.renderCharts();
            }, 100);
            return;
        }
        
        // PM Review Chart - only render if canvas exists and we have data
        if (pmCanvas && this.hasPMData) {
            const pmCtx = pmCanvas.getContext('2d');
            if (this.pmChart) {
                this.pmChart.destroy();
            }
            
            const pmApproved = this.reviewData.pmApprovedCount || 0;
            const pmPending = this.reviewData.pmPendingCount || 0;
            const pmTotal = pmApproved + pmPending;
            const self = this;
            
            // Register center text plugin for PM chart
            const pmCenterTextPlugin = {
                id: 'pmCenterText',
                beforeDraw: (chart) => {
                    const ctx = chart.ctx;
                    const centerX = chart.chartArea.left + (chart.chartArea.right - chart.chartArea.left) / 2;
                    const centerY = chart.chartArea.top + (chart.chartArea.bottom - chart.chartArea.top) / 2;
                    
                    ctx.save();
                    ctx.font = 'bold 20px Arial';
                    ctx.fillStyle = '#080707';
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'middle';
                    ctx.fillText(pmTotal.toString(), centerX, centerY - 10);
                    
                    ctx.font = '12px Arial';
                    ctx.fillStyle = '#706e6b';
                    ctx.fillText('Total', centerX, centerY + 10);
                    ctx.restore();
                }
            };
            
            this.pmChart = new window.Chart(pmCtx, {
                type: 'doughnut',
                data: {
                    labels: ['Approved', 'Pending'],
                    datasets: [{
                        data: [pmApproved, pmPending],
                        backgroundColor: ['#32CD32', '#FFD700']
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    resizeDelay: 0,
                    onClick: (event, elements) => {
                        if (elements.length > 0) {
                            const element = elements[0];
                            const index = element.index;
                            // Index 0 = Approved, Index 1 = Pending
                            if (index === 1) {
                                // Navigate to PM Pending Review
                                self.navigateToReviewListView('Pending_Review_PM_Code_Reviewer');
                            } else {
                                // Navigate to In Review Tasks (for approved)
                                self.navigateToReviewListView('In_Review_Tasks');
                            }
                        } else {
                            // Click on chart but not on segment - navigate to pending
                            self.navigateToReviewListView('Pending_Review_PM_Code_Reviewer');
                        }
                    },
                    plugins: {
                        pmCenterText: pmCenterTextPlugin,
                        title: {
                            display: true,
                            text: 'PM/Code Reviewer Approval',
                            font: {
                                size: 12
                            }
                        },
                        legend: {
                            position: 'bottom',
                            labels: {
                                boxWidth: 12,
                                padding: 8,
                                font: {
                                    size: 10
                                }
                            }
                        }
                    }
                }
            });
        }
        
        // Client Completion Approval Chart - only render if canvas exists and we have data
        if (clientCanvas && this.hasClientData) {
            const clientCtx = clientCanvas.getContext('2d');
            if (this.clientChart) {
                this.clientChart.destroy();
            }
            
            const clientApproved = this.reviewData.clientCompletionApprovedCount || 0;
            const clientPending = this.reviewData.clientCompletionPendingCount || 0;
            const clientTotal = clientApproved + clientPending;
            const self = this;
            
            // Register center text plugin for Client Completion chart
            const clientCenterTextPlugin = {
                id: 'clientCenterText',
                beforeDraw: (chart) => {
                    const ctx = chart.ctx;
                    const centerX = chart.chartArea.left + (chart.chartArea.right - chart.chartArea.left) / 2;
                    const centerY = chart.chartArea.top + (chart.chartArea.bottom - chart.chartArea.top) / 2;
                    
                    ctx.save();
                    ctx.font = 'bold 20px Arial';
                    ctx.fillStyle = '#080707';
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'middle';
                    ctx.fillText(clientTotal.toString(), centerX, centerY - 10);
                    
                    ctx.font = '12px Arial';
                    ctx.fillStyle = '#706e6b';
                    ctx.fillText('Total', centerX, centerY + 10);
                    ctx.restore();
                }
            };
            
            this.clientChart = new window.Chart(clientCtx, {
                type: 'doughnut',
                data: {
                    labels: ['Approved', 'Pending'],
                    datasets: [{
                        data: [clientApproved, clientPending],
                        backgroundColor: ['#32CD32', '#FFD700']
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    resizeDelay: 0,
                    onClick: (event, elements) => {
                        if (elements.length > 0) {
                            const element = elements[0];
                            const index = element.index;
                            // Index 0 = Approved, Index 1 = Pending
                            if (index === 1) {
                                // Navigate to Client Pending Review
                                self.navigateToReviewListView('Pending_Review_Client');
                            } else {
                                // Navigate to In Review Tasks (for approved)
                                self.navigateToReviewListView('In_Review_Tasks');
                            }
                        } else {
                            // Click on chart but not on segment - navigate to pending
                            self.navigateToReviewListView('Pending_Review_Client');
                        }
                    },
                    plugins: {
                        clientCenterText: clientCenterTextPlugin,
                        title: {
                            display: true,
                            text: 'Client Completion Approval (In Review)',
                            font: {
                                size: 12
                            }
                        },
                        legend: {
                            position: 'bottom',
                            labels: {
                                boxWidth: 12,
                                padding: 8,
                                font: {
                                    size: 10
                                }
                            }
                        }
                    }
                }
            });
        }
        
        // Client Development Approval Chart (Backlog workflow)
        if (clientDevCanvas && this.hasClientDevData) {
            const clientDevCtx = clientDevCanvas.getContext('2d');
            if (this.clientDevChart) {
                this.clientDevChart.destroy();
            }
            
            const clientDevApproved = this.reviewData.clientDevelopmentApprovedCount || 0;
            const clientDevPending = this.reviewData.clientDevelopmentPendingCount || 0;
            const clientDevTotal = clientDevApproved + clientDevPending;
            const self = this;
            
            // Register center text plugin for Client Development chart
            const clientDevCenterTextPlugin = {
                id: 'clientDevCenterText',
                beforeDraw: (chart) => {
                    const ctx = chart.ctx;
                    const centerX = chart.chartArea.left + (chart.chartArea.right - chart.chartArea.left) / 2;
                    const centerY = chart.chartArea.top + (chart.chartArea.bottom - chart.chartArea.top) / 2;
                    
                    ctx.save();
                    ctx.font = 'bold 20px Arial';
                    ctx.fillStyle = '#080707';
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'middle';
                    ctx.fillText(clientDevTotal.toString(), centerX, centerY - 10);
                    
                    ctx.font = '12px Arial';
                    ctx.fillStyle = '#706e6b';
                    ctx.fillText('Total', centerX, centerY + 10);
                    ctx.restore();
                }
            };
            
            this.clientDevChart = new window.Chart(clientDevCtx, {
                type: 'doughnut',
                data: {
                    labels: ['Approved', 'Pending'],
                    datasets: [{
                        data: [clientDevApproved, clientDevPending],
                        backgroundColor: ['#32CD32', '#FFD700']
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    resizeDelay: 0,
                    onClick: (event, elements) => {
                        if (elements.length > 0) {
                            const element = elements[0];
                            const index = element.index;
                            // Index 0 = Approved, Index 1 = Pending
                            if (index === 1) {
                                // Navigate to Backlog Ready for Client Review
                                self.navigateToReviewListView('Backlog_Ready_for_Client_Review');
                            } else {
                                // Navigate to Approved Ready for Dev
                                self.navigateToReviewListView('Approved_Ready_for_Dev');
                            }
                        } else {
                            // Click on chart but not on segment - navigate to ready for review
                            self.navigateToReviewListView('Backlog_Ready_for_Client_Review');
                        }
                    },
                    plugins: {
                        clientDevCenterText: clientDevCenterTextPlugin,
                        title: {
                            display: true,
                            text: 'Client Development Approval (Backlog)',
                            font: {
                                size: 12
                            }
                        },
                        legend: {
                            position: 'bottom',
                            labels: {
                                boxWidth: 12,
                                padding: 8,
                                font: {
                                    size: 10
                                }
                            }
                        }
                    }
                }
            });
        }
    }
    
    get pmApprovedCount() {
        return this.reviewData?.pmApprovedCount || 0;
    }
    
    get pmPendingCount() {
        return this.reviewData?.pmPendingCount || 0;
    }
    
    get clientCompletionApprovedCount() {
        return this.reviewData?.clientCompletionApprovedCount || 0;
    }
    
    get clientCompletionPendingCount() {
        return this.reviewData?.clientCompletionPendingCount || 0;
    }
    
    get inReviewTotal() {
        return this.reviewData?.inReviewTotal || 0;
    }
    
    get backlogTotal() {
        return this.reviewData?.backlogTotal || 0;
    }
    
    get readyForClientReviewCount() {
        return this.reviewData?.readyForClientReviewCount || 0;
    }
    
    get clientDevelopmentApprovedCount() {
        return this.reviewData?.clientDevelopmentApprovedCount || 0;
    }
    
    get clientDevelopmentPendingCount() {
        return this.reviewData?.clientDevelopmentPendingCount || 0;
    }
    
    get hasData() {
        return this.reviewData && (
            this.inReviewTotal > 0 ||
            this.backlogTotal > 0 ||
            this.pmApprovedCount > 0 ||
            this.pmPendingCount > 0 ||
            this.clientCompletionApprovedCount > 0 ||
            this.clientCompletionPendingCount > 0 ||
            this.clientDevelopmentApprovedCount > 0 ||
            this.clientDevelopmentPendingCount > 0
        );
    }
    
    get hasPMData() {
        return this.reviewData && (this.pmApprovedCount > 0 || this.pmPendingCount > 0);
    }
    
    get hasClientData() {
        return this.reviewData && (this.clientCompletionApprovedCount > 0 || this.clientCompletionPendingCount > 0);
    }
    
    get hasClientDevData() {
        return this.reviewData && (this.clientDevelopmentApprovedCount > 0 || this.clientDevelopmentPendingCount > 0);
    }
    
    handleChartClick(event) {
        // This handler is for the container div click (fallback)
        const chartType = event.currentTarget.dataset.chart;
        let listViewApiName;
        
        switch(chartType) {
            case 'pmChart':
                listViewApiName = 'Pending_Review_PM_Code_Reviewer';
                break;
            case 'clientChart':
                listViewApiName = 'Pending_Review_Client';
                break;
            case 'clientDevChart':
                listViewApiName = 'Backlog_Ready_for_Client_Review';
                break;
            default:
                return;
        }
        
        this.navigateToReviewListView(listViewApiName);
    }
    
    /**
     * @description Navigate to a review status-specific list view with optional account filtering
     * 
     * When on an Account record page, automatically filters the list view to that account
     * by passing the account ID via URL state parameters.
     * 
     * @param {string} listViewApiName - API name of the list view to navigate to
     * @private
     */
    navigateToReviewListView(listViewApiName) {
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
            // This will be available in the URL and can be used by custom components
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
