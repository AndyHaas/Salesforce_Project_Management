/**
 * Salesforce Messaging Wrapper
 *
 * This wrapper ensures proper initialization for the messaging component in Salesforce context.
 * It handles context detection and ensures messages load correctly.
 */

import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import {
  extractRecordIdFromPageReference,
  relatedIdsFromRecordAndObject
} from "./salesforceMessagingUtils";

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

    if (!this._recordId) {
      this._recordId = extractRecordIdFromPageReference(pageRef);
    }

    if (this._recordId && pageRef.attributes?.objectApiName) {
      const related = relatedIdsFromRecordAndObject(
        this._recordId,
        pageRef.attributes.objectApiName
      );
      if (related.relatedAccountId && !this._relatedAccountId) {
        this._relatedAccountId = related.relatedAccountId;
      }
      if (related.relatedProjectId && !this._relatedProjectId) {
        this._relatedProjectId = related.relatedProjectId;
      }
      if (related.relatedTaskId && !this._relatedTaskId) {
        this._relatedTaskId = related.relatedTaskId;
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
        // Core component handles its own initialization
      }
    }, 100);
  }
}
