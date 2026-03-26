public with sharing class PortalLoginController {
    
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
            
            // Send email with OTP
            sendOTPEmail(contact, otpCode);
            
            result.success = true;
            result.message = 'A verification code has been sent to your email address.';
            result.verificationId = verificationId;
            
        } catch (Exception e) {
            System.debug('Error in verifyEmailAndSendOTP: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            result.message = 'An error occurred. Please try again or contact support.';
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
            
        } catch (Exception e) {
            System.debug('Error in verifyOTPAndLogin: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            result.message = 'An error occurred during login. Please try again.';
        }
        
        return result;
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
     * Falls back to a simple in-memory approach if cache is not available
     */
    private static String storeOTP(String contactId, String email, String otpCode) {
        // Generate a unique verification ID
        Blob cryptoKey = Crypto.generateAesKey(128);
        String verificationId = EncodingUtil.base64Encode(cryptoKey).substring(0, 32);
        
        // Store in Platform Cache (if available)
        try {
            Cache.Org.put('portal_otp_' + verificationId, otpCode, OTP_EXPIRATION_MINUTES * 60);
            Cache.Org.put('portal_email_' + verificationId, email, OTP_EXPIRATION_MINUTES * 60);
            Cache.Org.put('portal_contact_' + verificationId, contactId, OTP_EXPIRATION_MINUTES * 60);
            Cache.Org.put('portal_timestamp_' + verificationId, String.valueOf(DateTime.now().getTime()), OTP_EXPIRATION_MINUTES * 60);
        } catch (Exception e) {
            System.debug('Platform Cache not available: ' + e.getMessage());
            // In production, you might want to use a custom object to store OTPs
            // For now, we'll throw an error if cache is not available
            throw new AuraHandledException('OTP storage is temporarily unavailable. Please try again later.');
        }
        
        return verificationId;
    }
    
    /**
     * Verifies OTP from Platform Cache
     */
    private static Boolean verifyOTP(String verificationId, String email, String otpCode) {
        try {
            // Retrieve from cache
            String storedOTP = (String)Cache.Org.get('portal_otp_' + verificationId);
            String storedEmail = (String)Cache.Org.get('portal_email_' + verificationId);
            String timestampStr = (String)Cache.Org.get('portal_timestamp_' + verificationId);
            
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
     */
    private static void markOTPAsUsed(String verificationId) {
        try {
            Cache.Org.remove('portal_otp_' + verificationId);
            Cache.Org.remove('portal_email_' + verificationId);
            Cache.Org.remove('portal_contact_' + verificationId);
            Cache.Org.remove('portal_timestamp_' + verificationId);
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
        
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
        } catch (Exception e) {
            System.debug('Error sending OTP email: ' + e.getMessage());
            throw new AuraHandledException('Failed to send verification email: ' + e.getMessage());
        }
    }
    
    // Wrapper classes
    public class LoginVerificationResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String verificationId;
    }
    
    public class LoginResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String username;
        @AuraEnabled public String userId;
    }
}

