import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import verifyEmailAndSendOTP from '@salesforce/apex/PortalLoginController.verifyEmailAndSendOTP';
import verifyOTPAndLogin from '@salesforce/apex/PortalLoginController.verifyOTPAndLogin';
import performAutoLogin from '@salesforce/apex/PortalLoginController.performAutoLogin';
import clearPortalCache from '@salesforce/apex/PortalLoginController.clearPortalCache';

export default class PortalLogin extends NavigationMixin(LightningElement) {
    @track email = '';
    @track otpCode = '';
    @track verificationId = '';
    @track step = 'email'; // 'email' or 'otp'
    @track isLoading = false;
    @track errorMessage = '';
    @track successMessage = '';
    @track stepTransition = false;
    @track isSandbox = false;
    @track sandboxOTPCode = ''; // OTP code for sandbox display

    get showEmailStep() {
        return this.step === 'email';
    }

    get showOTPStep() {
        return this.step === 'otp';
    }

    get cardClass() {
        return this.stepTransition ? 'login-card step-transition' : 'login-card';
    }

    get otpInputClass() {
        return 'otp-input-container';
    }

    /**
     * Lifecycle hook - called when component is inserted into the DOM
     * Clear any stale portal cache entries for security
     */
    connectedCallback() {
        // Clear portal cache on page load to ensure no stale entries
        // This is a best practice for security - clear any lingering OTP or login tokens
        clearPortalCache()
            .then(() => {
                console.log('Portal cache cleared on page load');
            })
            .catch((error) => {
                // Non-critical - cache entries will expire on their own
                console.warn('Could not clear portal cache:', error);
            });
    }

    handleEmailChange(event) {
        this.email = event.target.value;
        this.errorMessage = '';
        this.successMessage = '';
    }

    handleOTPChange(event) {
        this.otpCode = event.target.value;
        this.errorMessage = '';
        this.successMessage = '';
    }

    handleEmailInput(event) {
        // Real-time email validation
        this.email = event.target.value;
        this.errorMessage = '';
    }

    handleOTPInput(event) {
        // Auto-format and limit to 6 digits
        let value = event.target.value.replace(/\D/g, '').substring(0, 6);
        this.otpCode = value;
        this.errorMessage = '';
        
        // Auto-submit when 6 digits are entered
        if (value.length === 6) {
            setTimeout(() => {
                this.handleOTPSubmit();
            }, 100);
        }
    }

    handleKeyPress(event) {
        // Allow Enter key to submit
        if (event.key === 'Enter' && !this.isLoading) {
            if (this.step === 'email') {
                this.handleEmailSubmit();
            } else if (this.step === 'otp') {
                this.handleOTPSubmit();
            }
        }
    }

    async handleEmailSubmit() {
        if (!this.email || !this.isValidEmail(this.email)) {
            this.errorMessage = 'Please enter a valid email address.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const result = await verifyEmailAndSendOTP({ email: this.email });
            
            if (result.success) {
                this.verificationId = result.verificationId;
                this.successMessage = result.message;
                this.isSandbox = result.isSandbox || false;
                this.sandboxOTPCode = result.otpCode || '';
                
                // Transition to OTP step
                this.stepTransition = true;
                setTimeout(() => {
                    this.step = 'otp';
                    this.stepTransition = false;
                    // Focus on OTP input
                    setTimeout(() => {
                        const otpInput = this.template.querySelector('.otp-input-container input');
                        if (otpInput) {
                            otpInput.focus();
                        }
                    }, 100);
                }, 300);
            } else {
                this.errorMessage = result.message;
            }
        } catch (error) {
            console.error('Error verifying email:', error);
            console.error('Error details:', JSON.stringify(error, null, 2));
            
            // Extract error message from various possible error formats
            let errorMsg = 'An error occurred. Please try again.';
            if (error.body?.message) {
                errorMsg = error.body.message;
            } else if (error.body?.pageErrors && error.body.pageErrors.length > 0) {
                errorMsg = error.body.pageErrors[0].message;
            } else if (error.body?.fieldErrors) {
                const fieldErrors = Object.values(error.body.fieldErrors).flat();
                if (fieldErrors.length > 0) {
                    errorMsg = fieldErrors[0].message;
                }
            } else if (error.message) {
                errorMsg = error.message;
            }
            
            this.errorMessage = errorMsg;
        } finally {
            this.isLoading = false;
        }
    }

    async handleOTPSubmit() {
        if (!this.otpCode || this.otpCode.length !== 6) {
            this.errorMessage = 'Please enter the 6-digit verification code.';
            return;
        }

        if (!this.verificationId) {
            this.errorMessage = 'Verification session expired. Please start over.';
            this.step = 'email';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const result = await verifyOTPAndLogin({ 
                email: this.email, 
                otpCode: this.otpCode, 
                verificationId: this.verificationId 
            });
            
            if (result.success) {
                this.successMessage = result.message;
                
                // Redirect to LWC auto-login page (LWR compatible - Visualforce not supported in LWR)
                // The LWC will retrieve credentials from cache and submit login form
                if (result.sessionToken) {
                    // sessionToken contains the full URL to the auto-login page: /s/portal-auto-login?token=...
                    const baseUrl = window.location.origin;
                    const autoLoginUrl = baseUrl + result.sessionToken;
                    console.log('Redirecting to auto-login page:', autoLoginUrl);
                    
                    // Add a small delay to ensure the success message is visible
                    setTimeout(() => {
                        window.location.href = autoLoginUrl;
                    }, 500);
                } else {
                    // Fallback: redirect to community home page
                    this.redirectToCommunityHome();
                }
            } else {
                this.errorMessage = result.message;
            }
        } catch (error) {
            console.error('Error verifying OTP:', error);
            console.error('Error details:', JSON.stringify(error, null, 2));
            
            // Extract error message from various possible error formats
            let errorMsg = 'Invalid verification code. Please try again.';
            if (error.body?.message) {
                errorMsg = error.body.message;
            } else if (error.body?.pageErrors && error.body.pageErrors.length > 0) {
                errorMsg = error.body.pageErrors[0].message;
            } else if (error.body?.fieldErrors) {
                const fieldErrors = Object.values(error.body.fieldErrors).flat();
                if (fieldErrors.length > 0) {
                    errorMsg = fieldErrors[0].message;
                }
            } else if (error.message) {
                errorMsg = error.message;
            }
            
            this.errorMessage = errorMsg;
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToEmail() {
        this.stepTransition = true;
        setTimeout(() => {
            this.otpCode = '';
            this.verificationId = '';
            this.sandboxOTPCode = '';
            this.isSandbox = false;
            this.step = 'email';
            this.errorMessage = '';
            this.successMessage = '';
            this.stepTransition = false;
        }, 300);
    }

    handleResendOTP() {
        this.stepTransition = true;
        setTimeout(() => {
            this.otpCode = '';
            this.verificationId = '';
            this.sandboxOTPCode = '';
            this.isSandbox = false;
            this.step = 'email';
            this.errorMessage = '';
            this.successMessage = '';
            this.stepTransition = false;
            // Re-trigger email submission
            setTimeout(() => {
                this.handleEmailSubmit();
            }, 100);
        }, 300);
    }

    async performAutoLogin(loginToken) {
        try {
            const result = await performAutoLogin({ loginToken: loginToken });
            
            if (result.success && result.username && result.password) {
                // Submit login form to Experience Cloud login endpoint
                this.submitLoginForm(result.username, result.password, result.redirectUrl || '/s/');
            } else {
                // Login failed - show error
                this.errorMessage = result.message || 'Login failed. Please try again.';
                this.isLoading = false;
            }
        } catch (error) {
            console.error('Error during auto-login:', error);
            let errorMessage = 'An error occurred during login. Please try again.';
            
            if (error.body?.message) {
                errorMessage = error.body.message;
            } else if (error.message) {
                errorMessage = error.message;
            }
            
            this.errorMessage = errorMessage;
            this.isLoading = false;
        }
    }
    
    submitLoginForm(username, password, redirectUrl) {
        // Try multiple approaches for Experience Cloud login
        // Approach 1: Use the standard Salesforce login endpoint
        const baseUrl = window.location.origin;
        
        // Try the community login endpoint first
        let loginUrl = baseUrl + '/s/login';
        
        // Create a form and submit it to the Experience Cloud login endpoint
        const form = document.createElement('form');
        form.method = 'POST';
        form.action = loginUrl;
        form.style.display = 'none'; // Hide the form
        
        // Add username field (try both 'un' and 'username')
        const usernameInput = document.createElement('input');
        usernameInput.type = 'hidden';
        usernameInput.name = 'un';
        usernameInput.value = username;
        form.appendChild(usernameInput);
        
        // Add password field (try both 'pw' and 'password')
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
        console.log('Submitting login form to:', loginUrl);
        console.log('Username:', username);
        console.log('Redirect URL:', redirectUrl || '/s/');
        
        try {
            form.submit();
        } catch (error) {
            console.error('Form submission error:', error);
            // Fallback: try redirecting to home page with credentials in URL (not secure, but as last resort)
            // Actually, don't do this - it's insecure. Instead, show an error.
            this.errorMessage = 'Unable to complete login. Please contact support.';
            this.isLoading = false;
        }
    }

    redirectToCommunityHome() {
        // Get the current Experience Cloud site URL
        const siteUrl = window.location.origin;
        const communityPath = '/s'; // Standard Salesforce community path
        
        // Redirect to community home page
        window.location.href = `${siteUrl}${communityPath}/`;
    }

    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
}

