import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ensureSitePath } from 'c/portalCommon';
import getHomePageData from '@salesforce/apex/HomePageController.getHomePageData';

export default class HomePage extends NavigationMixin(LightningElement) {
    @api userFirstName;
    @api activeProjects = [];
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
    
    get projectsTableData() {
        return this.activeProjects.map(project => ({
            ...project,
            Name: project.Name,
            Status__c: project.Status__c || '',
            Burn_Rate__c: project.Burn_Rate__c || 0
        }));
    }

    handleProjectRowClick(event) {
        const row = event.detail.row;
        if (row && row.Id) {
            this.navigateToRecord(row.Id, 'Project__c');
        }
    }

    handleProjectRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        if (action.name === 'view' || action.name === 'navigate') {
            this.navigateToRecord(row.Id, 'Project__c');
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

