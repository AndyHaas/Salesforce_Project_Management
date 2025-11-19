/**
 * @description Reusable Task Hover Card Component
 * 
 * Displays a hover card with task field information when hovering over a task name.
 * Handles decoration of hover fields including display value formatting, status badge classes,
 * and multiline text handling.
 * 
 * USAGE:
 * - Used by: groupedTaskList, taskContextPanel
 * - Accepts raw hoverFields from Apex and taskStatus for badge class computation
 */
import { LightningElement, api } from 'lwc';

export default class TaskHoverCard extends LightningElement {
    _isVisible = false;
    
    connectedCallback() {
        // Find the parent wrapper and add hover listeners
        const parentWrapper = this.template.host.closest('.task-name-wrapper, .subtask-name-wrapper');
        if (parentWrapper) {
            parentWrapper.addEventListener('mouseenter', this.handleParentHover.bind(this));
            parentWrapper.addEventListener('mouseleave', this.handleParentLeave.bind(this));
            parentWrapper.addEventListener('focusin', this.handleParentHover.bind(this));
            parentWrapper.addEventListener('focusout', this.handleParentLeave.bind(this));
        }
    }
    
    handleParentHover() {
        this._isVisible = true;
    }
    
    handleParentLeave() {
        this._isVisible = false;
    }
    
    get showCard() {
        return this._isVisible && this.decoratedHoverFields && this.decoratedHoverFields.length > 0;
    }
    /**
     * @description Raw hover fields from Apex (before decoration)
     * @type {Array}
     */
    @api hoverFields;
    
    /**
     * @description Task status for computing badge classes
     * @type {String}
     */
    @api taskStatus;
    
    /**
     * @description Badge style to use: 'slds' for SLDS badges, 'custom' for custom status badges
     * @type {String}
     * @default 'slds'
     */
    @api badgeStyle = 'slds';
    
    /**
     * @description Decorated hover fields ready for display
     * @type {Array}
     */
    get decoratedHoverFields() {
        if (!this.hoverFields || !Array.isArray(this.hoverFields)) {
            return [];
        }
        
        return this.hoverFields.map(field => {
            const rawValue = typeof field.value === 'string' ? field.value : (field.value ?? '');
            const trimmedValue = typeof rawValue === 'string' ? rawValue.trim() : rawValue;
            const displayValue = trimmedValue && trimmedValue.length > 0 ? trimmedValue : '—';
            const isStatusField = field.apiName === 'Status__c';
            
            return {
                ...field,
                displayValue,
                valueClass: `hover-value${field.isLongText ? ' hover-value_multiline' : ''}`,
                isStatus: isStatusField,
                badgeClass: isStatusField ? this.getStatusBadgeClass(this.taskStatus) : ''
            };
        });
    }
    
    /**
     * @description Get status badge class based on badge style
     * @param {String} status - Task status
     * @returns {String} Badge class name
     */
    getStatusBadgeClass(status) {
        if (!status) {
            return this.badgeStyle === 'slds' ? 'slds-badge' : 'status-badge status-badge-default';
        }
        
        if (this.badgeStyle === 'slds') {
            return this.getSLDSBadgeClass(status);
        } else {
            return this.getCustomBadgeClass(status);
        }
    }
    
    /**
     * @description Get SLDS badge class for status
     * @param {String} status - Task status
     * @returns {String} SLDS badge class
     */
    getSLDSBadgeClass(status) {
        const statusClasses = {
            'Backlog': 'slds-badge slds-badge_lightest',
            'Pending': 'slds-badge slds-badge_warning',
            'In Progress': 'slds-badge slds-badge_info',
            'In Review': 'slds-badge slds-badge_inverse',
            'Blocked': 'slds-badge slds-badge_error',
            'Completed': 'slds-badge slds-badge_success',
            'Removed': 'slds-badge slds-badge_offline',
            'Closed': 'slds-badge slds-badge_success'
        };
        return statusClasses[status] || 'slds-badge';
    }
    
    /**
     * @description Get custom badge class for status
     * @param {String} status - Task status
     * @returns {String} Custom badge class
     */
    getCustomBadgeClass(status) {
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
            'removed': 'status-badge status-badge-removed',
            'Closed': 'status-badge status-badge-closed',
            'closed': 'status-badge status-badge-closed'
        };
        
        return statusClasses[status] || statusClasses[normalizedStatus] || 'status-badge status-badge-default';
    }
}

