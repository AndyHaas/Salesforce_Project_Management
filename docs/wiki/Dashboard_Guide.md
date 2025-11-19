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
3. Admin changes to the field set automatically flow to the dashboard table after a deploy/refresh.

### Customizing Columns

1. In Salesforce Setup, open Object Manager → `Project Task` → Field Sets.
2. Edit `Project_Task_Dashboard_Table` and drag/drop fields to adjust order or inclusion.
3. Save and deploy metadata (`force-app/main/default/objects/Project_Task__c/fieldSets/Project_Task_Dashboard_Table.fieldSet-meta.xml`).
4. Reload the dashboard—no code edits required.

### Supported Field Types

The component auto-detects standard types:

- `Name`: rendered as a record link using `taskUrl`.
- References: automatically display the related record’s `Name`.
- Numbers/Currency/Percent: right-aligned with percent values scaled (e.g., `50` → `50%`).
- Dates/DateTimes: formatted as `MMM DD, YYYY` (with time for DateTime).
- Textual fields: shown as plain text.

If a field type is not explicitly mapped, it falls back to `text`.

## Field Set Retrieval via CLI

To pull the latest field-set definition into the repo:

```bash
sf project retrieve start --metadata "FieldSet:Project_Task__c.Project_Task_Dashboard_Table"
```

This checkpoints admin changes before committing.

## Testing & Deployment

1. Run Apex tests covering the dashboard controller (specifically `ProjectTaskDashboardControllerTest`) to ensure field-set metadata is valid:

```bash
sf apex run test --tests ProjectTaskDashboardControllerTest
```

2. Deploy updated metadata:

```bash
sf project deploy start --source-dir force-app/main/default/lwc/taskListComponent \
  --source-dir force-app/main/default/classes/ProjectTaskDashboardController.cls \
  --source-dir force-app/main/default/classes/ProjectTaskDashboardControllerTest.cls \
  --source-dir force-app/main/default/objects/Project_Task__c/fieldSets/Project_Task_Dashboard_Table.fieldSet-meta.xml
```

## Troubleshooting

| Symptom | Likely Cause | Resolution |
| --- | --- | --- |
| Task list shows no columns | Field-set wire failed or field set empty | Verify `Project_Task_Dashboard_Table` contains at least one field and rerun retrieve/deploy |
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
- **Quick Action**: "Add Related Task" quick action on the Project Task record page

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
3. **Show/Hide Completed**: Toggle button to show or hide completed tasks in dependencies and subtasks
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

To customize which fields appear in hover cards:
1. In Salesforce Setup, open Object Manager → `Project Task` → Field Sets
2. Edit `Task_Hover_Fields` and add/remove fields
3. Deploy the field set metadata

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

### Objects & Field Sets
- `force-app/main/default/objects/Project_Task__c/fieldSets/Project_Task_Dashboard_Table.fieldSet-meta.xml`
- `force-app/main/default/objects/Project_Task__c/fieldSets/Task_Hover_Fields.fieldSet-meta.xml`
- `force-app/main/default/objects/Project_Task_Relationship__c/` (junction object)

### Triggers
- `force-app/main/default/triggers/ProjectTaskTrigger.trigger`

## Testing

### Test Suite

A comprehensive test suite has been created to ensure code quality and coverage for task-related functionality:

**Test Suite**: `TaskProjectTests`
- `ProjectTaskDashboardControllerTest`: Tests for dashboard controller methods including field set retrieval, task filtering, and metric calculations
- `TaskDependencyHelperTest`: Tests for dependency risk assessment and blocking status updates
- `TaskProgressCalculatorTest`: Tests for subtask progress calculation logic
- `TaskContextControllerTest`: Tests for relationship management and dependency data retrieval

### Running Tests

To run the test suite:

```bash
sf apex run test --test-suite TaskProjectTests
```

To run individual test classes:

```bash
sf apex run test --tests ProjectTaskDashboardControllerTest
sf apex run test --tests TaskDependencyHelperTest
sf apex run test --tests TaskProgressCalculatorTest
sf apex run test --tests TaskContextControllerTest
```

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

## Code Documentation

All Lightning Web Components and Apex classes have been updated with comprehensive usage documentation comments, including:
- Component descriptions and usage instructions
- Method documentation with parameter descriptions
- Class-level documentation explaining purpose and integration points
- Field set dependencies and configuration requirements

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

### Portal Deployment

Portal components are in the `force-app/portal` directory and can be deployed separately:

```bash
# Deploy portal only
sf project deploy start --source-dir force-app/portal

# Deploy everything
sf project deploy start
```

See `force-app/portal/README.md` for detailed portal setup instructions.

