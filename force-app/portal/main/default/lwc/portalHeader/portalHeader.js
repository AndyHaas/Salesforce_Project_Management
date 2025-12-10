import { LightningElement, api, wire } from 'lwc';
import USER_ID from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import FIRST_NAME_FIELD from '@salesforce/schema/User.FirstName';
import { ensureSitePath, getWelcomeLabel } from 'c/portalCommon';

export default class PortalHeader extends LightningElement {
    /**
     * @description Current user ID - null if not authenticated
     * @type {string|null}
     */
    userId = USER_ID;
    /**
     * @description Cached user first name for greeting
     * @type {string}
     */
    userFirstName;

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
    @api projectsFilterName = 'Open_Projects';

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
     * @description Greeting label for authenticated user
     * @returns {string}
     */
    get welcomeLabel() {
        return getWelcomeLabel(this.userFirstName);
    }

    @wire(getRecord, { recordId: USER_ID, fields: [FIRST_NAME_FIELD] })
    wiredUser({ data, error }) {
        if (data) {
            this.userFirstName = data.fields?.FirstName?.value || '';
        } else if (error) {
            // keep silent fallback to default welcome
            console.warn('Unable to load user first name', error);
        }
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
     * @description Handle login button click
     * @param {Event} event - Click event
     */
    handleLoginClick(event) {
        event.preventDefault();
        const loginUrl = '/s/login';
        this.navigateToUrl(loginUrl);
    }

    /**
     * @description Navigate to a URL (handles Experience Cloud path prefix)
     * @param {string} url - URL to navigate to
     */
    navigateToUrl(url) {
        const targetUrl = ensureSitePath(url, { currentPathname: window.location.pathname });
        window.location.href = targetUrl;
    }
}

