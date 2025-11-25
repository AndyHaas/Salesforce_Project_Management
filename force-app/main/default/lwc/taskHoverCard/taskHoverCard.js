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
    _parentWrapper = null;
    _boundHandlers = {
        mouseenter: null,
        mouseleave: null,
        focusin: null,
        focusout: null
    };
    
    connectedCallback() {
        // Use setTimeout to ensure DOM is fully rendered before finding parent
        // This is especially important when component is rendered inside loops or conditionally
        setTimeout(() => {
            // Try multiple approaches to find the parent wrapper
            let parentWrapper = this.template.host.closest('.task-name-wrapper, .subtask-name-wrapper');
            
            // Fallback: if closest doesn't work, try traversing up the DOM tree
            if (!parentWrapper) {
                let element = this.template.host.parentElement;
                while (element && !parentWrapper) {
                    if (element.classList && 
                        (element.classList.contains('task-name-wrapper') || 
                         element.classList.contains('subtask-name-wrapper'))) {
                        parentWrapper = element;
                        break;
                    }
                    element = element.parentElement;
                }
            }
            
            if (parentWrapper) {
                this._parentWrapper = parentWrapper;
                // Store bound handlers for cleanup
                this._boundHandlers.mouseenter = this.handleParentHover.bind(this);
                this._boundHandlers.mouseleave = this.handleParentLeave.bind(this);
                this._boundHandlers.focusin = this.handleParentHover.bind(this);
                this._boundHandlers.focusout = this.handleParentLeave.bind(this);
                
                parentWrapper.addEventListener('mouseenter', this._boundHandlers.mouseenter);
                parentWrapper.addEventListener('mouseleave', this._boundHandlers.mouseleave);
                parentWrapper.addEventListener('focusin', this._boundHandlers.focusin);
                parentWrapper.addEventListener('focusout', this._boundHandlers.focusout);
            } else {
                console.warn('taskHoverCard: Could not find parent wrapper (.task-name-wrapper or .subtask-name-wrapper)');
            }
        }, 0);
    }
    
    disconnectedCallback() {
        // Clean up event listeners
        if (this._parentWrapper && this._boundHandlers) {
            if (this._boundHandlers.mouseenter) {
                this._parentWrapper.removeEventListener('mouseenter', this._boundHandlers.mouseenter);
            }
            if (this._boundHandlers.mouseleave) {
                this._parentWrapper.removeEventListener('mouseleave', this._boundHandlers.mouseleave);
            }
            if (this._boundHandlers.focusin) {
                this._parentWrapper.removeEventListener('focusin', this._boundHandlers.focusin);
            }
            if (this._boundHandlers.focusout) {
                this._parentWrapper.removeEventListener('focusout', this._boundHandlers.focusout);
            }
        }
        this._parentWrapper = null;
        this._boundHandlers = {
            mouseenter: null,
            mouseleave: null,
            focusin: null,
            focusout: null
        };
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
            const isStatusField = field.apiName === 'Status__c';
            const isRichText = field.isRichText === true;
            
            // For Status field, use taskStatus prop as the authoritative source
            // For other fields, use lightning-formatted-rich-text which handles both HTML and plain text
            let displayValue;
            let richTextValue;
            if (isStatusField) {
                // Use taskStatus prop as the display value for Status field
                displayValue = this.taskStatus && this.taskStatus.trim().length > 0 ? this.taskStatus.trim() : '—';
                richTextValue = null;
            } else {
                // For all non-status fields, use lightning-formatted-rich-text
                // It handles both HTML (rich text) and plain text safely
                const trimmedValue = typeof rawValue === 'string' ? rawValue.trim() : rawValue;
                richTextValue = trimmedValue && trimmedValue.length > 0 ? trimmedValue : '';
                displayValue = ''; // Not used when using lightning-formatted-rich-text
            }
            
            return {
                ...field,
                displayValue,
                richTextValue, // Value for lightning-formatted-rich-text (handles both HTML and plain text)
                valueClass: `hover-value${field.isLongText ? ' hover-value_multiline' : ''}${isRichText ? ' hover-value_richtext' : ''}`,
                isStatus: isStatusField,
                isRichText: isRichText,
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

