# Permission Sets

## Overview

This document describes all permission sets used in the Milestone Task Management system. Permission sets provide granular access control for different user types, ensuring users have appropriate permissions for their roles.

## Permission Sets

### Client_Project_Management_Portal_User

**Location**: `force-app/main/default/permissionsets/Client_Project_Management_Portal_User.permissionset-meta.xml`

**Purpose**: Provides access to portal functionality for client users in the Experience Cloud portal.

**Target Users**: Client portal users (users with `AccountId` set)

**Key Permissions**:

#### Apex Class Access
- `HomePageController`
- `PasswordlessLoginController`
- `PortalMessagingController`
- `PortalProjectController`
- `PortalRecordListController`
- `PortalTaskController`

#### Message__c Object Access
- **Read**: Yes
- **Create**: Yes
- **Edit**: Yes (own messages)
- **Delete**: Yes (own messages)

#### Message__c Field Permissions
- **Editable**:
  - `Account__c`
  - `Body__c`
  - `Is_Read_By_Client__c`
  - `Mentioned_Contacts__c`
  - `Related_Project__c`
  - `Related_Task__c`
  - `Reply_To__c`
  - `Sender__c`
  - `Visible_To_Client__c`
- **Read-only**:
  - `Client_Notification_Sent__c`
  - `CreatedDate`
  - `Deleted__c`
  - `Is_Edited__c`
  - `Is_Pinned__c`
  - `Is_Read_By_Milestone_Team__c`
  - `Last_Edited_Date__c`
  - `PM_Notification_Sent__c`
  - `Recipient_Type__c`

#### Project_Task__c Field Permissions
- **Read-only**: Various fields for viewing tasks
- **Editable**: Limited fields for client interaction

#### Other Object Access
- `Project__c`: Read access
- `Account`: Read access
- `Contact`: Read access (for mentions)

### Project_Management_Team_Member

**Location**: `force-app/main/default/permissionsets/Project_Management_Team_Member.permissionset-meta.xml`

**Purpose**: Provides access for Milestone team members to manage projects, tasks, and messaging.

**Target Users**: Internal Milestone Consulting team members (users without `AccountId`)

**Key Permissions**:

#### Apex Class Access
- `ProjectTaskDashboardController`
- `TaskContextController`
- `TaskDependencyHelper`
- `TaskProgressCalculator`
- `TaskSubtaskHelper`
- `PortalMessagingController`
- `MessageNotificationScheduler` (for scheduling notifications)

#### Application Access
- `Project_Management`: Visible

#### Message__c Object Access
- **Read**: Yes
- **Create**: Yes
- **Edit**: Yes
- **Delete**: Yes

#### Message__c Field Permissions
- **Editable**:
  - `Account__c`
  - `Body__c`
  - `Client_Notification_Sent__c`
  - `Deleted__c`
  - `Is_Edited__c`
  - `Is_Pinned__c`
  - `Is_Read_By_Client__c`
  - `Is_Read_By_Milestone_Team__c`
  - `Last_Edited_Date__c`
  - `Mentioned_Contacts__c`
  - `PM_Notification_Sent__c`
  - `Recipient_Type__c`
  - `Related_Project__c`
  - `Related_Task__c`
  - `Reply_To__c`
  - `Sender__c`
  - `Visible_To_Client__c`

#### Project_Task__c Field Permissions
- **Editable**: Full access to task fields including:
  - `Client_User__c`
  - `Project_Manager__c`
  - Status fields
  - Hours fields
  - Dependency fields

#### Other Object Access
- `Project__c`: Full access
- `Project_Task__c`: Full access
- `Account`: Read access
- `Contact`: Read/Edit access

### Project_Management_User

**Location**: `force-app/main/default/permissionsets/Project_Management_User.permissionset-meta.xml`

**Purpose**: Base permission set for project management users with standard access.

**Target Users**: General project management team members

**Key Permissions**:
- Similar to `Project_Management_Team_Member` but with more restricted access
- Read access to most objects
- Limited edit capabilities

### Project_Management_Manager

**Location**: `force-app/main/default/permissionsets/Project_Management_Manager.permissionset-meta.xml`

**Purpose**: Enhanced permissions for project management managers.

**Target Users**: Project managers and team leads

**Key Permissions**:
- All permissions from `Project_Management_User`
- Additional edit capabilities
- Access to reporting and analytics
- Ability to manage team assignments

### Project_Management_Admin

**Location**: `force-app/main/default/permissionsets/Project_Management_Admin.permissionset-meta.xml`

**Purpose**: Full administrative access to project management functionality.

**Target Users**: System administrators and senior management

**Key Permissions**:
- Full access to all objects and fields
- Ability to configure system settings
- Access to all Apex classes
- Ability to manage permission sets

## Assignment Guidelines

### Client Portal Users

**Required Permission Set**: `Client_Project_Management_Portal_User`

**Assignment**:
1. Navigate to the user's record
2. Go to **Permission Set Assignments** related list
3. Click **Edit Assignments**
4. Add `Client_Project_Management_Portal_User`
5. Save

**When to Assign**:
- All users who will access the Experience Cloud portal
- Users must have `AccountId` set (portal users)

### Milestone Team Members

**Required Permission Set**: `Project_Management_Team_Member`

**Assignment**:
1. Navigate to the user's record
2. Go to **Permission Set Assignments** related list
3. Click **Edit Assignments**
4. Add `Project_Management_Team_Member`
5. Save

**When to Assign**:
- All internal Milestone Consulting team members
- Users who need to manage projects and tasks
- Users who need to send/receive messages
- Users should NOT have `AccountId` set (internal users)

### Additional Permission Sets

Assign additional permission sets based on role:
- **Managers**: Add `Project_Management_Manager`
- **Administrators**: Add `Project_Management_Admin`
- **Standard Users**: `Project_Management_User` may be sufficient

## Field-Level Security (FLS)

### Message Read Tracking

The system uses separate read tracking fields for clients and team members:

- **`Is_Read_By_Client__c`**: Tracks if client has read the message
  - **Client Users**: Can edit (mark as read)
  - **Team Members**: Can edit (mark as read for clients)
  
- **`Is_Read_By_Milestone_Team__c`**: Tracks if team has read the message
  - **Client Users**: Read-only
  - **Team Members**: Can edit (mark as read)

### Notification Tracking

- **`PM_Notification_Sent__c`**: Tracks if PM notification email was sent
  - **Client Users**: Read-only
  - **Team Members**: Can edit (for system updates)
  
- **`Client_Notification_Sent__c`**: Tracks if client notification email was sent
  - **Client Users**: Read-only
  - **Team Members**: Can edit (for system updates)

## Security Considerations

### Sharing Model

- **Portal Users**: Access controlled through WHERE clause filters in Apex
- **Team Members**: Full access to messaging functionality
- **Sharing Rules**: Not required - access controlled via FLS and Apex logic

### Field-Level Security Best Practices

1. **Principle of Least Privilege**: Users only get permissions they need
2. **Read-Only by Default**: Most fields are read-only for portal users
3. **Edit Own Records**: Portal users can edit their own messages only
4. **System Fields**: Notification and tracking fields are read-only for portal users

## Troubleshooting

### Common Issues

| Issue | Likely Cause | Resolution |
|-------|--------------|------------|
| User can't send messages | Missing permission set | Assign `Client_Project_Management_Portal_User` or `Project_Management_Team_Member` |
| User can't see messages | Missing object access | Verify permission set includes Message__c object access |
| User can't edit messages | Missing field edit permission | Verify field permissions in permission set |
| FLS errors in tests | Test user missing permissions | Assign permission sets in test setup or use `System.runAs()` |
| Can't mark messages as read | Missing field edit permission | Verify `Is_Read_By_Client__c` or `Is_Read_By_Milestone_Team__c` is editable |

### Verifying Permissions

To verify a user's permissions:

1. Navigate to the user's record
2. Click **Permission Set Assignments** related list
3. Verify required permission sets are assigned
4. Click on permission set name to view details
5. Check **Field Permissions** for specific field access

### Testing Permissions

When writing test classes:

1. Use `System.runAs()` to test with specific user context
2. Assign permission sets in `@testSetup` if needed
3. Use `@future` methods to avoid `MIXED_DML_OPERATION` errors
4. Wrap permission set assignment in `Test.startTest()/Test.stopTest()`

Example:
```apex
@testSetup
static void setupTestData() {
    Test.startTest();
    assignPermissionSets(UserInfo.getUserId());
    Test.stopTest();
    // ... rest of setup
}

@future
static void assignPermissionSets(Id userId) {
    // Assign permission sets
}
```

## Maintenance

### Adding New Fields

When adding new fields to `Message__c`:

1. Update relevant permission sets with field permissions
2. Determine if field should be editable or read-only for each user type
3. Update this documentation

### Adding New Classes

When adding new Apex classes:

1. Add class access to appropriate permission sets
2. Consider sharing model (`with sharing` vs `without sharing`)
3. Update this documentation

## Related Documentation

- **[Portal Messaging System](Portal_Messaging_System.md)**: Overview of messaging system
- **[MessageNotificationScheduler](MessageNotificationScheduler.md)**: Scheduler documentation
- **[PortalMessagingController](PortalMessagingController.md)**: Controller documentation

## Related Files

### Permission Sets
- `force-app/main/default/permissionsets/Client_Project_Management_Portal_User.permissionset-meta.xml`
- `force-app/main/default/permissionsets/Project_Management_Team_Member.permissionset-meta.xml`
- `force-app/main/default/permissionsets/Project_Management_User.permissionset-meta.xml`
- `force-app/main/default/permissionsets/Project_Management_Manager.permissionset-meta.xml`
- `force-app/main/default/permissionsets/Project_Management_Admin.permissionset-meta.xml`
