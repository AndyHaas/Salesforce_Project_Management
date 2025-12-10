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

    handleProjectClick(event) {
        event.preventDefault();
        const projectId = event.currentTarget.dataset.id;
        if (projectId) {
            this.navigateToRecord(projectId, 'Project__c');
        }
    }

    handleTaskClick(event) {
        event.preventDefault();
        const taskId = event.currentTarget.dataset.id;
        if (taskId) {
            this.navigateToRecord(taskId, 'Project_Task__c');
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

