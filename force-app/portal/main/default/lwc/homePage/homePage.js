import { LightningElement, wire, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ensureSitePath, formatPercent, formatFieldValue, formatDate } from 'c/portalCommon';
import getHomePageData from '@salesforce/apex/HomePageController.getHomePageData';
import getLatestMessages from '@salesforce/apex/PortalMessagingController.getLatestMessages';

export default class HomePage extends NavigationMixin(LightningElement) {
    @api userFirstName;
    @api activeProjects = [];
    @api tasksNeedingReviewCount = 0;
    @track latestMessages = [];
    isLoading = true;
    error;
    _latestMessagesError = null;
    
    // Data table columns for Projects
    projectsColumns = [
        { 
            label: 'Name', 
            fieldName: 'Name', 
            type: 'text',
            cellAttributes: { 
                class: 'slds-text-link' 
            }
        },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Burn Rate', fieldName: 'Burn_Rate__c', type: 'percent', typeAttributes: { step: '0.01' } }
    ];

    @wire(getHomePageData)
    wiredHomePageData({ error, data }) {
        if (data) {
            this.userFirstName = data.userFirstName;
            this.activeProjects = data.activeProjects || [];
            this.tasksNeedingReviewCount = data.tasksNeedingReviewCount || 0;
            
            // Add record URLs for navigation
            this.activeProjects = this.activeProjects.map(project => ({
                ...project,
                recordUrl: `#`
            }));
            
            this.isLoading = false;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.isLoading = false;
            console.error('Error loading home page data:', error);
        }
    }

    get hasActiveProjects() {
        return this.activeProjects && this.activeProjects.length > 0;
    }

    get hasTasksNeedingReview() {
        return this.tasksNeedingReviewCount > 0;
    }
    
    // Wire service to get latest messages
    @wire(getLatestMessages, { limitCount: 5 })
    wiredLatestMessages({ error, data }) {
        if (data) {
            this.latestMessages = data || [];
            this._latestMessagesError = null;
        } else if (error) {
            console.error('Error loading latest messages:', error);
            this.latestMessages = [];
            this._latestMessagesError = error;
        }
    }
    
    get hasLatestMessages() {
        return this.latestMessages && this.latestMessages.length > 0;
    }
    
    get formattedLatestMessages() {
        if (!this.latestMessages || this.latestMessages.length === 0) {
            return [];
        }
        
        return this.latestMessages.map(msg => ({
            ...msg,
            formattedDate: this.formatMessageDate(msg.createdDate),
            formattedBody: this.stripHtml(msg.body || '')
        }));
    }
    
    formatMessageDate(dateValue) {
        if (!dateValue) {
            return '';
        }
        const date = new Date(dateValue);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);
        
        if (diffMins < 1) {
            return 'Just now';
        } else if (diffMins < 60) {
            return `${diffMins}m ago`;
        } else if (diffHours < 24) {
            return `${diffHours}h ago`;
        } else if (diffDays < 7) {
            return `${diffDays}d ago`;
        } else {
            return formatDate(dateValue, '—');
        }
    }
    
    stripHtml(html) {
        if (!html) {
            return '';
        }
        // Remove HTML tags and decode entities
        const tmp = document.createElement('DIV');
        tmp.innerHTML = html;
        let text = tmp.textContent || tmp.innerText || '';
        // Limit to 100 characters
        if (text.length > 100) {
            text = text.substring(0, 100) + '...';
        }
        return text;
    }
    
    handleMessageClick(event) {
        const taskId = event.currentTarget.dataset.taskId;
        if (taskId) {
            const taskUrl = `/project-task/${taskId}`;
            this.navigateToUrl(taskUrl);
        }
    }
    
    get projectsTableRows() {
        if (!this.activeProjects || !this.projectsColumns.length) {
            return [];
        }
        
        return this.activeProjects.map((project, rowIndex) => {
            const rowKey = project.Id || rowIndex;
            
            const cells = this.projectsColumns.map((col, colIndex) => {
                let displayValue = project[col.fieldName];
                let isLink = false;
                
                // Format based on field type
                if (displayValue !== undefined && displayValue !== null && displayValue !== '') {
                    if (col.type === 'percent') {
                        displayValue = formatPercent(displayValue);
                    } else {
                        displayValue = formatFieldValue(displayValue, col.type || 'text');
                    }
                } else {
                    displayValue = '';
                }
                
                // Name column is clickable
                const isNameColumn = col.fieldName === 'Name';
                if (isNameColumn && project.Id) {
                    isLink = true;
                }
                
                return {
                    key: `${rowIndex}-${colIndex}`,
                    value: displayValue !== undefined && displayValue !== null ? String(displayValue) : '',
                    isLink: isLink,
                    recordId: isNameColumn ? project.Id : null
                };
            });
            
            return {
                key: rowKey,
                recordId: project.Id,
                cells: cells
            };
        });
    }

    handleProjectRowClick(event) {
        // Prevent default link behavior if clicking on a link
        if (event.target.tagName === 'A') {
            event.preventDefault();
        }
        
        // Get record ID from the row or the clicked element
        const recordId = event.currentTarget?.dataset?.recordId || 
                        event.target?.closest('[data-record-id]')?.dataset?.recordId ||
                        event.target?.closest('.project-row')?.dataset?.recordId;
        
        if (recordId) {
            event.stopPropagation();
            this.navigateToRecord(recordId, 'Project__c');
        }
    }

    handleViewReviewTasks() {
        // Navigate to project tasks list view filtered by Ready_for_Client_Review__c = true
        this.navigateToUrl('/project-task/Project_Task__c/Backlog_Ready_for_Client_Review');
    }

    navigateToRecord(recordId, objectApiName) {
        // Use portal navigation for Project__c, standard navigation for others
        if (objectApiName === 'Project__c') {
            const projectUrl = `/project/${recordId}`;
            this.navigateToUrl(projectUrl);
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: objectApiName,
                    actionName: 'view'
                }
            });
        }
    }

    navigateToUrl(url) {
        const targetUrl = ensureSitePath(url, { currentPathname: window.location.pathname });
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: targetUrl
            }
        });
    }
}

