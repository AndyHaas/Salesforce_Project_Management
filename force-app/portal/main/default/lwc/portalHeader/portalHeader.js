import { LightningElement, api, wire } from 'lwc';
import USER_ID from '@salesforce/user/Id';

export default class PortalHeader extends LightningElement {
    /**
     * @description Current user ID - null if not authenticated
     * @type {string|null}
     */
    userId = USER_ID;

    /**
     * @description Current route path
     * @type {string}
     */
    currentPath = '';

    /**
     * @description Object API name for Projects (default: Project__c)
     * @type {string}
     */
    @api projectsObjectApiName = 'Project__c';

    /**
     * @description Filter name for Projects list view
     * @type {string}
     */
    @api projectsFilterName = 'All';

    /**
     * @description Object API name for Project Tasks (default: Project_Task__c)
     * @type {string}
     */
    @api projectTasksObjectApiName = 'Project_Task__c';

    /**
     * @description Filter name for Project Tasks list view
     * @type {string}
     */
    @api projectTasksFilterName = 'All';

    /**
     * @description Whether user is authenticated
     * @returns {boolean}
     */
    get isAuthenticated() {
        return !!this.userId;
    }

    /**
     * @description Whether home route is active
     * @returns {boolean}
     */
    get isHomeActive() {
        return this.currentPath === '/' || this.currentPath === '/s/' || this.currentPath === '';
    }

    /**
     * @description Whether projects route is active
     * @returns {boolean}
     */
    get isProjectsActive() {
        return this.currentPath.startsWith('/project/') || this.currentPath.startsWith('/s/project/');
    }

    /**
     * @description Whether project tasks route is active
     * @returns {boolean}
     */
    get isProjectTasksActive() {
        return this.currentPath.startsWith('/project-task/') || this.currentPath.startsWith('/s/project-task/');
    }

    /**
     * @description Component lifecycle hook
     */
    connectedCallback() {
        this.updateCurrentPath();
        
        // Listen for navigation events (popstate for back/forward, hashchange for hash changes)
        window.addEventListener('popstate', this.handleLocationChange);
        window.addEventListener('hashchange', this.handleLocationChange);
        
        // Also listen for custom navigation events if needed
        window.addEventListener('locationchange', this.handleLocationChange);
    }

    /**
     * @description Component lifecycle hook
     */
    disconnectedCallback() {
        window.removeEventListener('popstate', this.handleLocationChange);
        window.removeEventListener('hashchange', this.handleLocationChange);
        window.removeEventListener('locationchange', this.handleLocationChange);
    }

    /**
     * @description Update current path from window location
     */
    updateCurrentPath() {
        const path = window.location.pathname;
        // Remove /s/ prefix if present (Experience Cloud path prefix)
        this.currentPath = path.replace(/^\/s/, '') || '/';
    }

    /**
     * @description Handle location change events
     */
    handleLocationChange = () => {
        this.updateCurrentPath();
    }

    /**
     * @description Handle home navigation click
     * @param {Event} event - Click event
     */
    handleHomeClick(event) {
        event.preventDefault();
        this.navigateToHome();
    }

    /**
     * @description Handle navigation link clicks
     * @param {Event} event - Click event
     */
    handleNavClick(event) {
        event.preventDefault();
        const route = event.currentTarget.dataset.route;
        
        switch (route) {
            case 'home':
                this.navigateToHome();
                break;
            case 'projects':
                this.navigateToProjects();
                break;
            case 'project-tasks':
                this.navigateToProjectTasks();
                break;
            default:
                console.warn('Unknown route:', route);
        }
    }

    /**
     * @description Navigate to home page
     */
    navigateToHome() {
        const homeUrl = '/';
        this.navigateToUrl(homeUrl);
    }

    /**
     * @description Navigate to projects list page
     */
    navigateToProjects() {
        // Format: /project/:objectApiName/:filterName
        const projectsUrl = `/project/${this.projectsObjectApiName}/${this.projectsFilterName}`;
        this.navigateToUrl(projectsUrl);
    }

    /**
     * @description Navigate to project tasks list page
     */
    navigateToProjectTasks() {
        // Format: /project-task/:objectApiName/:filterName
        const projectTasksUrl = `/project-task/${this.projectTasksObjectApiName}/${this.projectTasksFilterName}`;
        this.navigateToUrl(projectTasksUrl);
    }

    /**
     * @description Navigate to a URL (handles Experience Cloud path prefix)
     * @param {string} url - URL to navigate to
     */
    navigateToUrl(url) {
        // In Experience Cloud, URLs typically need /s/ prefix
        // Check if we're in Experience Cloud context
        const isExperienceCloud = window.location.pathname.startsWith('/s/');
        
        if (isExperienceCloud && !url.startsWith('/s/')) {
            // Add /s/ prefix for Experience Cloud
            url = '/s' + (url.startsWith('/') ? url : '/' + url);
        }
        
        // Use window.location for navigation in Experience Cloud
        window.location.href = url;
    }
}

