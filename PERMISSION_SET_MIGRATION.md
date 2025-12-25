# Permission Set Migration Guide

## New Permission Sets

Two consolidated permission sets have been created to replace the old ones:

### 1. Client_Project_Management_Portal_User
- **For**: Community Users (Portal/Experience Cloud users)
- **Replaces**: `Portal_Messaging`
- **Includes**: All portal functionality (messaging, projects, tasks, login)

### 2. Project_Management_Team_Member
- **For**: Milestone Consulting internal team members
- **Replaces**: `Project_Management_User`, `Project_Management_Manager`, `Project_Management_Admin`
- **Includes**: Full access to project management, tasks, messaging, and administrative functions

## Migration Steps

### Step 1: Assign New Permission Sets
1. Go to Setup → Permission Sets
2. Assign `Client_Project_Management_Portal_User` to all Community Users
3. Assign `Project_Management_Team_Member` to all Milestone team members

### Step 2: Unassign Old Permission Sets
Before deleting old permission sets, unassign them from all users:

**Currently Assigned:**
- `Portal_Messaging`: Assigned to **Andy Haas**
- `Project_Management_Admin`: Assigned to **Andy Haas**
- `Project_Management_User`: Assigned to **Kevin Pettitt**

**To Unassign:**
1. Go to Setup → Permission Sets
2. Click on each permission set
3. Click "Manage Assignments"
4. Remove all user assignments

### Step 3: Delete Old Permission Sets
Once all users are unassigned, run the destructive changes:

```bash
sf project deploy start --manifest package.xml --post-destructive-changes destructiveChanges.xml --target-org milestoneDevOrg
```

**Old Permission Sets to Delete:**
- `Portal_Messaging`
- `Project_Management_User`
- `Project_Management_Manager` ✅ (Already deleted - was unassigned)
- `Project_Management_Admin`

## Files

- `destructiveChanges.xml`: Contains the list of permission sets to delete
- `package.xml`: Empty package manifest for destructive deployment
