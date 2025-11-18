# Getting Started Guide

This guide will help you get started with the Milestone Task Management System. Whether you're a project manager, developer, or client user, this guide will walk you through the basics.

## Table of Contents

1. [What is the Task Management System?](#what-is-the-task-management-system)
2. [Accessing the System](#accessing-the-system)
3. [Your First Task](#your-first-task)
4. [Understanding Task Status](#understanding-task-status)
5. [Basic Navigation](#basic-navigation)
6. [Next Steps](#next-steps)

## What is the Task Management System?

The Milestone Task Management System is a Salesforce-based tool that helps teams:
- Track project tasks from idea to completion
- Manage task dependencies and relationships
- Monitor progress and hours
- Coordinate reviews and approvals
- Generate release notes

## Accessing the System

### Step 1: Log In
1. Log into your Salesforce org
2. Click the **App Launcher** (9-dot grid icon) in the top-left corner
3. Search for **"Project Management"** and click on it

### Step 2: Navigate to Tasks
- From the Project Management app, click on **"Project Tasks"** in the navigation menu
- You'll see a list of all tasks (or filtered tasks based on your permissions)

![Main Dashboard](images/01-main-dashboard.png)

*The main Project Tasks dashboard showing tasks organized by status and the Project Task Dashboard with metrics*

## Your First Task

### Creating a New Task

1. **Click "New"** button on the Project Tasks list view
   - The button is located in the top-right area of the list view
   
2. **Select Record Type** (first screen):
   ![Record Type Selection](images/02-create-new-task-form.png)
   
   Choose the appropriate record type for your task:
   - **Bug**: For fixing defects or issues
   - **Feature**: For new functionality
   - **Enhancement**: For improving existing features
   - **Data Migration**: For data-related work
   - **Training**: For training materials or sessions
   - **Other**: For anything that doesn't fit the above
   
   Click **"Next"** to proceed to the task form.

3. **Fill in the required fields**:
   ![Task Form Fields](images/03-task-form-fields.png)
   
   **Required Fields** (marked with red asterisk):
   - **Task Name**: A clear, descriptive name (e.g., "Implement User Login Feature")
   - **Account**: Select the customer account this task belongs to
   - **Status**: Start with "Backlog" for new tasks
   - **Priority**: Choose High, Medium, or Low

3. **Optional but recommended fields**:
   - **Description**: Detailed description of the task
   - **Developer**: Assign to a developer
   - **Client User**: Assign to a client contact
   - **Estimated Hours**: How many hours you think it will take
   - **Due Date**: When the task should be completed
   - **Start Date**: When work should begin

4. **Click "Save"**

### Viewing Your Task

After saving, you'll be taken to the task record page where you can:
- See all task details
- View related tasks and dependencies
- See progress indicators
- Add subtasks
- Track time spent

![Task Detail Page](images/04-task-detail-page.png)

*The task detail page showing task information, review workflow, dependencies, and related components*

## Understanding Task Status

Tasks move through different statuses during their lifecycle:

| Status | Description | What Happens |
|--------|-------------|--------------|
| **Backlog** | Task is planned but not started | Tasks wait here for client approval |
| **Pending** | Approved and ready to start | Waiting to begin work |
| **In Progress** | Currently being worked on | Active development |
| **In Review** | Work complete, awaiting review | PM/Code review and client approval |
| **Completed** | Fully approved and done | Ready for deployment |
| **Closed** | Task is finished | Final state |
| **Removed** | Task cancelled or no longer needed | Excluded from progress calculations |

### Status Flow

```
Backlog → Pending → In Progress → In Review → Completed → Closed
                                    ↓
                                 Removed (if cancelled)
```

## Basic Navigation

### List Views

The system provides several pre-built list views to help you find tasks:

- **My Tasks**: Tasks assigned to you
- **Backlog Tasks**: All tasks in backlog
- **In Progress Tasks**: Tasks currently being worked on
- **Pending Review - Client**: Tasks waiting for client approval
- **Blocked Tasks**: Tasks blocked by dependencies
- **Overdue Tasks**: Tasks past their due date
- **High Priority Tasks**: Tasks marked as high priority

### Using Filters

1. Click on a list view name (e.g., "My Tasks")
2. Use the search bar to find specific tasks
3. Click column headers to sort
4. Use the filter icon to add custom filters

### Task Record Page

When you click on a task, you'll see:

- **Details Section**: All task information
- **Related Tasks**: Tasks that are related or dependent
- **Dependency Visualizer**: Visual map of task dependencies
- **Progress Indicator**: Shows completion percentage
- **Chatter Feed**: Comments and updates

## Next Steps

Now that you understand the basics:

1. **Read the [User Guide](./User-Guide.md)** for detailed information on all features
2. **Review [Workflows and Processes](./Workflows-and-Processes.md)** to understand approval workflows
3. **Check out the [Dashboard Guide](./Dashboard-Guide.md)** to learn about analytics
4. **Explore the [FAQ](./FAQ.md)** for common questions

## Quick Tips

- ✅ Always assign tasks to developers and client users when possible
- ✅ Set realistic due dates and estimated hours
- ✅ Use the description field to provide context
- ✅ Link related tasks to show relationships
- ✅ Check for blocking dependencies before starting work
- ✅ Update actual hours as you work on tasks

## Need Help?

- Check the [FAQ](./FAQ.md) for answers to common questions
- Review the [Troubleshooting Guide](./Troubleshooting.md) for solutions
- Contact your system administrator

---

**Ready to dive deeper?** Continue to the [User Guide](./User-Guide.md)

