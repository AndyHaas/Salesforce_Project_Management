import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getProjectDetail from '@salesforce/apex/PortalProjectController.getProjectDetail';
import getProjectStatusColors from '@salesforce/apex/StatusColorController.getProjectStatusColors';
import getProjectTaskFiles from '@salesforce/apex/PortalProjectController.getProjectTaskFiles';
import { formatDate, formatBoolean } from 'c/portalCommon';

export default class ProjectDetail extends LightningElement {
    @track projectId;
    @track project;
    @track taskMetrics;

    isLoading = true;
    error;
    statusColors = {};
    _files = [];
    _filesError = null;

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

    @wire(getProjectStatusColors)
    wiredStatusColors({ error, data }) {
        if (data) {
            this.statusColors = data || {};
        } else if (error) {
            console.error('Error loading project status colors:', error);
            // Fall back to default colors
            this.statusColors = this.getDefaultStatusColors();
        }
    }
    
    // Wire service to get all files from all tasks in the project
    @wire(getProjectTaskFiles, { projectId: '$projectId' })
    wiredProjectTaskFiles({ error, data }) {
        if (data) {
            this._files = data || [];
            this._filesError = null;
        } else if (error) {
            console.error('Error loading project task files:', error);
            this._files = [];
            this._filesError = error;
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

    get statusBadgeClass() {
        const status = this.project?.status;
        if (!status) {
            return 'status-badge status-badge-default';
        }
        
        const statusStr = String(status);
        const normalizedStatus = statusStr.toLowerCase().replace(/\s+/g, '-');
        
        const statusClasses = {
            'Not Started': 'status-badge status-badge-not-started',
            'not started': 'status-badge status-badge-not-started',
            'not-started': 'status-badge status-badge-not-started',
            'R&D': 'status-badge status-badge-rd',
            'r&d': 'status-badge status-badge-rd',
            'Proposal': 'status-badge status-badge-proposal',
            'proposal': 'status-badge status-badge-proposal',
            'Development': 'status-badge status-badge-development',
            'development': 'status-badge status-badge-development',
            'Q&A': 'status-badge status-badge-qa',
            'q&a': 'status-badge status-badge-qa',
            'Deployed': 'status-badge status-badge-deployed',
            'deployed': 'status-badge status-badge-deployed',
            'Cancelled': 'status-badge status-badge-cancelled',
            'cancelled': 'status-badge status-badge-cancelled'
        };
        
        return statusClasses[status] || statusClasses[normalizedStatus] || 'status-badge status-badge-default';
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
        // Project Status colors from Project__c.Status__c.field-meta.xml
        return {
            'Not Started': '#DDDDDD',
            'R&D': '#FF99FF',
            'Proposal': '#FF9966',
            'Development': '#FFCC33',
            'Q&A': '#9999FF',
            'Deployed': '#33CC00',
            'Cancelled': '#CC0000'
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
    
    /**
     * @description Get files for display
     */
    get files() {
        if (!this._files || this._files.length === 0) {
            return [];
        }
        
        return this._files.map(file => ({
            ...file,
            downloadUrl: `/sfc/servlet.shepherd/document/download/${file.versionId}`,
            formattedSize: this.formatFileSize(file.size),
            formattedDate: this.formatFileDate(file.createdDate)
        }));
    }
    
    get hasFiles() {
        return this._files && this._files.length > 0;
    }
    
    get filesCount() {
        return this._files ? this._files.length : 0;
    }

    get hasInvoices() {
        return !!this.project?.invoiced;
    }

    get sectionLayoutClass() {
        return this.hasInvoices ? 'section two-col-sections three-col' : 'section two-col-sections';
    }
    
    /**
     * @description Format file size for display
     */
    formatFileSize(bytes) {
        if (!bytes || bytes === 0) {
            return '0 B';
        }
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
    }
    
    /**
     * @description Format file date for display
     */
    formatFileDate(dateValue) {
        if (!dateValue) {
            return '';
        }
        const date = new Date(dateValue);
        return date.toLocaleDateString('en-US', { 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric' 
        });
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
