# Dashboard Guide

Complete guide to using the Project Task Dashboard and its analytics components.

## Table of Contents

1. [Dashboard Overview](#dashboard-overview)
2. [Accessing the Dashboard](#accessing-the-dashboard)
3. [Dashboard Components](#dashboard-components)
4. [Account Filtering](#account-filtering)
5. [Customizing the Dashboard](#customizing-the-dashboard)
6. [Interpreting Metrics](#interpreting-metrics)

## Dashboard Overview

The Project Task Dashboard provides real-time analytics and visualizations for your project tasks. It consists of multiple components that can be configured and arranged to meet your needs.

### Key Features

- **Real-time Data**: Metrics update automatically as tasks change
- **Account Filtering**: Filter by one or more customer accounts
- **Visual Analytics**: Charts and graphs for easy understanding
- **Interactive Components**: Click to drill down into details
- **Configurable Layout**: Show/hide and reorder components

## Accessing the Dashboard

### Option 1: Project Task Home Page

1. Navigate to **Project Management** app
2. Click on **Project Task Home Page** in the navigation
3. View the full dashboard

### Option 2: Account Record Page

1. Navigate to an **Account** record
2. The dashboard automatically appears (if configured)
3. Automatically filters to that account's tasks

### Option 3: Custom App Page

1. Create a custom Lightning page
2. Add the **Project Task Dashboard** component
3. Configure component visibility and order

## Dashboard Components

### Account Filter Component

**Purpose**: Filter tasks by customer account(s)

**Features**:
- Multi-select account picker
- "Show All" option to clear filters
- Automatically hidden on Account record pages

**Usage**:
1. Click the account filter dropdown
2. Select one or more accounts
3. All dashboard components update automatically
4. Click "Clear" to show all accounts

**When to Use**:
- Viewing tasks across multiple accounts
- Comparing metrics between accounts
- Focusing on specific customer work

### Status Breakdown Component

**Purpose**: Visualize task distribution by status

**Display**:
- Pie chart or bar chart (configurable)
- Count of tasks per status
- Percentage breakdown
- Color-coded by status

**Statuses Shown**:
- Backlog
- Pending
- In Progress
- In Review
- Completed
- Closed
- Removed

**Interactions**:
- Click a segment/bar to filter task list
- Hover for detailed counts
- Legend shows status names

**Use Cases**:
- Quick overview of work distribution
- Identify bottlenecks (too many in one status)
- Track workflow health

### Priority Breakdown Component

**Purpose**: Analyze tasks by priority level

**Display**:
- Chart showing High, Medium, Low priority tasks
- Count and percentage for each
- Visual priority indicators

**Interactions**:
- Click to filter by priority
- View priority distribution

**Use Cases**:
- Identify high-priority work
- Balance workload by priority
- Track priority trends

### Hours Metrics Component

**Purpose**: Track estimated vs. actual hours

**Display Options**:
- **Chart View**: Visual comparison of estimated vs. actual
- **Grid View**: Summary cards with key metrics

**Metrics Shown**:
- Total Estimated Hours
- Total Actual Hours
- Variance (difference)
- Percentage complete
- Hours by status
- Hours by priority

**Interactions**:
- Toggle between chart and grid view
- Drill down by status or priority
- View trends over time

**Use Cases**:
- Monitor project budget
- Identify estimation accuracy
- Track time spent by status
- Forecast completion

### Progress Metrics Component

**Purpose**: Track overall task completion progress

**Metrics Shown**:
- Average progress percentage
- Tasks by progress range (0-25%, 25-50%, etc.)
- Progress trends
- Completed vs. in-progress tasks

**Interactions**:
- Click progress ranges to filter
- View detailed progress breakdown

**Use Cases**:
- Overall project health
- Identify tasks needing attention
- Track completion velocity

### Review Status Metrics Component

**Purpose**: Monitor review and approval pipeline

**Metrics Shown**:
- Tasks awaiting PM/Code Reviewer approval
- Tasks awaiting Client approval
- Review status breakdown
- Approval queue length

**Interactions**:
- Click to view tasks in each review stage
- Filter by review status

**Use Cases**:
- Monitor approval bottlenecks
- Track review turnaround time
- Ensure reviews are not delayed

### Due Date Metrics Component

**Purpose**: Track deadlines and overdue tasks

**Metrics Shown**:
- Tasks due today
- Tasks due this week
- Tasks due this month
- Overdue tasks count
- Upcoming deadlines

**Interactions**:
- Click to view tasks in each category
- Filter by due date range

**Use Cases**:
- Identify at-risk deadlines
- Plan upcoming work
- Monitor overdue tasks
- Resource planning

### Task List Component

**Purpose**: Interactive, filterable list of tasks

**Features**:
- Sortable columns
- Filterable by multiple criteria
- Quick actions
- Direct navigation to task records
- Status updates
- Bulk operations

**Columns** (configurable):
- Task Name
- Account
- Status
- Priority
- Developer
- Client User
- Due Date
- Progress
- Estimated Hours
- Actual Hours

**Interactions**:
- Click column headers to sort
- Use filters to narrow results
- Click task name to open record
- Use quick actions for common operations
- Select multiple tasks for bulk actions

**Use Cases**:
- Detailed task review
- Finding specific tasks
- Bulk status updates
- Task management operations

### Task Progress Indicator Component

**Purpose**: Visual progress indicator for individual tasks

**Display**:
- Progress bar
- Percentage complete
- Subtask completion count
- Visual status indicator

**Location**: Task record pages

**Use Cases**:
- Quick progress assessment
- Visual status indication
- Subtask completion tracking

### Task Dependency Visualizer Component

**Purpose**: Visual map of task dependencies

**Display**:
- Dependency graph
- Blocking relationships
- Related tasks
- Visual indicators for blocking/blocked tasks

**Location**: Task record pages

**Interactions**:
- Click tasks to navigate
- Expand/collapse dependency chains
- View dependency details

**Use Cases**:
- Understand task relationships
- Identify blocking tasks
- Plan dependency resolution
- Visualize project structure

## Account Filtering

### Automatic Filtering

When the dashboard is placed on an Account record page:
- Automatically filters to that account's tasks
- Account Filter component is hidden (not needed)
- All components show data for that account only

### Manual Filtering

When the dashboard is on other pages:
- Use Account Filter component to select accounts
- Supports multi-select (select multiple accounts)
- "Show All" clears the filter
- All components update automatically when filter changes

### Filter Behavior

- **No Filter**: Shows all tasks (all accounts)
- **Single Account**: Shows tasks for that account only
- **Multiple Accounts**: Shows tasks for all selected accounts
- **Filter Persistence**: Filter selection persists during session

## Customizing the Dashboard

### Component Visibility

In Lightning App Builder, you can show/hide components:

- **Show Account Filter**: Toggle account filter visibility
- **Show Status Breakdown**: Toggle status chart
- **Show Hours Metrics**: Toggle hours tracking
- **Show Review Status Metrics**: Toggle review metrics
- **Show Priority Breakdown**: Toggle priority chart
- **Show Progress Metrics**: Toggle progress tracking
- **Show Due Date Metrics**: Toggle due date tracking
- **Show Task List**: Toggle task list component

### Component Ordering

Set display order for each component:
- Lower numbers appear first
- Components with same order maintain insertion order
- Default order can be customized

**Example Configuration**:
- Account Filter: Order 0 (always first)
- Status Breakdown: Order 1
- Hours Metrics: Order 2
- Task List: Order 10 (last)

### Hours Metrics Display Mode

For Hours Metrics component:
- **Show Chart**: Display visual chart (default)
- **Hide Chart**: Show grid layout with summary cards

Choose based on preference and screen space.

## Interpreting Metrics

### Status Breakdown

**Healthy Distribution**:
- Most tasks in "In Progress" or "Completed"
- Few tasks stuck in "Backlog" or "In Review"
- Low "Removed" count

**Warning Signs**:
- Too many tasks in "Backlog" (approval bottleneck)
- Too many in "In Review" (review bottleneck)
- Many "Removed" tasks (scope issues)

### Hours Metrics

**Good Indicators**:
- Actual hours close to estimated (accurate estimation)
- Variance within 10-20% (acceptable)
- Hours increasing in "In Progress" status

**Warning Signs**:
- Actual hours significantly higher than estimated (estimation issues)
- Large variance (budget risk)
- Hours stuck in one status (workflow issues)

### Progress Metrics

**Good Indicators**:
- Average progress increasing over time
- Most tasks have some progress
- Completed tasks increasing

**Warning Signs**:
- Many tasks at 0% progress (not started)
- Progress stuck (blocked or abandoned)
- Low average progress (project at risk)

### Review Status Metrics

**Good Indicators**:
- Short approval queues
- Quick turnaround on reviews
- Balanced review workload

**Warning Signs**:
- Long approval queues (bottleneck)
- Tasks stuck in review (process issues)
- Many rejections (quality or communication issues)

### Due Date Metrics

**Good Indicators**:
- Few overdue tasks
- Upcoming deadlines manageable
- Due dates realistic

**Warning Signs**:
- Many overdue tasks (schedule issues)
- Clustering of deadlines (resource conflicts)
- Unrealistic due dates (planning issues)

## Best Practices

### Dashboard Usage

-  Check dashboard daily for updates
-  Monitor key metrics regularly
-  Use filters to focus on relevant work
-  Drill down into concerning metrics
-  Share dashboard insights with team

### Metric Interpretation

-  Look for trends, not just snapshots
-  Compare metrics over time
-  Identify root causes of issues
-  Use metrics to guide decisions
-  Don't over-optimize single metrics

### Customization

-  Configure dashboard for your role
-  Show metrics most relevant to you
-  Arrange components by priority
-  Test different configurations
-  Adjust based on feedback

---

**Related Documentation**:
- [User Guide](./User-Guide.md) - Complete feature documentation
- [Getting Started](./Getting-Started.md) - Basic usage
- [FAQ](./FAQ.md) - Common questions

