# Component Reference

Complete reference documentation for all Lightning Web Components in the Milestone Task Management System.

## Table of Contents

1. [Container Components](#container-components)
2. [Metric Components](#metric-components)
3. [Functional Components](#functional-components)
4. [Component Properties](#component-properties)
5. [Events and Communication](#events-and-communication)
6. [Usage Examples](#usage-examples)

## Container Components

### projectTaskDashboard

Main dashboard container component that orchestrates all child metric components.

**Location**: `force-app/main/default/lwc/projectTaskDashboard/`

**Purpose**: 
- Container for all dashboard metric components
- Handles account filtering via Lightning Message Service
- Manages component visibility and ordering
- Provides cross-component communication

#### Public Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `recordId` | String | null | Record ID when on record page |
| `showAccountFilter` | Boolean | true | Show/hide account filter |
| `showStatusBreakdown` | Boolean | true | Show/hide status breakdown |
| `showHoursMetrics` | Boolean | true | Show/hide hours metrics |
| `showHoursMetricsChart` | Boolean | true | Show chart or grid for hours |
| `showReviewStatusMetrics` | Boolean | true | Show/hide review status metrics |
| `showPriorityBreakdown` | Boolean | true | Show/hide priority breakdown |
| `showProgressMetrics` | Boolean | true | Show/hide progress metrics |
| `showTaskList` | Boolean | true | Show/hide task list |
| `showDueDateMetrics` | Boolean | true | Show/hide due date metrics |
| `accountFilterOrder` | Number | 0 | Display order for account filter |
| `statusBreakdownOrder` | Number | 1 | Display order for status breakdown |
| `hoursMetricsOrder` | Number | 2 | Display order for hours metrics |
| `reviewStatusMetricsOrder` | Number | 3 | Display order for review status |
| `priorityBreakdownOrder` | Number | 4 | Display order for priority breakdown |
| `progressMetricsOrder` | Number | 5 | Display order for progress metrics |
| `taskListOrder` | Number | 6 | Display order for task list |
| `dueDateMetricsOrder` | Number | 7 | Display order for due date metrics |

#### Features

- **Automatic Account Filtering**: When placed on Account record page, automatically filters to that account
- **Lightning Message Service**: Publishes account filter changes to child components
- **Dynamic Rendering**: Renders child components based on visibility settings
- **Configurable Ordering**: Components sorted by order property

#### Usage

```html
<c-project-task-dashboard
    show-status-breakdown="true"
    status-breakdown-order="1"
    show-hours-metrics="true"
    hours-metrics-order="2">
</c-project-task-dashboard>
```

## Metric Components

### taskStatusBreakdown

Displays task distribution by status in a chart format.

**Location**: `force-app/main/default/lwc/taskStatusBreakdown/`

**Purpose**: Visualize task status distribution

#### Features

- Pie chart or bar chart visualization
- Interactive chart (click to filter)
- Real-time data updates
- Account filtering support

#### Data Source

Queries `Project_Task__c` grouped by `Status__c`

#### Chart Library

Uses Chart.js (if configured) or native Salesforce charts

### taskPriorityBreakdown

Displays task distribution by priority level.

**Location**: `force-app/main/default/lwc/taskPriorityBreakdown/`

**Purpose**: Analyze tasks by priority

#### Features

- Priority distribution chart
- High/Medium/Low breakdown
- Visual priority indicators
- Account filtering support

### taskHoursMetrics

Tracks and displays hours metrics (estimated vs. actual).

**Location**: `force-app/main/default/lwc/taskHoursMetrics/`

**Purpose**: Hours tracking and variance analysis

#### Features

- Estimated vs. actual hours comparison
- Chart view and grid view
- Hours by status
- Hours by priority
- Variance calculations
- Account filtering support

#### Display Modes

- **Chart View**: Visual comparison
- **Grid View**: Summary cards with metrics

### taskProgressMetrics

Tracks overall task completion progress.

**Location**: `force-app/main/default/lwc/taskProgressMetrics/`

**Purpose**: Progress tracking and analysis

#### Features

- Average progress percentage
- Progress range distribution
- Completed vs. in-progress tracking
- Account filtering support

### taskReviewStatusMetrics

Monitors review and approval pipeline.

**Location**: `force-app/main/default/lwc/taskReviewStatusMetrics/`

**Purpose**: Review status tracking

#### Features

- Tasks awaiting PM/Code Reviewer approval
- Tasks awaiting Client approval
- Review status breakdown
- Approval queue monitoring
- Account filtering support

### taskDueDateMetrics

Tracks deadlines and overdue tasks.

**Location**: `force-app/main/default/lwc/taskDueDateMetrics/`

**Purpose**: Deadline tracking and alerts

#### Features

- Tasks due today
- Tasks due this week
- Tasks due this month
- Overdue tasks count
- Upcoming deadlines
- Account filtering support

## Functional Components

### taskDependencyVisualizer

Visual representation of task dependencies.

**Location**: `force-app/main/default/lwc/taskDependencyVisualizer/`

**Purpose**: Visualize task dependency relationships

#### Features

- Dependency graph visualization
- Blocking relationship indicators
- Related tasks display
- Interactive navigation
- Click to navigate to related tasks

#### Data Source

Queries related tasks via `Related_Task__c` field

#### Visualization

- Graph layout showing dependencies
- Color coding for blocking vs. related
- Visual indicators for risk status

### taskProgressIndicator

Visual progress indicator for individual tasks.

**Location**: `force-app/main/default/lwc/taskProgressIndicator/`

**Purpose**: Display task progress visually

#### Features

- Progress bar visualization
- Percentage display
- Subtask completion count
- Status color indicators

#### Usage

Typically placed on Project Task record pages

### relatedTasksList

Displays list of related tasks.

**Location**: `force-app/main/default/lwc/relatedTasksList/`

**Purpose**: Show related and dependent tasks

#### Features

- List of related tasks
- Relationship type indication
- Quick navigation to tasks
- Status indicators

#### Data Source

Uses `RelatedTasksController` Apex class

### groupedTaskList

Grouped task listing with filtering and sorting.

**Location**: `force-app/main/default/lwc/groupedTaskList/`

**Purpose**: Advanced task listing

#### Features

- Grouped display (by status, priority, etc.)
- Filterable and sortable
- Bulk operations support
- Quick actions
- Account filtering support

### taskListComponent

General-purpose task list component.

**Location**: `force-app/main/default/lwc/taskListComponent/`

**Purpose**: Flexible task listing

#### Features

- Configurable columns
- Advanced filtering
- Sorting capabilities
- Quick actions
- Bulk operations
- Account filtering support

### accountFilter

Account selection and filtering component.

**Location**: `force-app/main/default/lwc/accountFilter/`

**Purpose**: Account filtering for dashboard

#### Features

- Multi-select account picker
- "Show All" option
- LMS message publishing
- Automatic hiding on Account pages

#### Events

Publishes account filter changes via Lightning Message Service

## Component Properties

### Common Properties

Most metric components share these properties:

| Property | Type | Description |
|----------|------|-------------|
| `accountIds` | Array<String> | Filter by account IDs (from LMS) |
| `recordId` | String | Record ID when on record page |

### Property Binding

Components receive account filter via:
1. **Lightning Message Service**: Subscribes to `AccountFilter__c` channel
2. **Public Property**: `accountIds` array
3. **Record Context**: `recordId` when on record page

## Events and Communication

### Lightning Message Service

Components communicate via LMS using the `AccountFilter__c` message channel.

#### Message Format

```javascript
{
  accountIds: string[],  // Array of account IDs
  accountId: string       // Single account ID (backward compatibility)
}
```

#### Publishing Account Filter

```javascript
import { publish, MessageContext } from 'lightning/messageService';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';

// Publish filter
publish(this.messageContext, ACCOUNT_FILTER_MESSAGE_CHANNEL, {
  accountIds: ['001xx000000abc', '001xx000000def'],
  accountId: '001xx000000abc'
});
```

#### Subscribing to Account Filter

```javascript
import { subscribe, MessageContext } from 'lightning/messageService';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';

// Subscribe
subscribe(this.messageContext, ACCOUNT_FILTER_MESSAGE_CHANNEL, (message) => {
  this.accountIds = message.accountIds || [];
  this.loadData();
});
```

### Component Events

Components may fire custom events for:
- Task selection
- Status changes
- Navigation requests
- Filter changes

## Usage Examples

### Basic Dashboard Setup

```html
<!-- Lightning App Builder -->
<c-project-task-dashboard
    show-status-breakdown="true"
    show-hours-metrics="true"
    show-task-list="true">
</c-project-task-dashboard>
```

### Custom Component Ordering

```html
<c-project-task-dashboard
    show-status-breakdown="true"
    status-breakdown-order="2"
    show-hours-metrics="true"
    hours-metrics-order="1"
    show-priority-breakdown="true"
    priority-breakdown-order="3">
</c-project-task-dashboard>
```

### Account-Specific Dashboard

When placed on Account record page, dashboard automatically filters:

```html
<!-- On Account Record Page -->
<c-project-task-dashboard
    record-id="{!recordId}">
</c-project-task-dashboard>
```

### Individual Components on Record Page

```html
<!-- Project Task Record Page -->
<c-task-progress-indicator
    record-id="{!recordId}">
</c-task-progress-indicator>

<c-task-dependency-visualizer
    record-id="{!recordId}">
</c-task-dependency-visualizer>

<c-related-tasks-list
    record-id="{!recordId}">
</c-related-tasks-list>
```

## Component Development

### Creating New Metric Components

1. **Create LWC Component**
   ```bash
   sf lightning generate component --name NewMetric --type lwc
   ```

2. **Subscribe to Account Filter**
   ```javascript
   import { subscribe, MessageContext } from 'lightning/messageService';
   import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';
   ```

3. **Query Data**
   ```javascript
   import { LightningElement, wire } from 'lwc';
   import getTasks from '@salesforce/apex/ProjectTaskDashboardController.getTasks';
   ```

4. **Add to Dashboard**
   - Add public properties for visibility and ordering
   - Update `projectTaskDashboard` to include new component
   - Configure in Lightning App Builder

### Best Practices

-  Subscribe to LMS for account filtering
-  Use wire services for data loading
-  Implement error handling
-  Optimize queries for performance
-  Support bulk operations
-  Handle empty states gracefully
-  Provide loading indicators
-  Make components configurable

---

**Related Documentation**:
- [Architecture Overview](./Architecture-Overview.md) - System architecture
- [Apex Classes](./Apex-Classes.md) - Backend controllers
- [Development Guide](./Development-Guide.md) - Development setup

