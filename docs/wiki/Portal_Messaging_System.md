# Portal Messaging System

## Overview

The Portal Messaging system enables secure communication between clients and the Milestone Consulting team within the Experience Cloud portal and Salesforce Lightning Experience. The system supports bidirectional messaging, file attachments, mentions, replies, and context-aware message threading.

## Key Features

1. **Dual Context Support**: Works seamlessly in both Experience Cloud (Portal) and Salesforce Lightning Experience
2. **Recipient Type Management**: 
   - Portal users (clients) can send messages to "Milestone Team"
   - Milestone team members can send to "Client" or "Milestone Team"
   - Internal team messages can be hidden from clients
3. **Infinite Scrolling**: Messages load with pagination, newest messages at bottom, scroll up to load older messages
4. **Server-Side Search**: Full-text search across all messages with wildcard support (`*`, `%`, literal `_`)
5. **Message Management**: Edit, delete, pin, and mark messages as read
6. **File Attachments**: Link files to messages via ContentVersion
7. **Mentions**: Mention contacts in messages with autocomplete
8. **Replies**: Reply to messages with context inheritance
9. **Context-Aware Navigation**: Links work correctly in both portal and Salesforce contexts

## Components

The messaging system consists of the following components:

- **[portalMessaging Component](portalMessaging_Component.md)**: Core Lightning Web Component for messaging functionality
- **[salesforceMessaging Component](salesforceMessaging_Component.md)**: Wrapper component for Salesforce Lightning Experience
- **[PortalMessagingController](PortalMessagingController.md)**: Apex controller for all messaging operations

## Security & Access Control

### Sharing Model
- Class uses `without sharing` to allow portal users to create message records
- Access control enforced through WHERE clause filters:
  - Users can see messages they sent
  - Users can see messages in their recipient bucket (Client or Milestone Team)
  - Portal users only see messages visible to clients (`Visible_To_Client__c = true`)

### Field-Level Security
- `WITH SECURITY_ENFORCED` used in most queries
- FLS bypass in `updateMessage` is intentional and documented (allows portal users to edit their own messages)

### SOQL Injection Protection
- All user inputs use bind variables
- Search terms properly escaped for LIKE queries
- Order field validation using allowlist
- Constants used for field names

## Message Object Structure

The `Message__c` custom object contains:
- `Body__c`: Rich text message content
- `Sender__c`: Contact lookup (sender of the message)
- `Recipient_Type__c`: Picklist ("Client" or "Milestone Team")
- `Visible_To_Client__c`: Boolean (internal messages can be hidden)
- `Related_Task__c`: Lookup to Project_Task__c
- `Related_Project__c`: Lookup to Project__c
- `Account__c`: Lookup to Account
- `Mentioned_Contacts__c`: Comma-separated Contact IDs
- `Reply_To__c`: Lookup to Message__c (for replies)
- `Is_Read__c`: Boolean
- `Is_Edited__c`: Boolean
- `Is_Pinned__c`: Boolean
- `Deleted__c`: Boolean (soft delete)

## Recent Enhancements

### Auto-Creation of Contacts for Milestone Team Members
- Milestone team members (Salesforce Users without ContactId) can send messages
- System automatically creates/finds Contact records for Users when needed
- Method: `getOrCreateContactForUser()` handles this transparently

### Infinite Scrolling & Pagination
- Messages load in pages of 50 (configurable via `_messagesPerPage`)
- Reverse chronological order: newest messages at bottom
- Scroll to top to load older messages
- Loading indicators show when fetching more messages

### Server-Side Search
- Full-text search across `Body__c` and `Sender__r.Name`
- Wildcard support:
  - `*` converts to `%` (SQL wildcard)
  - `%` allowed as explicit wildcard
  - `_` treated as literal character (escaped)
- Search is debounced (500ms) to reduce server calls
- Search resets pagination

### Context-Aware Navigation
- Portal context: Uses `ensureSitePath()` for portal URLs
- Salesforce context: Uses Lightning Navigation Service
- Links automatically adapt based on runtime context

## Usage

### In Experience Cloud Portal
The messaging component is typically placed on:
- Project Task detail pages
- Project detail pages
- Account detail pages
- Home page

**Example Placement**:
```html
<!-- On Project Task Detail Page -->
<c-portal-messaging
    related-task-id={recordId}>
</c-portal-messaging>

<!-- On Project Detail Page -->
<c-portal-messaging
    related-project-id={recordId}>
</c-portal-messaging>

<!-- On Account Detail Page -->
<c-portal-messaging
    related-account-id={recordId}>
</c-portal-messaging>
```

### In Salesforce Lightning Experience
The `salesforceMessaging` wrapper component can be placed on:
- Project Task record pages
- Project record pages
- Account record pages
- App pages

**Example Placement**:
```html
<!-- On Project Task Record Page -->
<c-salesforce-messaging
    record-id={recordId}>
</c-salesforce-messaging>
```

**Note**: The `recordId` is automatically populated when placed on a Lightning Record Page. You can also explicitly set `related-task-id`, `related-project-id`, or `related-account-id` for context.

## Configuration

### Permission Sets
- **`Portal_Messaging`**: Permission set for portal users to access messaging functionality
  - Location: `force-app/main/default/permissionsets/Portal_Messaging.permissionset-meta.xml`
  - **Field Permissions**:
    - Read/Write: `Body__c`, `Account__c`, `Related_Project__c`, `Related_Task__c`, `Mentioned_Contacts__c`, `Is_Read__c`, `Deleted__c`
    - Read-only: `Is_Edited__c`, `Is_Pinned__c`, `Last_Edited_Date__c`
  - **Class Access**: `PortalMessagingController`
  - **Object Access**: `Message__c` (Read, Create, Edit, Delete)

### Message Channel
- **`MessageUpdate__c`**: Lightning Message Service channel for inter-component communication
  - Location: `force-app/main/default/messageChannels/MessageUpdate.messageChannel-meta.xml`
  - **Usage**: Notifies components when messages are created/updated/deleted
  - **Message Format**: `{ type: 'created'|'updated'|'deleted', messageId: String, relatedTaskId: String }`
  - **Subscribers**: Components can subscribe to receive real-time updates

### Component Configuration

**portalMessaging Component Properties**:
- All properties are optional and can be set via component attributes
- Component automatically detects context from `CurrentPageReference` if properties not set
- Priority for context: `relatedTaskId` > `relatedProjectId` > `relatedAccountId` > user's account

**Recipient Type Behavior**:
- **Portal Users**: Always send to "Milestone Team", selector hidden
- **Milestone Team Members**: Can choose "Client" or "Milestone Team", selector visible
- **Default**: Portal = "Milestone Team", Salesforce = "Client"

## Testing

### Test Coverage
- **Test Class**: `PortalMessagingControllerTest`
  - Location: `force-app/portal/main/default/classes/Portal/PortalMessagingControllerTest.cls`
  - **Coverage**: 70% (target: 80%)
  - **Test Methods** (24 total, 18 passing):
    - `testGetOrCreateContactForUser_MilestoneTeamMember`: Tests Contact auto-creation
    - `testSendMessage_MilestoneTeamMember`: Tests message sending
    - `testSendMessage_WithAllFields`: Tests message with all fields populated
    - `testSendMessage_WithRelatedProject`: Tests project context inheritance
    - `testSendMessage_WithRelatedAccount`: Tests account context inheritance
    - `testSendMessage_WithMentionedContacts`: Tests mention functionality
    - `testSendMessage_WithReplyTo`: Tests reply functionality
    - `testSendMessage_NoContextWithAccountId`: Tests fallback to user account
    - `testSendMessage_WithNullVisibleToClient`: Tests default visibility
    - `testSendMessage_ReplyToWithProject`: Tests reply inheriting project
    - `testSendMessage_ReplyToWithAccount`: Tests reply inheriting account
    - `testSendMessage_InternalMessageError`: Tests portal user cannot send internal messages
    - `testSendMessage_ValidationErrors`: Tests input validation
    - `testGetMessages_NoSearchTerm`: Tests basic message retrieval
    - `testGetMessages_EmptySearchTerm`: Tests empty search handling
    - `testGetMessages_WithPagination`: Tests pagination
    - `testGetMessages_WithRecipientType`: Tests recipient type filtering
    - `testGetMessages_WithRelatedTask`: Tests task context filtering
    - `testGetMessages_WithSearch`: Tests search functionality (failing - needs fix)
    - `testGetMessages_WithWildcardSearch`: Tests wildcard search (failing - needs fix)
    - `testGetMessages_WithPercentWildcard`: Tests % wildcard (failing - needs fix)
    - `testGetMessages_WithUnderscoreLiteral`: Tests _ literal (failing - needs fix)
    - `testGetCurrentUserContactId`: Tests Contact ID retrieval
    - `testIsMilestoneTeamMember`: Tests user type detection
    - `testGetLatestMessages`: Tests latest messages retrieval
    - `testGetMentionableContacts`: Tests mentionable contacts (failing - needs fix)
    - `testMarkAsRead`: Tests mark as read
    - `testUpdateMessage`: Tests message editing
    - `testPinMessage`: Tests message pinning
    - `testDeleteMessage`: Tests message deletion
    - `testGetContextInfo`: Tests context resolution

**Note**: Some search-related tests are failing and need investigation. Core functionality tests are passing.

## Code Quality

### Security
- ✅ **Bind Variables**: All user inputs use bind variables (`:currentUserContactId`, `:searchPattern`, etc.)
- ✅ **Input Validation**: Required field validation, limit validation (max 200), offset validation (non-negative)
- ✅ **Field-Level Security**: `WITH SECURITY_ENFORCED` used in most queries
- ✅ **Access Control**: WHERE clause filters ensure users only see their own messages or messages in their recipient bucket
- ✅ **Search Escaping**: Search terms properly escaped for LIKE queries (`_` and `\` escaped, `%` allowed as wildcard)
- ✅ **Order Field Validation**: Allowlist prevents injection (`CreatedDate`, `LastEditedDate`, `IsPinned`)

### Best Practices
- **Constants**: Field names and query limits defined as constants
- **Helper Methods**: `getCurrentUserWithContactFields()`, `normalizeOptional()` reduce code duplication
- **Error Handling**: Try-catch blocks in all public methods with meaningful error messages
- **Logging**: Debug logging with `LoggingLevel.DEBUG` for development
- **Documentation**: Comprehensive JSDoc comments on all methods
- **Code Organization**: Logical method grouping and clear variable naming

### Code Analysis
- **Manual Review Completed**: See `CODE_ANALYSIS_REPORT.md` for detailed analysis
- **Security Rating**: A- (excellent use of bind variables, proper validation)
- **Code Quality**: B+ (well-structured, minor improvements recommended)
- **Issues Found**: 1 medium (FLS bypass documented), 3 low (all addressed)

## Related Files

### Apex Classes
- `force-app/portal/main/default/classes/Portal/PortalMessagingController.cls`
- `force-app/portal/main/default/classes/Portal/PortalMessagingControllerTest.cls`

### Lightning Web Components
- `force-app/portal/main/default/lwc/portalMessaging/portalMessaging.js`
- `force-app/portal/main/default/lwc/portalMessaging/portalMessaging.html`
- `force-app/main/default/lwc/salesforceMessaging/salesforceMessaging.js`

### Custom Objects
- `force-app/main/default/objects/Message__c/` - Message object and fields

### Permission Sets
- `force-app/main/default/permissionsets/Portal_Messaging.permissionset-meta.xml`

### Message Channels
- `force-app/main/default/messageChannels/MessageUpdate.messageChannel-meta.xml`

## Troubleshooting

| Symptom | Likely Cause | Resolution |
| --- | --- | --- |
| Messages not loading | User doesn't have ContactId (Milestone team member) | System auto-creates Contact, but verify User has Name and Email. Check debug logs for Contact creation errors. |
| Search not working | Search term contains unescaped special characters | System handles escaping automatically. Verify search pattern is being passed correctly. Check Apex debug logs for query errors. |
| Navigation links broken | Context detection failed | Check pathname and page reference type detection logic. Verify `CurrentPageReference` is available. |
| Can't edit message | Not the sender | Only message sender can edit their own messages. Verify `Sender__c` matches current user's ContactId. |
| Internal messages visible to clients | `Visible_To_Client__c` not set correctly | Verify message was sent with `isVisibleToClient = false` by Milestone team member. Portal users cannot send internal messages. |
| Recipient type selector not showing | User is portal user | Portal users can only send to "Milestone Team", so selector is hidden. This is expected behavior. |
| Infinite scroll not loading more | No more messages available | Check `_hasMoreMessages` flag. Verify messages exist beyond current page. Check Apex logs for query results. |
| Messages in wrong order | Order direction issue | Messages are displayed newest at bottom (reverse chronological). Scroll to bottom to see newest messages. |
| Contact mentions not working | No mentionable contacts | Verify contacts have `Portal_Access_Enabled__c = true`. For portal users, contacts must be in same account. |
| File attachments not showing | ContentDocumentLink not created | Verify `linkFilesToMessage()` was called successfully. Check ContentVersion IDs are valid. |
| Component not detecting context | Page reference not available | Ensure component is on a Lightning Record Page or explicitly set `related-task-id`, `related-project-id`, or `related-account-id`. |

## Email Notifications

The system includes automated email notifications for unread messages:

- **Project Manager Notifications**: Sent when client messages remain unread for 5+ minutes
- **Client User Notifications**: Sent when team messages remain unread for 5+ minutes

See **[MessageNotificationScheduler](MessageNotificationScheduler.md)** for detailed documentation on scheduling and configuration.

## Email Notifications

The system includes automated email notifications for unread messages:

- **Project Manager Notifications**: Sent when client messages remain unread for 5+ minutes
- **Client User Notifications**: Sent when team messages remain unread for 5+ minutes

See **[MessageNotificationScheduler](MessageNotificationScheduler.md)** for detailed documentation on scheduling and configuration.

## Future Enhancements

Potential improvements for future releases:
- Real-time message updates via Platform Events
- Message threading visualization
- Advanced search filters (date range, sender, etc.)
- Message templates
- Email notifications for mentions
- Read receipts
- Message reactions/emojis
- Rich text formatting toolbar
- Message export functionality
