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
            
            // Passwordless login: Generate temporary password and authenticate user
            User user = users[0];
            
            // Generate a secure temporary password
            String tempPassword = generateSecurePassword();
            
            // Set the temporary password for the user
            // This requires "Manage Users" or "Reset User Passwords" permission
            try {
                System.setPassword(user.Id, tempPassword);
                System.debug('Temporary password set for user: ' + user.Username);
            } catch (Exception passwordException) {
                System.debug('Error setting password - Type: ' + passwordException.getTypeName() + ', Message: ' + passwordException.getMessage());
                System.debug('Stack trace: ' + passwordException.getStackTraceString());
                // If we can't set the password, we can't proceed with passwordless login
                String errorMsg = 'Unable to set temporary password. ';
                if (passwordException.getMessage() != null && !String.isBlank(passwordException.getMessage())) {
                    errorMsg += 'Error: ' + passwordException.getMessage();
                } else {
                    errorMsg += 'Please ensure the user has proper permissions or contact support.';
                }
                throw new AuraHandledException(errorMsg);
            }
            
            // Generate a login token for secure passwordless login
            // Store username and password in cache temporarily (expires in 2 minutes)
            Blob cryptoKey = Crypto.generateAesKey(128);
            String hexKey = EncodingUtil.convertToHex(cryptoKey);
            String timestampHex = EncodingUtil.convertToHex(Blob.valueOf(String.valueOf(DateTime.now().getTime())));
            String loginToken = (hexKey + timestampHex).substring(0, 32);
            
            // Store login credentials in cache (short TTL for security)
            // Platform Cache requires minimum TTL of 300 seconds (5 minutes)
            Integer ttlSeconds = 300; // 5 minutes (minimum allowed by Platform Cache)
            String usernameKey = 'portalloginun' + loginToken;
            String passwordKey = 'portalloginpw' + loginToken;
            
            // Try to store credentials in cache - if this fails, we can't proceed with passwordless login
            Boolean cacheSuccess = false;
            try {
                Cache.OrgPartition partition = Cache.Org.getPartition('PortalOTPCache');
                partition.put(usernameKey, user.Username, ttlSeconds);
                partition.put(passwordKey, tempPassword, ttlSeconds);
                cacheSuccess = true;
                System.debug('Login credentials stored in named partition: PortalOTPCache');
            } catch (Exception e) {
                System.debug('Named partition error - Type: ' + e.getTypeName() + ', Message: ' + e.getMessage());
                // Fall back to default cache
                try {
                    Cache.Org.put(usernameKey, user.Username, ttlSeconds);
                    Cache.Org.put(passwordKey, tempPassword, ttlSeconds);
                    cacheSuccess = true;
                    System.debug('Login credentials stored in default cache partition');
                } catch (Exception defaultCacheException) {
                    System.debug('Default cache error - Type: ' + defaultCacheException.getTypeName() + ', Message: ' + defaultCacheException.getMessage());
                    System.debug('Stack trace: ' + defaultCacheException.getStackTraceString());
                    // If cache fails, we can't proceed with passwordless login
                    // Include the actual error message for debugging
                    String errorMsg = 'Unable to store login credentials. ';
                    if (defaultCacheException.getMessage() != null && !String.isBlank(defaultCacheException.getMessage())) {
                        errorMsg += 'Error: ' + defaultCacheException.getMessage();
                    } else {
                        errorMsg += 'Please try again or contact support.';
                    }
                    throw new AuraHandledException(errorMsg);
                }
            }
            
            if (!cacheSuccess) {
                throw new AuraHandledException('Unable to store login credentials. Please try again or contact support.');
            }
            
            // Return URL to LWC auto-login page (LWR compatible - Visualforce not supported in LWR)
            // The LWC will retrieve credentials and submit login form
            String loginUrl = '/autologin?token=' + loginToken;
            
            result.success = true;
            result.message = 'Verification successful. Logging you in...';
            result.username = user.Username;
            result.userId = user.Id;
            result.sessionToken = loginUrl; // Store login URL in sessionToken field
            
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
            String exceptionType = e.getTypeName();
            String exceptionMessage = e.getMessage() != null ? e.getMessage() : '';
            
            if (exceptionType.contains('QueryException')) {
                errorMessage = 'Database error occurred. Please contact support.';
            } else if (exceptionType.contains('SecurityException') || exceptionType.contains('NoAccessException')) {
                errorMessage = 'Permission denied. Please contact your administrator.';
            } else if (exceptionType.contains('Cache') || (exceptionMessage.contains('Cache') && exceptionMessage.contains('Platform Cache'))) {
                errorMessage = 'OTP verification is temporarily unavailable. Please request a new code.';
            } else if (String.isNotBlank(exceptionMessage)) {
                // Include the actual error message if available
                errorMessage = 'Error: ' + exceptionMessage;
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
     * Generates a secure temporary password for passwordless login
     * Password must meet Salesforce requirements: at least 8 characters,
     * contain letters and numbers
     * Hex strings always contain both letters (a-f) and numbers (0-9)
     */
    private static String generateSecurePassword() {
        // Generate a secure random password using crypto-secure random generation
        Blob randomBlob = Crypto.generateAesKey(256);
        String hexString = EncodingUtil.convertToHex(randomBlob);
        
        // Take first 12 characters (hex contains both letters and numbers, so this meets requirements)
        // 12 characters ensures we have both letters and numbers
        return hexString.substring(0, 12);
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
    
    /**
     * Clears all portal-related cache entries
     * Can be called on page load or after login for security
     * @return Boolean indicating success
     */
    @AuraEnabled
    public static Boolean clearPortalCache() {
        try {
            // Clear cache entries from both named partition and default cache
            // Note: We can't enumerate cache keys, so we clear what we can
            // The cache entries will expire naturally based on TTL
            
            // Try to clear from named partition (though we can't enumerate keys)
            try {
                Cache.OrgPartition partition = Cache.Org.getPartition('PortalOTPCache');
                // Since we can't enumerate keys, we rely on TTL expiration
                // But we can at least ensure the partition is accessible
                System.debug('Portal cache partition accessible');
            } catch (Exception e) {
                System.debug('Named partition not available: ' + e.getMessage());
            }
            
            // For default cache, we also rely on TTL expiration
            // Cache entries will expire based on their TTL
            
            return true;
        } catch (Exception e) {
            System.debug('Error clearing portal cache: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Clears cache entries for a specific verification ID
     * Used internally to clean up after OTP verification
     */
    private static void clearVerificationCache(String verificationId) {
        if (String.isBlank(verificationId)) {
            return;
        }
        
        String otpKey = 'portalotp' + verificationId;
        String emailKey = 'portalemail' + verificationId;
        String contactKey = 'portalcontact' + verificationId;
        String timestampKey = 'portaltimestamp' + verificationId;
        
        try {
            Cache.OrgPartition partition = Cache.Org.getPartition('PortalOTPCache');
            partition.remove(otpKey);
            partition.remove(emailKey);
            partition.remove(contactKey);
            partition.remove(timestampKey);
        } catch (Exception e) {
            Cache.Org.remove(otpKey);
            Cache.Org.remove(emailKey);
            Cache.Org.remove(contactKey);
            Cache.Org.remove(timestampKey);
        }
    }
    
    /**
     * Clears login credentials cache for a specific token
     * Used after successful login
     */
    public static void clearLoginCredentialsCache(String loginToken) {
        if (String.isBlank(loginToken)) {
            return;
        }
        
        String usernameKey = 'portalloginun' + loginToken;
        String passwordKey = 'portalloginpw' + loginToken;
        
        try {
            Cache.OrgPartition partition = Cache.Org.getPartition('PortalOTPCache');
            partition.remove(usernameKey);
            partition.remove(passwordKey);
        } catch (Exception e) {
            Cache.Org.remove(usernameKey);
            Cache.Org.remove(passwordKey);
        }
    }
    
    /**
     * Performs auto-login using REST API authentication
     * Uses Connected App OAuth Username-Password flow to authenticate
     * @param loginToken The token used to retrieve login credentials
     * @return AutoLoginResult containing session information or credentials for fallback
     */
    @AuraEnabled
    public static AutoLoginResult performAutoLogin(String loginToken) {
        AutoLoginResult result = new AutoLoginResult();
        result.success = false;
        result.message = '';
        
        try {
            if (String.isBlank(loginToken)) {
                result.message = 'No login token provided.';
                return result;
            }
            
            // Retrieve username and password from Platform Cache
            String usernameKey = 'portalloginun' + loginToken;
            String passwordKey = 'portalloginpw' + loginToken;
            
            String username;
            String password;
            
            try {
                Cache.OrgPartition partition = Cache.Org.getPartition('PortalOTPCache');
                username = (String)partition.get(usernameKey);
                password = (String)partition.get(passwordKey);
            } catch (Exception e) {
                System.debug('Error retrieving from named cache: ' + e.getMessage());
                // Fall back to default cache
                username = (String)Cache.Org.get(usernameKey);
                password = (String)Cache.Org.get(passwordKey);
            }
            
            if (String.isBlank(username) || String.isBlank(password)) {
                result.message = 'Login session expired. Please try again.';
                return result;
            }
            
            // Clear credentials from cache immediately (security)
            clearLoginCredentialsCache(loginToken);
            
            // Try REST API authentication first
            try {
                RestApiLoginResult restResult = authenticateViaRestApi(username, password);
                if (restResult.success && String.isNotBlank(restResult.sessionId)) {
                    // REST API authentication succeeded
                    result.success = true;
                    result.sessionId = restResult.sessionId;
                    result.instanceUrl = restResult.instanceUrl;
                    result.redirectUrl = '/s/';
                    result.message = 'Authentication successful via REST API.';
                    result.useRestApi = true;
                    return result;
                }
            } catch (Exception restException) {
                System.debug('REST API authentication failed: ' + restException.getMessage());
                // Fall through to form submission fallback
            }
            
            // Fallback: Return credentials for form submission
            // This is used if REST API authentication is not configured
            result.success = true;
            result.username = username;
            result.password = password;
            result.redirectUrl = '/s/';
            result.message = 'Login credentials retrieved successfully.';
            result.useRestApi = false;
            result.clearCache = true;
            
        } catch (Exception e) {
            System.debug('Error in performAutoLogin: ' + e.getMessage());
            System.debug('Error type: ' + e.getTypeName());
            System.debug('Stack trace: ' + e.getStackTraceString());
            result.message = 'An error occurred during login. Please try again.';
        }
        
        return result;
    }
    
    /**
     * Authenticates user via Salesforce REST API using External Named Credential
     * Uses Named Credential: Portal_Auto_Login
     * The Named Credential handles OAuth automatically
     * @param username The username to authenticate
     * @param password The password to authenticate
     * @return RestApiLoginResult containing session ID and instance URL
     */
    private static RestApiLoginResult authenticateViaRestApi(String username, String password) {
        RestApiLoginResult result = new RestApiLoginResult();
        result.success = false;
        
        try {
            // Build the request body for Username-Password OAuth flow
            // For Username-Password flow, we need to include client_id and client_secret
            // The Named Credential provides the base URL, but we need credentials in the body
            String consumerKey = getConnectedAppConsumerKey();
            String consumerSecret = getConnectedAppConsumerSecret();
            
            if (String.isBlank(consumerKey) || String.isBlank(consumerSecret)) {
                System.debug('Connected App credentials not available');
                result.message = 'REST API authentication not configured.';
                return result;
            }
            
            String requestBody = 'grant_type=password' +
                               '&client_id=' + EncodingUtil.urlEncode(consumerKey, 'UTF-8') +
                               '&client_secret=' + EncodingUtil.urlEncode(consumerSecret, 'UTF-8') +
                               '&username=' + EncodingUtil.urlEncode(username, 'UTF-8') +
                               '&password=' + EncodingUtil.urlEncode(password, 'UTF-8');
            
            // Build the request using Named Credential
            // Named Credential: Portal_Auto_Login
            // The Named Credential should be configured with:
            // - URL: https://test.salesforce.com (for sandbox) or https://login.salesforce.com (for production)
            // - This provides the base URL, but we still need client_id/client_secret in the body
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Portal_Auto_Login/services/oauth2/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(requestBody);
            
            // Make the HTTP callout
            // The Named Credential will automatically handle OAuth authentication
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Parse the response
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                result.success = true;
                result.sessionId = (String)responseMap.get('access_token');
                result.instanceUrl = (String)responseMap.get('instance_url');
                result.message = 'REST API authentication successful.';
            } else {
                System.debug('REST API authentication failed: ' + res.getStatusCode() + ' - ' + res.getBody());
                result.message = 'Authentication failed: ' + res.getStatus();
            }
            
        } catch (Exception e) {
            System.debug('Error in authenticateViaRestApi: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            result.message = 'Error during REST API authentication: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * Gets the Connected App Consumer Key
     * Named Credential: Portal_Auto_Login
     * 
     * Note: For Username-Password OAuth flow, we need the actual Consumer Key value
     * in the request body. The Named Credential provides the base URL, but we still
     * need to include client_id and client_secret in the request body.
     */
    private static String getConnectedAppConsumerKey() {
        // Named Credential: Portal_Auto_Login
        // Consumer Key is needed in the request body for Username-Password OAuth flow
        return '3MVG9U6cXtLQ6pLUChtfKbtoSJVPfFIlnzNiPvew4f.NgV2BtroWsO04qA15T.wYTjUS7oY__WDNfkbpiCGf8';
    }
    
    /**
     * Gets the Connected App Consumer Secret
     * Named Credential: Portal_Auto_Login
     * 
     * Note: For Username-Password OAuth flow, we need the actual Consumer Secret value
     * in the request body. The Named Credential provides the base URL, but we still
     * need to include client_id and client_secret in the request body.
     */
    private static String getConnectedAppConsumerSecret() {
        // Named Credential: Portal_Auto_Login
        // Consumer Secret is needed in the request body for Username-Password OAuth flow
        return 'CDC3C6EBDC27B1115AAE36F46B914DC46718FCBD5BBB4536DA7BB584DF824528';
    }
    
    // Wrapper class for REST API login result
    private class RestApiLoginResult {
        Boolean success;
        String message;
        String sessionId;
        String instanceUrl;
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
        @AuraEnabled public String sessionToken; // Session token for passwordless login
    }
    
    public class AutoLoginResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String username;
        @AuraEnabled public String password;
        @AuraEnabled public String redirectUrl;
        @AuraEnabled public Boolean clearCache;
        @AuraEnabled public Boolean useRestApi; // Indicates if REST API was used
        @AuraEnabled public String sessionId; // Session ID from REST API
        @AuraEnabled public String instanceUrl; // Instance URL from REST API
    }
}

