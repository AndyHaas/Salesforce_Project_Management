/**
 * @description Scheduled job to check for unread messages from clients
 * and send email notifications to project managers if messages haven't been read within 5 minutes
 */
public class MessageNotificationScheduler implements Schedulable {
    
    // 5 minutes in milliseconds
    private static final Integer NOTIFICATION_DELAY_MINUTES = 5;
    
    /**
     * @description Execute method called by the scheduler
     * @param ctx SchedulableContext
     */
    public void execute(SchedulableContext ctx) {
        checkAndSendNotifications();
    }
    
    /**
     * @description Check for unread messages from clients and send notifications to project managers
     */
    public static void checkAndSendNotifications() {
        try {
            // Calculate the cutoff time (5 minutes ago)
            DateTime cutoffTime = DateTime.now().addMinutes(-NOTIFICATION_DELAY_MINUTES);
            
            // Find messages that:
            // 1. Were sent by clients (Recipient_Type__c = 'Milestone Team')
            // 2. Are not deleted
            // 3. Haven't been read by Milestone team (Is_Read_By_Milestone_Team__c = false)
            // 4. Were created more than 5 minutes ago
            // 5. Haven't had notification sent yet (PM_Notification_Sent__c = false)
            // 6. Have a related task or project (to identify project manager)
            List<Message__c> unreadMessages = [
                SELECT Id, Name, Body__c, CreatedDate, Sender__r.Name, Sender__r.Email,
                       Related_Task__c, Related_Task__r.Project_Manager__c, Related_Task__r.Project_Manager__r.Name,
                       Related_Task__r.Project_Manager__r.Email, Related_Task__r.Name,
                       Related_Project__c, Related_Project__r.Name, Related_Project__r.Account__r.Name,
                       Account__c, Account__r.Name
                FROM Message__c
                WHERE Recipient_Type__c = 'Milestone Team'
                AND Deleted__c = false
                AND Is_Read_By_Milestone_Team__c = false
                AND CreatedDate < :cutoffTime
                AND PM_Notification_Sent__c = false
                AND (Related_Task__c != null OR Related_Project__c != null)
                WITH SECURITY_ENFORCED
                LIMIT 200
            ];
            
            if (unreadMessages.isEmpty()) {
                System.debug('MessageNotificationScheduler: No unread messages found that need notifications');
                return;
            }
            
            System.debug('MessageNotificationScheduler: Found ' + unreadMessages.size() + ' unread messages to process');
            
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            List<Message__c> messagesToUpdate = new List<Message__c>();
            
            for (Message__c msg : unreadMessages) {
                // Try to get project manager from task first, then project
                Id projectManagerContactId = null;
                String projectManagerName = null;
                String projectManagerEmail = null;
                String contextName = null;
                
                if (msg.Related_Task__c != null && msg.Related_Task__r != null) {
                    projectManagerContactId = msg.Related_Task__r.Project_Manager__c;
                    if (msg.Related_Task__r.Project_Manager__r != null) {
                        projectManagerName = msg.Related_Task__r.Project_Manager__r.Name;
                        projectManagerEmail = msg.Related_Task__r.Project_Manager__r.Email;
                    }
                    contextName = msg.Related_Task__r.Name;
                }
                
                // If no project manager from task, we can't send notification
                // (Project__c doesn't have a Project_Manager field, only tasks do)
                if (projectManagerContactId == null || String.isBlank(projectManagerEmail)) {
                    System.debug('MessageNotificationScheduler: Message ' + msg.Id + ' has no project manager with email, skipping');
                    // Mark as sent anyway to avoid checking repeatedly
                    msg.PM_Notification_Sent__c = true;
                    messagesToUpdate.add(msg);
                    continue;
                }
                
                // Build email subject
                String subject = 'Unread Message from Client';
                if (msg.Related_Project__r != null) {
                    subject += ' - ' + msg.Related_Project__r.Name;
                }
                if (contextName != null) {
                    subject += ' - ' + contextName;
                }
                
                // Build email body (strip HTML for plain text)
                String plainTextBody = msg.Body__c != null ? msg.Body__c.replaceAll('<[^>]+>', '') : '';
                if (plainTextBody.length() > 500) {
                    plainTextBody = plainTextBody.substring(0, 500) + '...';
                }
                
                // Build context information
                String contextInfo = '';
                if (msg.Related_Task__r != null && msg.Related_Task__r.Name != null) {
                    contextInfo = 'Task: ' + msg.Related_Task__r.Name;
                } else if (msg.Related_Project__r != null && msg.Related_Project__r.Name != null) {
                    contextInfo = 'Project: ' + msg.Related_Project__r.Name;
                } else if (msg.Account__r != null && msg.Account__r.Name != null) {
                    contextInfo = 'Account: ' + msg.Account__r.Name;
                }
                
                // Create email
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setTargetObjectId(projectManagerContactId);
                email.setSaveAsActivity(false);
                email.setSubject(subject);
                email.setPlainTextBody(
                    'Hello ' + projectManagerName + ',\n\n' +
                    'You have an unread message from ' + msg.Sender__r.Name + 
                    (msg.Sender__r.Email != null ? ' (' + msg.Sender__r.Email + ')' : '') + '.\n\n' +
                    (String.isNotBlank(contextInfo) ? contextInfo + '\n\n' : '') +
                    'Message:\n' + plainTextBody + '\n\n' +
                    'This message was sent ' + getTimeAgo(msg.CreatedDate) + ' and has not been read yet.\n\n' +
                    'Please log into the portal to view and respond to the full message.\n\n' +
                    'Thank you,\n' +
                    'Project Management Portal'
                );
                emails.add(email);
                
                // Mark message as notification sent
                msg.PM_Notification_Sent__c = true;
                messagesToUpdate.add(msg);
            }
            
            // Send emails
            if (!emails.isEmpty()) {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emails);
                Integer successCount = 0;
                Integer failCount = 0;
                
                for (Messaging.SendEmailResult result : results) {
                    if (result.isSuccess()) {
                        successCount++;
                    } else {
                        failCount++;
                        System.debug('MessageNotificationScheduler: Email send failed: ' + result.getErrors());
                    }
                }
                
                System.debug('MessageNotificationScheduler: Sent ' + successCount + ' emails, ' + failCount + ' failed');
            }
            
            // Update messages to mark notifications as sent
            if (!messagesToUpdate.isEmpty()) {
                update messagesToUpdate;
                System.debug('MessageNotificationScheduler: Updated ' + messagesToUpdate.size() + ' messages');
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'MessageNotificationScheduler: Error in checkAndSendNotifications: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * @description Get human-readable time ago string
     * @param createdDate The message creation date
     * @return Time ago string (e.g., "5 minutes ago")
     */
    private static String getTimeAgo(DateTime createdDate) {
        if (createdDate == null) {
            return 'recently';
        }
        
        Long minutesAgo = (DateTime.now().getTime() - createdDate.getTime()) / (1000 * 60);
        
        if (minutesAgo < 1) {
            return 'just now';
        } else if (minutesAgo == 1) {
            return '1 minute ago';
        } else if (minutesAgo < 60) {
            return minutesAgo + ' minutes ago';
        } else {
            Long hoursAgo = minutesAgo / 60;
            if (hoursAgo == 1) {
                return '1 hour ago';
            } else if (hoursAgo < 24) {
                return hoursAgo + ' hours ago';
            } else {
                Long daysAgo = hoursAgo / 24;
                if (daysAgo == 1) {
                    return '1 day ago';
                } else {
                    return daysAgo + ' days ago';
                }
            }
        }
    }
}
