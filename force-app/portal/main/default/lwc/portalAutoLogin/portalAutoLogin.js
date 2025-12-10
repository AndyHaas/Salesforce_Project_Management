import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import performAutoLogin from '@salesforce/apex/PortalLoginController.performAutoLogin';

export default class PortalAutoLogin extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track errorMessage = '';
    @track successMessage = 'Logging you in...';

    connectedCallback() {
        // Get token from URL parameters
        const urlParams = new URLSearchParams(window.location.search);
        const token = urlParams.get('token');

        if (!token) {
            this.errorMessage = 'No login token provided.';
            this.isLoading = false;
            return;
        }

        // Perform auto-login
        this.handleAutoLogin(token);
    }

    async handleAutoLogin(loginToken) {
        try {
            console.log('portalAutoLogin: Starting auto-login with token:', loginToken);
            const result = await performAutoLogin({ loginToken: loginToken });
            console.log('portalAutoLogin: performAutoLogin result:', JSON.stringify(result));

            if (result.success) {
                // Always use GET with credentials for web session creation
                // REST API sessions don't create web session cookies, so we need to use the login endpoint
                if (result.username && result.password) {
                    console.log('portalAutoLogin: Credentials retrieved, submitting login form');
                    console.log('portalAutoLogin: Username:', result.username);
                    console.log('portalAutoLogin: Redirect URL:', result.redirectUrl || '/s/');
                    // Submit login form via POST
                    this.submitLoginForm(result.username, result.password, result.redirectUrl || '/s/', result.loginToken);
                } else {
                    console.error('portalAutoLogin: No credentials available');
                    this.errorMessage = 'Authentication credentials not available. Please try again.';
                    this.isLoading = false;
                    
                    // Redirect to login page after 3 seconds
                    setTimeout(() => {
                        window.location.href = '/s/login';
                    }, 3000);
                }
            } else {
                // Login failed - show error and redirect to login
                console.error('portalAutoLogin: Login failed -', result.message);
                this.errorMessage = result.message || 'Login session expired. Please try again.';
                this.isLoading = false;
                
                // Redirect to login page after 3 seconds
                setTimeout(() => {
                    window.location.href = '/s/login';
                }, 3000);
            }
        } catch (error) {
            console.error('portalAutoLogin: Error during auto-login:', error);
            console.error('portalAutoLogin: Error details:', JSON.stringify(error, null, 2));
            let errorMessage = 'An error occurred during login. Please try again.';

            if (error.body?.message) {
                errorMessage = error.body.message;
            } else if (error.message) {
                errorMessage = error.message;
            }

            this.errorMessage = errorMessage;
            this.isLoading = false;

            // Redirect to login page after 3 seconds
            setTimeout(() => {
                window.location.href = '/s/login';
            }, 3000);
        }
    }

    async submitLoginForm(username, password, redirectUrl, loginToken) {
        // Experience Cloud /s/login doesn't accept POST (501) or GET with credentials (redirect loop)
        // Use Apex REST endpoint that uses Site.login() server-side
        const baseUrl = window.location.origin;
        const restEndpoint = baseUrl + '/services/apexrest/portal/autologin/';
        const homeUrl = redirectUrl || '/s/';

        console.log('portalAutoLogin: Using REST endpoint for login');
        console.log('portalAutoLogin: Username:', username);
        console.log('portalAutoLogin: REST Endpoint:', restEndpoint);
        console.log('portalAutoLogin: Redirect URL:', homeUrl);

        try {
            // Call REST endpoint to perform login
            const response = await fetch(restEndpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    token: loginToken
                })
            });

            const result = await response.json();
            console.log('portalAutoLogin: REST endpoint response:', result);

            if (response.ok && result.success === 'true' && result.redirectUrl) {
                // Login successful - redirect to the URL returned by Site.login()
                console.log('portalAutoLogin: Login successful, redirecting to:', result.redirectUrl);
                window.location.href = result.redirectUrl;
            } else {
                // Login failed
                console.error('portalAutoLogin: Login failed -', result.error || 'Unknown error');
                this.errorMessage = result.error || 'Login failed. Please try again.';
                this.isLoading = false;
                
                // Clear cache on failure
                if (loginToken) {
                    try {
                        // Call Apex to clear cache (we can't do this from LWC directly)
                        // Cache will expire naturally
                    } catch (e) {
                        console.error('portalAutoLogin: Error clearing cache:', e);
                    }
                }
                
                // Redirect to login page after 3 seconds
                setTimeout(() => {
                    window.location.href = '/s/login';
                }, 3000);
            }
        } catch (error) {
            console.error('portalAutoLogin: Error calling REST endpoint:', error);
            this.errorMessage = 'An error occurred during login. Please try again.';
            this.isLoading = false;
            
            // Redirect to login page after 3 seconds
            setTimeout(() => {
                window.location.href = '/s/login';
            }, 3000);
        }
    }

}

