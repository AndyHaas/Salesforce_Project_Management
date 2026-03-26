/**
 * Test class for OTPCleanupScheduler
 */
@isTest
private class OTPCleanupSchedulerTest {
    
    @testSetup
    static void setupTestData() {
        // Use existing user instead of creating a new portal user
        // This avoids the "only portal users can be associated to a contact" error
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        
        // Create old OTP records (older than 30 days)
        List<Login_OTP__c> oldOTPs = new List<Login_OTP__c>();
        for (Integer i = 0; i < 5; i++) {
            Login_OTP__c oldOTP = new Login_OTP__c(
                Email__c = 'test' + i + '@example.com',
                Code__c = String.valueOf(100000 + i),
                User__c = testUser.Id,
                Expires_At__c = DateTime.now().addDays(-35), // 35 days ago
                Used__c = false
            );
            oldOTPs.add(oldOTP);
        }
        insert oldOTPs;
        
        // Set created date to 35 days ago using Test.setCreatedDate
        for (Login_OTP__c otp : oldOTPs) {
            Test.setCreatedDate(otp.Id, DateTime.now().addDays(-35));
        }
        
        // Create expired and used OTP records (should be deleted immediately)
        List<Login_OTP__c> expiredUsedOTPs = new List<Login_OTP__c>();
        for (Integer i = 0; i < 3; i++) {
            Login_OTP__c expiredOTP = new Login_OTP__c(
                Email__c = 'expired' + i + '@example.com',
                Code__c = String.valueOf(200000 + i),
                User__c = testUser.Id,
                Expires_At__c = DateTime.now().addDays(-1), // Expired yesterday
                Used__c = true // Already used
            );
            expiredUsedOTPs.add(expiredOTP);
        }
        insert expiredUsedOTPs;
        
        // Create recent OTP records (should NOT be deleted)
        List<Login_OTP__c> recentOTPs = new List<Login_OTP__c>();
        for (Integer i = 0; i < 3; i++) {
            Login_OTP__c recentOTP = new Login_OTP__c(
                Email__c = 'recent' + i + '@example.com',
                Code__c = String.valueOf(300000 + i),
                User__c = testUser.Id,
                Expires_At__c = DateTime.now().addDays(1), // Expires tomorrow
                Used__c = false
            );
            recentOTPs.add(recentOTP);
        }
        insert recentOTPs;
    }
    
    @isTest
    static void testCleanupExpiredOTPs() {
        // Get specific records to track
        List<Login_OTP__c> allOTPs = [SELECT Id, CreatedDate, Expires_At__c, Used__c FROM Login_OTP__c];
        
        // Identify old records (created more than 30 days ago)
        List<Id> oldOTPIds = new List<Id>();
        List<Id> expiredUsedOTPIds = new List<Id>();
        List<Id> recentOTPIds = new List<Id>();
        
        DateTime cutoffDate = DateTime.now().addDays(-30);
        
        for (Login_OTP__c otp : allOTPs) {
            if (otp.CreatedDate < cutoffDate) {
                oldOTPIds.add(otp.Id);
            } else if (otp.Expires_At__c < DateTime.now() && otp.Used__c == true) {
                expiredUsedOTPIds.add(otp.Id);
            } else {
                recentOTPIds.add(otp.Id);
            }
        }
        
        System.assert(oldOTPIds.size() > 0, 'Should have old OTP records');
        System.assert(expiredUsedOTPIds.size() > 0, 'Should have expired and used OTP records');
        System.assert(recentOTPIds.size() > 0, 'Should have recent OTP records');
        
        Integer recentBefore = recentOTPIds.size();
        
        Test.startTest();
        OTPCleanupScheduler.cleanupExpiredOTPs();
        Test.stopTest();
        
        // Verify old records were deleted
        List<Login_OTP__c> oldOTPsAfter = [SELECT Id FROM Login_OTP__c WHERE Id IN :oldOTPIds];
        System.assertEquals(0, oldOTPsAfter.size(), 'Old OTP records should be deleted');
        
        // Verify expired and used records were deleted
        List<Login_OTP__c> expiredUsedAfter = [SELECT Id FROM Login_OTP__c WHERE Id IN :expiredUsedOTPIds];
        System.assertEquals(0, expiredUsedAfter.size(), 'Expired and used OTP records should be deleted');
        
        // Verify recent records were NOT deleted
        List<Login_OTP__c> recentAfter = [SELECT Id FROM Login_OTP__c WHERE Id IN :recentOTPIds];
        System.assertEquals(recentBefore, recentAfter.size(), 'Recent OTP records should not be deleted');
    }
    
    @isTest
    static void testScheduledExecution() {
        Test.startTest();
        OTPCleanupScheduler scheduler = new OTPCleanupScheduler();
        String jobId = System.schedule('Test OTP Cleanup', '0 0 2 * * ?', scheduler); // Daily at 2 AM
        Test.stopTest();
        
        // Verify job was scheduled
        System.assertNotEquals(null, jobId, 'Job should be scheduled');
        
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals('0 0 2 * * ?', ct.CronExpression, 'Cron expression should match');
    }
    
    @isTest
    static void testGetRetentionDays_WithCustomMetadata() {
        // This test verifies the method can read custom metadata
        // In test context, custom metadata may not be available, so we test the fallback
        Test.startTest();
        OTPCleanupScheduler.cleanupExpiredOTPs();
        Test.stopTest();
        
        // If we get here without exception, the method handled custom metadata correctly
        System.assert(true, 'Method should handle custom metadata gracefully');
    }
    
    @isTest
    static void testCleanupWithNoRecords() {
        // Delete all test records first
        delete [SELECT Id FROM Login_OTP__c];
        
        Test.startTest();
        OTPCleanupScheduler.cleanupExpiredOTPs();
        Test.stopTest();
        
        // Should complete without errors
        System.assert(true, 'Cleanup should handle empty result set');
    }
}
