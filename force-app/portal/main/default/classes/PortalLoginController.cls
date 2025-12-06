public without sharing class PortalLoginController {
    
    // OTP expiration time in minutes
    private static final Integer OTP_EXPIRATION_MINUTES = 10;
    
    /**
     * Verifies if a contact with the given email has portal access enabled
     * and sends an OTP email if valid
     * @param email The email address to verify
     * @return LoginVerificationResult containing verification status and message
     */
    @AuraEnabled
    public static LoginVerificationResult verifyEmailAndSendOTP(String email) {
        LoginVerificationResult result = new LoginVerificationResult();
        result.success = false;
        result.message = '';
        
        try {
            if (String.isBlank(email)) {
                result.message = 'Email address is required.';
                return result;
            }
            
            // Normalize email (trim and lowercase)
            email = email.trim().toLowerCase();
            
            // Find contact with matching email
            List<Contact> contacts = [
                SELECT Id, Email, Portal_Access_Enabled__c, AccountId, 
                       Account.Has_Portal_Access_Enabled_Contact__c, FirstName, LastName
                FROM Contact
                WHERE Email = :email
                AND Portal_Access_Enabled__c = true
                LIMIT 1
            ];
            
            if (contacts.isEmpty()) {
                // Don't reveal if email exists - security best practice
                result.message = 'If an account exists with this email, a verification code will be sent.';
                return result;
            }
            
            Contact contact = contacts[0];
            
            // Verify both Contact and Account have portal access enabled
            if (!contact.Portal_Access_Enabled__c) {
                result.message = 'Portal access is not enabled for this contact.';
                return result;
            }
            
            if (contact.AccountId == null) {
                result.message = 'Contact is not associated with an Account.';
                return result;
            }
            
            // Check Account field (we'll query it separately to be safe)
            Account account = [
                SELECT Id, Has_Portal_Access_Enabled_Contact__c
                FROM Account
                WHERE Id = :contact.AccountId
                LIMIT 1
            ];
            
            if (!account.Has_Portal_Access_Enabled_Contact__c) {
                result.message = 'Portal access is not enabled for the associated Account.';
                return result;
            }
            
            // Check if user exists for this contact
            List<User> users = [
                SELECT Id, Username, IsActive
                FROM User
                WHERE ContactId = :contact.Id
                AND IsActive = true
                LIMIT 1
            ];
            
            if (users.isEmpty()) {
                result.message = 'No active user account found for this contact. Please contact your administrator.';
                return result;
            }
            
            // Generate OTP and store it
            String otpCode = generateOTP();
            String verificationId = storeOTP(contact.Id, email, otpCode);
            
            // Check if this is a sandbox org
            Boolean isSandbox = isSandboxOrg();
            
            // Send email with OTP (attempt even in sandbox)
            try {
                sendOTPEmail(contact, otpCode);
            } catch (Exception emailException) {
                // In sandbox, email might fail but we'll show the code anyway
                if (!isSandbox) {
                    throw emailException; // Re-throw in production
                }
                System.debug('Email send failed in sandbox (expected): ' + emailException.getMessage());
            }
            
            result.success = true;
            if (isSandbox) {
                result.message = 'A verification code has been sent to your email address.';
                result.message += ' (Sandbox Mode: Your code is ' + otpCode + ')';
                result.otpCode = otpCode; // Include OTP code for sandbox display
            } else {
                result.message = 'A verification code has been sent to your email address.';
            }
            result.verificationId = verificationId;
            result.isSandbox = isSandbox;
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException to preserve the specific error message
            System.debug('AuraHandledException in verifyEmailAndSendOTP: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug('Error in verifyEmailAndSendOTP: ' + e.getMessage());
            System.debug('Error type: ' + e.getTypeName());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Provide more specific error messages based on exception type
            String errorMessage = 'An error occurred. Please try again or contact support.';
            if (e.getTypeName().contains('QueryException')) {
                errorMessage = 'Database error occurred. Please contact support.';
            } else if (e.getTypeName().contains('EmailException') || e.getMessage().contains('email')) {
                errorMessage = 'Failed to send verification email. Please check your email address and try again.';
            } else if (e.getMessage().contains('Cache')) {
                errorMessage = 'OTP storage is temporarily unavailable. Please try again in a moment.';
            } else if (e.getMessage() != null && !String.isBlank(e.getMessage())) {
                // Include the actual error message if available
                errorMessage = 'Error: ' + e.getMessage();
            }
            
            result.message = errorMessage;
        }
        
        return result;
    }
    
    /**
     * Verifies the OTP code and returns login information
     * Note: Actual login will be handled by redirecting to Salesforce's standard login flow
     * @param email The email address
     * @param otpCode The OTP code entered by the user
     * @param verificationId The verification ID from the initial request
     * @return LoginResult containing login status and username for redirect
     */
    @AuraEnabled
    public static LoginResult verifyOTPAndLogin(String email, String otpCode, String verificationId) {
        LoginResult result = new LoginResult();
        result.success = false;
        result.message = '';
        
        try {
            if (String.isBlank(email) || String.isBlank(otpCode) || String.isBlank(verificationId)) {
                result.message = 'Email, verification code, and verification ID are required.';
                return result;
            }
            
            email = email.trim().toLowerCase();
            
            // Verify OTP
            Boolean otpValid = verifyOTP(verificationId, email, otpCode);
            
            if (!otpValid) {
                result.message = 'Invalid or expired verification code. Please request a new code.';
                return result;
            }
            
            // Find contact
            List<Contact> contacts = [
                SELECT Id, Email, AccountId
                FROM Contact
                WHERE Email = :email
                AND Portal_Access_Enabled__c = true
                LIMIT 1
            ];
            
            if (contacts.isEmpty()) {
                result.message = 'Contact not found.';
                return result;
            }
            
            Contact contact = contacts[0];
            
            // Get user
            List<User> users = [
                SELECT Id, Username
                FROM User
                WHERE ContactId = :contact.Id
                AND IsActive = true
                LIMIT 1
            ];
            
            if (users.isEmpty()) {
                result.message = 'No active user account found.';
                return result;
            }
            
            // Mark OTP as used
            markOTPAsUsed(verificationId);
            
            // For passwordless login, we can use Site.login() if a password reset token is available
            // or redirect to the login page with username pre-filled
            // Note: True passwordless login requires additional setup (Auth.SessionManagement)
            result.success = true;
            result.message = 'Verification successful.';
            result.username = users[0].Username;
            result.userId = users[0].Id;
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException to preserve the specific error message
            System.debug('AuraHandledException in verifyOTPAndLogin: ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug('Error in verifyOTPAndLogin: ' + e.getMessage());
            System.debug('Error type: ' + e.getTypeName());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Provide more specific error messages based on exception type
            String errorMessage = 'An error occurred during login. Please try again.';
            if (e.getTypeName().contains('QueryException')) {
                errorMessage = 'Database error occurred. Please contact support.';
            } else if (e.getMessage().contains('Cache')) {
                errorMessage = 'OTP verification is temporarily unavailable. Please request a new code.';
            } else if (e.getMessage() != null && !String.isBlank(e.getMessage())) {
                // Include the actual error message if available
                errorMessage = 'Error: ' + e.getMessage();
            }
            
            result.message = errorMessage;
        }
        
        return result;
    }
    
    /**
     * Checks if the current org is a sandbox
     */
    private static Boolean isSandboxOrg() {
        try {
            // Check if org name contains common sandbox indicators
            String orgId = UserInfo.getOrganizationId();
            Organization org = [SELECT Id, InstanceName, IsSandbox FROM Organization WHERE Id = :orgId LIMIT 1];
            return org.IsSandbox;
        } catch (Exception e) {
            System.debug('Error checking sandbox status: ' + e.getMessage());
            // Default to false if we can't determine
            return false;
        }
    }
    
    /**
     * Generates a 6-digit OTP code
     */
    private static String generateOTP() {
        Integer otp = Integer.valueOf(Math.random() * 900000) + 100000;
        return String.valueOf(otp);
    }
    
    /**
     * Stores OTP in Platform Cache
     * Falls back to default cache partition if named partition is not available
     */
    private static String storeOTP(String contactId, String email, String otpCode) {
        // Generate a unique verification ID using hex encoding (alphanumeric only)
        // Platform Cache keys must be alphanumeric, so we use hex instead of base64
        Blob cryptoKey = Crypto.generateAesKey(128);
        String hexKey = EncodingUtil.convertToHex(cryptoKey);
        // Add timestamp for uniqueness and ensure at least 32 characters
        String timestampHex = EncodingUtil.convertToHex(Blob.valueOf(String.valueOf(DateTime.now().getTime())));
        String verificationId = (hexKey + timestampHex).substring(0, 32);
        
        Integer ttlSeconds = OTP_EXPIRATION_MINUTES * 60;
        // Platform Cache keys must be alphanumeric - no underscores allowed
        String otpKey = 'portalotp' + verificationId;
        String emailKey = 'portalemail' + verificationId;
        String contactKey = 'portalcontact' + verificationId;
        String timestampKey = 'portaltimestamp' + verificationId;
        
        // Try to use named partition first, fall back to default cache
        try {
            Cache.OrgPartition partition = Cache.Org.getPartition('PortalOTPCache');
            partition.put(otpKey, otpCode, ttlSeconds);
            partition.put(emailKey, email, ttlSeconds);
            partition.put(contactKey, contactId, ttlSeconds);
            partition.put(timestampKey, String.valueOf(DateTime.now().getTime()), ttlSeconds);
            System.debug('OTP stored in named partition: PortalOTPCache');
        } catch (Exception e) {
            System.debug('Named partition error - Type: ' + e.getTypeName() + ', Message: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Fall back to default cache partition
            try {
                Cache.Org.put(otpKey, otpCode, ttlSeconds);
                Cache.Org.put(emailKey, email, ttlSeconds);
                Cache.Org.put(contactKey, contactId, ttlSeconds);
                Cache.Org.put(timestampKey, String.valueOf(DateTime.now().getTime()), ttlSeconds);
                System.debug('OTP stored in default cache partition');
            } catch (Exception defaultCacheException) {
                System.debug('Default cache error - Type: ' + defaultCacheException.getTypeName() + ', Message: ' + defaultCacheException.getMessage());
                System.debug('Stack trace: ' + defaultCacheException.getStackTraceString());
                // Include the actual error message in the exception
                String errorMsg = 'OTP storage is temporarily unavailable. ';
                if (defaultCacheException.getMessage() != null && !String.isBlank(defaultCacheException.getMessage())) {
                    errorMsg += 'Error: ' + defaultCacheException.getMessage();
                } else {
                    errorMsg += 'Please ensure Platform Cache is enabled in your org.';
                }
                throw new AuraHandledException(errorMsg);
            }
        }
        
        return verificationId;
    }
    
    /**
     * Verifies OTP from Platform Cache
     * Falls back to default cache partition if named partition is not available
     */
    private static Boolean verifyOTP(String verificationId, String email, String otpCode) {
        try {
            // Platform Cache keys must be alphanumeric - no underscores allowed
            String otpKey = 'portalotp' + verificationId;
            String emailKey = 'portalemail' + verificationId;
            String timestampKey = 'portaltimestamp' + verificationId;
            
            String storedOTP;
            String storedEmail;
            String timestampStr;
            
            // Try to retrieve from named partition first, fall back to default cache
            try {
                Cache.OrgPartition partition = Cache.Org.getPartition('PortalOTPCache');
                storedOTP = (String)partition.get(otpKey);
                storedEmail = (String)partition.get(emailKey);
                timestampStr = (String)partition.get(timestampKey);
            } catch (Exception e) {
                System.debug('Named partition not available, using default cache: ' + e.getMessage());
                // Fall back to default cache partition
                storedOTP = (String)Cache.Org.get(otpKey);
                storedEmail = (String)Cache.Org.get(emailKey);
                timestampStr = (String)Cache.Org.get(timestampKey);
            }
            
            if (String.isBlank(storedOTP) || String.isBlank(storedEmail)) {
                return false; // OTP not found or expired
            }
            
            // Verify email matches
            if (!storedEmail.equalsIgnoreCase(email)) {
                return false;
            }
            
            // Verify OTP code matches
            if (!storedOTP.equals(otpCode)) {
                return false;
            }
            
            // Check expiration (additional check beyond cache expiration)
            if (String.isNotBlank(timestampStr)) {
                Long timestamp = Long.valueOf(timestampStr);
                Long expirationTime = timestamp + (OTP_EXPIRATION_MINUTES * 60 * 1000);
                if (DateTime.now().getTime() > expirationTime) {
                    return false; // Expired
                }
            }
            
            return true;
        } catch (Exception e) {
            System.debug('Error verifying OTP: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Marks OTP as used by removing it from cache
     * Falls back to default cache partition if named partition is not available
     */
    private static void markOTPAsUsed(String verificationId) {
        try {
            // Platform Cache keys must be alphanumeric - no underscores allowed
            String otpKey = 'portalotp' + verificationId;
            String emailKey = 'portalemail' + verificationId;
            String contactKey = 'portalcontact' + verificationId;
            String timestampKey = 'portaltimestamp' + verificationId;
            
            // Try to remove from named partition first, fall back to default cache
            try {
                Cache.OrgPartition partition = Cache.Org.getPartition('PortalOTPCache');
                partition.remove(otpKey);
                partition.remove(emailKey);
                partition.remove(contactKey);
                partition.remove(timestampKey);
            } catch (Exception e) {
                System.debug('Named partition not available, using default cache: ' + e.getMessage());
                // Fall back to default cache partition
                Cache.Org.remove(otpKey);
                Cache.Org.remove(emailKey);
                Cache.Org.remove(contactKey);
                Cache.Org.remove(timestampKey);
            }
        } catch (Exception e) {
            System.debug('Error marking OTP as used: ' + e.getMessage());
        }
    }
    
    /**
     * Sends OTP email to the contact
     */
    private static void sendOTPEmail(Contact contact, String otpCode) {
        // Use Salesforce Email functionality
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[]{contact.Email});
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
            }
        } catch (Exception e) {
            System.debug('Could not set org-wide email address: ' + e.getMessage());
            // Continue without org-wide email address
        }
        
        // Set save as activity to track email
        email.setSaveAsActivity(false);
        
        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
            
            // Check if email was sent successfully
            if (results != null && !results.isEmpty()) {
                Messaging.SendEmailResult result = results[0];
                if (!result.isSuccess()) {
                    String errorMsg = 'Email send failed: ';
                    if (result.getErrors() != null && !result.getErrors().isEmpty()) {
                        errorMsg += result.getErrors()[0].getMessage();
                    } else {
                        errorMsg += 'Unknown error';
                    }
                    System.debug('Email send error: ' + errorMsg);
                    throw new AuraHandledException('Failed to send verification email. Please check email deliverability settings in Setup > Email Administration > Deliverability. Error: ' + errorMsg);
                } else {
                    System.debug('OTP email sent successfully to: ' + contact.Email);
                }
            } else {
                System.debug('Email send returned null or empty results');
                throw new AuraHandledException('Failed to send verification email. Email deliverability may be disabled. Please contact your administrator.');
            }
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is
            throw e;
        } catch (Exception e) {
            System.debug('Error sending OTP email: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to send verification email: ' + e.getMessage() + '. Please check email deliverability settings in Setup > Email Administration > Deliverability.');
        }
    }
    
    // Wrapper classes
    public class LoginVerificationResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String verificationId;
        @AuraEnabled public String otpCode; // Only populated in sandbox
        @AuraEnabled public Boolean isSandbox; // Indicates if this is a sandbox org
    }
    
    public class LoginResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String username;
        @AuraEnabled public String userId;
    }
}

