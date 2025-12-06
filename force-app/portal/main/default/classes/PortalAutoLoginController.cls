public class PortalAutoLoginController {
    
    public PageReference autoLogin() {
        try {
            // Get login token from URL parameter
            String token = ApexPages.currentPage().getParameters().get('token');
            
            if (String.isBlank(token)) {
                System.debug('No login token provided');
                return new PageReference('/s/login');
            }
            
            // Retrieve username and password from Platform Cache
            String usernameKey = 'portalloginun' + token;
            String passwordKey = 'portalloginpw' + token;
            
            String username;
            String password;
            
            try {
                Cache.OrgPartition partition = Cache.Org.getPartition('PortalOTPCache');
                username = (String)partition.get(usernameKey);
                password = (String)partition.get(passwordKey);
            } catch (Exception e) {
                // Fall back to default cache
                username = (String)Cache.Org.get(usernameKey);
                password = (String)Cache.Org.get(passwordKey);
            }
            
            if (String.isBlank(username) || String.isBlank(password)) {
                System.debug('Login credentials not found in cache for token: ' + token);
                return new PageReference('/s/login');
            }
            
            // Clear the credentials from cache after retrieval (security)
            // Use the centralized method from PortalLoginController
            PortalLoginController.clearLoginCredentialsCache(token);
            
            // Also clear any OTP cache entries that might be lingering for this user
            // (We can't get the verificationId from here, but OTP entries will expire on their own)
            
            // Use Site.login() to authenticate the user
            // This works in Visualforce page context
            PageReference loginResult = Site.login(username, password, '/s/');
            
            if (loginResult != null) {
                return loginResult;
            } else {
                System.debug('Site.login() returned null');
                return new PageReference('/s/login');
            }
        } catch (Exception e) {
            System.debug('Error in autoLogin: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Redirect to login page on error
            return new PageReference('/s/login');
        }
    }
}
