# PortalMessagingController

## Overview

**Location**: `force-app/portal/main/default/classes/Portal/PortalMessagingController.cls`

The `PortalMessagingController` is the main Apex controller for all messaging operations. It handles data retrieval, message creation, updates, and security enforcement.

## Sharing Model

`without sharing` - Allows portal users to create message records while maintaining security through WHERE clause filters.

## Key Methods

### sendMessage()

**Parameters**: 
- `messageBody` (String, required)
- `recipientType` (String, required) - "Client" or "Milestone Team"
- `relatedAccountId` (String, optional)
- `relatedProjectId` (String, optional)
- `relatedTaskId` (String, optional)
- `mentionedContactIds` (List<String>, optional)
- `isVisibleToClient` (Boolean, optional, default: true)
- `replyToMessageId` (String, optional)

**Returns**: Message ID (String)

**Features**:
- Auto-creates Contact for Milestone team members if needed
- Inherits context from task/project/account (priority: Task > Project > Account)
- Inherits context from reply-to message if replying
- Validates portal users cannot send internal messages
- Sends mention notifications

**Implementation Flow**:
1. Validates required fields (`messageBody`, `recipientType`)
2. Gets current user with Contact fields
3. Gets/creates Contact for user (handles Milestone team members)
4. Creates message record
5. Sets context (Task > Project > Account priority)
6. Handles reply-to message context inheritance
7. Sets mentioned contacts
8. Validates portal users cannot send internal messages
9. Inserts message
10. Sends mention notifications
11. Returns message ID

### getMessages()

**Parameters**:
- `recipientType` (String, optional)
- `relatedAccountId` (String, optional)
- `relatedProjectId` (String, optional)
- `relatedTaskId` (String, optional)
- `limitCount` (Integer, optional, default: 50, max: 200)
- `offset` (Integer, optional, default: 0)
- `orderByField` (String, optional, default: "CreatedDate")
- `orderDirection` (String, optional, default: "DESC")
- `searchTerm` (String, optional)

**Returns**: `List<MessageInfo>`

**Features**:
- Server-side filtering by recipient type and context
- Server-side search with wildcard support
- Pagination with OFFSET
- Access control via WHERE clause filters
- Field-level security enforcement (`WITH SECURITY_ENFORCED`)
- Reverse chronological order (newest at bottom)

**Implementation Flow**:
1. Normalizes input parameters
2. Gets current user and Contact
3. Builds access filters (sender OR recipient bucket)
4. Builds context filter (Task > Project > Account)
5. Builds search filters (if search term provided)
6. Assembles WHERE clause
7. Validates and normalizes limit, offset, order field, order direction
8. Constructs SOQL query with bind variables
9. Executes query with `WITH SECURITY_ENFORCED`
10. Converts to `MessageInfo` objects
11. Returns message list

### getLatestMessages(limitCount)

**Parameters**:
- `limitCount` (Integer, optional, default: 10)

**Returns**: `List<MessageInfo>` - Recent messages for notifications

**Cacheable**: Yes

### updateMessage(messageId, messageBody)

**Parameters**:
- `messageId` (String, required)
- `messageBody` (String, required)

**Security**: Only sender can edit their own messages

**Features**: 
- Updates body
- Sets `Is_Edited__c = true`
- Updates `Last_Edited_Date__c`

**Note**: FLS bypassed here to allow portal users to edit their own messages. Security is enforced via sender verification - users can only edit messages they sent.

### deleteMessage(messageId)

**Parameters**:
- `messageId` (String, required)

**Type**: Soft delete (sets `Deleted__c = true`)

**Security**: Only sender can delete their own messages

### markAsRead(messageId)

**Parameters**:
- `messageId` (String, required)

**Action**: Sets `Is_Read__c = true`

### pinMessage(messageId, isPinned)

**Parameters**:
- `messageId` (String, required)
- `isPinned` (Boolean, required)

**Action**: Sets `Is_Pinned__c` flag

### getMentionableContacts(searchTerm)

**Parameters**:
- `searchTerm` (String, optional)

**Returns**: `List<ContactInfo>` - Contacts available for mentions

**Filtering**: 
- Portal users: Contacts in same account
- Milestone team members: Contacts with `Portal_Access_Enabled__c = true`

**Limit**: 20 contacts

### linkFilesToMessage(messageId, contentVersionIds)

**Parameters**:
- `messageId` (String, required)
- `contentVersionIds` (List<String>, required)

**Action**: Links ContentVersion records to messages via ContentDocumentLink

### getMessageFiles(messageId)

**Parameters**:
- `messageId` (String, required)

**Returns**: `List<FileInfo>` - Files attached to message

### getContextInfo(relatedAccountId, relatedProjectId, relatedTaskId)

**Parameters**:
- `relatedAccountId` (String, optional)
- `relatedProjectId` (String, optional)
- `relatedTaskId` (String, optional)

**Returns**: `ContextInfo` - Context information for messaging component

**Cacheable**: Yes

## Helper Methods

### getOrCreateContactForUser(User user)

**Private method**: Creates/finds Contact for Milestone team members

**Logic**:
1. Returns `user.ContactId` if available
2. Searches for existing Contact by email
3. Creates new Contact if not found

**Used by**: All methods that need sender ContactId

### normalizeOptional(String value)

Normalizes undefined/blank strings from JavaScript

**Handles**: `null`, empty strings, `'undefined'`, `'null'` strings

### getCurrentUserWithContactFields()

**Private method**: Gets current user with Contact fields

**Returns**: User record with `Id`, `ContactId`, `AccountId`, `Name`, `Email`

## Constants

### Field Name Constants
- `FIELD_ID`, `FIELD_ACCOUNT`, `FIELD_PROJECT`, `FIELD_TASK`, etc.

### Recipient Type Constants
- `RECIPIENT_CLIENT`: "Client"
- `RECIPIENT_TEAM`: "Milestone Team"

### Query Limits
- `MAX_MESSAGE_LIMIT`: 200
- `DEFAULT_MESSAGE_LIMIT`: 50
- `MAX_CONTACT_SEARCH_LIMIT`: 20

## Search Pattern Processing

The controller processes search terms to support wildcards:

```apex
// Convert * to %
String processedSearch = normalizedSearchTerm.replace('*', '%');

// Escape _ and \ (but NOT %)
// _ is treated as literal character
// Note: Bind variables provide SQL injection protection, so escapeSingleQuotes not needed
// We only escape LIKE special characters (_ and \) to treat them as literals
String escapedSearch = processedSearch.replaceAll('([_\\\\])', '\\\\$1');

// Wrap with % if not already present
if (!escapedSearch.startsWith('%')) {
    escapedSearch = '%' + escapedSearch;
}
if (!escapedSearch.endsWith('%')) {
    escapedSearch = escapedSearch + '%';
}
```

**Wildcard Behavior**:
- `*` converts to `%` (SQL wildcard)
- `%` allowed as explicit wildcard
- `_` treated as literal character (escaped)

## Access Control Logic

Access control is enforced through WHERE clause filters:

```apex
// User can see messages they sent
accessFilters.add('Sender__c = :currentUserContactId');

// OR messages in their recipient bucket
if (recipientType == 'Client') {
    accessFilters.add('Recipient_Type__c = :recipientClientValue AND Account__c = :currentUserAccountId');
} else if (recipientType == 'Milestone Team') {
    accessFilters.add('Recipient_Type__c = :recipientTeamValue');
}

// Portal users only see messages visible to clients
if (currentUser.AccountId != null) {
    accessFilters.add('Visible_To_Client__c = true');
}
```

## Security Features

### SOQL Injection Protection
- All user inputs use bind variables (`:currentUserContactId`, `:searchPattern`, etc.)
- Search terms properly escaped for LIKE queries
- Order field validation using allowlist (`CreatedDate`, `LastEditedDate`, `IsPinned`)
- Constants used for field names

### Field-Level Security
- `WITH SECURITY_ENFORCED` used in most queries
- FLS bypass in `updateMessage` is intentional and documented (allows portal users to edit their own messages)

### Input Validation
- Required field validation
- Limit validation (max 200)
- Offset validation (non-negative)

## Error Handling

All public methods include try-catch blocks with meaningful error messages:

```apex
try {
    // Method logic
} catch (DmlException e) {
    // Handle DML errors with field-specific messages
} catch (Exception e) {
    // Handle generic errors
    throw new AuraHandledException('Error message: ' + e.getMessage());
}
```

## Related Documentation

- [Portal Messaging System](Portal_Messaging_System.md) - System overview and configuration
- [portalMessaging Component](portalMessaging_Component.md) - LWC component documentation
