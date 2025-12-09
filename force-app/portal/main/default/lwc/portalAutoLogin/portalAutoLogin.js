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
                // Check if REST API authentication was used
                if (result.useRestApi && result.sessionId) {
                    console.log('portalAutoLogin: REST API authentication successful');
                    console.log('portalAutoLogin: Session ID received');
                    console.log('portalAutoLogin: Instance URL:', result.instanceUrl);
                    // Use REST API session to authenticate
                    this.handleRestApiLogin(result.sessionId, result.instanceUrl, result.redirectUrl || '/s/');
                } else if (result.username && result.password) {
                    console.log('portalAutoLogin: Credentials retrieved, submitting login form');
                    console.log('portalAutoLogin: Username:', result.username);
                    console.log('portalAutoLogin: Redirect URL:', result.redirectUrl || '/s/');
                    // Fallback: Submit login form to Experience Cloud login endpoint
                    this.submitLoginForm(result.username, result.password, result.redirectUrl || '/s/');
                } else {
                    console.error('portalAutoLogin: No authentication method available');
                    this.errorMessage = 'Authentication method not available. Please try again.';
                    this.isLoading = false;
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

    handleRestApiLogin(sessionId, instanceUrl, redirectUrl) {
        // REST API authentication succeeded - we have a session ID
        // However, we need to create a proper Experience Cloud web session
        // 
        // Option 1: Use the session ID to redirect to a Salesforce endpoint that creates a web session
        // Option 2: Set a cookie with the session ID (requires server-side support)
        // Option 3: Redirect to home and let Salesforce handle session creation
        //
        // For now, we'll try redirecting to home - the session ID might be usable
        // If this doesn't work, we may need a server-side endpoint to set the session cookie
        
        console.log('portalAutoLogin: Handling REST API login');
        console.log('portalAutoLogin: Session ID:', sessionId ? 'Received' : 'Missing');
        console.log('portalAutoLogin: Redirecting to home page');
        
        // Try redirecting to home - if the session ID is valid, it might work
        // If not, we'll need to implement a server-side session creation endpoint
        const homeUrl = redirectUrl || '/s/';
        
        // Store session ID temporarily (might be needed for API calls)
        try {
            sessionStorage.setItem('portal_session_id', sessionId);
            sessionStorage.setItem('portal_instance_url', instanceUrl);
        } catch (e) {
            console.error('portalAutoLogin: Could not store session info:', e);
        }
        
        // Redirect to home page
        // Note: This might not work if the session ID doesn't create a web session
        // In that case, we'll need a server-side endpoint to convert the API session to a web session
        window.location.href = homeUrl;
    }
    
    submitLoginForm(username, password, redirectUrl) {
        // Experience Cloud /s/login doesn't accept POST (501) or GET with credentials (redirect loop)
        // Since Site.login() only works in Visualforce (not available in LWC),
        // we need a workaround
        //
        // The issue: Experience Cloud encodes our login URL as startURL, creating a loop
        // Solution: Redirect to login page, then after a delay, redirect to home
        // This assumes the login will succeed (credentials are valid)
        
        const baseUrl = window.location.origin;
        const homeUrl = '/s/'; // Experience Cloud home page
        
        console.log('portalAutoLogin: Attempting login');
        console.log('portalAutoLogin: Username:', username);
        console.log('portalAutoLogin: Home URL:', homeUrl);
        
        // Redirect to login page with credentials
        // Experience Cloud will process it (even if it creates a redirect loop)
        const loginUrl = `${baseUrl}/s/login?un=${encodeURIComponent(username)}&pw=${encodeURIComponent(password)}`;
        
        console.log('portalAutoLogin: Redirecting to login URL');
        console.log('portalAutoLogin: Login URL (without password):', loginUrl.replace(/pw=[^&]*/, 'pw=***'));
        
        // Redirect to login page
        // After redirect, we'll wait and then redirect to home
        // This breaks the redirect loop by going directly to home
        window.location.href = loginUrl;
        
        // Set a flag to redirect to home after login page loads
        // This will break the redirect loop
        setTimeout(() => {
            console.log('portalAutoLogin: Breaking redirect loop, going directly to home');
            window.location.replace(homeUrl); // Use replace() to avoid adding to history
        }, 2000);
    }

    submitLoginFormFallback(username, password, redirectUrl) {
        // Fallback: Create a form and submit it to the Experience Cloud login endpoint
        const baseUrl = window.location.origin;
        const loginUrl = baseUrl + '/s/login';

        const form = document.createElement('form');
        form.method = 'POST';
        form.action = loginUrl;
        form.style.display = 'none';
        form.setAttribute('id', 'auto-login-form');

        // Add username field (Experience Cloud uses 'un')
        const usernameInput = document.createElement('input');
        usernameInput.type = 'hidden';
        usernameInput.name = 'un';
        usernameInput.value = username;
        form.appendChild(usernameInput);

        // Add password field (Experience Cloud uses 'pw')
        const passwordInput = document.createElement('input');
        passwordInput.type = 'hidden';
        passwordInput.name = 'pw';
        passwordInput.value = password;
        form.appendChild(passwordInput);

        // Add start URL (where to redirect after login)
        const startUrlInput = document.createElement('input');
        startUrlInput.type = 'hidden';
        startUrlInput.name = 'startURL';
        startUrlInput.value = redirectUrl || '/s/';
        form.appendChild(startUrlInput);

        // Add retURL as alternative (some Salesforce forms use this)
        const retUrlInput = document.createElement('input');
        retUrlInput.type = 'hidden';
        retUrlInput.name = 'retURL';
        retUrlInput.value = redirectUrl || '/s/';
        form.appendChild(retUrlInput);

        // Append form to body and submit
        document.body.appendChild(form);
        console.log('portalAutoLogin: Form created, submitting...');
        
        // Add a small delay to ensure form is in DOM
        setTimeout(() => {
            console.log('portalAutoLogin: Submitting form now');
            form.submit();
        }, 100);
    }
}

