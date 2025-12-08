public without sharing class PortalLoginTestController {
    
    public String redirectUrl { get; set; }
    
    public PageReference init() {
        try {
            // Get email parameter from URL, or use a default test email
            String email = ApexPages.currentPage().getParameters().get('email');
            
            if (String.isBlank(email)) {
                // Use a default test email - you can change this to your test user's email
                email = 'andy.haas@milestoneconsulting.tech.william';
            }
            
            // Normalize email
            email = email.trim().toLowerCase();
            
            // Find the user/contact with this email
            List<User> users = [
                SELECT Id, Username, Email, IsActive
                FROM User
                WHERE Email = :email
                AND IsActive = true
                AND UserType = 'PowerPartner'
                LIMIT 1
            ];
            
            if (users.isEmpty()) {
                // If no user found, show error
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'No active portal user found with email: ' + email + '. Please provide a valid email parameter.'
                ));
                return null;
            }
            
            User user = users[0];
            
            // Generate a secure temporary password
            String tempPassword = generateSecurePassword();
            
            // Set the temporary password for the user
            try {
                System.setPassword(user.Id, tempPassword);
                System.debug('Test: Temporary password set for user: ' + user.Username);
            } catch (Exception passwordException) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Unable to set temporary password: ' + passwordException.getMessage()
                ));
                return null;
            }
            
            // Generate a login token
            Blob cryptoKey = Crypto.generateAesKey(128);
            String hexKey = EncodingUtil.convertToHex(cryptoKey);
            String timestampHex = EncodingUtil.convertToHex(Blob.valueOf(String.valueOf(DateTime.now().getTime())));
            String loginToken = (hexKey + timestampHex).substring(0, 32);
            
            // Store login credentials in cache (5 minutes TTL)
            Integer ttlSeconds = 300;
            String usernameKey = 'portalloginun' + loginToken;
            String passwordKey = 'portalloginpw' + loginToken;
            
            Boolean cacheSuccess = false;
            try {
                Cache.OrgPartition partition = Cache.Org.getPartition('PortalOTPCache');
                partition.put(usernameKey, user.Username, ttlSeconds);
                partition.put(passwordKey, tempPassword, ttlSeconds);
                cacheSuccess = true;
                System.debug('Test: Login credentials stored in named partition');
            } catch (Exception e) {
                System.debug('Test: Named partition error: ' + e.getMessage());
                try {
                    Cache.Org.put(usernameKey, user.Username, ttlSeconds);
                    Cache.Org.put(passwordKey, tempPassword, ttlSeconds);
                    cacheSuccess = true;
                    System.debug('Test: Login credentials stored in default cache');
                } catch (Exception defaultCacheException) {
                    ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.ERROR,
                        'Unable to store login credentials: ' + defaultCacheException.getMessage()
                    ));
                    return null;
                }
            }
            
            if (!cacheSuccess) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    'Unable to store login credentials in cache.'
                ));
                return null;
            }
            
            // Create redirect URL to auto-login page
            redirectUrl = '/s/apex/PortalAutoLogin?token=' + loginToken;
            
            // Redirect immediately
            PageReference pageRef = new PageReference(redirectUrl);
            pageRef.setRedirect(true);
            return pageRef;
            
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error: ' + e.getMessage()
            ));
            System.debug('Test: Exception: ' + e.getMessage());
            System.debug('Test: Stack trace: ' + e.getStackTraceString());
            return null;
        }
    }
    
    private String generateSecurePassword() {
        // Generate a secure random password
        Blob randomBlob = Crypto.generateAesKey(256);
        String hexString = EncodingUtil.convertToHex(randomBlob);
        // Take first 16 characters and ensure it has required complexity
        String password = hexString.substring(0, 16) + 'A1!';
        return password;
    }
}

