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
        // Experience Cloud login - try direct form submission
        // The form submission should work if credentials are valid
        const baseUrl = window.location.origin;
        const loginUrl = baseUrl + '/s/login';

        console.log('portalAutoLogin: Attempting login');
        console.log('portalAutoLogin: Login URL:', loginUrl);
        console.log('portalAutoLogin: Username:', username);
        console.log('portalAutoLogin: Redirect URL:', redirectUrl);
        console.log('portalAutoLogin: Password length:', password ? password.length : 0);

        // Create form and submit directly
        // Experience Cloud login form expects: un, pw, startURL
        const form = document.createElement('form');
        form.method = 'POST';
        form.action = loginUrl;
        form.style.display = 'none';
        form.setAttribute('id', 'auto-login-form');
        form.setAttribute('autocomplete', 'off');

        // Add username field (required)
        const usernameInput = document.createElement('input');
        usernameInput.type = 'text';
        usernameInput.name = 'un';
        usernameInput.value = username;
        usernameInput.autocomplete = 'username';
        form.appendChild(usernameInput);

        // Add password field (required)
        const passwordInput = document.createElement('input');
        passwordInput.type = 'password';
        passwordInput.name = 'pw';
        passwordInput.value = password;
        passwordInput.autocomplete = 'current-password';
        form.appendChild(passwordInput);

        // Add start URL (where to redirect after successful login)
        // Experience Cloud home page - try the root path first
        // If that doesn't work, the user will be logged in and can navigate manually
        const homeUrl = '/'; // Try root first (Experience Cloud will resolve to home)
        const startUrlInput = document.createElement('input');
        startUrlInput.type = 'hidden';
        startUrlInput.name = 'startURL';
        startUrlInput.value = homeUrl;
        form.appendChild(startUrlInput);

        // Add retURL as well (some Salesforce forms use this)
        const retUrlInput = document.createElement('input');
        retUrlInput.type = 'hidden';
        retUrlInput.name = 'retURL';
        retUrlInput.value = homeUrl;
        form.appendChild(retUrlInput);
        
        console.log('portalAutoLogin: startURL set to:', homeUrl);
        console.log('portalAutoLogin: If redirect fails, user is still logged in and can navigate');

        // Append form to body
        document.body.appendChild(form);
        console.log('portalAutoLogin: Form created, submitting...');
        console.log('portalAutoLogin: Form action:', form.action);
        console.log('portalAutoLogin: Form method:', form.method);
        
        // Submit form immediately
        // Note: This will cause a page navigation, so any code after this won't execute
        try {
            form.submit();
        } catch (error) {
            console.error('portalAutoLogin: Form submission error:', error);
            this.errorMessage = 'Unable to submit login form. Please try again.';
            this.isLoading = false;
        }
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

