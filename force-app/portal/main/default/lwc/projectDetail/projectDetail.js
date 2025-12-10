import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getProjectDetail from '@salesforce/apex/PortalProjectController.getProjectDetail';
import getStatusColors from '@salesforce/apex/StatusColorController.getStatusColors';
import { formatDate, formatBoolean } from 'c/portalCommon';

export default class ProjectDetail extends LightningElement {
    @track projectId;
    @track project;
    @track taskMetrics;

    isLoading = true;
    error;
    statusColors = {};

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

    @wire(getStatusColors)
    wiredStatusColors({ error, data }) {
        if (data) {
            this.statusColors = data || {};
        } else if (error) {
            console.error('Error loading status colors:', error);
            // Fall back to default colors
            this.statusColors = this.getDefaultStatusColors();
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

    get statusBadgeStyle() {
        const status = this.project?.status;
        if (!status) {
            return '';
        }
        
        // Use colors from Apex (which reads from field metadata)
        // If not loaded yet, use default colors
        const backgroundColor = this.statusColors[status] || this.getDefaultStatusColors()[status] || '#F3F3F3';
        
        // Determine text color based on background brightness
        const textColor = this.getContrastTextColor(backgroundColor);
        
        return `background-color: ${backgroundColor}; color: ${textColor};`;
    }

    getDefaultStatusColors() {
        return {
            'Backlog': '#E5E5E5',
            'Pending': '#FFB75D',
            'In Progress': '#0176D3',
            'In Review': '#5B21B6',
            'Blocked': '#C23934',
            'Completed': '#2E844A',
            'Removed': '#706E6B',
            'Closed': '#2E844A'
        };
    }

    getContrastTextColor(hexColor) {
        if (!hexColor) return '#080707';
        
        // Remove # if present
        const hex = hexColor.replace('#', '');
        
        // Convert to RGB
        const r = parseInt(hex.substring(0, 2), 16);
        const g = parseInt(hex.substring(2, 4), 16);
        const b = parseInt(hex.substring(4, 6), 16);
        
        // Calculate brightness using relative luminance formula
        // https://www.w3.org/WAI/GL/wiki/Relative_luminance
        const brightness = (r * 299 + g * 587 + b * 114) / 1000;
        
        // Return black for light backgrounds, white for dark backgrounds
        return brightness > 128 ? '#080707' : '#FFFFFF';
    }

    get displayAccount() {
        return this.project?.accountName || '—';
    }

    get displayCreatedDate() {
        return formatDate(this.project?.createdDate, '—');
    }

    get displayStartDate() {
        return formatDate(this.project?.startDate, '—');
    }

    get displayEndDate() {
        return formatDate(this.project?.endDate, '—');
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

    get displayInvoiced() {
        return formatBoolean(this.project?.invoiced, '—');
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
