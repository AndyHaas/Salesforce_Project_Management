import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import performAutoLogin from '@salesforce/apex/PortalLoginController.performAutoLogin';

export default class PortalAutoLogin extends NavigationMixin(LightningElement) {
    connectedCallback() {
        // Get token from URL parameters
        const urlParams = new URLSearchParams(window.location.search);
        const token = urlParams.get('token');
        
        if (!token) {
            console.error('No token provided in URL');
            this.redirectToLogin('No login token provided. Please try again.');
            return;
        }
        
        // Perform auto-login
        this.handleAutoLogin(token);
    }
    
    async handleAutoLogin(token) {
        try {
            const result = await performAutoLogin({ loginToken: token });
            
            if (result.success && result.username && result.password) {
                // Submit login form to Experience Cloud login endpoint
                this.submitLoginForm(result.username, result.password, result.redirectUrl || '/s/');
            } else {
                // Login failed - redirect to login page with error
                this.redirectToLogin(result.message || 'Login failed. Please try again.');
            }
        } catch (error) {
            console.error('Error during auto-login:', error);
            let errorMessage = 'An error occurred during login. Please try again.';
            
            if (error.body?.message) {
                errorMessage = error.body.message;
            } else if (error.message) {
                errorMessage = error.message;
            }
            
            this.redirectToLogin(errorMessage);
        }
    }
    
    submitLoginForm(username, password, redirectUrl) {
        // Create a form and submit it to the Experience Cloud login endpoint
        const form = document.createElement('form');
        form.method = 'POST';
        form.action = '/s/login'; // Experience Cloud login endpoint
        
        // Add username field
        const usernameInput = document.createElement('input');
        usernameInput.type = 'hidden';
        usernameInput.name = 'un';
        usernameInput.value = username;
        form.appendChild(usernameInput);
        
        // Add password field
        const passwordInput = document.createElement('input');
        passwordInput.type = 'hidden';
        passwordInput.name = 'pw';
        passwordInput.value = password;
        form.appendChild(passwordInput);
        
        // Add start URL (where to redirect after login)
        const startUrlInput = document.createElement('input');
        startUrlInput.type = 'hidden';
        startUrlInput.name = 'startURL';
        startUrlInput.value = redirectUrl;
        form.appendChild(startUrlInput);
        
        // Append form to body and submit
        document.body.appendChild(form);
        form.submit();
    }
    
    redirectToLogin(errorMessage) {
        // Redirect to login page with error message
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Login'
            },
            state: {
                error: errorMessage
            }
        });
    }
    
    redirectToCommunityHome() {
        // Redirect to community home page
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Home'
            }
        });
    }
}

