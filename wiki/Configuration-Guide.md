# Configuration Guide

Complete guide for configuring the Milestone Task Management System after installation.

## Table of Contents

1. [Initial Configuration](#initial-configuration)
2. [User Setup](#user-setup)
3. [Workflow Configuration](#workflow-configuration)
4. [Dashboard Configuration](#dashboard-configuration)
5. [Customization Options](#customization-options)
6. [Advanced Configuration](#advanced-configuration)

## Initial Configuration

### Step 1: Verify Installation

1. Navigate to Setup †’ Custom Code †’ Apex Classes
2. Verify all classes are present:
   - TaskProgressCalculator
   - TaskDependencyHelper
   - RelatedTasksController
   - ProjectTaskDashboardController

3. Navigate to Setup †’ Custom Code †’ Apex Triggers
4. Verify ProjectTaskTrigger is active

5. Navigate to Setup †’ Object Manager
6. Verify custom objects exist:
   - Project_Task__c
   - Release_Notes__c
   - Release_Tag__c
   - Release_Version__c

### Step 2: Activate Automation

1. **Activate Triggers**
   - Setup †’ Custom Code †’ Apex Triggers
   - Verify ProjectTaskTrigger is active

2. **Activate Flows**
   - Setup †’ Process Automation †’ Flows
   - Activate all flows:
     - Progress Calculation Flow
     - Dependency Risk Assessment Flow
     - Status Change Automation Flow
     - Release Notes Generation Flow

3. **Activate Approval Processes**
   - Setup †’ Process Automation †’ Approval Processes
   - Activate:
     - Approval_Process_Project_Task_Waiting_For_Client_Approval_on_Backlog_Task
     - Approval_Process_Project_Task_PM_Code_Reviewer_Approval
     - Approval_Process_Project_Task_Client_Completion_Approval

## User Setup

### Assign Permission Sets

1. **Navigate to Permission Sets**
   - Setup †’ Users †’ Permission Sets

2. **Assign to Users**
   - For each permission set:
     - Click on permission set name
     - Click "Manage Assignments"
     - Click "Add Assignments"
     - Select users
     - Click "Assign"

3. **Recommended Assignments**:
   - **System Administrators**: Project_Management_Admin
   - **Project Managers**: Project_Management_Manager
   - **Developers**: Project_Management_User
   - **Clients**: Project_Management_User (with limited field access)

### Configure User Profiles

1. **Verify Object Access**
   - Setup †’ Users †’ Profiles
   - For each profile:
     - Object Settings †’ Project Task
     - Verify object permissions
     - Adjust as needed

2. **Configure Field-Level Security**
   - For each profile:
     - Field-Level Security †’ Project Task
     - Set field visibility and editability
     - Restrict sensitive fields as needed

## Workflow Configuration

### Approval Process Configuration

#### Client Development Approval

1. **Entry Criteria**
   - Status = Backlog
   - Ready_for_Client_Review__c = true

2. **Approver Assignment**
   - Use field: Client_User__c
   - Or specify user/queue

3. **Field Updates on Approval**
   - Client_Approved_for_Development__c = true
   - Status = Pending

4. **Field Updates on Rejection**
   - Client_Approved_for_Development__c = false
   - Status remains Backlog

#### PM/Code Reviewer Approval

1. **Entry Criteria**
   - Status = In Review
   - Reviewed_by_PM_Code_Reviewer__c = false

2. **Approver Assignment**
   - Specify PM or Code Reviewer user/queue
   - Or use role-based assignment

3. **Field Updates on Approval**
   - Reviewed_by_PM_Code_Reviewer__c = true
   - Status remains In Review
   - Trigger Client Completion Approval

#### Client Completion Approval

1. **Entry Criteria**
   - Status = In Review
   - Reviewed_by_PM_Code_Reviewer__c = true
   - Client_Approved_for_Completion__c = false

2. **Approver Assignment**
   - Use field: Client_User__c

3. **Field Updates on Approval**
   - Client_Approved_for_Completion__c = true
   - Status = Completed

### Flow Configuration

#### Progress Calculation Flow

1. **Trigger**
   - Object: Project_Task__c
   - Trigger: Record-Triggered Flow
   - Entry Criteria: Status is changed OR Parent_Task__c is changed

2. **Actions**
   - Call TaskProgressCalculator Apex class
   - Or implement calculation logic in flow

#### Dependency Risk Assessment Flow

1. **Trigger**
   - Object: Project_Task__c
   - Trigger: Record-Triggered Flow
   - Entry Criteria: Status is changed OR Related_Task__c is changed

2. **Actions**
   - Call TaskDependencyHelper Apex class
   - Or implement assessment logic in flow

## Dashboard Configuration

### Create Lightning Pages

1. **Project Task Home Page**
   - Setup †’ Lightning App Builder
   - Create new page: "Project Task Home Page"
   - Add components:
     - Project Task Dashboard (container)
   - Configure component properties
   - Activate page

2. **Project Task Record Page**
   - Setup †’ Lightning App Builder
   - Create new page: "Project Task Record Page"
   - Add components:
     - Task Progress Indicator
     - Task Dependency Visualizer
     - Related Tasks List
   - Configure component properties
   - Assign to Project_Task__c object
   - Activate page

### Configure Dashboard Components

1. **Component Visibility**
   - In Lightning App Builder
   - Select Project Task Dashboard component
   - Configure visibility properties:
     - Show Account Filter
     - Show Status Breakdown
     - Show Hours Metrics
     - (etc.)

2. **Component Ordering**
   - Set order properties for each component
   - Lower numbers appear first

3. **Account Filtering**
   - Configure automatic filtering on Account pages
   - Set up manual filtering for other pages

## Customization Options

### Custom Fields

#### Adding Custom Fields

1. **Create Field**
   - Setup †’ Object Manager †’ Project Task †’ Fields & Relationships
   - Click "New"
   - Choose field type
   - Configure field properties

2. **Add to Page Layout**
   - Setup †’ Object Manager †’ Project Task †’ Page Layouts
   - Edit layout
   - Add field to appropriate section

3. **Update Permission Sets**
   - Add field to permission sets
   - Set field-level security

#### Common Customizations

- **Custom Status Values**: Add new status picklist values
- **Custom Priority Values**: Add new priority options
- **Additional Tracking Fields**: Add fields for specific tracking needs
- **Integration Fields**: Add fields for external system integration

### Validation Rules

#### Adding Validation Rules

1. **Create Rule**
   - Setup †’ Object Manager †’ Project Task †’ Validation Rules
   - Click "New"
   - Define error condition
   - Set error message

2. **Test Rule**
   - Create test records
   - Verify rule triggers correctly
   - Adjust as needed

#### Common Validation Rules

- Status transition rules
- Required field combinations
- Date validations
- Dependency validations

### List Views

#### Creating Custom List Views

1. **Create View**
   - Go to Project Tasks tab
   - Click list view dropdown
   - Click "New"
   - Configure filters and columns

2. **Common List Views**
   - My Tasks (This Week)
   - High Priority (This Month)
   - Blocked Tasks (All Time)
   - Custom filtered views

### Page Layouts

#### Customizing Page Layouts

1. **Edit Layout**
   - Setup †’ Object Manager †’ Project Task †’ Page Layouts
   - Edit layout
   - Add/remove fields
   - Reorganize sections

2. **Assign to Profiles**
   - Assign layouts to profiles
   - Use different layouts for different roles

## Advanced Configuration

### Sharing Rules

#### Configure Sharing

1. **Organization-Wide Defaults**
   - Setup †’ Sharing Settings
   - Set Project_Task__c default sharing
   - Typically: Private

2. **Sharing Rules**
   - Setup †’ Sharing Settings †’ Sharing Rules
   - Create rules based on:
     - Account ownership
     - Role hierarchy
     - Criteria-based sharing

### Remote Site Settings

#### Configure External Resources

1. **Chart.js (if used)**
   - Setup †’ Remote Site Settings
   - Verify ChartJS remote site exists
   - Activate if needed

2. **Other External Resources**
   - Add remote sites as needed
   - Configure CSP trusted sites

### Email Templates

#### Create Email Templates

1. **Approval Request Templates**
   - Setup †’ Communication Templates †’ Email Templates
   - Create templates for:
     - Client Development Approval
     - PM/Code Reviewer Approval
     - Client Completion Approval

2. **Configure in Approval Processes**
   - Add email templates to approval processes
   - Customize template content

### Notifications

#### Configure Notifications

1. **Approval Notifications**
   - Configure email notifications in approval processes
   - Set notification preferences

2. **Chatter Notifications**
   - Enable Chatter on Project_Task__c
   - Configure @mention notifications
   - Set up feed tracking

### Integration Configuration

#### External System Integration

1. **API Access**
   - Setup †’ API
   - Generate API tokens if needed
   - Configure OAuth if needed

2. **Webhook Configuration**
   - Set up outbound messages
   - Configure platform events (if used)

3. **Data Import/Export**
   - Configure data loader settings
   - Set up scheduled exports if needed

## Configuration Checklist

### Post-Installation

- [ ] All Apex classes deployed
- [ ] All triggers active
- [ ] All flows activated
- [ ] All approval processes activated
- [ ] Permission sets assigned
- [ ] Lightning pages created and activated
- [ ] Page layouts configured
- [ ] List views created
- [ ] Sharing rules configured
- [ ] Email templates created
- [ ] Remote site settings configured

### User Onboarding

- [ ] Users assigned to permission sets
- [ ] Profiles configured
- [ ] Field-level security set
- [ ] User training completed
- [ ] Documentation provided

### System Testing

- [ ] Test task creation
- [ ] Test progress calculation
- [ ] Test dependency assessment
- [ ] Test approval workflows
- [ ] Test dashboard components
- [ ] Test list views
- [ ] Test sharing rules

---

**Related Documentation**:
- [Installation Guide](./Installation-Guide.md) - Installation steps
- [User Guide](./User-Guide.md) - End-user documentation
- [Architecture Overview](./Architecture-Overview.md) - System architecture

