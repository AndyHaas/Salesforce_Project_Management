# Frequently Asked Questions (FAQ)

Common questions and answers about the Milestone Task Management System.

## Table of Contents

1. [General Questions](#general-questions)
2. [Task Management](#task-management)
3. [Workflows and Approvals](#workflows-and-approvals)
4. [Progress and Time Tracking](#progress-and-time-tracking)
5. [Dependencies and Relationships](#dependencies-and-relationships)
6. [Dashboard and Analytics](#dashboard-and-analytics)
7. [Troubleshooting](#troubleshooting)

## General Questions

### What is the Milestone Task Management System?

The Milestone Task Management System is a Salesforce-based solution for managing project tasks, tracking progress, managing dependencies, and coordinating reviews and approvals. It provides a complete workflow from task planning to completion.

### Who can use the system?

The system is designed for:
- **Project Managers**: Create tasks, manage workflows, monitor progress
- **Developers**: Work on tasks, update status, track time
- **Clients**: Review and approve tasks
- **Code Reviewers**: Review completed work
- **Administrators**: Configure and maintain the system

### How do I access the system?

1. Log into your Salesforce org
2. Click the App Launcher (9-dot grid)
3. Search for "Project Management"
4. Click on the app
5. Navigate to "Project Tasks" tab

### What permissions do I need?

You need one of these permission sets:
- **Project Management User**: Standard user access
- **Project Management Manager**: Manager-level access
- **Project Management Admin**: Full administrative access

Contact your administrator to assign the appropriate permission set.

## Task Management

### How do I create a new task?

1. Go to Project Tasks tab
2. Click "New" button
3. Fill in required fields (Task Name, Account, Status, Priority, Record Type)
4. Add optional details (Description, Developer, Client User, etc.)
5. Click "Save"

See the [Getting Started Guide](./Getting-Started.md) for detailed steps.

### What are the different task record types?

- **Bug**: Fixing defects or issues
- **Feature**: New functionality
- **Enhancement**: Improving existing features
- **Data Migration**: Data-related work
- **Training**: Training materials or sessions
- **Other**: Anything that doesn't fit the above

### Can I change a task's record type after creation?

Yes, you can edit the task and change the record type if needed.

### What's the difference between a task and a subtask?

A **task** is a standalone work item. A **subtask** is a child of a parent task, used to break down larger work into smaller pieces. Subtasks automatically calculate the parent task's progress.

### How do I create subtasks?

1. Open the parent task
2. Scroll to the "Subtasks" related list
3. Click "New"
4. Fill in subtask details
5. The Parent Task field is automatically set
6. Click "Save"

### Can a subtask have its own subtasks?

No, subtasks cannot have subtasks. The hierarchy is limited to two levels: parent tasks and subtasks.

### How do I delete a task?

You don't delete tasks. Instead, change the status to "Removed" if the task is cancelled or no longer needed. This preserves the task history while excluding it from active calculations.

### Can I restore a removed task?

Yes, simply change the status from "Removed" back to the appropriate status (e.g., "Backlog" or "In Progress").

## Workflows and Approvals

### Why do I need client approval before starting work?

This ensures that:
- The client understands what will be built
- Requirements are clear before development begins
- Budget and scope are approved
- There are no surprises later

### What happens if a client rejects a task?

The task remains in "Backlog" status. The Project Manager can:
1. Review the rejection feedback
2. Update the task based on feedback
3. Resubmit for approval

### Can I skip the approval process?

No, the approval workflows are required to ensure quality and client satisfaction. The system enforces these workflows through validation rules.

### How long does approval take?

Approval time depends on:
- Client responsiveness
- Task complexity
- Review workload

The system sends notifications to approvers, but actual turnaround time varies.

### What if I need to change a task after it's approved?

You can edit the task, but significant changes may require:
- Client re-approval (if scope changes)
- Status change back to "Backlog" (if major changes)
- New approval process

### Can I change a task's status directly?

Yes, but some status changes trigger approval processes:
- **Backlog †’ Pending**: Requires client approval
- **In Review †’ Completed**: Requires PM review and client approval

Other status changes (e.g., Pending †’ In Progress) don't require approval.

## Progress and Time Tracking

### How is progress calculated?

For tasks with subtasks:
- Progress = (Completed Subtasks / Total Active Subtasks) Ã— 100
- Subtasks with status "Removed" are excluded
- Only "Completed" or "Closed" subtasks count as done

For tasks without subtasks, progress is not automatically calculated (you can track manually if needed).

### Why isn't my task progress updating?

Check:
1. Does the task have subtasks? (Progress is based on subtasks)
2. Are subtask statuses being updated?
3. Are subtasks marked as "Completed" or "Closed"?
4. Is there a system error? (Check with administrator)

### How do I update actual hours?

1. Open the task record
2. Find the "Actual Hours" field
3. Update with the time spent
4. Click "Save"

**Tip**: Update hours incrementally as you work, not just at the end.

### Should I estimate hours for subtasks or the parent task?

Estimate hours for **both**:
- Parent task: Overall estimate
- Subtasks: Detailed breakdown

The system rolls up subtask hours to the parent, but having both helps with planning and tracking.

### What's the difference between Estimated Hours and Total Estimated Hours?

- **Estimated Hours**: Hours for this specific task
- **Total Estimated Hours**: Sum of all subtask estimated hours (rollup field, read-only)

For parent tasks, Total Estimated Hours shows the sum of all subtask estimates.

## Dependencies and Relationships

### What's a blocking dependency?

A blocking dependency means one task **must** be completed before another can start. If Task B depends on Task A, Task B cannot begin until Task A is done.

### How do I create a dependency?

1. Open the task that depends on another
2. Find "Related Task" field
3. Select the task it depends on
4. Choose "Blocking Dependency" as Relationship Type
5. Click "Save"

### What happens if a blocking task isn't completed?

The dependent task is automatically flagged as "At Risk Due to Dependencies". The system monitors this and updates the flag when the blocking task is completed.

### Can I have circular dependencies?

No, the system prevents circular dependencies. For example, if Task A depends on Task B, you cannot make Task B depend on Task A.

### What's the difference between "Blocking Dependency" and "Related Task"?

- **Blocking Dependency**: One task must complete before the other can start
- **Related Task**: Tasks are related but don't have a blocking relationship

Use "Related Task" for general relationships, "Blocking Dependency" for critical path items.

### How do I see all tasks that depend on a specific task?

1. Open the task
2. Look at the "Dependency Visualizer" component
3. It shows tasks that depend on this task (and tasks this task depends on)

## Dashboard and Analytics

### Why don't I see all components on the dashboard?

Components can be hidden/shown in Lightning App Builder. Contact your administrator to configure component visibility.

### How do I filter tasks by account?

- **On Account record page**: Automatically filtered to that account
- **On other pages**: Use the Account Filter component at the top

### Can I filter by multiple accounts?

Yes, the Account Filter supports multi-select. Select multiple accounts to see tasks for all of them.

### Why are my metrics different from what I expect?

Check:
1. Account filter settings (are you filtering correctly?)
2. Date ranges (if applicable)
3. Task statuses (removed tasks may be excluded)
4. Permissions (you may not see all tasks)

### How often do metrics update?

Metrics update in real-time as tasks change. There may be a brief delay (seconds) for calculations to complete.

### Can I export dashboard data?

The dashboard itself doesn't export, but you can:
1. Use the Task List component to view tasks
2. Export the task list using Salesforce's standard export features
3. Create reports in Salesforce for detailed exports

## Troubleshooting

### I can't see the Project Management app

**Solution**: Contact your administrator. You may need:
- Permission set assigned
- App access granted
- Profile permissions

### I get an error when trying to check "Ready for Client Review"

**Error**: "Ready for Client Review can only be checked when Status is Backlog"

**Solution**: The task status must be "Backlog". Change the status first, then check the box.

### My progress isn't updating

**Possible Causes**:
1. Task has no subtasks (progress only calculated for parent tasks with subtasks)
2. Subtasks not marked as "Completed" or "Closed"
3. System error (contact administrator)

**Solution**: 
- Verify subtask statuses
- Check if subtasks are properly linked to parent
- Contact administrator if issue persists

### I can't change a task's status

**Possible Causes**:
1. Missing required approvals
2. Validation rule preventing the change
3. Permission restrictions

**Solution**:
- Complete required approval workflows
- Check validation error messages
- Contact administrator if permissions issue

### The approval process isn't triggering

**Possible Causes**:
1. Approval process not activated
2. Required fields not set (e.g., Client User)
3. Workflow configuration issue

**Solution**: Contact your administrator to check approval process configuration.

### I don't see the Dependency Visualizer component

**Possible Causes**:
1. Component not added to page layout
2. No dependencies configured
3. Permission restrictions

**Solution**: Contact administrator to add component to page layout.

### Hours aren't rolling up to parent task

**Check**:
1. Are subtasks properly linked to parent?
2. Are hours entered on subtasks?
3. Is the rollup field formula working?

**Solution**: Verify subtask relationships and contact administrator if rollup fields aren't working.

### Can't assign a Client User

**Possible Causes**:
1. No client users available
2. Field not on page layout
3. Permission restrictions

**Solution**: 
- Ensure client contacts exist
- Contact administrator to add field to layout
- Check permissions

---

**Still have questions?** Check the [Troubleshooting Guide](./Troubleshooting.md) or contact your system administrator.

