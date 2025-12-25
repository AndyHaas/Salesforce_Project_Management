# Permission Set Comparison: Manager vs Admin

## Overview

This document compares `Project_Management_Manager` and `Project_Management_Admin` permission sets to help determine which one to assign to users.

## Key Differences Summary

| Feature | Project_Management_Manager | Project_Management_Admin |
|---------|----------------------------|--------------------------|
| **Modify All Records** | ❌ No (`modifyAllRecords=false`) | ❌ No (`modifyAllRecords=false`) |
| **View All Records** | ✅ Yes (`viewAllRecords=true`) | ✅ Yes (`viewAllRecords=true`) |
| **Delete Permission** | ✅ Yes (can delete) | ✅ Yes (can delete) |
| **Project__c Access** | Read-only | Full access (Create, Edit, Delete) |
| **Release_Notes_Done__c** | Read-only | Editable |
| **Apex Classes** | 3 classes | 3 classes (same) |
| **Record Ownership** | Can only edit own records | Can only edit own records |

**Important**: Both Manager and Admin have `modifyAllRecords=false`, meaning they can only edit records they own. Only Manager and Admin have delete permissions - all other permission sets cannot delete records.

## Detailed Comparison

### Apex Class Access

Both permission sets have identical Apex class access:

- ✅ `ProjectTaskDashboardController` - Dashboard functionality
- ✅ `TaskDependencyHelper` - Task dependency management
- ✅ `TaskProgressCalculator` - Task progress calculations

**Note**: Neither has access to:
- `TaskContextController`
- `TaskSubtaskHelper`
- `PortalMessagingController`
- `MessageNotificationScheduler`

### Object Permissions

#### Project_Task__c

**Manager:**
- Create: ✅
- Read: ✅
- Edit: ✅ (own records only)
- Delete: ✅
- View All Records: ✅
- **Modify All Records: ❌** (key difference)
- View All Fields: ✅

**Admin:**
- Create: ✅
- Read: ✅
- Edit: ✅ (own records only)
- Delete: ✅
- View All Records: ✅
- **Modify All Records: ❌** (same as Manager)
- View All Fields: ✅

**Impact**: Both Manager and Admin can only edit tasks they own. The key difference is that Admin can create/edit/delete projects, while Manager cannot.

#### Project__c

**Manager:**
- Create: ❌
- Read: ✅ (all records)
- Edit: ❌
- Delete: ❌
- View All Records: ✅
- Modify All Records: ❌

**Admin:**
- Create: ✅
- Read: ✅ (all records)
- Edit: ✅
- Delete: ✅
- View All Records: ✅
- Modify All Records: ✅

**Impact**: Manager can only view projects, while Admin can create, edit, and delete projects.

#### Release Objects (Release_Notes__c, Release_Tag__c, Release_Version__c)

**Manager:**
- Create: ✅
- Read: ✅
- Edit: ✅ (own records only)
- Delete: ✅
- View All Records: ✅
- **Modify All Records: ❌**

**Admin:**
- Create: ✅
- Read: ✅
- Edit: ✅ (all records)
- Delete: ✅
- View All Records: ✅
- **Modify All Records: ✅**

**Impact**: Both Manager and Admin can only edit release records they own. Both have delete permissions.

### Field Permissions

#### Key Difference: Release_Notes_Done__c

| Field | Manager | Admin |
|-------|---------|-------|
| `Release_Notes_Done__c` | ❌ Read-only | ✅ Editable |

**All other fields are identical** between Manager and Admin permission sets.

### Record Ownership Impact

#### Manager (`modifyAllRecords=false`)
- Can **view** all records across the organization
- Can only **edit/delete** records they own
- Must be assigned as owner to modify records
- Good for managers who need visibility but limited modification rights
- **Can delete** records (only Manager and Admin have delete permissions)

#### Admin (`modifyAllRecords=false`)
- Can **view** all records across the organization
- Can only **edit/delete** records they own (same as Manager)
- Must be assigned as owner to modify records
- **Can delete** records (only Manager and Admin have delete permissions)
- **Key difference**: Can create/edit/delete projects (Manager cannot)

## When to Use Each Permission Set

### Use Project_Management_Manager When:

- User is a **project manager** or **team lead**
- User needs **visibility** into all projects and tasks
- User should only **edit their own tasks** (not others' tasks)
- User should **not create/edit/delete projects** (read-only access)
- User needs **limited administrative control** (view all, edit own)
- Organization wants to **restrict cross-ownership editing**

### Use Project_Management_Admin When:

- User is a **system administrator** or **senior management**
- User needs **full administrative control** over all records
- User needs to **edit any task** regardless of ownership
- User needs to **create/edit/delete projects**
- User needs to **manage release notes** (can edit `Release_Notes_Done__c`)
- Organization needs **unrestricted access** for administrative tasks

## Permission Hierarchy

```
Project_Management_User (Limited)
    ↓
Project_Management_Manager (View All, Edit Own)
    ↓
Project_Management_Admin (View All, Edit All)
    ↓
Project_Management_Team_Member (Full + Messaging)
```

**Note**: `Project_Management_Team_Member` is actually the most comprehensive permission set because it includes messaging functionality and more Apex classes, even though it's not in the "hierarchy" name.

## Common Scenarios

### Scenario 1: Project Manager Needs Visibility
**Use**: `Project_Management_Manager`
- Can see all tasks across projects
- Can only edit tasks assigned to them
- Cannot modify projects directly
- Good for oversight without full control

### Scenario 2: System Administrator
**Use**: `Project_Management_Admin`
- Can see and edit all records
- Can create/modify/delete projects
- Can fix data issues across all records
- Full administrative access

### Scenario 3: Senior Manager Needs Full Control
**Use**: `Project_Management_Admin`
- Can manage any task or project
- Can override ownership restrictions
- Can manage release notes completion
- Administrative oversight

### Scenario 4: Team Lead with Messaging
**Use**: `Project_Management_Team_Member` (not Manager or Admin)
- Has all Manager capabilities
- Plus messaging functionality
- Plus more Apex classes
- Most comprehensive access

## Recommendation

**Default Assignment:**
- **Project Managers**: Assign `Project_Management_Manager` for visibility with controlled editing
- **System Administrators**: Assign `Project_Management_Admin` for full administrative control
- **Team Leads with Messaging**: Assign `Project_Management_Team_Member` for comprehensive access

**Note**: If a user needs messaging functionality, they should use `Project_Management_Team_Member` instead of Manager or Admin, as neither Manager nor Admin includes messaging access.

## Migration Path

If a Manager needs Admin access:

1. **Replace** `Project_Management_Manager` with `Project_Management_Admin`
2. **Or add** `Project_Management_Admin` (permission sets are additive, but Admin supersedes Manager's restrictions)

If an Admin needs Messaging:

1. **Add** `Project_Management_Team_Member` (includes messaging + Admin-like access)
2. **Or keep** `Project_Management_Admin` and add messaging separately

## Security Considerations

### Manager Permission Set
- **Safer**: Limits editing to own records
- **Prevents**: Accidental modification of others' work
- **Good for**: Organizations wanting oversight without full control

### Admin Permission Set
- **Powerful**: Can modify any record
- **Risk**: Accidental changes to any record
- **Good for**: Administrators who need to fix data issues
- **Recommendation**: Use sparingly, only for trusted administrators

## Related Documentation

- **[Permission Sets](Permission_Sets.md)**: Complete permission set documentation
- **[Permission Set Comparison](Permission_Set_Comparison.md)**: Team Member vs User comparison
- **[Portal Messaging System](Portal_Messaging_System.md)**: Messaging functionality overview
