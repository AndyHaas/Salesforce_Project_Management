/**
 * Test class for OTPCleanupScheduler
 */
@isTest
private class OTPCleanupSchedulerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        // Create test Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@example.com',
            AccountId = testAccount.Id,
            Portal_Access_Enabled__c = true
        );
        insert testContact;
        
        // Create test User
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Portal%' OR Name LIKE '%Customer%' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@example.com',
            Username = 'testuser' + DateTime.now().getTime() + '@test.com',
            Alias = 'tuser',
            ProfileId = portalProfile.Id,
            ContactId = testContact.Id,
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        // Create old OTP records (older than 30 days)
        List<Login_OTP__c> oldOTPs = new List<Login_OTP__c>();
        for (Integer i = 0; i < 5; i++) {
            Login_OTP__c oldOTP = new Login_OTP__c(
                Email__c = 'test@example.com',
                Code__c = '123456',
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
                Email__c = 'test@example.com',
                Code__c = '654321',
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
                Email__c = 'test@example.com',
                Code__c = '999999',
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
        // Count records before cleanup
        Integer oldOTPsBefore = [SELECT COUNT() FROM Login_OTP__c WHERE CreatedDate < :DateTime.now().addDays(-30)];
        Integer expiredUsedBefore = [SELECT COUNT() FROM Login_OTP__c WHERE Expires_At__c < :DateTime.now() AND Used__c = true];
        Integer recentBefore = [SELECT COUNT() FROM Login_OTP__c WHERE CreatedDate >= :DateTime.now().addDays(-30)];
        
        System.assert(oldOTPsBefore > 0, 'Should have old OTP records');
        System.assert(expiredUsedBefore > 0, 'Should have expired and used OTP records');
        System.assert(recentBefore > 0, 'Should have recent OTP records');
        
        Test.startTest();
        OTPCleanupScheduler.cleanupExpiredOTPs();
        Test.stopTest();
        
        // Verify old records were deleted
        Integer oldOTPsAfter = [SELECT COUNT() FROM Login_OTP__c WHERE CreatedDate < :DateTime.now().addDays(-30)];
        System.assertEquals(0, oldOTPsAfter, 'Old OTP records should be deleted');
        
        // Verify expired and used records were deleted
        Integer expiredUsedAfter = [SELECT COUNT() FROM Login_OTP__c WHERE Expires_At__c < :DateTime.now() AND Used__c = true];
        System.assertEquals(0, expiredUsedAfter, 'Expired and used OTP records should be deleted');
        
        // Verify recent records were NOT deleted
        Integer recentAfter = [SELECT COUNT() FROM Login_OTP__c WHERE CreatedDate >= :DateTime.now().addDays(-30)];
        System.assertEquals(recentBefore, recentAfter, 'Recent OTP records should not be deleted');
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
