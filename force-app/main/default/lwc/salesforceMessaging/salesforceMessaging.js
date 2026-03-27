/**
 * Salesforce Messaging Wrapper
 *
 * This wrapper ensures proper initialization for the messaging component in Salesforce context.
 * It handles context detection and ensures messages load correctly.
 */

import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";

export default class SalesforceMessaging extends LightningElement {
  _recordId;
  _relatedAccountId;
  _relatedProjectId;
  _relatedTaskId;

  @api
  get recordId() {
    return this._recordId;
  }
  set recordId(value) {
    this._recordId = value;
  }
  @api
  get relatedAccountId() {
    return this._relatedAccountId;
  }
  set relatedAccountId(value) {
    this._relatedAccountId = value;
  }
  @api
  get relatedProjectId() {
    return this._relatedProjectId;
  }
  set relatedProjectId(value) {
    this._relatedProjectId = value;
  }
  @api
  get relatedTaskId() {
    return this._relatedTaskId;
  }
  set relatedTaskId(value) {
    this._relatedTaskId = value;
  }

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
    if (!this._recordId) {
      const { attributes = {}, state = {} } = pageRef;
      this._recordId = state.recordId || attributes.recordId;
    }

    // Auto-populate context based on object type
    if (this._recordId && pageRef.attributes?.objectApiName) {
      const objectApiName = pageRef.attributes.objectApiName;
      if (objectApiName === "Account" && !this._relatedAccountId) {
        this._relatedAccountId = this._recordId;
      } else if (objectApiName === "Project__c" && !this._relatedProjectId) {
        this._relatedProjectId = this._recordId;
      } else if (objectApiName === "Project_Task__c" && !this._relatedTaskId) {
        this._relatedTaskId = this._recordId;
      }
    }

    this._isInitialized = true;
  }

  /**
   * @description Get the core messaging component reference
   */
  get coreComponent() {
    if (!this._coreComponent) {
      this._coreComponent = this.template.querySelector("c-portal-messaging");
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
        console.log("Salesforce Messaging wrapper initialized");
      }
    }, 100);
  }
}
