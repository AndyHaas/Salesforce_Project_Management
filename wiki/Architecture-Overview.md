# Architecture Overview

Technical architecture and design of the Milestone Task Management System.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Data Model](#data-model)
3. [Component Architecture](#component-architecture)
4. [Automation Architecture](#automation-architecture)
5. [Integration Points](#integration-points)
6. [Security Model](#security-model)
7. [Performance Considerations](#performance-considerations)

## System Architecture

### High-Level Architecture

```
”””””””””””””””””””””””””””””””””””””””””””””””””””””””””””
”‚                   Salesforce Platform                   ”‚
”””””””””””””””””””””””””””””””””””””””””””””””””””””””””””¤
”‚                                                         ”‚
”‚  ””””””””””””””””  ””””””””””””””””  ”””””””””””””””” ”‚
”‚  ”‚   Lightning  ”‚  ”‚   Lightning  ”‚  ”‚   Lightning  ”‚ ”‚
”‚  ”‚ Web Components”‚  ”‚   Flows      ”‚  ”‚   Pages      ”‚ ”‚
”‚  ”””””””””¬””””””””˜  ”””””””””¬””””””””˜  ”””””””””¬””””””””˜ ”‚
”‚         ”‚                  ”‚                  ”‚         ”‚
”‚  ””””””””´”””””””””””””””””””´”””””””””””””””””””´””””””” ”‚
”‚  ”‚              Apex Controllers & Helpers            ”‚ ”‚
”‚  ”””””””””¬”””””””””””””””””””””””””””””””””””””””””””””˜ ”‚
”‚         ”‚                                                ”‚
”‚  ””””””””´””””””””””””””””””””””””””””””””””””””””””””” ”‚
”‚  ”‚              Triggers & Automation                 ”‚ ”‚
”‚  ”””””””””¬”””””””””””””””””””””””””””””””””””””””””””””˜ ”‚
”‚         ”‚                                                ”‚
”‚  ””””””””´””””””””””””””””””””””””””””””””””””””””””””” ”‚
”‚  ”‚           Custom Objects & Fields                   ”‚ ”‚
”‚  ”””””””””””””””””””””””””””””””””””””””””””””””””””””””˜ ”‚
”‚                                                         ”‚
””””””””””””””””””””””””””””””””””””””””””””””””””””””””””””˜
```

### Technology Stack

- **Platform**: Salesforce Lightning Platform
- **UI Framework**: Lightning Web Components (LWC)
- **Backend**: Apex (Triggers, Controllers, Helper Classes)
- **Automation**: Lightning Flows, Process Builder, Workflow Rules
- **Data Model**: Custom Objects with relationships
- **API Version**: 65.0

## Data Model

### Core Objects

#### Project_Task__c

The primary object for task management.

**Key Relationships**:
- **Parent-Child**: Self-referential (Parent_Task__c †’ Project_Task__c)
- **Related Tasks**: Self-referential (Related_Task__c †’ Project_Task__c)
- **Account**: Lookup to Account (Account__c)
- **Developer**: Lookup to User (Developer__c)
- **Client User**: Lookup to User (Client_User__c)
- **Release Notes**: Lookup to Release_Notes__c

**Key Fields**:
- Status__c (Picklist)
- Priority__c (Picklist)
- Progress_Percentage__c (Number, Formula/Rollup)
- Estimated_Hours__c (Number)
- Actual_Hours__c (Number)
- Total_Estimated_Hours__c (Rollup Summary)
- Total_Actual_Hours__c (Rollup Summary)
- At_Risk_Due_to_Dependencies__c (Checkbox)
- Is_Blocking__c (Checkbox)

#### Release_Notes__c

Release documentation and notes.

**Key Relationships**:
- **Release Version**: Lookup to Release_Version__c
- **Release Tag**: Lookup to Release_Tag__c
- **Tasks**: Many-to-many via Project_Task__c.Release_Notes__c

#### Release_Version__c

Version management for releases.

#### Release_Tag__c

Tagging system for releases.

### Data Relationships

```
Account
  ”””” Project_Task__c (Many)
       ””” Parent_Task__c †’ Project_Task__c (Self)
       ””” Related_Task__c †’ Project_Task__c (Self)
       ””” Developer__c †’ User
       ””” Client_User__c †’ User
       ”””” Release_Notes__c †’ Release_Notes__c
            ””” Release_Version__c †’ Release_Version__c
            ”””” Release_Tag__c †’ Release_Tag__c
```

### Field Types and Calculations

#### Rollup Summary Fields

- **Total_Estimated_Hours__c**: Sum of subtask Estimated_Hours__c
- **Total_Actual_Hours__c**: Sum of subtask Actual_Hours__c

#### Formula Fields

- **Progress_Percentage__c**: Calculated from subtask completion
- **Status_Color_Indicator__c**: Visual status indicator
- **Priority_Icon__c**: Priority visualization
- **Review_Status_Icons__c**: Review status visualization
- **Has_Parent_Task__c**: Boolean formula
- **Has_Related_Task__c**: Boolean formula
- **Has_Developer__c**: Boolean formula
- **Has_Client_User__c**: Boolean formula
- **Has_Release_Notes__c**: Boolean formula
- **Is_Overdue__c**: Date comparison formula

## Component Architecture

### Lightning Web Components

#### Container Components

**projectTaskDashboard**
- Main dashboard container
- Orchestrates child components
- Handles account filtering via LMS
- Configurable component visibility and ordering

**Key Features**:
- Lightning Message Service (LMS) for cross-component communication
- Dynamic component rendering
- Account filtering (automatic on Account pages)
- Configurable via Lightning App Builder

#### Metric Components

**taskStatusBreakdown**
- Status distribution visualization
- Chart.js integration
- Interactive filtering

**taskPriorityBreakdown**
- Priority analysis
- Chart visualization

**taskHoursMetrics**
- Hours tracking (estimated vs. actual)
- Chart and grid views
- Variance calculations

**taskProgressMetrics**
- Progress tracking
- Average progress calculation
- Progress range distribution

**taskReviewStatusMetrics**
- Review pipeline tracking
- Approval queue monitoring

**taskDueDateMetrics**
- Deadline tracking
- Overdue task identification
- Upcoming deadline alerts

#### Functional Components

**taskDependencyVisualizer**
- Visual dependency graph
- Blocking relationship visualization
- Interactive navigation

**taskProgressIndicator**
- Individual task progress bar
- Subtask completion tracking
- Visual status indicators

**relatedTasksList**
- Related tasks display
- Relationship type indication
- Quick navigation

**groupedTaskList**
- Grouped task listing
- Filterable and sortable
- Bulk operations support

**taskListComponent**
- General-purpose task list
- Advanced filtering
- Quick actions

**accountFilter**
- Account selection component
- Multi-select support
- LMS message publishing

### Component Communication

#### Lightning Message Service (LMS)

Components communicate via LMS for:
- Account filtering
- Cross-component updates
- Event broadcasting

**Message Channel**: `AccountFilter__c`

**Message Format**:
```javascript
{
  accountIds: string[],
  accountId: string  // For backward compatibility
}
```

#### Component Hierarchy

```
projectTaskDashboard (Container)
  ””” accountFilter (Optional)
  ””” taskStatusBreakdown
  ””” taskPriorityBreakdown
  ””” taskHoursMetrics
  ””” taskProgressMetrics
  ””” taskReviewStatusMetrics
  ””” taskDueDateMetrics
  ”””” taskListComponent
```

## Automation Architecture

### Triggers

#### ProjectTaskTrigger

**Purpose**: Central trigger for all task automation

**Events**: Before Insert, After Insert, Before Update, After Update

**Handler Pattern**: Delegates to helper classes

**Logic**:
```apex
trigger ProjectTaskTrigger on Project_Task__c (
    before insert, after insert,
    before update, after update
) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            TaskProgressCalculator.calculateProgress(Trigger.new);
            TaskDependencyHelper.assessDependencyRisk(Trigger.new);
        }
    }
}
```

### Apex Helper Classes

#### TaskProgressCalculator

**Purpose**: Calculate parent task progress from subtasks

**Methods**:
- `calculateProgress(List<Project_Task__c> tasks)`

**Logic**:
1. Identify parent tasks from subtasks
2. Query all subtasks for each parent
3. Calculate completion percentage
4. Update parent task fields:
   - Progress_Percentage__c
   - Total_Estimated_Hours__c
   - Total_Actual_Hours__c

**Formula**:
```
Progress = (Completed Subtasks / Total Active Subtasks) Ã— 100
```

**Exclusions**: Subtasks with status "Removed" are excluded

#### TaskDependencyHelper

**Purpose**: Assess dependency risk and update blocking flags

**Methods**:
- `assessDependencyRisk(List<Project_Task__c> tasks)`

**Logic**:
1. Identify tasks with blocking dependencies
2. Check status of blocking tasks
3. Update "At Risk Due to Dependencies" flag
4. Update "Is Blocking" flag for tasks that block others

**Risk Assessment**:
- Task is at risk if blocking task status is NOT:
  - Completed
  - Closed
  - In Review
  - Removed

#### RelatedTasksController

**Purpose**: Provide related tasks data to LWC

**Methods**:
- `getRelatedTasks(String taskId)`

**Returns**: List of related tasks with relationship details

#### ProjectTaskDashboardController

**Purpose**: Provide dashboard data to LWC components

**Methods**:
- Various methods for metrics calculation
- Data aggregation for charts
- Filtering and querying

### Flows

#### Progress Calculation Flow

**Purpose**: Alternative/additional progress calculation

**Trigger**: Task status change

**Actions**: Update progress fields

#### Dependency Risk Assessment Flow

**Purpose**: Assess and flag dependency risks

**Trigger**: Task status or dependency change

**Actions**: Update risk flags

#### Status Change Automation Flow

**Purpose**: Automate status-based actions

**Trigger**: Status field change

**Actions**: Field updates, notifications

#### Release Notes Generation Flow

**Purpose**: Generate release notes from completed tasks

**Trigger**: Manual or scheduled

**Actions**: Create release notes records

### Approval Processes

#### Approval Process 1: Client Development Approval

**Entry Criteria**:
- Status = Backlog
- Ready_for_Client_Review__c = true

**Approver**: Client User (from Client_User__c field)

**Actions on Approval**:
- Set Client_Approved_for_Development__c = true
- Change Status to Pending

#### Approval Process 2: PM/Code Reviewer Approval

**Entry Criteria**:
- Status = In Review
- Reviewed_by_PM_Code_Reviewer__c = false

**Approver**: PM or Code Reviewer

**Actions on Approval**:
- Set Reviewed_by_PM_Code_Reviewer__c = true
- Trigger Client Completion Approval

#### Approval Process 3: Client Completion Approval

**Entry Criteria**:
- Status = In Review
- Reviewed_by_PM_Code_Reviewer__c = true
- Client_Approved_for_Completion__c = false

**Approver**: Client User

**Actions on Approval**:
- Set Client_Approved_for_Completion__c = true
- Change Status to Completed

## Integration Points

### External Integrations

#### Chart.js (Optional)

- Used for chart visualizations
- CSP Trusted Site configured
- Remote Site Setting configured
- Loaded from CDN or static resource

### Internal Salesforce Integrations

#### Standard Objects

- **Account**: Customer account relationship
- **User**: Developer and client user assignments
- **Chatter**: Feed tracking enabled on Project_Task__c

#### Platform Features

- **Lightning App Builder**: Component configuration
- **Lightning Message Service**: Cross-component communication
- **Lightning Data Service**: Record access
- **Platform Events**: (Future enhancement)

## Security Model

### Permission Sets

#### Project_Management_Admin

**Access**:
- Full CRUD on all objects
- All fields editable
- System configuration access

#### Project_Management_Manager

**Access**:
- Full CRUD on Project_Task__c
- Read on Release objects
- Limited system configuration

#### Project_Management_User

**Access**:
- Create/Read/Edit on assigned tasks
- Read on related tasks
- Limited field access

### Sharing Model

- **Organization Default**: Private
- **Sharing Rules**: Based on account or role
- **Manual Sharing**: Supported
- **Apex Sharing**: (If implemented)

### Field-Level Security

- Controlled via permission sets
- Sensitive fields restricted
- Formula fields respect FLS

### Object-Level Security

- Controlled via profiles and permission sets
- Custom objects require explicit access
- Related list visibility controlled

## Performance Considerations

### Query Optimization

- **Bulkification**: All triggers and classes are bulkified
- **SOQL Limits**: Queries optimized to minimize SOQL calls
- **Selective Queries**: Indexed fields used in WHERE clauses

### Governor Limits

- **DML Operations**: Bulk DML in triggers
- **SOQL Queries**: Minimized and optimized
- **CPU Time**: Efficient algorithms
- **Heap Size**: Efficient data structures

### Caching Strategies

- **Component Data**: Cached where appropriate
- **LMS Messages**: Efficient message passing
- **Wire Services**: Automatic caching by platform

### Scalability

- **Large Data Volumes**: Handled via pagination
- **List Views**: Optimized with filters
- **Dashboard**: Aggregated queries
- **Rollup Fields**: Efficient calculation

### Best Practices

-  Bulk operations in all code
-  Selective queries with indexed fields
-  Efficient data structures
-  Minimal DML operations
-  Proper error handling
-  Governor limit awareness

---

**Related Documentation**:
- [Component Reference](./Component-Reference.md) - Detailed component docs
- [Apex Classes](./Apex-Classes.md) - Backend code documentation
- [API Reference](./API-Reference.md) - Integration documentation

