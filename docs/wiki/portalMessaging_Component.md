# portalMessaging Component

## Overview

**Location**: `force-app/portal/main/default/lwc/portalMessaging/`

The `portalMessaging` component is the core messaging component that works in both Experience Cloud (Portal) and Salesforce Lightning Experience contexts. It handles all messaging functionality including sending, receiving, searching, editing, and managing messages.

## Features

- Message display with infinite scrolling (newest at bottom)
- Server-side search with wildcard support
- Message sending with context inheritance
- Message editing (sender only)
- Message deletion (soft delete)
- Message pinning
- Mark as read functionality
- File attachments
- Contact mentions with autocomplete
- Reply to messages
- Context-aware navigation

## Properties

- `@api recordId`: Automatically populated when on a Lightning Record Page
- `@api relatedAccountId`: Optional account ID for message context
- `@api relatedProjectId`: Optional project ID for message context
- `@api relatedTaskId`: Optional task ID for message context

## Context Detection

The component automatically detects its runtime context using multiple methods:
1. **Pathname check**: Experience Cloud URLs start with `/s/`
2. **User type**: Milestone team members (no AccountId) are in Salesforce context
3. **Page reference type**: Experience Cloud pages have `comm__` prefix, Salesforce has `standard__`

## Behavior by Context

### Portal (Experience Cloud)
- Users can only send to "Milestone Team"
- Recipient type selector is hidden
- Navigation uses `ensureSitePath()` for portal URLs
- Default `recipientType`: "Milestone Team"

### Salesforce Lightning Experience
- Milestone team members can send to "Client" or "Milestone Team"
- Recipient type selector is shown
- Can send internal messages (not visible to clients)
- Navigation uses Lightning Navigation Service
- Default `recipientType`: "Client"

## State Management

```javascript
_messages = [];                    // Loaded messages array
_currentOffset = 0;                // Pagination offset
_isLoadingMore = false;            // Loading state
_hasMoreMessages = true;           // More messages available
_messagesPerPage = 50;            // Page size
_searchTimeout = null;            // Debounce timer
messageSearchTerm = '';            // Current search term
recipientType = null;              // Recipient type (Client/Team)
```

## Lifecycle Methods

- `connectedCallback()`: Initializes component, detects context, loads initial messages
- `renderedCallback()`: Handles scroll position after message load
- `disconnectedCallback()`: Unsubscribes from message channel

## Wire Services

- `@wire(CurrentPageReference)`: Detects page context and extracts record IDs
- `@wire(MessageContext)`: Sets up Lightning Message Service context

## Key Methods

- `loadMessages(append)`: Load messages with pagination and search
- `loadMoreMessages()`: Load next page of messages (infinite scroll)
- `handleScroll(event)`: Detect scroll position and load more when near top
- `sendMessage()`: Send a new message
- `handleMessageSearchChange(event)`: Handle search input with debouncing
- `handleClearSearch()`: Clear search and reload all messages
- `markAsRead(messageId)`: Mark message as read
- `updateMessage(messageId, body)`: Edit message
- `deleteMessage(messageId)`: Delete message
- `pinMessage(messageId, isPinned)`: Pin/unpin message
- `buildLink(recordId, objectType)`: Build navigation link based on context
- `handleNavigateToRecord(event)`: Handle navigation in Salesforce context

## Event Handlers

- `handleScroll(event)`: Detects scroll near top, loads more messages
- `handleMessageSearchChange(event)`: Debounced search input handler
- `handleSendMessage()`: Sends new message
- `handleEditMessage(event)`: Opens edit modal
- `handleDeleteMessage(event)`: Deletes message
- `handlePinMessage(event)`: Pins/unpins message
- `handleNavigateToRecord(event)`: Handles navigation in Salesforce context

## Getters

- `messages`: Returns processed messages with task footer visibility logic
- `isLoadingMore`: Returns loading state
- `hasMoreMessages`: Returns whether more messages available
- `messageCount`: Returns message count
- `messageCountText`: Returns pluralized "message"/"messages"
- `isExperienceCloud`: Returns true if in Experience Cloud context
- `isSalesforceContext`: Returns true if in Salesforce context

## Scroll Management

- `scrollToBottom()`: Scrolls to bottom on initial load
- `maintainScrollPosition()`: Maintains scroll position when loading older messages
- Scroll detection: Triggers load when within 200px of top

## Search Implementation

- Debounced input (500ms delay)
- Server-side search via `getMessages()` with `searchTerm` parameter
- Wildcard support: `*` → `%`, `%` allowed, `_` escaped
- Search resets pagination (`_currentOffset = 0`)

## Message Channel Integration

- Subscribes to `MessageUpdate__c` channel for real-time updates
- Publishes updates when messages are created/updated/deleted

## Usage Example

```html
<c-portal-messaging
    record-id={recordId}
    related-task-id={taskId}
    related-project-id={projectId}
    related-account-id={accountId}>
</c-portal-messaging>
```

## Related Documentation

- [Portal Messaging System](Portal_Messaging_System.md) - System overview and configuration
- [PortalMessagingController](PortalMessagingController.md) - Apex controller documentation
