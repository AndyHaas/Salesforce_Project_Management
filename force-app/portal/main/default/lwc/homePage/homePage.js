import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getHomePageData from '@salesforce/apex/HomePageController.getHomePageData';

export default class HomePage extends NavigationMixin(LightningElement) {
    @api userFirstName;
    @api activeProjects = [];
    @api openTasks = [];
    @api tasksNeedingReviewCount = 0;
    isLoading = true;
    error;
    
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
        { label: 'Hours', fieldName: 'Total_Time__c', type: 'number', typeAttributes: { minimumFractionDigits: 2 } }
    ];
    
    // Data table columns for Tasks
    tasksColumns = [
        { 
            label: 'Name', 
            fieldName: 'Name', 
            type: 'text',
            cellAttributes: { 
                class: 'slds-text-link' 
            }
        },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Hours', fieldName: 'Total_Actual_Hours__c', type: 'number', typeAttributes: { minimumFractionDigits: 2 } }
    ];

    @wire(getHomePageData)
    wiredHomePageData({ error, data }) {
        if (data) {
            this.userFirstName = data.userFirstName;
            this.activeProjects = data.activeProjects || [];
            this.openTasks = data.openTasks || [];
            this.tasksNeedingReviewCount = data.tasksNeedingReviewCount || 0;
            
            // Add record URLs for navigation
            this.activeProjects = this.activeProjects.map(project => ({
                ...project,
                recordUrl: `#`
            }));
            
            this.openTasks = this.openTasks.map(task => ({
                ...task,
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

    get hasOpenTasks() {
        return this.openTasks && this.openTasks.length > 0;
    }

    get hasTasksNeedingReview() {
        return this.tasksNeedingReviewCount > 0;
    }
    
    get projectsTableData() {
        return this.activeProjects.map(project => ({
            ...project,
            Name: project.Name,
            Status__c: project.Status__c || '',
            Total_Time__c: project.Total_Time__c || 0
        }));
    }
    
    get tasksTableData() {
        return this.openTasks.map(task => ({
            ...task,
            Name: task.Name,
            Status__c: task.Status__c || '',
            Total_Actual_Hours__c: task.Total_Actual_Hours__c || 0
        }));
    }

    handleProjectRowClick(event) {
        const row = event.detail.row;
        if (row && row.Id) {
            this.navigateToRecord(row.Id, 'Project__c');
        }
    }

    handleTaskRowClick(event) {
        const row = event.detail.row;
        if (row && row.Id) {
            this.navigateToRecord(row.Id, 'Project_Task__c');
        }
    }

    handleProjectRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        if (action.name === 'view' || action.name === 'navigate') {
            this.navigateToRecord(row.Id, 'Project__c');
        }
    }

    handleTaskRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        if (action.name === 'view' || action.name === 'navigate') {
            this.navigateToRecord(row.Id, 'Project_Task__c');
        }
    }

    handleViewReviewTasks() {
        // Navigate to project tasks list view filtered by Ready_for_Client_Review__c = true
        this.navigateToUrl('/project-task/Project_Task__c/Backlog_Ready_for_Client_Review');
    }

    navigateToRecord(recordId, objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: objectApiName,
                actionName: 'view'
            }
        });
    }

    navigateToUrl(url) {
        const isExperienceCloud = window.location.pathname.startsWith('/s/');
        
        if (isExperienceCloud && !url.startsWith('/s/')) {
            url = '/s' + (url.startsWith('/') ? url : '/' + url);
        }
        
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: url
            }
        });
    }
}

