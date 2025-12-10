/**
 * Controller for Custom Email OTP Passwordless Login
 * This uses a custom OTP flow stored in Login_OTP__c custom object
 * Compatible with External Apps Login license users
 */
public without sharing class PasswordlessLoginController {
    
    // OTP expiration time in minutes
    private static final Integer OTP_EXPIRATION_MINUTES = 10;
    
    // Start URL for redirect after successful login (home page)
    private static final String DEFAULT_START_URL = '/';
    
    /**
     * Initiates passwordless login by generating and sending OTP via email
     * @param email The email address of the user
     * @return PasswordlessLoginResult containing success status and message
     */
    @AuraEnabled(cacheable=false)
    public static PasswordlessLoginResult startPasswordlessLogin(String email) {
        PasswordlessLoginResult result = new PasswordlessLoginResult();
        result.success = false;
        result.message = '';
        
        try {
            // Validate inputs
            if (String.isBlank(email)) {
                throw new AuraHandledException('Email address is required.');
            }
            
            // Normalize email
            email = email.trim().toLowerCase();
            
            // First, find the Contact by email
            List<Contact> contacts = [
                SELECT Id, Email, Portal_Access_Enabled__c, AccountId, FirstName, LastName
                FROM Contact
                WHERE Email = :email
                AND Portal_Access_Enabled__c = true
                LIMIT 1
            ];
            
            if (contacts.isEmpty()) {
                // Don't reveal user existence - security best practice
                System.debug('PasswordlessLogin: No active contact found for email: ' + email);
                throw new AuraHandledException('If an account exists with this email, a verification code will be sent.');
            }
            
            Contact contact = contacts[0];
            
            // Now find the User by ContactId
            List<User> users = [
                SELECT Id, Username, Email, IsActive, ContactId
                FROM User
                WHERE ContactId = :contact.Id
                AND IsActive = true
                LIMIT 1
            ];
            
            if (users.isEmpty()) {
                // Don't reveal user existence - security best practice
                System.debug('PasswordlessLogin: No active user found for contact: ' + contact.Id);
                throw new AuraHandledException('If an account exists with this email, a verification code will be sent.');
            }
            
            User targetUser = users[0];
            
            if (!targetUser.IsActive) {
                System.debug('PasswordlessLogin: User is not active: ' + targetUser.Id);
                throw new AuraHandledException('If an account exists with this email, a verification code will be sent.');
            }
            
            System.debug('PasswordlessLogin: Found user - Id: ' + targetUser.Id + ', Username: ' + targetUser.Username);
            
            // Generate 6-digit OTP
            String otpCode = generateOTP();
            
            // Store OTP in custom object
            Login_OTP__c loginOTP = new Login_OTP__c();
            loginOTP.Email__c = email;
            loginOTP.Code__c = otpCode;
            loginOTP.User__c = targetUser.Id;
            loginOTP.Expires_At__c = DateTime.now().addMinutes(OTP_EXPIRATION_MINUTES);
            loginOTP.Used__c = false;
            
            insert loginOTP;
            System.debug('PasswordlessLogin: OTP stored in Login_OTP__c: ' + loginOTP.Id);
            
            // Send email with OTP
            try {
                sendOTPEmail(contact, otpCode);
                System.debug('PasswordlessLogin: OTP email sent successfully to: ' + contact.Email);
            } catch (Exception emailException) {
                System.debug('PasswordlessLogin: Error sending email - ' + emailException.getMessage());
                System.debug('PasswordlessLogin: Error type: ' + emailException.getTypeName());
                System.debug('PasswordlessLogin: Stack trace: ' + emailException.getStackTraceString());
                
                // Delete the OTP record if email fails
                try {
                    delete loginOTP;
                } catch (Exception deleteException) {
                    System.debug('PasswordlessLogin: Error deleting OTP after email failure: ' + deleteException.getMessage());
                }
                
                // Provide more specific error message
                String errorMsg = 'Failed to send verification code. ';
                if (emailException.getMessage().contains('INVALID_EMAIL_ADDRESS')) {
                    errorMsg += 'Invalid email address.';
                } else if (emailException.getMessage().contains('EMAIL_EXCEPTION')) {
                    errorMsg += 'Email delivery failed. Please check your email settings or contact support.';
                } else {
                    errorMsg += 'Please try again or contact support.';
                }
                throw new AuraHandledException(errorMsg);
            }
            
            // Success
            result.success = true;
            result.message = 'A verification code has been sent to your email address.';
            result.userId = targetUser.Id; // Store for verification step
            result.identifier = loginOTP.Id; // Store OTP record ID for verification
            
            // In sandbox, return the OTP code for testing purposes
            result.isSandbox = isSandboxOrg();
            if (result.isSandbox) {
                result.otpCode = otpCode;
                System.debug('PasswordlessLogin: Sandbox detected - OTP code returned: ' + otpCode);
            }
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is to preserve user-friendly messages
            System.debug('PasswordlessLogin: AuraHandledException - ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug('PasswordlessLogin: Unexpected error in startPasswordlessLogin: ' + e.getMessage());
            System.debug('PasswordlessLogin: Error type: ' + e.getTypeName());
            System.debug('PasswordlessLogin: Stack trace: ' + e.getStackTraceString());
            
            // Don't expose internal error details to users
            throw new AuraHandledException('An error occurred while starting passwordless login. Please try again or contact support.');
        }
        
        return result;
    }
    
    /**
     * Verifies the OTP code and completes passwordless login
     * @param userId The User ID from the start step
     * @param identifier The Login_OTP__c record ID from the start step
     * @param otpCode The OTP code entered by the user
     * @return PasswordlessLoginResult containing status and redirect URL
     */
    @AuraEnabled(cacheable=false)
    public static PasswordlessLoginResult verifyPasswordlessLogin(Id userId, String identifier, String otpCode) {
        PasswordlessLoginResult result = new PasswordlessLoginResult();
        result.success = false;
        result.message = '';
        result.isSandbox = isSandboxOrg();
        
        try {
            // Validate inputs
            if (String.isBlank(userId)) {
                throw new AuraHandledException('User identifier is required. Please start over.');
            }
            
            if (String.isBlank(identifier)) {
                throw new AuraHandledException('Verification session identifier is required. Please start over.');
            }
            
            if (String.isBlank(otpCode)) {
                throw new AuraHandledException('Verification code is required.');
            }
            
            // Normalize OTP code (remove spaces)
            otpCode = otpCode.trim();
            
            // Verify the user exists and is active
            List<User> users = [
                SELECT Id, Username, IsActive
                FROM User
                WHERE Id = :userId
                AND IsActive = true
                LIMIT 1
            ];
            
            if (users.isEmpty()) {
                System.debug('PasswordlessLogin: User not found or inactive: ' + userId);
                throw new AuraHandledException('Invalid user session. Please start over.');
            }
            
            User targetUser = users[0];
            
            // Retrieve and verify OTP from custom object
            List<Login_OTP__c> otpRecords = [
                SELECT Id, Email__c, Code__c, Expires_At__c, Used__c, User__c
                FROM Login_OTP__c
                WHERE Id = :identifier
                AND User__c = :userId
                LIMIT 1
            ];
            
            if (otpRecords.isEmpty()) {
                System.debug('PasswordlessLogin: OTP record not found: ' + identifier);
                throw new AuraHandledException('Invalid or expired verification code. Please request a new code.');
            }
            
            Login_OTP__c otpRecord = otpRecords[0];
            
            // Check if OTP has been used
            if (otpRecord.Used__c) {
                System.debug('PasswordlessLogin: OTP already used: ' + identifier);
                throw new AuraHandledException('This verification code has already been used. Please request a new code.');
            }
            
            // Check if OTP has expired
            if (otpRecord.Expires_At__c < DateTime.now()) {
                System.debug('PasswordlessLogin: OTP expired: ' + identifier);
                throw new AuraHandledException('Verification code has expired. Please request a new code.');
            }
            
            // Verify OTP code matches
            if (!otpRecord.Code__c.equals(otpCode)) {
                System.debug('PasswordlessLogin: OTP code mismatch');
                throw new AuraHandledException('Invalid verification code. Please check and try again.');
            }
            
            // Mark OTP as used
            otpRecord.Used__c = true;
            update otpRecord;
            
            // Generate a secure temporary password for authentication
            String tempPassword = generateSecurePassword();
            
            // Set the temporary password for the user
            try {
                System.setPassword(targetUser.Id, tempPassword);
                System.debug('PasswordlessLogin: Temporary password set for user: ' + targetUser.Username);
            } catch (Exception passwordException) {
                System.debug('PasswordlessLogin: Error setting password - ' + passwordException.getMessage());
                throw new AuraHandledException('Unable to authenticate. Please contact support.');
            }
            
            // Use Site.login() to authenticate and create a session
            // This returns a PageReference with the redirect URL
            PageReference loginResult = Site.login(targetUser.Username, tempPassword, DEFAULT_START_URL);
            
            if (loginResult != null) {
                // Login successful - return the redirect URL
                result.success = true;
                result.message = 'Verification successful. Logging you in...';
                
                // Get the redirect URL and ensure it goes to home page without /s path
                result.redirectUrl = normalizeRedirectUrl(loginResult.getUrl());
                System.debug('PasswordlessLogin: Successfully authenticated user: ' + targetUser.Id);
                System.debug('PasswordlessLogin: Redirect URL: ' + result.redirectUrl);
            } else {
                // Login failed
                System.debug('PasswordlessLogin: Site.login() returned null');
                throw new AuraHandledException('Login failed. Please try again.');
            }
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is to preserve user-friendly messages
            System.debug('PasswordlessLogin: AuraHandledException - ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug('PasswordlessLogin: Unexpected error in verifyPasswordlessLogin: ' + e.getMessage());
            System.debug('PasswordlessLogin: Error type: ' + e.getTypeName());
            System.debug('PasswordlessLogin: Stack trace: ' + e.getStackTraceString());
            
            // Don't expose internal error details to users
            throw new AuraHandledException('An error occurred while verifying the code. Please try again or contact support.');
        }
        
        return result;
    }
    
    /**
     * Checks if the current org is a sandbox
     * @return true if sandbox, false otherwise
     */
    private static Boolean isSandboxOrg() {
        try {
            Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
            return org.IsSandbox;
        } catch (Exception e) {
            System.debug('PasswordlessLogin: Could not determine sandbox status: ' + e.getMessage());
            return false; // Fail safe - assume production
        }
    }
    
    /**
     * Normalizes the redirect URL to ensure it goes to home page without /s path
     * @param redirectUrl The URL from Site.login()
     * @return Normalized URL (always starts with /)
     */
    private static String normalizeRedirectUrl(String redirectUrl) {
        if (String.isBlank(redirectUrl)) {
            return DEFAULT_START_URL;
        }
        
        // Remove /s/ prefix if present
        if (redirectUrl.startsWith('/s/')) {
            redirectUrl = redirectUrl.substring(3); // Remove '/s/'
        } else if (redirectUrl.equals('/s') || redirectUrl.equals('/s/')) {
            return DEFAULT_START_URL;
        }
        
        // Ensure it starts with /
        if (!redirectUrl.startsWith('/')) {
            redirectUrl = '/' + redirectUrl;
        }
        
        return redirectUrl;
    }
    
    /**
     * Generates a random 6-digit OTP code
     */
    private static String generateOTP() {
        Integer otp = Integer.valueOf(Math.random() * 900000) + 100000;
        return String.valueOf(otp);
    }
    
    /**
     * Validates email send result and throws exception if failed
     * @param results The Messaging.SendEmailResult array
     * @param contact The contact the email was sent to
     */
    private static void validateEmailSendResult(Messaging.SendEmailResult[] results, Contact contact) {
        if (results == null || results.isEmpty()) {
            System.debug('PasswordlessLogin: Email send returned null results');
            throw new AuraHandledException('Email send returned no results. Please check your email settings.');
        }
        
        Messaging.SendEmailResult sendResult = results[0];
        if (!sendResult.isSuccess()) {
            logEmailErrors(sendResult);
            String errorMsg = buildEmailErrorMessage(sendResult);
            throw new AuraHandledException(errorMsg);
        }
        
        System.debug('PasswordlessLogin: Email sent successfully to: ' + contact.Email);
        System.debug('PasswordlessLogin: Email target object ID: ' + contact.Id);
    }
    
    /**
     * Logs all email send errors for debugging
     * @param sendResult The Messaging.SendEmailResult
     */
    private static void logEmailErrors(Messaging.SendEmailResult sendResult) {
        System.debug('PasswordlessLogin: Email send failed');
        System.debug('PasswordlessLogin: Error status code: ' + sendResult.getErrors());
        
        for (Messaging.SendEmailError error : sendResult.getErrors()) {
            System.debug('PasswordlessLogin: Email error - Status: ' + error.getStatusCode() + 
                        ', Message: ' + error.getMessage() + ', Fields: ' + error.getFields());
        }
    }
    
    /**
     * Builds a user-friendly error message from email send result
     * @param sendResult The Messaging.SendEmailResult
     * @return Error message string
     */
    private static String buildEmailErrorMessage(Messaging.SendEmailResult sendResult) {
        String errorMsg = 'Email delivery failed. ';
        if (sendResult != null && !sendResult.getErrors().isEmpty()) {
            String firstError = sendResult.getErrors()[0].getMessage();
            if (String.isNotBlank(firstError)) {
                errorMsg += firstError;
            } else {
                errorMsg += 'Please check your email settings or contact support.';
            }
        } else {
            errorMsg += 'Please check your email settings or contact support.';
        }
        return errorMsg;
    }
    
    /**
     * Generates a secure temporary password for passwordless login
     * Password must meet Salesforce requirements: at least 8 characters,
     * contain letters and numbers
     */
    private static String generateSecurePassword() {
        // Generate a secure random password using crypto-secure random generation
        Blob randomBlob = Crypto.generateAesKey(256);
        String hexString = EncodingUtil.convertToHex(randomBlob);
        
        // Take first 12 characters (hex contains both letters and numbers, so this meets requirements)
        return hexString.substring(0, 12);
    }
    
    /**
     * Sends OTP email to the contact
     * Uses setTargetObjectId for better deliverability in Experience Cloud
     */
    private static void sendOTPEmail(Contact contact, String otpCode) {
        // Validate email address
        if (String.isBlank(contact.Email)) {
            throw new AuraHandledException('Contact email address is missing.');
        }
        
        if (contact.Id == null) {
            throw new AuraHandledException('Contact ID is missing.');
        }
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        // Use setTargetObjectId for better deliverability in Experience Cloud
        // This ensures emails respect org email settings and deliverability
        // Note: Cannot use both setTargetObjectId and setToAddresses together
        email.setTargetObjectId(contact.Id);
        email.setSaveAsActivity(false); // Don't create an activity record
        
        email.setSubject('Your Portal Login Verification Code');
        email.setPlainTextBody(
            'Hello ' + (contact.FirstName != null ? contact.FirstName : '') + ',\n\n' +
            'Your verification code for the Project Management Portal is: ' + otpCode + '\n\n' +
            'This code will expire in ' + OTP_EXPIRATION_MINUTES + ' minutes.\n\n' +
            'If you did not request this code, please ignore this email.\n\n' +
            'Thank you,\n' +
            'Project Management Portal'
        );
        email.setHtmlBody(
            '<p>Hello ' + (contact.FirstName != null ? contact.FirstName : '') + ',</p>' +
            '<p>Your verification code for the Project Management Portal is: <strong style="font-size: 18px;">' + otpCode + '</strong></p>' +
            '<p>This code will expire in ' + OTP_EXPIRATION_MINUTES + ' minutes.</p>' +
            '<p>If you did not request this code, please ignore this email.</p>' +
            '<p>Thank you,<br/>Project Management Portal</p>'
        );
        
        // Try to set org-wide email address if available
        try {
            List<OrgWideEmailAddress> orgWideEmails = [
                SELECT Id, Address, DisplayName 
                FROM OrgWideEmailAddress 
                WHERE IsAllowAllProfiles = true 
                LIMIT 1
            ];
            if (!orgWideEmails.isEmpty()) {
                email.setOrgWideEmailAddressId(orgWideEmails[0].Id);
                System.debug('PasswordlessLogin: Using org-wide email address: ' + orgWideEmails[0].Address);
            } else {
                System.debug('PasswordlessLogin: No org-wide email address found, using default sender');
            }
        } catch (Exception e) {
            System.debug('PasswordlessLogin: Could not set org-wide email address: ' + e.getMessage());
        }
        
        // Send email and check results
        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
        validateEmailSendResult(results, contact);
    }
    
    /**
     * Wrapper class for passwordless login results
     */
    public class PasswordlessLoginResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id userId; // User ID to use in verification step
        @AuraEnabled public String identifier; // Login_OTP__c record ID from start step
        @AuraEnabled public String redirectUrl; // URL to redirect to after successful login
        @AuraEnabled public String otpCode; // OTP code (only returned in sandbox for testing)
        @AuraEnabled public Boolean isSandbox; // Indicates if the org is a sandbox
    }
}
