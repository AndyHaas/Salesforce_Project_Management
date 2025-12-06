public class PortalAutoLoginController {
    
    public PageReference autoLogin() {
        try {
            // Get login token from URL parameter
            String token = ApexPages.currentPage().getParameters().get('token');
            System.debug('PortalAutoLogin: Token received: ' + token);
            
            if (String.isBlank(token)) {
                System.debug('PortalAutoLogin: No login token provided');
                PageReference loginPage = new PageReference('/s/login');
                loginPage.setRedirect(true);
                return loginPage;
            }
            
            // Retrieve username and password from Platform Cache
            String usernameKey = 'portalloginun' + token;
            String passwordKey = 'portalloginpw' + token;
            
            System.debug('PortalAutoLogin: Looking for credentials with keys: ' + usernameKey + ', ' + passwordKey);
            
            String username;
            String password;
            
            try {
                Cache.OrgPartition partition = Cache.Org.getPartition('PortalOTPCache');
                username = (String)partition.get(usernameKey);
                password = (String)partition.get(passwordKey);
                System.debug('PortalAutoLogin: Retrieved from named partition - Username: ' + (String.isNotBlank(username) ? 'found' : 'not found') + ', Password: ' + (String.isNotBlank(password) ? 'found' : 'not found'));
            } catch (Exception e) {
                System.debug('PortalAutoLogin: Named partition error: ' + e.getMessage());
                // Fall back to default cache
                try {
                    username = (String)Cache.Org.get(usernameKey);
                    password = (String)Cache.Org.get(passwordKey);
                    System.debug('PortalAutoLogin: Retrieved from default cache - Username: ' + (String.isNotBlank(username) ? 'found' : 'not found') + ', Password: ' + (String.isNotBlank(password) ? 'found' : 'not found'));
                } catch (Exception defaultCacheException) {
                    System.debug('PortalAutoLogin: Default cache error: ' + defaultCacheException.getMessage());
                }
            }
            
            if (String.isBlank(username) || String.isBlank(password)) {
                System.debug('PortalAutoLogin: Login credentials not found in cache for token: ' + token);
                System.debug('PortalAutoLogin: Username blank: ' + String.isBlank(username) + ', Password blank: ' + String.isBlank(password));
                // Redirect to login page with error message
                PageReference loginPage = new PageReference('/s/login');
                loginPage.getParameters().put('error', 'Login session expired. Please try again.');
                loginPage.setRedirect(true);
                return loginPage;
            }
            
            System.debug('PortalAutoLogin: Credentials found, attempting login for username: ' + username);
            
            // Use Site.login() to authenticate the user
            // This works in Visualforce page context
            PageReference loginResult = Site.login(username, password, '/s/');
            
            System.debug('PortalAutoLogin: Site.login() result: ' + (loginResult != null ? loginResult.getUrl() : 'null'));
            
            if (loginResult != null) {
                // Clear the credentials from cache after successful login (security)
                PortalLoginController.clearLoginCredentialsCache(token);
                System.debug('PortalAutoLogin: Login successful, redirecting to: ' + loginResult.getUrl());
                // Ensure redirect is set
                loginResult.setRedirect(true);
                return loginResult;
            } else {
                System.debug('PortalAutoLogin: Site.login() returned null - login failed');
                // Clear credentials even on failure (they're invalid anyway)
                PortalLoginController.clearLoginCredentialsCache(token);
                PageReference loginPage = new PageReference('/s/login');
                loginPage.getParameters().put('error', 'Login failed. Please try again.');
                loginPage.setRedirect(true);
                return loginPage;
            }
        } catch (Exception e) {
            System.debug('PortalAutoLogin: Exception in autoLogin: ' + e.getMessage());
            System.debug('PortalAutoLogin: Exception type: ' + e.getTypeName());
            System.debug('PortalAutoLogin: Stack trace: ' + e.getStackTraceString());
            // Redirect to login page on error
            PageReference loginPage = new PageReference('/s/login');
            loginPage.getParameters().put('error', 'An error occurred during login. Please try again.');
            loginPage.setRedirect(true);
            return loginPage;
        }
    }
}
