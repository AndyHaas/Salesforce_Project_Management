# Installation Guide

Complete guide for installing and deploying the Milestone Task Management System to your Salesforce org.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation Methods](#installation-methods)
3. [Post-Installation Configuration](#post-installation-configuration)
4. [Verification](#verification)
5. [Troubleshooting Installation](#troubleshooting-installation)

## Prerequisites

### Required Tools

- **Salesforce CLI** (sf CLI) - Version 7.0 or later
- **Node.js** - Version 14.x or later (for development tools)
- **Git** - For cloning the repository
- **VS Code** (recommended) - With Salesforce Extensions

### Required Salesforce Features

- **Salesforce Org** with API access enabled
- **Lightning Experience** enabled
- **My Domain** configured (required for Lightning Web Components)
- **API Version 65.0** or later

### Required Permissions

- **System Administrator** profile or equivalent
- **Modify All Data** permission
- **Customize Application** permission
- **Deploy Change Sets** permission (if using change sets)

## Installation Methods

### Method 1: Salesforce CLI (Recommended)

This is the recommended method for developers and administrators.

#### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd Milestone-Task-Management
```

#### Step 2: Authenticate with Salesforce

```bash
sf org login web --alias myorg
```

Or use an existing authenticated org:

```bash
sf org list
```

#### Step 3: Deploy to Salesforce

```bash
sf project deploy start
```

This deploys all metadata to your org.

#### Step 4: Run Tests (Optional but Recommended)

```bash
sf apex run test --class-names ProjectTaskDashboardControllerTest --result-format human --code-coverage
```

### Method 2: VS Code with Salesforce Extensions

#### Step 1: Open Project in VS Code

1. Open VS Code
2. File †’ Open Folder
3. Select the project directory

#### Step 2: Authorize Org

1. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows)
2. Type "SFDX: Authorize an Org"
3. Follow the prompts

#### Step 3: Deploy Source to Org

1. Right-click on `force-app` folder
2. Select "SFDX: Deploy Source to Org"
3. Wait for deployment to complete

### Method 3: Change Sets (For Production Orgs)

#### Step 1: Create Outbound Change Set

1. In source org: Setup †’ Outbound Change Sets
2. Create new change set
3. Add all components:
   - Custom Objects (Project_Task__c, Release_Notes__c, etc.)
   - Custom Fields
   - Lightning Web Components
   - Apex Classes
   - Triggers
   - Permission Sets
   - Flows
   - FlexiPages
   - List Views
   - Validation Rules
   - Record Types

#### Step 2: Upload Change Set

1. Upload change set
2. Note the change set name

#### Step 3: Deploy to Target Org

1. In target org: Setup †’ Inbound Change Sets
2. Find and select the change set
3. Click "Deploy"
4. Review and confirm

## Post-Installation Configuration

### Step 1: Assign Permission Sets

Assign permission sets to users:

1. Setup †’ Users †’ Permission Sets
2. For each permission set:
   - Click on the permission set name
   - Click "Manage Assignments"
   - Click "Add Assignments"
   - Select users
   - Click "Assign"

**Permission Sets to Assign**:
- **Project Management Admin**: For system administrators
- **Project Management Manager**: For project managers
- **Project Management User**: For developers and standard users

### Step 2: Configure Approval Processes

The system includes approval processes that need to be activated:

1. Setup †’ Process Automation †’ Approval Processes
2. Find and activate:
   - `Approval_Process_Project_Task_Waiting_For_Client_Approval_on_Backlog_Task`
   - `Approval_Process_Project_Task_PM_Code_Reviewer_Approval`
   - `Approval_Process_Project_Task_Client_Completion_Approval`

3. For each process:
   - Review entry criteria
   - Configure approver assignment
   - Set field updates
   - Activate the process

### Step 3: Configure Flows

Review and activate flows:

1. Setup †’ Process Automation †’ Flows
2. Activate required flows:
   - Progress Calculation Flow
   - Dependency Risk Assessment Flow
   - Status Change Automation Flow
   - Release Notes Generation Flow

3. Test each flow to ensure proper operation

### Step 4: Configure Page Layouts

Ensure page layouts are assigned:

1. Setup †’ Object Manager †’ Project Task
2. Click "Page Layouts"
3. Assign layouts to profiles:
   - Default layout for most users
   - Custom layouts for specific roles if needed

### Step 5: Configure Lightning Pages

Set up Lightning pages:

1. Setup †’ Lightning App Builder
2. Create or edit:
   - **Project Task Home Page**: Main dashboard page
   - **Project Task Record Page**: Task detail page

3. Add components:
   - Project Task Dashboard (home page)
   - Task Dependency Visualizer (record page)
   - Task Progress Indicator (record page)
   - Related Tasks List (record page)

4. Configure component properties
5. Activate pages

### Step 6: Configure List Views

Verify list views are accessible:

1. Go to Project Tasks tab
2. Verify list views are available:
   - My Tasks
   - Backlog Tasks
   - In Progress Tasks
   - Pending Review - Client
   - Blocked Tasks
   - Overdue Tasks
   - High Priority Tasks
   - (and others)

3. Set default list view if needed

### Step 7: Configure Quick Actions

Set up quick actions on page layouts:

1. Setup †’ Object Manager †’ Project Task
2. Click "Buttons, Links, and Actions"
3. Verify quick actions exist:
   - Mark Reviewed by PM/Code Reviewer
   - Mark Reviewed by Client
   - Generate Release Notes

4. Add to page layouts as needed

### Step 8: Configure Remote Site Settings

If using external resources (e.g., Chart.js):

1. Setup †’ Remote Site Settings
2. Verify settings exist:
   - ChartJS (if using Chart.js)
   - Other required remote sites

3. Activate if needed

### Step 9: Configure CSP Trusted Sites

For Chart.js or other external JavaScript:

1. Setup †’ CSP Trusted Sites
2. Verify ChartJS trusted site exists
3. Activate if needed

## Verification

### Verify Installation

Run through this checklist to verify installation:

#### Custom Objects

- [ ] Project_Task__c object exists
- [ ] Release_Notes__c object exists
- [ ] Release_Tag__c object exists
- [ ] Release_Version__c object exists

#### Custom Fields

- [ ] All Project_Task__c fields are present
- [ ] Rollup fields are working (Total_Estimated_Hours__c, Total_Actual_Hours__c)
- [ ] Formula fields are calculating correctly

#### Lightning Web Components

- [ ] projectTaskDashboard component deployed
- [ ] taskDependencyVisualizer component deployed
- [ ] taskProgressIndicator component deployed
- [ ] All other LWC components deployed

#### Apex Classes

- [ ] ProjectTaskDashboardController class exists
- [ ] RelatedTasksController class exists
- [ ] TaskProgressCalculator class exists
- [ ] TaskDependencyHelper class exists

#### Triggers

- [ ] ProjectTaskTrigger exists and is active

#### Permission Sets

- [ ] Project_Management_Admin permission set exists
- [ ] Project_Management_Manager permission set exists
- [ ] Project_Management_User permission set exists

#### Flows

- [ ] All flows are activated
- [ ] Flows execute without errors

#### Approval Processes

- [ ] All approval processes are activated
- [ ] Approval processes trigger correctly

### Test Basic Functionality

1. **Create a Test Task**
   - Navigate to Project Tasks
   - Create a new task
   - Verify all fields are accessible
   - Save successfully

2. **Test Progress Calculation**
   - Create a parent task
   - Create subtasks
   - Mark subtasks as completed
   - Verify parent progress updates

3. **Test Dependencies**
   - Create two tasks
   - Link one as blocking dependency
   - Verify "At Risk" flag updates

4. **Test Dashboard**
   - Navigate to Project Task Home Page
   - Verify all components load
   - Test account filtering
   - Verify metrics display correctly

5. **Test Approval Workflow**
   - Create a Backlog task
   - Mark "Ready for Client Review"
   - Verify approval process triggers
   - Complete approval
   - Verify status changes

## Troubleshooting Installation

### Issue: Deployment Fails

**Error**: "Component deployment failed"

**Solutions**:
1. Check API version compatibility
2. Verify all dependencies are included
3. Check for missing required fields
4. Review deployment errors in detail
5. Deploy in smaller batches if needed

### Issue: Components Not Appearing

**Error**: LWC components not visible

**Solutions**:
1. Verify My Domain is configured
2. Check component metadata files
3. Verify API version 65.0 or later
4. Clear browser cache
5. Redeploy components

### Issue: Permission Sets Not Working

**Error**: Users cannot access features

**Solutions**:
1. Verify permission sets are assigned
2. Check object and field permissions
3. Verify profile permissions
4. Check field-level security
5. Reassign permission sets if needed

### Issue: Flows Not Executing

**Error**: Flows don't trigger

**Solutions**:
1. Verify flows are activated
2. Check entry criteria
3. Verify trigger conditions
4. Test flows manually
5. Review flow debug logs

### Issue: Approval Processes Not Triggering

**Error**: Approvals don't start

**Solutions**:
1. Verify processes are activated
2. Check entry criteria
3. Verify required fields are set
4. Check approver assignment
5. Review approval process configuration

### Issue: Rollup Fields Not Calculating

**Error**: Total hours not updating

**Solutions**:
1. Verify rollup field configuration
2. Check parent-child relationships
3. Verify field types are correct
4. Test with sample data
5. Contact Salesforce support if needed

## Next Steps

After successful installation:

1. **Train Users**: Provide training on system usage
2. **Configure Data**: Set up initial tasks and accounts
3. **Customize**: Adjust workflows and processes as needed
4. **Monitor**: Watch for issues and optimize
5. **Document**: Document any org-specific customizations

## Support

For installation issues:

1. Review this guide thoroughly
2. Check [Troubleshooting Guide](./Troubleshooting.md)
3. Review deployment logs
4. Contact system administrator
5. Open an issue in the repository

---

**Related Documentation**:
- [Configuration Guide](./Configuration-Guide.md) - System configuration
- [Architecture Overview](./Architecture-Overview.md) - System architecture
- [Development Guide](./Development-Guide.md) - Development setup

