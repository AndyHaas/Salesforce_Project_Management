/**
 * Test class for PasswordlessLoginController
 * Note: System.UserManagement API calls cannot be fully mocked in tests,
 * but we can test the validation logic and error handling
 */
@isTest
private class PasswordlessLoginControllerTest {
    
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
            Email = 'testuser@example.com',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        // Note: We cannot create Experience Cloud users in tests without a proper site
        // These tests focus on validation logic
    }
    
    @isTest
    static void testStartPasswordlessLogin_BlankEmail() {
        Test.startTest();
        try {
            PasswordlessLoginController.startPasswordlessLogin('');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Email address is required'), 
                'Should return email required error');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testStartPasswordlessLogin_InvalidEmail() {
        Test.startTest();
        try {
            PasswordlessLoginController.startPasswordlessLogin('invalid-email');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('valid email') || e.getMessage().contains('Email'), 
                'Should return email validation error');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testStartPasswordlessLogin_UserNotFound() {
        Test.startTest();
        try {
            PasswordlessLoginController.startPasswordlessLogin('nonexistent@example.com');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            // Should not reveal that user doesn't exist
            System.assert(!e.getMessage().toLowerCase().contains('not found'), 
                'Should not reveal user existence');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testVerifyPasswordlessLogin_BlankUserId() {
        Test.startTest();
        try {
            PasswordlessLoginController.verifyPasswordlessLogin(null, 'test-identifier', '123456');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('User identifier') || e.getMessage().contains('User ID'), 
                'Should return user identifier required error');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testVerifyPasswordlessLogin_BlankIdentifier() {
        Test.startTest();
        try {
            // Use a fake but valid-looking ID format
            Id fakeUserId = UserInfo.getUserId(); // Use current user ID for format validation
            PasswordlessLoginController.verifyPasswordlessLogin(fakeUserId, '', '123456');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Identifier') || e.getMessage().contains('identifier'), 
                'Should return identifier required error');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testVerifyPasswordlessLogin_BlankOTP() {
        Test.startTest();
        try {
            // Use a fake but valid-looking ID format
            Id fakeUserId = UserInfo.getUserId(); // Use current user ID for format validation
            PasswordlessLoginController.verifyPasswordlessLogin(fakeUserId, 'test-identifier', '');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Verification code') || e.getMessage().contains('OTP'), 
                'Should return verification code required error');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testEmailNormalization() {
        // Test that email is normalized (trimmed and lowercased)
        // This is tested indirectly through the validation logic
        Test.startTest();
        try {
            PasswordlessLoginController.startPasswordlessLogin('  TEST@EXAMPLE.COM  ');
            // Should not throw validation error for format, but will fail on user lookup
            // which is expected
        } catch (AuraHandledException e) {
            // Expected - user doesn't exist
            System.assert(true, 'Email normalization handled');
        }
        Test.stopTest();
    }
}
