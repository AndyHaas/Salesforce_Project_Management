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
    _renderedRichTextFields = new Map();
    
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
    
    renderedCallback() {
        // Render rich text fields using lwc:dom-manual
        // This runs after every render, so we need to check if card is visible
        if (this._isVisible && this.decoratedHoverFields && this.decoratedHoverFields.length > 0) {
            // Use setTimeout to ensure DOM is fully rendered after template updates
            setTimeout(() => {
                this.decoratedHoverFields.forEach(field => {
                    if (field.isRichText && field.apiName) {
                        const richTextElement = this.template.querySelector(`[data-rich-text="${field.apiName}"]`);
                        if (richTextElement) {
                            // Use htmlValue (raw HTML) for rich text fields
                            const currentValue = field.htmlValue || '';
                            const lastRenderedValue = this._renderedRichTextFields.get(field.apiName);
                            // Only update if value changed to avoid unnecessary DOM manipulation
                            if (currentValue !== lastRenderedValue) {
                                richTextElement.innerHTML = currentValue;
                                this._renderedRichTextFields.set(field.apiName, currentValue);
                            }
                        }
                    }
                });
            }, 0);
        }
    }
    
    handleParentHover() {
        this._isVisible = true;
        // Trigger render update when card becomes visible
        // Use setTimeout to ensure DOM is ready
        setTimeout(() => {
            if (this.decoratedHoverFields && this.decoratedHoverFields.length > 0) {
                this.decoratedHoverFields.forEach(field => {
                    if (field.isRichText && field.apiName) {
                        const richTextElement = this.template.querySelector(`[data-rich-text="${field.apiName}"]`);
                        if (richTextElement) {
                            // Use htmlValue (raw HTML) for rich text fields
                            const htmlContent = field.htmlValue || '';
                            richTextElement.innerHTML = htmlContent;
                            this._renderedRichTextFields.set(field.apiName, htmlContent);
                        }
                    }
                });
            }
        }, 50);
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
            // For rich text fields, preserve the raw HTML value
            // For other fields, use trimmed display value
            let displayValue;
            let htmlValue;
            if (isStatusField) {
                // Use taskStatus prop as the display value for Status field
                displayValue = this.taskStatus && this.taskStatus.trim().length > 0 ? this.taskStatus.trim() : '—';
                htmlValue = null;
            } else if (isRichText) {
                htmlValue = rawValue || '';
                displayValue = htmlValue && htmlValue.length > 0 ? htmlValue : '—';
            } else {
                const trimmedValue = typeof rawValue === 'string' ? rawValue.trim() : rawValue;
                displayValue = trimmedValue && trimmedValue.length > 0 ? trimmedValue : '—';
                htmlValue = null;
            }
            
            return {
                ...field,
                displayValue,
                htmlValue, // Store raw HTML for rich text fields
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

