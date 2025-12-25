/**
 * Salesforce Messaging Wrapper
 * 
 * This wrapper ensures proper initialization for the messaging component in Salesforce context.
 * It handles context detection and ensures messages load correctly.
 */

import { LightningElement, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

export default class SalesforceMessaging extends LightningElement {
    @api recordId;
    @api relatedAccountId;
    @api relatedProjectId;
    @api relatedTaskId;
    
    _coreComponent;
    _isInitialized = false;
    
    /**
     * @description Wire service to detect current page reference
     * Ensures recordId is properly set from page reference
     */
    @wire(CurrentPageReference)
    resolvePageReference(pageRef) {
        if (!pageRef || this._isInitialized) {
            return;
        }
        
        // Extract recordId from page reference if not provided via @api
        if (!this.recordId) {
            const { attributes = {}, state = {} } = pageRef;
            this.recordId = state.recordId || attributes.recordId;
        }
        
        // Auto-populate context based on object type
        if (this.recordId && pageRef.attributes?.objectApiName) {
            const objectApiName = pageRef.attributes.objectApiName;
            if (objectApiName === 'Account' && !this.relatedAccountId) {
                this.relatedAccountId = this.recordId;
            } else if (objectApiName === 'Project__c' && !this.relatedProjectId) {
                this.relatedProjectId = this.recordId;
            } else if (objectApiName === 'Project_Task__c' && !this.relatedTaskId) {
                this.relatedTaskId = this.recordId;
            }
        }
        
        this._isInitialized = true;
    }
    
    /**
     * @description Get the core messaging component reference
     */
    get coreComponent() {
        if (!this._coreComponent) {
            this._coreComponent = this.template.querySelector('c-portal-messaging');
        }
        return this._coreComponent;
    }
    
    /**
     * @description Component lifecycle hook
     */
    connectedCallback() {
        // Ensure core component is ready
        setTimeout(() => {
            if (this.coreComponent) {
                // Core component will handle its own initialization
                console.log('Salesforce Messaging wrapper initialized');
            }
        }, 100);
    }
}
