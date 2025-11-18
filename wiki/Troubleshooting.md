# Troubleshooting Guide

Solutions to common issues and problems in the Milestone Task Management System.

## Table of Contents

1. [Access and Permissions](#access-and-permissions)
2. [Task Creation and Editing](#task-creation-and-editing)
3. [Workflow and Approval Issues](#workflow-and-approval-issues)
4. [Progress and Calculation Issues](#progress-and-calculation-issues)
5. [Dashboard and Component Issues](#dashboard-and-component-issues)
6. [Data and Field Issues](#data-and-field-issues)
7. [Performance Issues](#performance-issues)

## Access and Permissions

### Issue: Cannot see Project Management app

**Symptoms**:
- App doesn't appear in App Launcher
- "Insufficient Privileges" error

**Solutions**:

1. **Check Permission Set Assignment**
   - Go to Setup → Users → Permission Sets
   - Verify you have one of these assigned:
     - Project Management User
     - Project Management Manager
     - Project Management Admin
   - If not assigned, contact administrator

2. **Check App Access**
   - Go to Setup → Apps → App Manager
   - Find "Project Management" app
   - Verify it's assigned to your profile
   - Contact administrator if not assigned

3. **Check Profile Permissions**
   - Verify your profile has access to Project_Task__c object
   - Contact administrator to grant access

### Issue: Cannot create or edit tasks

**Symptoms**:
- "Insufficient Privileges" error
- "Read Only" fields
- Cannot save changes

**Solutions**:

1. **Verify Object Permissions**
   - Check that your permission set includes:
     - Create permission on Project_Task__c
     - Edit permission on Project_Task__c
   - Contact administrator if missing

2. **Check Field-Level Security**
   - Some fields may be read-only based on FLS
   - Contact administrator to adjust FLS if needed

3. **Verify Record Access**
   - Ensure you have access to the record
   - Check sharing rules if applicable

## Task Creation and Editing

### Issue: Validation error when saving task

**Symptoms**:
- Red error message when saving
- Specific validation rule error

**Common Validation Errors**:

1. **"Ready for Client Review can only be checked when Status is Backlog"**
   - **Cause**: Trying to check Ready for Client Review when status is not Backlog
   - **Solution**: Change status to "Backlog" first, then check the box

2. **"Circular dependency detected"**
   - **Cause**: Creating a dependency loop (A depends on B, B depends on A)
   - **Solution**: Remove one of the dependencies to break the loop

3. **"A task cannot be its own parent"**
   - **Cause**: Setting Parent Task to the same task
   - **Solution**: Select a different parent task

4. **"Estimated Hours must be >= 0"**
   - **Cause**: Negative hours entered
   - **Solution**: Enter 0 or positive number

**General Solution**:
- Read the error message carefully
- Follow the instructions in the error
- Check field values match requirements
- Contact administrator if error persists

### Issue: Cannot change task status

**Symptoms**:
- Status field is read-only
- Status change doesn't save
- Validation error on status change

**Solutions**:

1. **Check Required Approvals**
   - Some status changes require approvals first
   - Complete approval workflows before changing status
   - See [Workflows and Processes](./Workflows-and-Processes.md)

2. **Check Validation Rules**
   - Some status changes may be restricted
   - Review validation error messages
   - Ensure prerequisites are met

3. **Check Permissions**
   - Verify you have edit permission
   - Contact administrator if permission issue

### Issue: Cannot assign Developer or Client User

**Symptoms**:
- Field not visible
- Cannot select user
- "Insufficient Privileges" error

**Solutions**:

1. **Check Field Visibility**
   - Field may not be on page layout
   - Contact administrator to add field

2. **Check User Availability**
   - Ensure users exist and are active
   - Verify users have appropriate permissions

3. **Check Field-Level Security**
   - Verify FLS allows editing
   - Contact administrator if needed

## Workflow and Approval Issues

### Issue: Approval process not triggering

**Symptoms**:
- Approval request not sent
- No notification received
- Status doesn't change after approval

**Solutions**:

1. **Check Approval Process Status**
   - Go to Setup → Process Automation → Approval Processes
   - Verify process is "Active"
   - Contact administrator if inactive

2. **Check Entry Criteria**
   - Verify task meets entry criteria:
     - Correct status
     - Required fields set (e.g., Client User)
     - Checkboxes in correct state
   - Review [Workflows and Processes](./Workflows-and-Processes.md)

3. **Check Approver Assignment**
   - Verify approver is assigned correctly
   - Check Client User field is set (for client approvals)
   - Ensure approver has necessary permissions

4. **Check Workflow Configuration**
   - Verify workflow actions are configured
   - Check field updates are set correctly
   - Contact administrator if configuration issue

### Issue: Cannot approve or reject task

**Symptoms**:
- Approval button not visible
- "Insufficient Privileges" error
- Approval doesn't process

**Solutions**:

1. **Check Approver Assignment**
   - Verify you are the assigned approver
   - Check approval history to see current approver
   - Contact administrator if incorrectly assigned

2. **Check Approval Access**
   - Verify you have approval permissions
   - Check your role in approval process
   - Contact administrator if needed

3. **Check Approval Status**
   - Verify approval is still pending
   - Check if already approved/rejected
   - Review approval history

### Issue: Status doesn't change after approval

**Symptoms**:
- Approval completes but status unchanged
- Fields not updating automatically

**Solutions**:

1. **Check Workflow Actions**
   - Verify workflow has field update actions
   - Check actions are configured correctly
   - Contact administrator to review workflow

2. **Check Validation Rules**
   - Validation rule may prevent status change
   - Review validation error messages
   - Adjust field values to meet validation

3. **Manual Status Update**
   - If workflow fails, manually update status
   - Contact administrator to fix workflow

## Progress and Calculation Issues

### Issue: Progress percentage not updating

**Symptoms**:
- Progress stuck at 0% or old value
- Subtasks completed but progress unchanged

**Solutions**:

1. **Verify Subtask Status**
   - Progress only calculated for parent tasks with subtasks
   - Ensure subtasks are marked "Completed" or "Closed"
   - Check subtask statuses are saved

2. **Check Subtask Relationships**
   - Verify subtasks are linked to parent (Parent Task field set)
   - Check parent task is correct
   - Re-link if necessary

3. **Check Calculation Trigger**
   - Progress calculates when subtask status changes
   - Try updating a subtask status to trigger recalculation
   - Contact administrator if trigger not firing

4. **Manual Recalculation**
   - Contact administrator to run recalculation
   - May need to trigger Apex class manually

### Issue: Hours not rolling up to parent

**Symptoms**:
- Total Estimated Hours or Total Actual Hours not updating
- Rollup fields show 0 or old values

**Solutions**:

1. **Check Rollup Field Type**
   - Verify fields are Rollup Summary fields
   - Check rollup is configured correctly
   - Contact administrator if configuration issue

2. **Verify Subtask Relationships**
   - Ensure subtasks are properly linked
   - Check Parent Task field is set
   - Re-link if necessary

3. **Check Field Values**
   - Verify hours are entered on subtasks
   - Check Estimated Hours and Actual Hours fields have values
   - Ensure values are numbers (not text)

4. **Trigger Recalculation**
   - Update a subtask to trigger rollup
   - Contact administrator if rollup not working

### Issue: "At Risk Due to Dependencies" flag incorrect

**Symptoms**:
- Flag shows true when dependency is complete
- Flag shows false when task is blocked

**Solutions**:

1. **Check Dependency Status**
   - Verify blocking task status
   - Task is not at risk if blocking task is:
     - Completed
     - Closed
     - In Review
     - Removed
   - Update blocking task status if needed

2. **Check Relationship Type**
   - Verify relationship is "Blocking Dependency"
   - "Related Task" relationships don't trigger risk flag
   - Update relationship type if needed

3. **Trigger Recalculation**
   - Update blocking task status to trigger recalculation
   - Contact administrator if flag not updating

## Dashboard and Component Issues

### Issue: Dashboard components not showing

**Symptoms**:
- Components missing from dashboard
- Blank spaces where components should be
- "Component Error" messages

**Solutions**:

1. **Check Component Visibility**
   - Components may be hidden in configuration
   - Go to Lightning App Builder
   - Verify component visibility settings
   - Enable components as needed

2. **Check Permissions**
   - Verify you have access to underlying data
   - Check object and field permissions
   - Contact administrator if permission issue

3. **Check Component Configuration**
   - Verify components are properly configured
   - Check for configuration errors
   - Contact administrator to review

### Issue: Dashboard shows wrong data

**Symptoms**:
- Showing tasks from wrong account
- Metrics don't match expectations
- Filters not working

**Solutions**:

1. **Check Account Filter**
   - Verify account filter is set correctly
   - Clear and reset filter if needed
   - Check if on Account record page (auto-filtered)

2. **Check Data Access**
   - Verify you can see the tasks in question
   - Check sharing rules and permissions
   - Ensure tasks exist and are accessible

3. **Refresh Dashboard**
   - Refresh the page
   - Clear browser cache
   - Try in different browser

### Issue: Component errors or blank displays

**Symptoms**:
- "Error loading component" message
- Blank component areas
- JavaScript errors in console

**Solutions**:

1. **Check Browser Console**
   - Open browser developer tools (F12)
   - Check for JavaScript errors
   - Report errors to administrator

2. **Check Component Status**
   - Verify Lightning Web Components are deployed
   - Check component metadata
   - Contact administrator if component missing

3. **Clear Cache**
   - Clear browser cache
   - Hard refresh (Ctrl+F5 or Cmd+Shift+R)
   - Try different browser

## Data and Field Issues

### Issue: Fields not visible on page

**Symptoms**:
- Expected fields missing
- Cannot find specific field
- Fields in different location

**Solutions**:

1. **Check Page Layout**
   - Field may not be on current page layout
   - Check other sections of page
   - Contact administrator to add field

2. **Check Field-Level Security**
   - Field may be hidden by FLS
   - Verify FLS settings
   - Contact administrator if needed

3. **Check Record Type**
   - Some fields may be record-type specific
   - Verify correct record type selected
   - Check record type page layout

### Issue: Field values not saving

**Symptoms**:
- Changes don't persist
- Field reverts to old value
- Save button doesn't work

**Solutions**:

1. **Check Required Fields**
   - Ensure all required fields are filled
   - Check for validation errors
   - Review error messages

2. **Check Field Editability**
   - Field may be read-only
   - Check field properties
   - Verify permissions

3. **Check Validation Rules**
   - Validation may prevent save
   - Review validation error messages
   - Adjust values to meet validation

### Issue: Lookup fields not finding records

**Symptoms**:
- Cannot find related record
- Lookup returns no results
- "No records found" message

**Solutions**:

1. **Check Record Existence**
   - Verify record exists
   - Check record is not deleted
   - Ensure record is accessible

2. **Check Lookup Filter**
   - Lookup may have filter criteria
   - Verify record meets filter criteria
   - Contact administrator if filter too restrictive

3. **Check Permissions**
   - Verify you can see the related record
   - Check object and field permissions
   - Contact administrator if permission issue

## Performance Issues

### Issue: Dashboard loads slowly

**Symptoms**:
- Long load times
- Components load one by one
- Timeout errors

**Solutions**:

1. **Reduce Data Volume**
   - Use account filters to limit data
   - Filter by date ranges if available
   - Reduce number of visible components

2. **Check Data Volume**
   - Large number of tasks may slow dashboard
   - Contact administrator to optimize queries
   - Consider archiving old tasks

3. **Browser Performance**
   - Close other browser tabs
   - Clear browser cache
   - Update browser to latest version

### Issue: Task list loads slowly

**Symptoms**:
- Long load times for task list
- Pagination issues
- Timeout errors

**Solutions**:

1. **Use Filters**
   - Apply filters to reduce results
   - Use list views with filters
   - Limit date ranges

2. **Reduce Columns**
   - Fewer columns = faster loading
   - Hide unnecessary columns
   - Use compact view if available

3. **Contact Administrator**
   - May need query optimization
   - Consider indexing
   - Review data volume

---

**Still experiencing issues?** Contact your system administrator with:
- Detailed description of the issue
- Steps to reproduce
- Error messages (if any)
- Screenshots (if helpful)
- Browser and Salesforce version information

