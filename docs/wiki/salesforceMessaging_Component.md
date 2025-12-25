# salesforceMessaging Component

## Overview

**Location**: `force-app/main/default/lwc/salesforceMessaging/`

The `salesforceMessaging` component is a wrapper component for Salesforce Lightning Experience that uses `portalMessaging` internally. It provides a consistent API for Salesforce contexts while delegating functionality to the core component.

## Purpose

This wrapper ensures proper initialization for the messaging component in Salesforce context. It handles context detection and ensures messages load correctly when used in Lightning Experience.

## Properties

- `@api recordId`: Record ID from the Lightning Record Page
- `@api relatedAccountId`: Optional account ID for message context
- `@api relatedProjectId`: Optional project ID for message context
- `@api relatedTaskId`: Optional task ID for message context

All properties are passed through to the core `portalMessaging` component.

## Wire Services

- `@wire(CurrentPageReference)`: Detects current page reference and extracts record IDs

## Key Functionality

### Page Reference Resolution

The component automatically extracts the `recordId` from the page reference if not provided via `@api`:

```javascript
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
```

### Component Initialization

The component ensures the core `portalMessaging` component is ready:

```javascript
connectedCallback() {
    // Ensure core component is ready
    setTimeout(() => {
        if (this.coreComponent) {
            // Core component will handle its own initialization
            console.log('Salesforce Messaging wrapper initialized');
        }
    }, 100);
}
```

## Usage

Place on Salesforce Lightning record pages or app pages. The component automatically uses the core `portalMessaging` component with Salesforce-specific navigation.

### Example Placement

```html
<!-- On Project Task Record Page -->
<c-salesforce-messaging
    record-id={recordId}>
</c-salesforce-messaging>

<!-- On Project Record Page -->
<c-salesforce-messaging
    record-id={recordId}>
</c-salesforce-messaging>

<!-- On Account Record Page -->
<c-salesforce-messaging
    record-id={recordId}>
</c-salesforce-messaging>
```

**Note**: The `recordId` is automatically populated when placed on a Lightning Record Page. The component will also auto-populate `relatedAccountId`, `relatedProjectId`, or `relatedTaskId` based on the object type.

## Related Documentation

- [portalMessaging Component](portalMessaging_Component.md) - Core component documentation
- [Portal Messaging System](Portal_Messaging_System.md) - System overview and configuration
