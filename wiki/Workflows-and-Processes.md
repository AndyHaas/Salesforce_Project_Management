# Workflows and Processes

This document explains the approval workflows and business processes in the Milestone Task Management System.

## Table of Contents

1. [Task Lifecycle Overview](#task-lifecycle-overview)
2. [Workflow 1: Backlog to Pending](#workflow-1-backlog-to-pending)
3. [Workflow 2: In Review to Completed](#workflow-2-in-review-to-completed)
4. [Status Transitions](#status-transitions)
5. [Approval Processes](#approval-processes)
6. [Validation Rules](#validation-rules)

## Task Lifecycle Overview

Tasks move through a structured lifecycle with specific approval gates:

```
”””””””””””
”‚ Backlog ”‚ † New tasks start here
”””””””¬”””””˜
     ”‚ Client Approval Required
     †
”””””””””””
”‚ Pending ”‚ † Approved, ready to start
”””””””¬”””””˜
     ”‚ Work begins
     †
””””””””””””””””
”‚ In Progress  ”‚ † Active development
”””””””¬””””””””””˜
     ”‚ Work complete
     †
”””””””””””””
”‚ In Review ”‚ † PM Review + Client Approval Required
”””””””¬”””””””˜
     ”‚ Both approvals received
     †
”””””””””””””
”‚ Completed ”‚ † Ready for deployment
”””””””¬”””””””˜
     ”‚ Final closure
     †
””””””””””
”‚ Closed ”‚ † Final state
”””””””””””˜
```

## Workflow 1: Backlog to Pending

**Purpose**: Ensure client approval before starting development work.

### Initial State

- **Status**: `Backlog`
- **Ready for Client Review**: `false` (unchecked)
- **Client Approved for Development**: `false` (unchecked)

### Step 1: PM Submits for Client Review

**Who**: Project Manager

**Action**:
1. Open the task record
2. Check the **Ready for Client Review** checkbox
3. Click **Save**

**What Happens**:
- Status remains `Backlog`
- Approval process is automatically triggered: `Approval_Process_Project_Task_Waiting_For_Client_Approval_on_Backlog_Task`
- Client receives approval request notification

**Validation**:
- `Ready for Client Review` can only be `true` when Status = `Backlog`
- If validation fails, an error message is displayed

### Step 2a: Client Approves

**Who**: Client User

**Action**:
1. Client receives approval request (email/notification)
2. Client reviews the task
3. Client approves the request

**What Happens Automatically**:
- `Client Approved for Development` is set to `true`
- Status automatically changes to `Pending`
- Task is now ready to begin development
- Developer can start work

**Result**:
- Task moves to development queue
- Developer can change status to "In Progress" when starting work

### Step 2b: Client Rejects

**Who**: Client User

**Action**:
1. Client receives approval request
2. Client reviews the task
3. Client rejects the request (with optional comments)

**What Happens Automatically**:
- `Client Approved for Development` remains `false`
- Status remains `Backlog`
- `Ready for Client Review` may remain `true` (PM can address feedback)

**Result**:
- PM receives rejection notification
- PM can address feedback, update task, and resubmit
- Task remains in Backlog until approved

### Resubmission Process

If a task is rejected:
1. PM addresses client feedback
2. Updates task description or other fields as needed
3. `Ready for Client Review` is already checked (or PM checks it again)
4. Approval process is triggered again
5. Client reviews and approves/rejects

## Workflow 2: In Review to Completed

**Purpose**: Ensure quality through internal review and client sign-off before marking complete.

### Initial State

- **Status**: `In Review`
- **Reviewed by PM/Code Reviewer**: `false` (unchecked)
- **Client Approved for Completion**: `false` (unchecked)

### Step 1: Task Moves to In Review

**Who**: Developer

**Action**:
1. Developer completes work on the task
2. Changes status from `In Progress` to `In Review`
3. Clicks **Save**

**What Happens**:
- Status is now `In Review`
- Approval process is automatically triggered: `Approval_Process_Project_Task_PM_Code_Reviewer_Approval`
- PM/Code Reviewer receives approval request notification

### Step 2: PM/Code Reviewer Approval

**Who**: PM or Code Reviewer

**Action**:
1. PM/Code Reviewer receives approval request
2. Reviews the completed work
3. Approves or rejects

**If Approved**:
- `Reviewed by PM/Code Reviewer` is automatically set to `true`
- Status remains `In Review`
- Client approval process is automatically triggered: `Approval_Process_Project_Task_Client_Completion_Approval`
- Client receives approval request

**If Rejected**:
- `Reviewed by PM/Code Reviewer` remains `false`
- Status may change back to `In Progress` (depending on workflow configuration)
- Developer receives rejection notification with feedback
- Developer addresses feedback and resubmits

### Step 3: Client Completion Approval

**Who**: Client User

**Prerequisites**:
- `Reviewed by PM/Code Reviewer` = `true`
- Status = `In Review`
- `Client Approved for Completion` = `false`

**Action**:
1. Client receives approval request
2. Client reviews the completed work
3. Client approves or rejects

**If Approved**:
- `Client Approved for Completion` is automatically set to `true`
- Status automatically changes to `Completed`
- Task is ready for deployment

**If Rejected**:
- `Client Approved for Completion` remains `false`
- Status may change back to `In Progress` (depending on workflow configuration)
- Developer receives rejection notification
- Developer addresses feedback and resubmits

### Quick Actions

For faster workflow, use Quick Actions:

#### Mark Reviewed by PM/Code Reviewer
- Available on tasks with Status = `In Review`
- Quickly sets `Reviewed by PM/Code Reviewer` = `true`
- Triggers client approval process

#### Mark Reviewed by Client
- Available on tasks with Status = `In Review` and `Reviewed by PM/Code Reviewer` = `true`
- Quickly sets `Client Approved for Completion` = `true`
- Changes status to `Completed`

## Status Transitions

### Valid Status Transitions

| From Status | To Status | Requirements |
|-------------|-----------|-------------|
| Backlog | Pending | `Client Approved for Development` = `true` |
| Backlog | Removed | No approval needed (cancellation) |
| Pending | In Progress | No approval needed |
| Pending | Backlog | No approval needed (reprioritization) |
| Pending | Removed | No approval needed (cancellation) |
| In Progress | In Review | No approval needed |
| In Progress | Backlog | No approval needed (reprioritization) |
| In Progress | Removed | No approval needed (cancellation) |
| In Review | Completed | `Reviewed by PM/Code Reviewer` = `true` AND `Client Approved for Completion` = `true` |
| In Review | In Progress | Rejection or feedback needed |
| Completed | Closed | No approval needed (final closure) |
| Any | Removed | No approval needed (cancellation) |

### Status Field Values

- **Backlog**: Planned but not approved
- **Pending**: Approved, ready to start
- **In Progress**: Active development
- **In Review**: Awaiting review and approval
- **Completed**: Approved and ready for deployment
- **Closed**: Final state, archived
- **Removed**: Cancelled, excluded from calculations

## Approval Processes

### Approval Process 1: Client Development Approval

**Name**: `Approval_Process_Project_Task_Waiting_For_Client_Approval_on_Backlog_Task`

**Triggered When**:
- Status = `Backlog`
- `Ready for Client Review` changes to `true`

**Approver**: Client User (from `Client_User__c` field)

**Actions on Approval**:
- Set `Client Approved for Development` = `true`
- Change Status to `Pending`

**Actions on Rejection**:
- `Client Approved for Development` remains `false`
- Status remains `Backlog`

### Approval Process 2: PM/Code Reviewer Approval

**Name**: `Approval_Process_Project_Task_PM_Code_Reviewer_Approval`

**Triggered When**:
- Status changes to `In Review`
- `Reviewed by PM/Code Reviewer` = `false`

**Approver**: PM or Code Reviewer (based on workflow configuration)

**Actions on Approval**:
- Set `Reviewed by PM/Code Reviewer` = `true`
- Status remains `In Review`
- Trigger Client Completion Approval process

**Actions on Rejection**:
- `Reviewed by PM/Code Reviewer` remains `false`
- Status may change to `In Progress`

### Approval Process 3: Client Completion Approval

**Name**: `Approval_Process_Project_Task_Client_Completion_Approval`

**Triggered When**:
- Status = `In Review`
- `Reviewed by PM/Code Reviewer` = `true`
- `Client Approved for Completion` = `false`

**Approver**: Client User (from `Client_User__c` field)

**Actions on Approval**:
- Set `Client Approved for Completion` = `true`
- Change Status to `Completed`

**Actions on Rejection**:
- `Client Approved for Completion` remains `false`
- Status may change to `In Progress`

## Validation Rules

The system includes validation rules to ensure data integrity and workflow compliance:

### Rule 1: Ready for Client Review Status
- **Field**: `Ready_for_Client_Review__c`
- **Rule**: Can only be `true` when Status = `Backlog`
- **Error Message**: "Ready for Client Review can only be checked when Status is Backlog"

### Rule 2: Client Approved for Development Status
- **Field**: `Client_Approved_for_Development__c`
- **Rule**: Can only be `true` when Status = `Pending` or `Backlog`
- **Error Message**: "Client Approved for Development can only be true when Status is Pending or Backlog"

### Rule 3: Reviewed by PM/Code Reviewer Status
- **Field**: `Reviewed_by_PM_Code_Reviewer__c`
- **Rule**: Can only be `true` when Status = `In Review`
- **Error Message**: "Reviewed by PM/Code Reviewer can only be checked when Status is In Review"

### Rule 4: Client Approved for Completion Status
- **Field**: `Client_Approved_for_Completion__c`
- **Rule**: Can only be `true` when Status = `Completed` or `In Review`
- **Error Message**: "Client Approved for Completion can only be true when Status is Completed or In Review"

### Rule 5: Circular Dependency Prevention
- **Fields**: `Related_Task__c`, `Relationship_Type__c`
- **Rule**: Prevents creating circular blocking dependencies
- **Error Message**: "Circular dependency detected. This would create a dependency loop."

### Rule 6: Parent Self-Reference Prevention
- **Field**: `Parent_Task__c`
- **Rule**: Task cannot be its own parent
- **Error Message**: "A task cannot be its own parent"

### Rule 7: Estimated Hours Validation
- **Field**: `Estimated_Hours__c`
- **Rule**: Must be >= 0
- **Error Message**: "Estimated Hours must be greater than or equal to 0"

## Workflow Best Practices

### For Project Managers

-  Review tasks before marking "Ready for Client Review"
-  Ensure all required information is complete
-  Set realistic due dates and estimates
-  Monitor approval queues regularly
-  Follow up on rejected approvals promptly

### For Developers

-  Update status to "In Review" when work is complete
-  Provide clear descriptions of what was done
-  Address review feedback promptly
-  Update actual hours as you work

### For Clients

-  Review tasks promptly
-  Provide clear feedback when rejecting
-  Approve tasks that meet requirements
-  Communicate any concerns early

### For Code Reviewers

-  Review code thoroughly
-  Test functionality when possible
-  Provide constructive feedback
-  Approve when quality standards are met

---

**Related Documentation**:
- [User Guide](./User-Guide.md) - Detailed feature documentation
- [Getting Started](./Getting-Started.md) - Basic usage guide
- [FAQ](./FAQ.md) - Common questions

