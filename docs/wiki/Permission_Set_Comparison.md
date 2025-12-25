# Permission Set Comparison: Team Member vs User

## Overview

This document compares `Project_Management_Team_Member` and `Project_Management_User` permission sets to help determine which one to assign to users.

## Key Differences Summary

| Feature | Project_Management_Team_Member | Project_Management_User |
|---------|-------------------------------|------------------------|
| **Access Level** | Full administrative access | Limited user access |
| **Record Visibility** | View all records (`viewAllRecords=true`) | Own records only (`viewAllRecords=false`) |
| **Record Modification** | Modify all records (`modifyAllRecords=true`) | Own records only (`modifyAllRecords=false`) |
| **Delete Permission** | Can delete records | Cannot delete records |
| **Apex Classes** | 7 classes (full access) | 1 class (dashboard only) |
| **Messaging Access** | Full access to Message__c | No access to Message__c |
| **Task Helper Classes** | Yes (TaskContextController, TaskDependencyHelper, etc.) | No |
| **Content Management** | Yes (ContentDocument, ContentVersion) | No |

## Detailed Comparison

### Apex Class Access

#### Project_Management_Team_Member
- ✅ `ProjectTaskDashboardController` - Dashboard functionality
- ✅ `TaskContextController` - Task context panel
- ✅ `TaskDependencyHelper` - Task dependency management
- ✅ `TaskProgressCalculator` - Task progress calculations
- ✅ `TaskSubtaskHelper` - Subtask management
- ✅ `PortalMessagingController` - Messaging functionality
- ✅ `MessageNotificationScheduler` - Email notification scheduling

#### Project_Management_User
- ✅ `ProjectTaskDashboardController` - Dashboard functionality only
- ❌ No access to helper classes
- ❌ No access to messaging
- ❌ No access to notification scheduler

### Object Permissions

#### Project_Task__c

**Team Member:**
- Create: ✅
- Read: ✅
- Edit: ✅
- Delete: ✅
- View All Records: ✅
- Modify All Records: ✅
- View All Fields: ✅

**User:**
- Create: ✅
- Read: ✅
- Edit: ✅ (own records only)
- Delete: ❌
- View All Records: ❌
- Modify All Records: ❌
- View All Fields: ❌

#### Project__c

**Team Member:**
- Create: ✅
- Read: ✅
- Edit: ✅
- Delete: ✅
- View All Records: ✅
- Modify All Records: ✅

**User:**
- Create: ❌
- Read: ✅ (own records only)
- Edit: ❌
- Delete: ❌
- View All Records: ❌
- Modify All Records: ❌

#### Message__c

**Team Member:**
- Full access: Create, Read, Edit, Delete
- View All Records: ✅
- Modify All Records: ✅

**User:**
- No access: ❌

#### Project_Task_Relationship__c

**Team Member:**
- Full access: Create, Read, Edit, Delete
- View All Records: ✅
- Modify All Records: ✅

**User:**
- No access: ❌

### Field Permissions

#### Key Fields - Team Member Can Edit, User Cannot

| Field | Team Member | User |
|-------|-------------|------|
| `At_Risk_Due_to_Dependencies__c` | ✅ Editable | ❌ Read-only |
| `Is_Blocking__c` | ✅ Editable | ❌ Read-only |
| `Progress_Percentage__c` | ✅ Editable | ❌ Read-only |
| `Total_Actual_Hours__c` | ✅ Editable | ❌ Read-only |
| `Total_Estimated_Hours__c` | ✅ Editable | ❌ Read-only |
| `Release_Notes_Done__c` | ✅ Editable | ❌ Read-only |

#### Fields Both Can Edit

- `Actual_Hours__c`
- `Client_Approved_for_Completion__c`
- `Client_Approved_for_Development__c`
- `Client_User__c`
- `Description__c`
- `Developer__c`
- `Due_Date__c`
- `Project_Manager__c`
- `Estimated_Hours__c`
- `Parent_Task__c`
- `Ready_for_Client_Review__c`
- `Release_Notes__c`
- `Reviewed_by_PM_Code_Reviewer__c`
- `Start_Date__c`

### Content Management

**Team Member:**
- ✅ `ContentDocument` - Create, Read, Edit, Delete
- ✅ `ContentDocumentLink` - Create, Read, Edit, Delete
- ✅ `ContentVersion` - Create, Read, Edit, Delete

**User:**
- ❌ No access to content management objects

## When to Use Each Permission Set

### Use Project_Management_Team_Member When:

- User is a **Milestone Consulting team member** (internal employee)
- User needs to **manage all projects and tasks** (not just their own)
- User needs **messaging functionality** (send/receive messages)
- User needs to **delete records** (tasks, projects, messages)
- User needs access to **task helper classes** (dependencies, progress, subtasks)
- User needs to **manage content/files** (attachments, documents)
- User needs to **schedule notifications** (MessageNotificationScheduler)
- User is a **project manager** or **team lead**

### Use Project_Management_User When:

- User is a **standard team member** with limited responsibilities
- User only needs to **view and edit their own tasks**
- User does **not need messaging functionality**
- User does **not need to delete records**
- User only needs **dashboard access** (view reports, analytics)
- User does **not need administrative functions**
- User is a **junior team member** or **contractor** with limited access needs

## Recommendation

**Default Assignment:**
- **Internal Milestone Team Members**: Assign `Project_Management_Team_Member`
- **Standard Users/Contractors**: Assign `Project_Management_User`

**Note**: Most internal team members will need `Project_Management_Team_Member` to access messaging, manage dependencies, and have full project visibility. Only assign `Project_Management_User` if the user has very limited responsibilities and doesn't need messaging or administrative functions.

## Migration Path

If a user currently has `Project_Management_User` but needs additional access:

1. **Add** `Project_Management_Team_Member` permission set (they can have both)
2. **Or replace** `Project_Management_User` with `Project_Management_Team_Member`

Permission sets are additive, so users can have multiple permission sets assigned.

## Related Documentation

- **[Permission Sets](Permission_Sets.md)**: Complete permission set documentation
- **[Portal Messaging System](Portal_Messaging_System.md)**: Messaging functionality overview
