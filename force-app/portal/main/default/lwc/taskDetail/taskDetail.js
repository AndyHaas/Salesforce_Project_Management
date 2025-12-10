import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import getTaskDetail from '@salesforce/apex/PortalTaskController.getTaskDetail';
import getStatusColors from '@salesforce/apex/StatusColorController.getStatusColors';
import { formatDate, formatNumber, formatPercent } from 'c/portalCommon';

export default class TaskDetail extends NavigationMixin(LightningElement) {
    @track taskId;
    @track task;
    
    isLoading = true;
    error;
    statusColors = {};

    @wire(CurrentPageReference)
    resolvePageReference(pageRef) {
        if (!pageRef) {
            return;
        }

        const { attributes = {}, state = {} } = pageRef;
        let taskId = state.recordId || attributes.recordId || state.c__taskId;

        if (!taskId && typeof window !== 'undefined') {
            let pathname = window.location.pathname || '';
            pathname = pathname.replace(/^\/s/, '');
            const parts = pathname.split('/').filter(Boolean);
            const taskIdx = parts.indexOf('task');
            if (taskIdx !== -1 && taskIdx + 1 < parts.length) {
                taskId = decodeURIComponent(parts[taskIdx + 1]);
            }
        }

        if (taskId && taskId !== this.taskId) {
            this.taskId = taskId;
        }
    }

    @wire(getStatusColors)
    wiredStatusColors({ error, data }) {
        if (data) {
            this.statusColors = data || {};
        } else if (error) {
            console.error('Error loading status colors:', error);
            this.statusColors = this.getDefaultStatusColors();
        }
    }

    @wire(getTaskDetail, { taskId: '$taskId' })
    wiredTaskDetail({ data, error }) {
        if (!this.taskId) {
            return;
        }
        this.isLoading = false;
        if (data) {
            this.task = data.task;
            this.error = undefined;
        } else if (error) {
            this.error = this.formatError(error);
            this.task = undefined;
        }
    }

    get hasData() {
        return !!this.task && !this.error;
    }

    get displayName() {
        return this.task?.Name || '—';
    }

    get displayStatus() {
        return this.task?.Status__c || '—';
    }

    get displayPriority() {
        return this.task?.Priority__c || '—';
    }

    get displayDescription() {
        return this.task?.Description__c || '—';
    }

    get displayStartDate() {
        return formatDate(this.task?.Start_Date__c, '—');
    }

    get displayDueDate() {
        return formatDate(this.task?.Due_Date__c, '—');
    }

    get displayProgress() {
        return formatPercent(this.task?.Progress_Percentage__c, '—');
    }

    get displayEstimatedHours() {
        return formatNumber(this.task?.Estimated_Hours__c, '—');
    }

    get displayActualHours() {
        return formatNumber(this.task?.Actual_Hours__c, '—');
    }

    get displayTotalEstimatedHours() {
        return formatNumber(this.task?.Total_Estimated_Hours__c, '—');
    }

    get displayTotalActualHours() {
        return formatNumber(this.task?.Total_Actual_Hours__c, '—');
    }

    get displayProject() {
        return this.task?.Project__r?.Name || '—';
    }

    get displayAccount() {
        return this.task?.Account__r?.Name || '—';
    }

    get displayProjectManager() {
        return this.task?.Project_Manager__r?.Name || '—';
    }

    get displayDeveloper() {
        return this.task?.Developer__r?.Name || '—';
    }

    get displayClientUser() {
        return this.task?.Client_User__r?.Name || '—';
    }

    get displayParentTask() {
        return this.task?.Parent_Task__r?.Name || '—';
    }

    get hasParentTask() {
        return !!this.task?.Parent_Task__c;
    }

    get isOverdue() {
        return this.task?.Is_Overdue__c === true;
    }

    get statusBadgeClass() {
        const status = this.task?.Status__c;
        if (!status) {
            return 'status-badge status-badge-default';
        }
        
        const statusStr = String(status);
        const normalizedStatus = statusStr.toLowerCase().replace(/\s+/g, '-');
        
        const statusClasses = {
            'Backlog': 'status-badge status-badge-backlog',
            'backlog': 'status-badge status-badge-backlog',
            'Pending': 'status-badge status-badge-pending',
            'pending': 'status-badge status-badge-pending',
            'In Progress': 'status-badge status-badge-in-progress',
            'in progress': 'status-badge status-badge-in-progress',
            'in-progress': 'status-badge status-badge-in-progress',
            'In Review': 'status-badge status-badge-in-review',
            'in review': 'status-badge status-badge-in-review',
            'in-review': 'status-badge status-badge-in-review',
            'Blocked': 'status-badge status-badge-blocked',
            'blocked': 'status-badge status-badge-blocked',
            'Completed': 'status-badge status-badge-completed',
            'completed': 'status-badge status-badge-completed',
            'Removed': 'status-badge status-badge-removed',
            'removed': 'status-badge status-badge-removed'
        };
        
        return statusClasses[status] || statusClasses[normalizedStatus] || 'status-badge status-badge-default';
    }

    get statusBadgeStyle() {
        const status = this.task?.Status__c;
        if (!status) {
            return '';
        }
        
        const backgroundColor = this.statusColors[status] || this.getDefaultStatusColors()[status] || '#F3F3F3';
        const textColor = this.getContrastTextColor(backgroundColor);
        
        return `background-color: ${backgroundColor}; color: ${textColor};`;
    }

    get priorityBadgeClass() {
        const priority = this.task?.Priority__c;
        if (!priority) {
            return 'priority-badge priority-badge-none';
        }
        
        const priorityStr = String(priority).toLowerCase();
        const priorityClasses = {
            'high': 'priority-badge priority-badge-high',
            'medium': 'priority-badge priority-badge-medium',
            'low': 'priority-badge priority-badge-low',
            'none': 'priority-badge priority-badge-none'
        };
        
        return priorityClasses[priorityStr] || 'priority-badge priority-badge-none';
    }

    getDefaultStatusColors() {
        return {
            'Backlog': '#E5E5E5',
            'Pending': '#FFB75D',
            'In Progress': '#0176D3',
            'In Review': '#5B21B6',
            'Blocked': '#C23934',
            'Completed': '#2E844A',
            'Removed': '#706E6B'
        };
    }

    getContrastTextColor(hexColor) {
        if (!hexColor) return '#080707';
        
        const hex = hexColor.replace('#', '');
        const r = parseInt(hex.substring(0, 2), 16);
        const g = parseInt(hex.substring(2, 4), 16);
        const b = parseInt(hex.substring(4, 6), 16);
        const brightness = (r * 299 + g * 587 + b * 114) / 1000;
        
        return brightness > 128 ? '#080707' : '#FFFFFF';
    }

    handleProjectClick() {
        if (this.task?.Project__c) {
            const projectUrl = `/project/${this.task.Project__c}`;
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: projectUrl
                }
            });
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
