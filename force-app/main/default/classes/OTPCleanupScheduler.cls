/**
 * @description Scheduled job to clean up old Login_OTP__c records
 * Uses custom metadata to configure retention period
 */
public without sharing class OTPCleanupScheduler implements Schedulable {
    
    /**
     * @description Execute method called by the scheduler
     * @param ctx SchedulableContext
     */
    public void execute(SchedulableContext ctx) {
        cleanupExpiredOTPs();
    }
    
    /**
     * @description Clean up expired and old OTP records based on custom metadata configuration
     */
    public static void cleanupExpiredOTPs() {
        try {
            // Get retention period from custom metadata (default to 30 days if not configured)
            Integer retentionDays = getRetentionDays();
            DateTime cutoffDate = DateTime.now().addDays(-retentionDays);
            
            System.debug('OTPCleanupScheduler: Cleaning up OTP records older than ' + retentionDays + ' days (before ' + cutoffDate + ')');
            
            // Find OTP records that are:
            // 1. Older than the retention period, OR
            // 2. Expired and used (safe to delete immediately)
            List<Login_OTP__c> recordsToDelete = [
                SELECT Id
                FROM Login_OTP__c
                WHERE CreatedDate < :cutoffDate
                   OR (Expires_At__c < :DateTime.now() AND Used__c = true)
                WITH SECURITY_ENFORCED
                LIMIT 10000
            ];
            
            if (recordsToDelete.isEmpty()) {
                System.debug('OTPCleanupScheduler: No OTP records found to clean up');
                return;
            }
            
            System.debug('OTPCleanupScheduler: Found ' + recordsToDelete.size() + ' OTP records to delete');
            
            // Delete in batches to avoid governor limits
            List<Database.DeleteResult> deleteResults = Database.delete(recordsToDelete, false);
            
            Integer successCount = 0;
            Integer failCount = 0;
            
            for (Database.DeleteResult result : deleteResults) {
                if (result.isSuccess()) {
                    successCount++;
                } else {
                    failCount++;
                    System.debug('OTPCleanupScheduler: Delete failed for record ' + result.getId() + ': ' + result.getErrors());
                }
            }
            
            System.debug('OTPCleanupScheduler: Deleted ' + successCount + ' OTP records, ' + failCount + ' failed');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OTPCleanupScheduler: Error in cleanupExpiredOTPs: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * @description Get retention days from custom metadata
     * @return Integer Number of days to retain OTP records (default: 30)
     */
    private static Integer getRetentionDays() {
        try {
            // Query custom metadata for retention period
            // Use DeveloperName = 'Default_Config' or get the first record
            List<OTP_Cleanup_Config__mdt> configs = [
                SELECT Retention_Days__c
                FROM OTP_Cleanup_Config__mdt
                WHERE DeveloperName = 'Default_Config'
                LIMIT 1
            ];
            
            if (!configs.isEmpty() && configs[0].Retention_Days__c != null) {
                Integer retentionDays = configs[0].Retention_Days__c.intValue();
                System.debug('OTPCleanupScheduler: Using retention period from custom metadata: ' + retentionDays + ' days');
                return retentionDays;
            }
            
            // Fallback: try to get any config record
            List<OTP_Cleanup_Config__mdt> anyConfigs = [
                SELECT Retention_Days__c
                FROM OTP_Cleanup_Config__mdt
                LIMIT 1
            ];
            
            if (!anyConfigs.isEmpty() && anyConfigs[0].Retention_Days__c != null) {
                Integer retentionDays = anyConfigs[0].Retention_Days__c.intValue();
                System.debug('OTPCleanupScheduler: Using retention period from first config: ' + retentionDays + ' days');
                return retentionDays;
            }
            
            // Default to 30 days if no custom metadata found
            System.debug('OTPCleanupScheduler: No custom metadata found, using default retention: 30 days');
            return 30;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OTPCleanupScheduler: Error reading custom metadata, using default: ' + e.getMessage());
            return 30; // Default to 30 days on error
        }
    }
}
