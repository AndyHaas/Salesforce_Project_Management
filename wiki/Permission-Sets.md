# Permission Sets

Documentation for all permission sets in the Milestone Task Management System.

## Table of Contents

1. [Permission Set Overview](#permission-set-overview)
2. [Project_Management_Admin](#project_management_admin)
3. [Project_Management_Manager](#project_management_manager)
4. [Project_Management_User](#project_management_user)
5. [Assigning Permission Sets](#assigning-permission-sets)
6. [Customizing Permission Sets](#customizing-permission-sets)

## Permission Set Overview

The system includes three permission sets designed for different user roles:

1. **Project_Management_Admin**: Full administrative access
2. **Project_Management_Manager**: Manager-level access with additional permissions
3. **Project_Management_User**: Standard user access for developers and clients

## Project_Management_Admin

**Purpose**: Full administrative access to all system features

**Recommended For**:
- System administrators
- Technical leads
- Users who need to configure the system

### Object Permissions

| Object | Create | Read | Edit | Delete | View All | Modify All |
|--------|---------|------|------|--------|----------|------------|
| Project_Task__c | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Release_Notes__c | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Release_Tag__c | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Release_Version__c | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### Field Permissions

- **All Fields**: Full access (Read, Edit)
- **System Fields**: Full access
- **Formula Fields**: Read access (formula fields are read-only)

### Apex Class Access

- TaskProgressCalculator: ✅
- TaskDependencyHelper: ✅
- RelatedTasksController: ✅
- ProjectTaskDashboardController: ✅

### System Permissions

- Customize Application: ✅
- Modify All Data: ✅
- View All Data: ✅
- Manage Users: ✅ (if needed)
- Customize Application: ✅

## Project_Management_Manager

**Purpose**: Manager-level access with ability to manage tasks and view analytics

**Recommended For**:
- Project managers
- Team leads
- Users who manage projects

### Object Permissions

| Object | Create | Read | Edit | Delete | View All | Modify All |
|--------|---------|------|------|--------|----------|------------|
| Project_Task__c | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| Release_Notes__c | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| Release_Tag__c | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| Release_Version__c | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |

### Field Permissions

- **Most Fields**: Read and Edit access
- **System Fields**: Read access
- **Sensitive Fields**: May be restricted (configure as needed)

### Apex Class Access

- TaskProgressCalculator: ✅
- TaskDependencyHelper: ✅
- RelatedTasksController: ✅
- ProjectTaskDashboardController: ✅

### System Permissions

- Customize Application: ❌
- Modify All Data: ❌
- View All Data: ✅
- Manage Users: ❌

## Project_Management_User

**Purpose**: Standard user access for day-to-day task management

**Recommended For**:
- Developers
- Client users
- Standard team members

### Object Permissions

| Object | Create | Read | Edit | Delete | View All | Modify All |
|--------|---------|------|------|--------|----------|------------|
| Project_Task__c | ✅ | ✅ | ✅* | ❌ | ❌ | ❌ |
| Release_Notes__c | ✅ | ✅ | ✅* | ❌ | ❌ | ❌ |
| Release_Tag__c | ✅ | ✅ | ✅* | ❌ | ❌ | ❌ |
| Release_Version__c | ✅ | ✅ | ✅* | ❌ | ❌ | ❌ |

*Edit access may be restricted to own records or specific fields

### Field Permissions

- **Standard Fields**: Read and Edit (for own records)
- **Sensitive Fields**: Read only or restricted
- **System Fields**: Read only

### Apex Class Access

- TaskProgressCalculator: ✅ (indirect via triggers)
- TaskDependencyHelper: ✅ (indirect via triggers)
- RelatedTasksController: ✅
- ProjectTaskDashboardController: ✅

### System Permissions

- Customize Application: ❌
- Modify All Data: ❌
- View All Data: ❌
- Manage Users: ❌

## Assigning Permission Sets

### Method 1: Individual Assignment

1. **Navigate to Permission Sets**
   - Setup → Users → Permission Sets

2. **Select Permission Set**
   - Click on permission set name (e.g., Project_Management_User)

3. **Manage Assignments**
   - Click "Manage Assignments" button
   - Click "Add Assignments"
   - Select users
   - Click "Assign"

### Method 2: Mass Assignment

1. **Navigate to Users**
   - Setup → Users → Users

2. **Select Users**
   - Use checkboxes to select multiple users

3. **Assign Permission Sets**
   - Click "Permission Set Assignments" related list
   - Click "Add Assignments"
   - Select permission sets
   - Click "Assign"

### Method 3: Via Profile (Not Recommended)

While you can assign permission sets to profiles, it's better to assign to individual users for flexibility.

## Customizing Permission Sets

### Adding Custom Permissions

1. **Edit Permission Set**
   - Setup → Users → Permission Sets
   - Click on permission set name
   - Click "Edit"

2. **Add Permissions**
   - Object Settings: Add object permissions
   - Field Permissions: Add field-level security
   - Apex Class Access: Add Apex class access
   - System Permissions: Add system permissions

3. **Save Changes**
   - Click "Save"

### Creating Custom Permission Sets

You can create custom permission sets for specific needs:

1. **Create New Permission Set**
   - Setup → Users → Permission Sets
   - Click "New"
   - Enter label and API name
   - Click "Save"

2. **Configure Permissions**
   - Add object permissions
   - Configure field-level security
   - Add Apex class access
   - Set system permissions

3. **Assign to Users**
   - Follow assignment steps above

### Common Customizations

#### Client-Only Permission Set

Create a permission set for client users with limited access:

- **Object Permissions**: Read only on Project_Task__c
- **Field Permissions**: Limited field access (no internal fields)
- **Apex Class Access**: RelatedTasksController only
- **System Permissions**: None

#### Developer Permission Set

Create a permission set for developers:

- **Object Permissions**: Full CRUD on Project_Task__c (own records)
- **Field Permissions**: Full access to development-related fields
- **Apex Class Access**: All classes
- **System Permissions**: None

#### Read-Only Permission Set

Create a permission set for stakeholders who only need to view:

- **Object Permissions**: Read only on all objects
- **Field Permissions**: Read only on all fields
- **Apex Class Access**: Dashboard controller only
- **System Permissions**: None

## Best Practices

### Permission Set Management

- ✅ **Principle of Least Privilege**: Grant minimum necessary permissions
- ✅ **Role-Based Assignment**: Assign based on job function
- ✅ **Regular Review**: Periodically review and update permissions
- ✅ **Documentation**: Document any custom permission sets

### Security Considerations

- ✅ **Field-Level Security**: Restrict sensitive fields
- ✅ **Sharing Rules**: Use sharing rules for record-level access
- ✅ **Audit Trail**: Monitor permission set assignments
- ✅ **Testing**: Test permissions with test users

### User Management

- ✅ **Onboarding**: Assign permission sets during user onboarding
- ✅ **Role Changes**: Update permissions when roles change
- ✅ **Offboarding**: Remove permission sets when users leave
- ✅ **Training**: Train users on their permissions

## Troubleshooting

### Issue: User Cannot Access Features

**Solutions**:
1. Verify permission set is assigned
2. Check object permissions
3. Verify field-level security
4. Check sharing rules
5. Verify profile permissions

### Issue: User Has Too Much Access

**Solutions**:
1. Review permission set assignments
2. Remove unnecessary permission sets
3. Adjust field-level security
4. Review sharing rules
5. Create more restrictive permission set

### Issue: Permission Set Not Working

**Solutions**:
1. Verify permission set is active
2. Check assignment is saved
3. Verify user is active
4. Check for conflicting permissions
5. Review profile permissions

---

**Related Documentation**:
- [Configuration Guide](./Configuration-Guide.md) - System configuration
- [User Guide](./User-Guide.md) - End-user documentation
- [Installation Guide](./Installation-Guide.md) - Installation steps

