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

            if (result.success && result.username && result.password) {
                console.log('portalAutoLogin: Credentials retrieved, submitting login form');
                console.log('portalAutoLogin: Username:', result.username);
                console.log('portalAutoLogin: Redirect URL:', result.redirectUrl || '/s/');
                // Submit login form to Experience Cloud login endpoint
                this.submitLoginForm(result.username, result.password, result.redirectUrl || '/s/');
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

    submitLoginForm(username, password, redirectUrl) {
        // Experience Cloud /s/login doesn't accept POST (501 error)
        // GET with credentials creates a redirect loop (double-encoding issue)
        // Since Site.login() only works in Visualforce (not available in LWC),
        // we'll use a workaround: redirect to login page, then manually redirect to home
        // 
        // The login page will process the credentials, and we'll redirect to home
        // after a short delay, assuming the login succeeded
        
        const baseUrl = window.location.origin;
        const homeUrl = '/s/'; // Experience Cloud home page
        
        console.log('portalAutoLogin: Attempting login via redirect');
        console.log('portalAutoLogin: Username:', username);
        console.log('portalAutoLogin: Home URL:', homeUrl);
        
        // Redirect to login page with credentials
        // Don't include startURL to avoid double-encoding
        const loginUrl = `${baseUrl}/s/login?un=${encodeURIComponent(username)}&pw=${encodeURIComponent(password)}`;
        
        console.log('portalAutoLogin: Redirecting to login URL');
        console.log('portalAutoLogin: Login URL (without password):', loginUrl.replace(/pw=[^&]*/, 'pw=***'));
        
        // Redirect to login page
        window.location.href = loginUrl;
        
        // After redirect, if we're still on login page, redirect to home
        // This handles the case where login succeeds but redirect doesn't work
        setTimeout(() => {
            if (window.location.pathname.includes('/login')) {
                console.log('portalAutoLogin: Still on login page, redirecting to home');
                window.location.href = homeUrl;
            }
        }, 3000);
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

