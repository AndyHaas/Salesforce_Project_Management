# Dashboard Guide

## Overview

The Project Task Dashboard surfaces the key Lightning Web Components and Apex services that power project visibility in Salesforce. The dashboard now drives its task table dynamically from the `Project_Task_Dashboard_Table` field set, letting admins control which columns appear without touching code.

Core elements:

- `projectTaskDashboard`: container component that orchestrates filter messages and refreshes
- `taskListComponent`: paginated datatable driven by the field set
- `taskContextPanel`: unified component displaying task relationships, dependencies, subtasks, and progress
- `taskHoverCard`: reusable hover card component for displaying task details
- `linkTaskModal`: modal for creating and editing task relationships
- `groupedTaskList`: task list grouped by status with expandable subtasks
- Metric cards (Hours, Progress, Priority, Due Dates, Review Status) backed by `ProjectTaskDashboardController`

## Field Set–Driven Task List

### How It Works

1. `ProjectTaskDashboardController.getTaskListFieldSetDefinition()` reads the `Project_Task_Dashboard_Table` field set on `Project_Task__c`, returning API names, labels, data types, and reference metadata.
2. `taskListComponent` wires both the task list data and the field-set definition. When either changes:
   - Columns are rebuilt dynamically with the right datatable types, type attributes, and cell decorations (e.g., status badges, numeric alignment, percent formatting).
   - Row data is reprocessed to inject helper display fields (URL for `Name`, reference labels, percent normalization, CSS status classes).
3. Admin changes to the field set automatically appear in the dashboard table after refreshing the page.

### Customizing Columns

Admins can customize which columns appear in the task list table without any code changes:

1. **In Salesforce Setup**: Navigate to Object Manager → `Project Task` → Field Sets
2. **Edit Field Set**: Click on `Project_Task_Dashboard_Table` to edit
3. **Add/Remove Fields**: Drag and drop fields to adjust order or inclusion
   - Fields can be added from any available field on the Project Task object
   - Field order in the field set determines column order in the table
4. **Save Changes**: Click Save in the Salesforce UI
5. **Reload Dashboard**: Refresh the dashboard page—columns will update automatically

**Note**: No code changes are required. The component automatically detects and renders fields from the field set.

### Supported Field Types

The component auto-detects standard types:

- `Name`: rendered as a record link using `taskUrl`.
- References: automatically display the related record’s `Name`.
- Numbers/Currency/Percent: right-aligned with percent values scaled (e.g., `50` → `50%`).
- Dates/DateTimes: formatted as `MMM DD, YYYY` (with time for DateTime).
- Textual fields: shown as plain text.

If a field type is not explicitly mapped, it falls back to `text`.

## Field Set Management

### Field Sets Used

The system uses two main field sets that can be customized by admins:

1. **`Project_Task_Dashboard_Table`**: Controls which columns appear in the task list datatable
2. **`Task_Hover_Fields`**: Controls which fields appear in task hover cards

### Updating Field Sets

Both field sets can be updated through the Salesforce UI. Changes take effect immediately after saving.


## Troubleshooting

| Symptom | Likely Cause | Resolution |
| --- | --- | --- |
| Task list shows no columns | Field-set wire failed or field set empty | Verify `Project_Task_Dashboard_Table` contains at least one field and refresh the page |
| Column shows API name instead of label | Field set entry missing label | Update field set label in Setup |
| Reference columns display Ids | Relationship not accessible or missing from query | Ensure the field is reference type and has relationship access; controller auto-adds `relationship.Name` |
| Percent field displays 0–1 values | Field stored as decimal fraction | Confirm field is defined as Percent (metadata) so scaling logic applies |

## Task Relationship Management

### Overview

Task relationships are managed through the `Project_Task_Relationship__c` junction object, which replaced the legacy `Related_Task__c` lookup field. This allows for many-to-many relationships between tasks and supports different relationship types.

### Junction Object Structure

The `Project_Task_Relationship__c` object contains:
- `Task_A__c`: The primary task (the task that depends on or is related to Task B)
- `Task_B__c`: The related task (the task that Task A depends on or is related to)
- `Relationship_Type__c`: The type of relationship (Related, Blocking Dependency, Epic/Feature Parent)

### Relationship Types

1. **Related**: Tasks are related but not dependent on each other
2. **Blocking Dependency**: Task A cannot proceed until Task B is completed
3. **Epic/Feature Parent**: Task A is part of a larger epic or feature represented by Task B

### Creating Relationships

Relationships can be created through:
- **Link Task Modal**: Accessible from the Task Context Panel via the "Link Task" button

The Link Task Modal allows you to:
- Select a related task (Task B)
- Choose the relationship type
- Edit existing relationships
- Delete relationships

### Apex Controller

The `TaskContextController` class provides methods for managing relationships:
- `getDependencyData()`: Retrieves all relationships, dependencies, and subtasks for a task
- `createTaskRelationship()`: Creates a new relationship between two tasks
- `updateTaskRelationship()`: Updates an existing relationship's type
- `deleteTaskRelationship()`: Deletes a relationship
- `getRelationshipDetails()`: Retrieves relationship details for editing
- `searchTasks()`: Searches for tasks by name (for lookup functionality)

### Dependency Risk Assessment

The `TaskDependencyHelper` class automatically assesses dependency risk:
- Updates `At_Risk_Due_to_Dependencies__c` when blocking dependencies are incomplete
- Updates `Is_Blocking__c` when a task blocks other tasks
- Triggered automatically on task insert/update via `ProjectTaskTrigger`

## Task Context Panel

### Overview

The `taskContextPanel` is a unified component that displays comprehensive task context information, including:
- Task progress (subtask progress bar for parent tasks)
- Task relationships (parent, dependencies, dependents, subtasks)
- Risk indicators and blocking status
- Hover cards for quick task details

### Features

1. **Subtask Progress**: Automatically calculates and displays progress based on completed subtasks
2. **Relationship Display**: Shows all related tasks organized by type:
   - Parent Task
   - Dependencies (tasks this task depends on)
   - Dependent Tasks (tasks that depend on this task)
   - Subtasks
3. **Show/Hide Completed**: Toggle button to show or hide completed tasks in dependencies and subtasks (dependent tasks are always shown)
4. **Collapsible Sections**: Each relationship section can be expanded/collapsed
5. **Link Task Button**: Quick access to create new relationships
6. **Edit/Delete Relationships**: Menu actions on each relationship for editing or deleting

### Usage

The component is used on the Project Task record page in the sidebar region. It accepts:
- `recordId`: The Project Task record ID (required)
- `showLinkTaskButton`: Whether to show the Link Task button (defaults to true)

### Auto-Refresh

The component automatically refreshes when:
- The record is updated
- Related records are created/updated/deleted via standard UI
- Quick actions complete (creates child records)
- Manual refresh via Lightning Message Service

### Apex Controller

Uses `TaskContextController.getDependencyData()` which:
- Retrieves parent task information
- Queries junction object for all relationships
- Calculates subtask progress
- Builds hover field data from the `Task_Hover_Fields` field set

## Task Hover Card

### Overview

The `taskHoverCard` is a reusable component that displays task field information when hovering over a task name. It provides a consistent way to show task details across different components.

### Features

1. **Field Set Driven**: Uses the `Task_Hover_Fields` field set to determine which fields to display
2. **Automatic Formatting**: Handles display value formatting, status badge classes, and multiline text
3. **Status Badges**: Supports both SLDS badges and custom status badges
4. **Accessibility**: Includes proper ARIA attributes and keyboard navigation support

### Usage

The component is used by:
- `groupedTaskList`: Displays hover cards for tasks in the grouped list
- `taskContextPanel`: Displays hover cards for related tasks

### Properties

- `hoverFields`: Array of field objects from Apex (required)
- `taskStatus`: Task status for computing badge classes (required)
- `badgeStyle`: Badge style to use ('slds' or 'custom', defaults to 'slds')

### Field Set Configuration

Admins can customize which fields appear in hover cards without any code changes:

1. **In Salesforce Setup**: Navigate to Object Manager → `Project Task` → Field Sets
2. **Edit Field Set**: Click on `Task_Hover_Fields` to edit
3. **Add/Remove Fields**: Drag and drop fields to adjust which fields are displayed
   - Fields can be added from any available field on the Project Task object
   - Field order in the field set determines display order in the hover card
4. **Save Changes**: Click Save in the Salesforce UI
5. **Test**: Hover over a task name—the hover card will automatically show the updated fields

**Note**: No code changes are required. The component automatically detects and renders fields from the field set.

## Link Task Modal

### Overview

The `linkTaskModal` component provides a modal interface for creating and editing task relationships. It supports both create and edit modes.

### Features

1. **Create Mode**: Create new relationships between tasks
2. **Edit Mode**: Update existing relationship types
3. **Validation**: Prevents self-referencing relationships and duplicate relationships
4. **Lookup Field**: Uses Lightning lookup field for selecting related tasks
5. **Relationship Type Selection**: Dropdown for choosing relationship type

### Usage

The modal is embedded in the `taskContextPanel` component and can be opened:
- Via the "Link Task" button in the context panel
- Via the "Edit" menu action on existing relationships

### Events

- `relationshipcreated`: Fired when a new relationship is created
- `relationshipupdated`: Fired when an existing relationship is updated

## Grouped Task List

### Overview

The `groupedTaskList` component displays tasks grouped by status with expandable subtasks, hover field details, and filtering capabilities.

### Features

1. **Status Grouping**: Tasks are automatically grouped by status
2. **Expandable Subtasks**: Click to expand/collapse subtasks for each task
3. **Hover Cards**: Uses `taskHoverCard` component for task details on hover
4. **Account Filtering**: Filter tasks by account via dropdown or message channel
5. **"Me" Mode**: Filter to show only tasks assigned to the current user
6. **Show/Hide Completed**: Toggle to show or hide completed status groups
7. **Collapsible Status Groups**: Each status group can be expanded/collapsed

### Usage

The component can be placed on:
- Account record pages (automatically filters by account)
- App pages
- Home pages

### Properties

- `recordId`: Automatically populated when on an Account record page
- `accountId`: Can be set manually for App/Home pages
- `showAccountFilter`: Show/hide the account filter dropdown (defaults to true)

### Message Channel Integration

The component subscribes to `AccountFilter__c` message channel for cross-component filtering.

## Related Files

### Lightning Web Components
- `force-app/main/default/lwc/taskListComponent/taskListComponent.js`
- `force-app/main/default/lwc/taskContextPanel/taskContextPanel.js`
- `force-app/main/default/lwc/taskHoverCard/taskHoverCard.js`
- `force-app/main/default/lwc/linkTaskModal/linkTaskModal.js`
- `force-app/main/default/lwc/groupedTaskList/groupedTaskList.js`
- `force-app/main/default/lwc/projectTaskDashboard/projectTaskDashboard.js`

### Apex Classes
- `force-app/main/default/classes/ProjectTaskDashboardController.cls`
- `force-app/main/default/classes/ProjectTaskDashboardControllerTest.cls`
- `force-app/main/default/classes/TaskContextController.cls`
- `force-app/main/default/classes/TaskContextControllerTest.cls`
- `force-app/main/default/classes/TaskDependencyHelper.cls`
- `force-app/main/default/classes/TaskDependencyHelperTest.cls`
- `force-app/main/default/classes/TaskProgressCalculator.cls`
- `force-app/main/default/classes/TaskProgressCalculatorTest.cls`
- `force-app/main/default/classes/TaskSubtaskHelper.cls`
- `force-app/main/default/classes/TaskSubtaskHelperTest.cls`

### Objects & Field Sets
- `force-app/main/default/objects/Project_Task__c/fieldSets/Project_Task_Dashboard_Table.fieldSet-meta.xml`
- `force-app/main/default/objects/Project_Task__c/fieldSets/Task_Hover_Fields.fieldSet-meta.xml`
- `force-app/main/default/objects/Project_Task_Relationship__c/` (junction object)

### Triggers
- `force-app/main/default/triggers/ProjectTaskTrigger.trigger` - Handles all automated business logic for Project Tasks including subtask user population, parent status updates, progress calculation, and dependency risk assessment

## Testing

### Test Suite

A comprehensive test suite has been created to ensure code quality and coverage for task-related functionality:

**Test Suite**: `TaskProjectTests`
- `ProjectTaskDashboardControllerTest`: Tests for dashboard controller methods including field set retrieval, task filtering, and metric calculations
- `TaskDependencyHelperTest`: Tests for dependency risk assessment and blocking status updates
- `TaskProgressCalculatorTest`: Tests for subtask progress calculation logic
- `TaskContextControllerTest`: Tests for relationship management and dependency data retrieval
- `TaskSubtaskHelperTest`: Tests for subtask user population, parent status updates, and validation logic


## Layout & Page Configuration Updates

### Project Task Layout

The Project Task layout has been updated to include:
- **Junction Object Related Lists**: Two related lists for `Project_Task_Relationship__c`:
  - "Task A Relationships" (where this task is Task A)
  - "Task B Relationships" (where this task is Task B)
- **Enhanced Field Organization**: Fields organized into logical sections (Information, Progress & Hours, Description, System Information)
- **Related Lists**: Subtasks related list showing child tasks

### Project Task Record Page

The record page flexipage includes:
- **Task Context Panel**: Sidebar component displaying relationships, dependencies, and progress
- **Enhanced Field Display**: Key fields displayed in the header region
- **Related Lists**: Junction object related lists for viewing all task relationships

## Automated Business Logic (Triggers & Helpers)

### ProjectTaskTrigger

The `ProjectTaskTrigger` handles all automated business logic for Project Tasks.

#### Trigger Contexts

- **before insert**: Populates subtask fields from parent before save
- **before update**: Validates parent tasks cannot be closed with open subtasks
- **after insert**: Calculates progress and assesses dependency risk
- **after update**: Updates parent status, recalculates progress, and reassesses dependencies
- **after delete**: Recalculates parent progress when subtasks are deleted

#### Helper Classes

1. **TaskSubtaskHelper**: Manages subtask relationships and validations
   - `populateSubtaskUsers()`: Automatically populates OwnerId and Client_User__c from parent task when creating subtasks
   - `updateParentTaskStatus()`: Updates parent task status when subtask moves from Backlog→Pending or Pending→In Progress
   - `validateParentCanBeClosed()`: Prevents closing a parent task if it has open subtasks

2. **TaskProgressCalculator**: Calculates parent task progress based on subtasks
   - Updates `Progress_Percentage__c`, `Total_Estimated_Hours__c`, and `Total_Actual_Hours__c`
   - Based on subtask completion status and hours

3. **TaskDependencyHelper**: Assesses dependency risk and blocking status
   - Updates `At_Risk_Due_to_Dependencies__c` when blocking dependencies are incomplete
   - Updates `Is_Blocking__c` when a task blocks other tasks

## Code Documentation

All Lightning Web Components and Apex classes have been updated with comprehensive usage documentation comments, including:
- Component descriptions and usage instructions
- Method documentation with parameter descriptions
- Class-level documentation explaining purpose and integration points
- Field set dependencies and configuration requirements
- Trigger documentation explaining execution order and business logic

This documentation is embedded in the code and can be viewed in IDEs and documentation generators.

## Portal/Digital Experience Updates

### Client Project Management Portal

Significant UI/UX updates have been made to the Experience Cloud portal:

#### Header & Footer Styling
- **Header**: Updated to match production website design with logo and navigation
- **Footer**: Black background with white logo, matching production branding
- **Gradient Backgrounds**: Header section wrapper with gradient background style
- **Text Styling**: All header text set to white for proper contrast
- **HTML Editor Content**: Comprehensive CSS for HTML Editor content in header and footer

#### Portal Features
- **Custom Login**: OTP authentication via `portalLogin` component
- **Home Page**: "Coming Soon" page with feature preview cards using Lightning icons
- **Project Task Views**: List and detail views for project tasks in the portal
- **Account Views**: List, detail, and related list views for accounts

#### Portal Configuration
- **Network**: `Client - Project Management Portal` Experience Cloud site
- **Theme**: Custom theme with header and footer styling
- **Routes**: Configured routes for login, home, account, and project task pages
- **Static Resources**: `MilestoneTheme.css` for portal styling

See `force-app/portal/README.md` for detailed portal setup instructions.

## Portal Messaging System

### Overview

The Portal Messaging system enables secure communication between clients and the Milestone Consulting team within the Experience Cloud portal and Salesforce Lightning Experience. The system supports bidirectional messaging, file attachments, mentions, replies, and context-aware message threading.

### Key Features

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

### Components

#### Lightning Web Components

- **`portalMessaging`**: Core messaging component used in both contexts
  - Location: `force-app/portal/main/default/lwc/portalMessaging/`
  - Features: Message display, sending, editing, search, infinite scroll
  - Context detection: Automatically detects Experience Cloud vs. Salesforce context
  
- **`salesforceMessaging`**: Wrapper component for Salesforce Lightning Experience
  - Location: `force-app/main/default/lwc/salesforceMessaging/`
  - Uses `portalMessaging` internally for consistent functionality

#### Apex Controller

- **`PortalMessagingController`**: Main controller for all messaging operations
  - Location: `force-app/portal/main/default/classes/Portal/PortalMessagingController.cls`
  - Methods:
    - `sendMessage()`: Send new messages with context inheritance
    - `getMessages()`: Retrieve messages with filtering, pagination, and search
    - `getLatestMessages()`: Get recent messages for notifications
    - `updateMessage()`: Edit existing messages (sender only)
    - `deleteMessage()`: Soft delete messages
    - `markAsRead()`: Mark messages as read
    - `pinMessage()`: Pin/unpin messages
    - `getMentionableContacts()`: Get contacts for mention autocomplete
    - `linkFilesToMessage()`: Attach files to messages
    - `getMessageFiles()`: Retrieve files attached to messages
    - `getContextInfo()`: Get context information for messaging component

### Security & Access Control

#### Sharing Model
- Class uses `without sharing` to allow portal users to create message records
- Access control enforced through WHERE clause filters:
  - Users can see messages they sent
  - Users can see messages in their recipient bucket (Client or Milestone Team)
  - Portal users only see messages visible to clients (`Visible_To_Client__c = true`)

#### Field-Level Security
- `WITH SECURITY_ENFORCED` used in most queries
- FLS bypass in `updateMessage` is intentional and documented (allows portal users to edit their own messages)

#### SOQL Injection Protection
- All user inputs use bind variables
- Search terms properly escaped for LIKE queries
- Order field validation using allowlist
- Constants used for field names

### Message Object Structure

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

### Recent Enhancements

#### Auto-Creation of Contacts for Milestone Team Members
- Milestone team members (Salesforce Users without ContactId) can send messages
- System automatically creates/finds Contact records for Users when needed
- Method: `getOrCreateContactForUser()` handles this transparently

#### Infinite Scrolling & Pagination
- Messages load in pages of 50 (configurable via `_messagesPerPage`)
- Reverse chronological order: newest messages at bottom
- Scroll to top to load older messages
- Loading indicators show when fetching more messages

#### Server-Side Search
- Full-text search across `Body__c` and `Sender__r.Name`
- Wildcard support:
  - `*` converts to `%` (SQL wildcard)
  - `%` allowed as explicit wildcard
  - `_` treated as literal character (escaped)
- Search is debounced (500ms) to reduce server calls
- Search resets pagination

#### Context-Aware Navigation
- Portal context: Uses `ensureSitePath()` for portal URLs
- Salesforce context: Uses Lightning Navigation Service
- Links automatically adapt based on runtime context

### Usage

#### In Experience Cloud Portal
The messaging component is typically placed on:
- Project Task detail pages
- Project detail pages
- Account detail pages
- Home page

#### In Salesforce Lightning Experience
The `salesforceMessaging` wrapper component can be placed on:
- Project Task record pages
- Project record pages
- Account record pages
- App pages

### Configuration

#### Permission Sets
- `Portal_Messaging`: Permission set for portal users to access messaging functionality
  - Location: `force-app/main/default/permissionsets/Portal_Messaging.permissionset-meta.xml`

#### Message Channel
- `MessageUpdate__c`: Lightning Message Service channel for inter-component communication
  - Location: `force-app/main/default/messageChannels/MessageUpdate.messageChannel-meta.xml`
  - Used to notify components when messages are created/updated

### Testing

#### Test Coverage
- **Test Class**: `PortalMessagingControllerTest`
  - Location: `force-app/portal/main/default/classes/Portal/PortalMessagingControllerTest.cls`
  - Coverage: 70% (target: 80%)
  - Tests cover:
    - Message sending with various contexts
    - Message retrieval with filtering and search
    - Contact auto-creation for Milestone team members
    - Pagination and infinite scrolling
    - Message editing, deletion, pinning
    - Error handling and validation

### Code Quality

#### Security
- ✅ Bind variables for all user inputs
- ✅ Input validation and normalization
- ✅ Field-level security enforcement
- ✅ Access control via WHERE clause filters
- ✅ Search term escaping for LIKE queries

#### Best Practices
- Constants for field names and limits
- Helper methods to reduce code duplication
- Comprehensive error handling
- Detailed logging for debugging
- Proper documentation in code comments

### Related Files

#### Apex Classes
- `force-app/portal/main/default/classes/Portal/PortalMessagingController.cls`
- `force-app/portal/main/default/classes/Portal/PortalMessagingControllerTest.cls`

#### Lightning Web Components
- `force-app/portal/main/default/lwc/portalMessaging/portalMessaging.js`
- `force-app/portal/main/default/lwc/portalMessaging/portalMessaging.html`
- `force-app/main/default/lwc/salesforceMessaging/salesforceMessaging.js`

#### Custom Objects
- `force-app/main/default/objects/Message__c/` - Message object and fields

#### Permission Sets
- `force-app/main/default/permissionsets/Portal_Messaging.permissionset-meta.xml`

#### Message Channels
- `force-app/main/default/messageChannels/MessageUpdate.messageChannel-meta.xml`

### Troubleshooting

| Symptom | Likely Cause | Resolution |
| --- | --- | --- |
| Messages not loading | User doesn't have ContactId (Milestone team member) | System auto-creates Contact, but verify User has Name and Email |
| Search not working | Search term contains unescaped special characters | System handles escaping automatically, but verify search pattern |
| Navigation links broken | Context detection failed | Check pathname and page reference type detection logic |
| Can't edit message | Not the sender | Only message sender can edit their own messages |
| Internal messages visible to clients | `Visible_To_Client__c` not set correctly | Verify message was sent with `isVisibleToClient = false` by Milestone team member |

### Future Enhancements

Potential improvements for future releases:
- Real-time message updates via Platform Events
- Message threading visualization
- Advanced search filters (date range, sender, etc.)
- Message templates
- Email notifications for mentions
- Read receipts
- Message reactions/emojis

