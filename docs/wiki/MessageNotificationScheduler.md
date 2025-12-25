# MessageNotificationScheduler

## Overview

**Location**: `force-app/portal/main/default/classes/Portal/MessageNotificationScheduler.cls`

The `MessageNotificationScheduler` is a scheduled Apex class that automatically sends email notifications for unread messages in the Portal Messaging system. It checks for messages that have been unread for more than 5 minutes and sends notifications to the appropriate recipients.

## Purpose

The scheduler provides automated email notifications to ensure timely communication:

1. **Project Manager Notifications**: When a client sends a message to the Milestone Team and it remains unread for 5+ minutes, the assigned project manager receives an email notification.

2. **Client User Notifications**: When a Milestone team member sends a message to a Client and it remains unread for 5+ minutes, the assigned client user receives an email notification.

## Key Features

- **Automatic Email Notifications**: Sends emails after 5-minute delay for unread messages
- **Dual Notification Types**: Handles both PM and Client user notifications
- **Validation**: Ensures recipients exist and have email addresses before sending
- **Duplicate Prevention**: Marks messages as notification sent to prevent repeated emails
- **Error Handling**: Comprehensive error handling with debug logging

## Sharing Model

`without sharing` - Allows the scheduler to update Message__c records regardless of sharing rules, ensuring notifications are sent even if the running user doesn't have direct access to all messages.

## Configuration

### Notification Delay

The notification delay is configured as a constant:

```apex
private static final Integer NOTIFICATION_DELAY_MINUTES = 5;
```

This can be modified in the class if a different delay is needed.

## Methods

### execute(SchedulableContext ctx)

**Purpose**: Entry point for the scheduled job execution.

**Implementation**: Calls `checkAndSendNotifications()` to process all notifications.

**Usage**: This method is called automatically by Salesforce when the scheduled job runs.

### checkAndSendNotifications()

**Purpose**: Main method that orchestrates notification checking and sending.

**Implementation**:
1. Calls `checkAndSendPMNotifications()` to handle project manager notifications
2. Calls `checkAndSendClientNotifications()` to handle client user notifications

**Usage**: Can be called manually for testing or one-time execution.

### checkAndSendPMNotifications()

**Purpose**: Checks for unread messages from clients and sends notifications to project managers.

**Query Criteria**:
- `Recipient_Type__c = 'Milestone Team'`
- `Deleted__c = false`
- `Is_Read_By_Milestone_Team__c = false`
- `CreatedDate < (now - 5 minutes)`
- `PM_Notification_Sent__c = false`
- `Related_Task__c != null` (required to identify project manager)

**Validation**:
- Project manager must be set on the related task
- Project manager must have an email address
- If validation fails, message is marked as `PM_Notification_Sent__c = true` to prevent repeated checks

**Email Content**:
- Subject: "Unread Message from Client - [Project Name] - [Task Name]"
- Body includes:
  - Greeting with project manager name
  - Sender information
  - Context (Task/Project/Account)
  - Message preview (first 500 characters, HTML stripped)
  - Time ago information
  - Link to portal

### checkAndSendClientNotifications()

**Purpose**: Checks for unread messages sent to clients and sends notifications to client users.

**Query Criteria**:
- `Recipient_Type__c = 'Client'`
- `Deleted__c = false`
- `Is_Read_By_Client__c = false`
- `CreatedDate < (now - 5 minutes)`
- `Client_Notification_Sent__c = false`
- `Related_Task__c != null` (required to identify client user)

**Validation**:
- Client user must be set on the related task (`Client_User__c`)
- Client user must have an email address
- If validation fails, message is marked as `Client_Notification_Sent__c = true` to prevent repeated checks

**Email Content**:
- Subject: "Unread Message from Milestone Team - [Project Name] - [Task Name]"
- Body includes:
  - Greeting with client user name
  - Sender information
  - Context (Task/Project/Account)
  - Message preview (first 500 characters, HTML stripped)
  - Time ago information
  - Link to portal

### getTimeAgo(DateTime createdDate)

**Purpose**: Helper method to format human-readable time differences.

**Returns**: String like "5 minutes ago", "1 hour ago", "2 days ago", etc.

**Usage**: Used in email body to show when the message was sent.

## Scheduling the Job

The scheduler must be manually scheduled after deployment. It does not automatically start.

### Option 1: Using Apex Anonymous Script (Recommended)

Execute the following script in **Developer Console > Debug > Open Execute Anonymous Window** or via Salesforce CLI:

```apex
// Schedule MessageNotificationScheduler to run every 10 minutes
// Cron expression format: Second Minute Hour Day_of_month Month Day_of_week Year
// This example runs every 10 minutes: 0 */10 * * * ?
// For every 5 minutes: 0 */5 * * * ?

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
```

### Option 2: Using Salesforce Setup UI

1. Navigate to **Setup > Apex Classes**
2. Find `MessageNotificationScheduler`
3. Click **Schedule Apex**
4. Configure:
   - **Job Name**: `Message Notification Scheduler`
   - **Frequency**: Every 10 minutes (or desired interval)
   - **Start Date**: Today
   - **Start Time**: Current time or desired start time
   - **End Date**: Leave blank (runs indefinitely)

### Cron Expression Examples

| Frequency | Cron Expression | Description |
|-----------|----------------|-------------|
| Every 5 minutes | `0 */5 * * * ?` | Runs every 5 minutes |
| Every 10 minutes | `0 */10 * * * ?` | Runs every 10 minutes (recommended) |
| Every 15 minutes | `0 */15 * * * ?` | Runs every 15 minutes |
| Every hour | `0 0 * * * ?` | Runs at the top of every hour |
| Every day at 9 AM | `0 0 9 * * ?` | Runs once daily at 9:00 AM |

**Note**: Running every 5-10 minutes is recommended to ensure timely notifications while not overloading the system.

## Monitoring

### Viewing Scheduled Jobs

To view active scheduled jobs:

1. Navigate to **Setup > Scheduled Jobs**
2. Look for "Message Notification Scheduler"
3. Check **Status**, **Next Scheduled Run**, and **Last Run**

### Debug Logs

The scheduler includes comprehensive debug logging:

- `MessageNotificationScheduler: Found X unread messages to process`
- `MessageNotificationScheduler: Sent X emails, Y failed`
- `MessageNotificationScheduler: Updated X messages`
- Error logs with stack traces for troubleshooting

To view logs:

1. Navigate to **Setup > Debug Logs**
2. Create a trace flag for the user running the scheduled job
3. Set log level to **DEBUG** for `MessageNotificationScheduler`
4. Check logs after the scheduled job runs

### Email Delivery

Email delivery can be monitored:

1. Navigate to **Setup > Email Administration > Deliverability**
2. Ensure "Access to Send Email" is set to "All email"
3. Check **Setup > Email Log Files** for delivery status

## Testing

### Test Class

**Location**: `force-app/portal/main/default/classes/Portal/MessageNotificationSchedulerTest.cls`

**Coverage**: Comprehensive test coverage including:

- `testCheckAndSendNotifications()`: Tests PM notification flow
- `testScheduledExecution()`: Tests scheduler can be scheduled
- `testMessageWithoutProjectManager()`: Tests validation when PM is missing
- `testClientNotification()`: Tests client user notification flow
- `testClientNotification_NoClientUser()`: Tests validation when client user is missing
- `testClientNotification_NoEmail()`: Tests validation when client user has no email

**Running Tests**:

```bash
sf apex run test --class-names MessageNotificationSchedulerTest --target-org <org-alias>
```

### Manual Testing

To manually test the scheduler:

1. Create test messages that meet the criteria (unread, older than 5 minutes)
2. Execute the scheduler manually:
   ```apex
   MessageNotificationScheduler.checkAndSendNotifications();
   ```
3. Verify emails are sent and messages are marked as notification sent

## Custom Fields

The scheduler uses the following custom fields on `Message__c`:

- `Is_Read_By_Milestone_Team__c`: Boolean - Tracks if message read by Milestone team
- `Is_Read_By_Client__c`: Boolean - Tracks if message read by client
- `PM_Notification_Sent__c`: Boolean - Tracks if PM notification sent
- `Client_Notification_Sent__c`: Boolean - Tracks if client notification sent

## Dependencies

### Required Relationships

- `Message__c.Related_Task__c` → `Project_Task__c` (required for both notification types)
- `Project_Task__c.Project_Manager__c` → `Contact` (required for PM notifications)
- `Project_Task__c.Client_User__c` → `Contact` (required for client notifications)

### Required Fields

- `Contact.Email`: Required on both project manager and client user contacts

## Troubleshooting

| Issue | Likely Cause | Resolution |
|-------|--------------|------------|
| No notifications sent | Job not scheduled | Schedule the job using Apex anonymous script or Setup UI |
| Emails not delivered | Email deliverability settings | Check Setup > Email Administration > Deliverability |
| Notifications sent multiple times | Job scheduled multiple times | Check Scheduled Jobs, abort duplicate jobs |
| PM notifications not sent | Project manager not set on task | Ensure `Project_Manager__c` is populated on related task |
| Client notifications not sent | Client user not set on task | Ensure `Client_User__c` is populated on related task |
| No email address error | Contact missing email | Ensure `Contact.Email` is populated for PM and client user |
| Messages not found | CreatedDate not set correctly in tests | Use `Test.setCreatedDate()` in test classes |

## Best Practices

1. **Schedule Frequency**: Run every 5-10 minutes for timely notifications without overloading the system
2. **Monitor Logs**: Regularly check debug logs for errors or issues
3. **Email Deliverability**: Ensure email deliverability is configured correctly
4. **Test Coverage**: Maintain high test coverage for reliability
5. **Error Handling**: The scheduler includes comprehensive error handling - monitor logs for any exceptions

## Related Documentation

- **[Portal Messaging System](Portal_Messaging_System.md)**: Overview of the messaging system
- **[PortalMessagingController](PortalMessagingController.md)**: Main messaging controller
- **[Permission Sets](Permission_Sets.md)**: Permission set configuration

## Related Files

### Apex Classes
- `force-app/portal/main/default/classes/Portal/MessageNotificationScheduler.cls`
- `force-app/portal/main/default/classes/Portal/MessageNotificationSchedulerTest.cls`

### Custom Fields
- `force-app/main/default/objects/Message__c/fields/PM_Notification_Sent__c.field-meta.xml`
- `force-app/main/default/objects/Message__c/fields/Client_Notification_Sent__c.field-meta.xml`
- `force-app/main/default/objects/Message__c/fields/Is_Read_By_Milestone_Team__c.field-meta.xml`
- `force-app/main/default/objects/Message__c/fields/Is_Read_By_Client__c.field-meta.xml`
