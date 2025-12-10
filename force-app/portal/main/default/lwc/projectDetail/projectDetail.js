import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getProjectDetail from '@salesforce/apex/PortalProjectController.getProjectDetail';

export default class ProjectDetail extends LightningElement {
    @track projectId;
    @track project;
    @track taskMetrics;

    isLoading = true;
    error;

    @wire(CurrentPageReference)
    resolvePageReference(pageRef) {
        if (!pageRef) {
            return;
        }

        const { attributes = {}, state = {} } = pageRef;
        let projectId = state.recordId || attributes.recordId || state.c__projectId;

        if (!projectId && typeof window !== 'undefined') {
            let pathname = window.location.pathname || '';
            pathname = pathname.replace(/^\/s/, '');
            const parts = pathname.split('/').filter(Boolean);
            const projectIdx = parts.indexOf('project');
            if (projectIdx !== -1 && projectIdx + 1 < parts.length) {
                projectId = decodeURIComponent(parts[projectIdx + 1]);
            }
        }

        if (projectId && projectId !== this.projectId) {
            this.projectId = projectId;
        }
    }

    @wire(getProjectDetail, { projectId: '$projectId' })
    wiredProjectDetail({ data, error }) {
        if (!this.projectId) {
            return;
        }
        this.isLoading = false;
        if (data) {
            this.project = data.project;
            this.taskMetrics = data.taskMetrics;
            this.error = undefined;
        } else if (error) {
            this.error = this.formatError(error);
            this.project = undefined;
            this.taskMetrics = undefined;
        }
    }

    get hasData() {
        return !!this.project && !this.error;
    }

    get displayStatus() {
        return this.project?.status || '—';
    }

    get displayAccount() {
        return this.project?.accountName || '—';
    }

    get displayCreatedDate() {
        return this.formatDate(this.project?.createdDate);
    }

    get displayStartDate() {
        return this.formatDate(this.project?.startDate);
    }

    get displayEndDate() {
        return this.formatDate(this.project?.endDate);
    }

    get displayBurnRate() {
        const burnRate = this.project?.burnRate;
        if (burnRate === undefined || burnRate === null) {
            return '—';
        }
        const percentValue = parseFloat(burnRate);
        if (isNaN(percentValue)) {
            return '—';
        }
        // Salesforce stores percent values as 50 for 50%, just add % symbol
        return `${percentValue.toFixed(2)}%`;
    }

    formatDate(value) {
        if (!value) {
            return '—';
        }
        try {
            const d = new Date(value);
            const year = d.getFullYear();
            const month = String(d.getMonth() + 1).padStart(2, '0');
            const day = String(d.getDate()).padStart(2, '0');
            return `${year}-${month}-${day}`;
        } catch (e) {
            return value;
        }
    }

    formatError(err) {
        if (!err) {
            return 'Unknown error';
        }
        if (err.body && err.body.message) {
            return err.body.message;
        }
        if (err.message) {
            return err.message;
        }
        return 'Unable to load data';
    }
}
