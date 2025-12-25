# Setup Guide

Complete first-time setup checklist for the Project Management Portal system. Follow these steps in order to ensure all components are properly configured.

**Location**: This guide covers setup for the entire Project Management system, including portal functionality, schedulers, and permission sets.

## Prerequisites

Before starting setup, ensure you have:
- ✅ Salesforce org with Experience Cloud (Community Cloud) enabled
- ✅ System Administrator access
- ✅ Platform Cache enabled (required for OTP functionality)
- ✅ Email Deliverability configured

## Setup Checklist

### Phase 1: Initial Configuration

#### 1. Enable Platform Cache
**Required for**: OTP login functionality

**Steps**:
1. Navigate to **Setup > Platform Cache**
2. Click **Enable Platform Cache**
3. Allocate cache size (minimum recommended: 10 MB)
4. Save

**Verification**: Platform Cache should show as "Enabled" in Setup

#### 2. Configure Email Deliverability
**Required for**: OTP emails and message notifications

**Steps**:
1. Navigate to **Setup > Email Administration > Deliverability**
2. Set "Access to Send Email" to **"All email"**
3. Save

**Verification**: Email deliverability should be set to "All email"

#### 3. Enable Portal Access for Contacts
**Required for**: Client portal access

**Steps**:
1. Navigate to **Contact** object records
2. For each client contact that needs portal access:
   - Edit the Contact record
   - Check **Portal Access Enabled** (`Portal_Access_Enabled__c`)
   - Ensure **Email** field is populated and matches User.Email
   - Save

**Verification**: Contact records should have `Portal_Access_Enabled__c = true`

#### 4. Verify User Configuration
**Required for**: Portal login

**For Portal Users**:
- User must have associated Contact record
- Contact must have `Portal_Access_Enabled__c = true`
- Contact.Email must match User.Email
- User must be active (`IsActive = true`)
- User must have Experience Cloud license

**For Internal Users**:
- User should NOT have ContactId set
- User must be active (`IsActive = true`)

### Phase 2: Permission Set Assignment

#### 5. Assign Client Portal Permission Set
**Required for**: Client users to access portal

**Steps**:
1. Navigate to **Setup > Users > Users**
2. Select a client user (user with ContactId)
3. Click **Permission Set Assignments** related list
4. Click **Edit Assignments**
5. Add **`Client_Project_Management_Portal_User`**
6. Save

**Repeat for all client users who need portal access**

**Verification**: Users should have `Client_Project_Management_Portal_User` assigned

#### 6. Assign Team Member Permission Set
**Required for**: Internal Milestone team members

**Steps**:
1. Navigate to **Setup > Users > Users**
2. Select an internal team member (user without ContactId)
3. Click **Permission Set Assignments** related list
4. Click **Edit Assignments**
5. Add **`Project_Management_Team_Member`**
6. Save

**Repeat for all internal team members**

**Additional Permission Sets** (assign as needed):
- **`Project_Management_User`**: Standard user access
- **`Project_Management_Manager`**: Manager access (can delete records)
- **`Project_Management_Admin`**: Full administrative access (can delete records)

**Verification**: Users should have appropriate permission sets assigned

**See**: [Permission Sets](Permission_Sets.md) for detailed permission set information

### Phase 3: Scheduled Jobs Configuration

#### 7. Schedule Message Notification Scheduler
**Purpose**: Automatically sends email notifications for unread messages

**Schedule**: Every 5-10 minutes (recommended: 10 minutes)

**Apex Anonymous Script**:
```apex
// Schedule MessageNotificationScheduler to run every 10 minutes
// Cron expression: 0 */10 * * * ? (every 10 minutes)
// Alternative: 0 */5 * * * ? (every 5 minutes)

MessageNotificationScheduler scheduler = new MessageNotificationScheduler();
String cronExpression = '0 */10 * * * ?'; // Every 10 minutes
String jobName = 'Message Notification Scheduler';

// Check if job already exists and abort it first
List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name = :jobName
];
if (!existingJobs.isEmpty()) {
    System.abortJob(existingJobs[0].Id);
    System.debug('Aborted existing job: ' + existingJobs[0].Id);
}

// Schedule the new job
String jobId = System.schedule(jobName, cronExpression, scheduler);
System.debug('Scheduled job: ' + jobId + ' with expression: ' + cronExpression);
System.debug('Job will run every 10 minutes');
```

**Alternative: Schedule via Setup UI**:
1. Navigate to **Setup > Apex Classes**
2. Find **`MessageNotificationScheduler`**
3. Click **Schedule Apex**
4. Enter **Job Name**: `Message Notification Scheduler`
5. Set **Frequency**: Every 10 minutes
6. Set **Start Date** and **Start Time**
7. Click **Save**

**Verification**:
1. Navigate to **Setup > Scheduled Jobs**
2. Verify **Message Notification Scheduler** appears
3. Check **Status** is "Waiting" or "Executing"
4. Check **Next Scheduled Run** time

**See**: [MessageNotificationScheduler](MessageNotificationScheduler.md) for detailed documentation

#### 8. Schedule OTP Cleanup Scheduler
**Purpose**: Automatically deletes old OTP records to prevent database bloat

**Schedule**: Daily at 2:00 AM (low usage time)

**Apex Anonymous Script**:
```apex
// Schedule OTPCleanupScheduler to run daily at 2 AM
OTPCleanupScheduler scheduler = new OTPCleanupScheduler();
String cronExpression = '0 0 2 * * ?'; // Daily at 2:00 AM
String jobName = 'OTP Cleanup Scheduler';

// Check if job already exists and abort it first
List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name = :jobName
];
if (!existingJobs.isEmpty()) {
    System.abortJob(existingJobs[0].Id);
    System.debug('Aborted existing job: ' + existingJobs[0].Id);
}

// Schedule the new job
String jobId = System.schedule(jobName, cronExpression, scheduler);
System.debug('Scheduled job: ' + jobId + ' with expression: ' + cronExpression);
System.debug('Job will run daily at 2:00 AM');
```

**Verification**:
1. Navigate to **Setup > Scheduled Jobs**
2. Verify **OTP Cleanup Scheduler** appears
3. Check **Status** is "Waiting"
4. Check **Next Scheduled Run** time (should be next 2:00 AM)

**See**: [Portal Login Setup](Portal_Login_Setup.md#otp-cleanup-process) for detailed documentation

### Phase 4: Custom Metadata Configuration

#### 9. Configure OTP Cleanup Retention Period
**Purpose**: Set how long OTP records are retained before deletion

**Default**: 30 days

**Steps**:
1. Navigate to **Setup > Custom Metadata Types**
2. Find **OTP Cleanup Config**
3. Click **Manage Records**
4. Edit **Default Config** (or create a new record)
5. Update **Retention Days** field (e.g., 7, 14, 30, 60 days)
6. Save

**Verification**: Custom metadata record should show updated retention days

**Note**: If no custom metadata is configured, the system defaults to 30 days

### Phase 5: Experience Cloud Site Configuration

#### 10. Verify Experience Cloud Site
**Purpose**: Ensure portal site is properly configured

**Steps**:
1. Navigate to **Setup > Digital Experiences > All Sites**
2. Find **Client - Project Management Portal**
3. Verify site is **Active**
4. Click **Builder** to verify pages are configured
5. Verify **Login Page** uses custom login component

**Verification**: Site should be active and accessible

**See**: [Portal Package Info](Portal_Package_Info.md) for site configuration details

#### 11. Configure Site Guest User Permissions
**Purpose**: Ensure guest user has necessary object/field access

**Steps**:
1. Navigate to **Setup > Digital Experiences > All Sites**
2. Click **Client - Project Management Portal**
3. Click **Administration > Public Access Settings**
4. Verify guest user has read access to necessary objects
5. Adjust permissions as needed

**Verification**: Guest user should have appropriate access

### Phase 6: Testing & Verification

#### 12. Test Portal Login
**Purpose**: Verify OTP login functionality works

**Steps**:
1. Navigate to Experience Cloud site login page
2. Enter email address of a user with `Portal_Access_Enabled__c = true`
3. Verify OTP email is received
4. Enter OTP code
5. Verify successful login

**Verification**: User should be able to log in using OTP

#### 13. Test Message Notifications
**Purpose**: Verify email notifications are sent

**Steps**:
1. Create a test message from client to project manager
2. Wait 5-10 minutes
3. Verify project manager receives email notification
4. Check debug logs for scheduler execution

**Verification**: Email notifications should be sent automatically

#### 14. Verify Scheduled Jobs Are Running
**Purpose**: Ensure schedulers are executing properly

**Steps**:
1. Navigate to **Setup > Scheduled Jobs**
2. Wait for scheduled run time
3. Check **Last Run** timestamp
4. Review debug logs for execution details

**Verification**: Jobs should show recent execution times

#### 15. Run Apex Tests
**Purpose**: Verify all components are working correctly

**Apex Anonymous Script**:
```apex
// Run all test classes
List<ApexTestQueueItem> testQueueItems = new List<ApexTestQueueItem>();

// Add test classes
testQueueItems.add(new ApexTestQueueItem(ApexClassId = [SELECT Id FROM ApexClass WHERE Name = 'MessageNotificationSchedulerTest' LIMIT 1].Id));
testQueueItems.add(new ApexTestQueueItem(ApexClassId = [SELECT Id FROM ApexClass WHERE Name = 'OTPCleanupSchedulerTest' LIMIT 1].Id));
testQueueItems.add(new ApexTestQueueItem(ApexClassId = [SELECT Id FROM ApexClass WHERE Name = 'PortalMessagingControllerTest' LIMIT 1].Id));
testQueueItems.add(new ApexTestQueueItem(ApexClassId = [SELECT Id FROM ApexClass WHERE Name = 'PasswordlessLoginControllerTest' LIMIT 1].Id));

insert testQueueItems;
System.debug('Test execution queued. Check Setup > Apex Test Execution for results.');
```

**Or via CLI**:
```bash
sf apex run test --class-names MessageNotificationSchedulerTest,OTPCleanupSchedulerTest,PortalMessagingControllerTest,PasswordlessLoginControllerTest --target-org <org-alias> --code-coverage
```

**Verification**: All tests should pass with adequate code coverage

## Quick Reference: All Scheduling Scripts

### Message Notification Scheduler (Every 10 minutes)
```apex
MessageNotificationScheduler scheduler = new MessageNotificationScheduler();
String cronExpression = '0 */10 * * * ?';
String jobName = 'Message Notification Scheduler';

List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name = :jobName
];
if (!existingJobs.isEmpty()) {
    System.abortJob(existingJobs[0].Id);
}

String jobId = System.schedule(jobName, cronExpression, scheduler);
System.debug('Scheduled: ' + jobId);
```

### OTP Cleanup Scheduler (Daily at 2 AM)
```apex
OTPCleanupScheduler scheduler = new OTPCleanupScheduler();
String cronExpression = '0 0 2 * * ?';
String jobName = 'OTP Cleanup Scheduler';

List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name 
    FROM CronTrigger 
    WHERE CronJobDetail.Name = :jobName
];
if (!existingJobs.isEmpty()) {
    System.abortJob(existingJobs[0].Id);
}

String jobId = System.schedule(jobName, cronExpression, scheduler);
System.debug('Scheduled: ' + jobId);
```

## Troubleshooting

### Common Issues

#### Portal Login Not Working
- ✅ Verify Platform Cache is enabled
- ✅ Verify Contact has `Portal_Access_Enabled__c = true`
- ✅ Verify Contact.Email matches User.Email
- ✅ Check Email Deliverability settings
- ✅ Review debug logs for OTP generation errors

#### Message Notifications Not Sending
- ✅ Verify MessageNotificationScheduler is scheduled
- ✅ Check Scheduled Jobs for execution status
- ✅ Verify Project Manager email is set on Task
- ✅ Verify Client User email is set on Task
- ✅ Check debug logs for scheduler execution
- ✅ Verify Email Deliverability is set to "All email"

#### OTP Records Not Being Cleaned Up
- ✅ Verify OTPCleanupScheduler is scheduled
- ✅ Check Scheduled Jobs for execution status
- ✅ Verify custom metadata retention period is configured
- ✅ Check debug logs for cleanup execution
- ✅ Manually run cleanup: `OTPCleanupScheduler.cleanupExpiredOTPs();`

#### Permission Errors
- ✅ Verify permission sets are assigned to users
- ✅ Check Field-Level Security (FLS) for custom fields
- ✅ Verify users have appropriate object access
- ✅ Check sharing rules if applicable

## Related Documentation

- **[Portal Package Info](Portal_Package_Info.md)**: Complete package overview
- **[Portal Login Setup](Portal_Login_Setup.md)**: Detailed login configuration
- **[MessageNotificationScheduler](MessageNotificationScheduler.md)**: Notification scheduler details
- **[Permission Sets](Permission_Sets.md)**: Permission set documentation
- **[Permission Set Comparison](Permission_Set_Comparison.md)**: Team Member vs User differences
- **[Manager vs Admin Comparison](Manager_vs_Admin_Comparison.md)**: Manager vs Admin differences

## Maintenance

### Regular Tasks

**Weekly**:
- Review scheduled job execution logs
- Check for any failed email deliveries
- Monitor OTP cleanup execution

**Monthly**:
- Review permission set assignments
- Verify portal access for active users
- Check custom metadata configurations
- Review test coverage

**As Needed**:
- Update retention periods in custom metadata
- Adjust scheduler frequencies
- Add/remove permission set assignments
- Update Experience Cloud site configuration
