# Apex Classes Reference

Complete documentation for all Apex classes in the Milestone Task Management System.

## Table of Contents

1. [TaskProgressCalculator](#taskprogresscalculator)
2. [TaskDependencyHelper](#taskdependencyhelper)
3. [RelatedTasksController](#relatedtaskscontroller)
4. [ProjectTaskDashboardController](#projecttaskdashboardcontroller)
5. [Best Practices](#best-practices)

## TaskProgressCalculator

**Location**: `force-app/main/default/classes/TaskProgressCalculator.cls`

**Purpose**: Calculate parent task progress based on subtask completion

**Access Modifier**: `public with sharing`

### Methods

#### calculateProgress

```apex
public static void calculateProgress(List<Project_Task__c> tasks)
```

**Purpose**: Calculate and update progress for parent tasks based on their subtasks

**Parameters**:
- `tasks`: List of Project_Task__c records (typically from trigger)

**Logic**:
1. Identifies parent tasks from subtasks in the input list
2. Queries all subtasks for each parent task
3. Calculates completion percentage:
   - Completed subtasks = status 'Completed' or 'Closed'
   - Total active subtasks = all subtasks except 'Removed'
   - Progress = (Completed / Total Active) × 100
4. Updates parent task fields:
   - `Progress_Percentage__c`
   - `Total_Estimated_Hours__c` (sum of subtask estimates)
   - `Total_Actual_Hours__c` (sum of subtask actual hours)

**Bulkification**:  Fully bulkified

**Governor Limits**: Optimized to minimize SOQL queries

**Example Usage**:
```apex
List<Project_Task__c> tasks = [SELECT Id, Parent_Task__c FROM Project_Task__c WHERE Id IN :taskIds];
TaskProgressCalculator.calculateProgress(tasks);
```

### Key Features

- **Automatic Calculation**: Triggered on subtask insert/update
- **Excludes Removed**: Subtasks with status 'Removed' are excluded from calculations
- **Hours Rollup**: Automatically sums estimated and actual hours
- **Bulk Safe**: Handles multiple parent tasks efficiently

## TaskDependencyHelper

**Location**: `force-app/main/default/classes/TaskDependencyHelper.cls`

**Purpose**: Assess dependency risk and update blocking flags

**Access Modifier**: `public with sharing`

### Methods

#### assessDependencyRisk

```apex
public static void assessDependencyRisk(List<Project_Task__c> tasks)
```

**Purpose**: Assess and flag tasks that are at risk due to blocking dependencies

**Parameters**:
- `tasks`: List of Project_Task__c records (typically from trigger)

**Logic**:
1. Identifies tasks with blocking dependencies
2. Checks status of blocking tasks
3. Updates `At_Risk_Due_to_Dependencies__c` flag:
   - `true` if blocking task is NOT: Completed, Closed, In Review, or Removed
   - `false` if blocking task is completed or in non-blocking state
4. Updates `Is_Blocking__c` flag for tasks that have blocking dependencies on them
5. Handles reverse dependencies (tasks that depend on the updated tasks)

**Bulkification**:  Fully bulkified

**Governor Limits**: Optimized queries, handles large dependency chains

**Example Usage**:
```apex
List<Project_Task__c> tasks = [SELECT Id, Related_Task__c, Relationship_Type__c FROM Project_Task__c WHERE Id IN :taskIds];
TaskDependencyHelper.assessDependencyRisk(tasks);
```

### Key Features

- **Bidirectional Assessment**: Checks both forward and reverse dependencies
- **Status-Based Logic**: Considers task status in risk assessment
- **Blocking Flag**: Updates `Is_Blocking__c` for tasks that block others
- **Automatic Updates**: Triggered on task status or dependency changes

### Risk Assessment Rules

A task is at risk if its blocking dependency:
- Status is NOT 'Completed'
- Status is NOT 'Closed'
- Status is NOT 'In Review' (work done, just waiting approval)
- Status is NOT 'Removed' (no longer active)

## RelatedTasksController

**Location**: `force-app/main/default/classes/RelatedTasksController.cls`

**Purpose**: Provide related tasks data to Lightning Web Components

**Access Modifier**: `public with sharing`

### Methods

#### getRelatedTasks

```apex
@AuraEnabled(cacheable=true)
public static List<RelatedTaskWrapper> getRelatedTasks(String taskId)
```

**Purpose**: Retrieve related tasks for a given task

**Parameters**:
- `taskId`: ID of the task to get related tasks for

**Returns**: List of `RelatedTaskWrapper` objects containing:
- Task ID
- Task Name
- Status
- Priority
- Relationship Type
- Other relevant fields

**Cacheable**:  Yes (cacheable=true for performance)

**Example Usage**:
```javascript
// In LWC
import getRelatedTasks from '@salesforce/apex/RelatedTasksController.getRelatedTasks';

@wire(getRelatedTasks, { taskId: '$recordId' })
wiredRelatedTasks({ error, data }) {
    if (data) {
        this.relatedTasks = data;
    }
}
```

### Wrapper Class

```apex
public class RelatedTaskWrapper {
    @AuraEnabled public String taskId;
    @AuraEnabled public String taskName;
    @AuraEnabled public String status;
    @AuraEnabled public String priority;
    @AuraEnabled public String relationshipType;
    // ... other fields
}
```

## ProjectTaskDashboardController

**Location**: `force-app/main/default/classes/ProjectTaskDashboardController.cls`

**Purpose**: Provide dashboard data and metrics to Lightning Web Components

**Access Modifier**: `public with sharing`

### Methods

#### getStatusBreakdown

```apex
@AuraEnabled(cacheable=true)
public static List<StatusBreakdownWrapper> getStatusBreakdown(List<String> accountIds)
```

**Purpose**: Get task count grouped by status

**Parameters**:
- `accountIds`: List of account IDs to filter by (empty = all accounts)

**Returns**: List of status breakdown data

#### getPriorityBreakdown

```apex
@AuraEnabled(cacheable=true)
public static List<PriorityBreakdownWrapper> getPriorityBreakdown(List<String> accountIds)
```

**Purpose**: Get task count grouped by priority

**Parameters**:
- `accountIds`: List of account IDs to filter by

**Returns**: List of priority breakdown data

#### getHoursMetrics

```apex
@AuraEnabled(cacheable=true)
public static HoursMetricsWrapper getHoursMetrics(List<String> accountIds)
```

**Purpose**: Get hours metrics (estimated vs. actual)

**Parameters**:
- `accountIds`: List of account IDs to filter by

**Returns**: Hours metrics wrapper with totals and breakdowns

#### getProgressMetrics

```apex
@AuraEnabled(cacheable=true)
public static ProgressMetricsWrapper getProgressMetrics(List<String> accountIds)
```

**Purpose**: Get progress metrics

**Parameters**:
- `accountIds`: List of account IDs to filter by

**Returns**: Progress metrics wrapper

#### getReviewStatusMetrics

```apex
@AuraEnabled(cacheable=true)
public static ReviewStatusMetricsWrapper getReviewStatusMetrics(List<String> accountIds)
```

**Purpose**: Get review status metrics

**Parameters**:
- `accountIds`: List of account IDs to filter by

**Returns**: Review status metrics wrapper

#### getDueDateMetrics

```apex
@AuraEnabled(cacheable=true)
public static DueDateMetricsWrapper getDueDateMetrics(List<String> accountIds)
```

**Purpose**: Get due date metrics

**Parameters**:
- `accountIds`: List of account IDs to filter by

**Returns**: Due date metrics wrapper

#### getTasks

```apex
@AuraEnabled(cacheable=true)
public static List<Project_Task__c> getTasks(List<String> accountIds, String filters)
```

**Purpose**: Get filtered list of tasks

**Parameters**:
- `accountIds`: List of account IDs to filter by
- `filters`: JSON string of additional filters

**Returns**: List of Project_Task__c records

### Key Features

- **Cacheable Methods**: All methods use `cacheable=true` for performance
- **Account Filtering**: All methods support account filtering
- **Bulk Safe**: Handles large data volumes efficiently
- **Flexible Filtering**: Supports complex filter combinations

## Best Practices

### Code Quality

-  **Bulkification**: All methods handle bulk operations
-  **Error Handling**: Proper try-catch blocks
-  **Governor Limits**: Optimized to avoid limits
-  **Security**: Uses `with sharing` for data security
-  **Documentation**: Well-documented code

### Performance

-  **SOQL Optimization**: Minimize queries, use selective queries
-  **Caching**: Use `cacheable=true` for LWC methods
-  **Bulk Operations**: Process records in bulk
-  **Selective Queries**: Use indexed fields in WHERE clauses

### Security

-  **Sharing Rules**: Respects sharing rules with `with sharing`
-  **Field-Level Security**: Respects FLS automatically
-  **Input Validation**: Validate inputs before processing
-  **Error Messages**: Don't expose sensitive information

### Testing

-  **Test Coverage**: Maintain >75% code coverage
-  **Bulk Testing**: Test with large data volumes
-  **Edge Cases**: Test boundary conditions
-  **Negative Testing**: Test error scenarios

---

**Related Documentation**:
- [Architecture Overview](./Architecture-Overview.md) - System architecture
- [Component Reference](./Component-Reference.md) - LWC components
- [Development Guide](./Development-Guide.md) - Development practices

