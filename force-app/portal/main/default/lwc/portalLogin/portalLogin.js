import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import verifyEmailAndSendOTP from '@salesforce/apex/PortalLoginController.verifyEmailAndSendOTP';
import verifyOTPAndLogin from '@salesforce/apex/PortalLoginController.verifyOTPAndLogin';

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
                
                // Transition effect before redirect
                this.stepTransition = true;
                
                // Redirect to community home page
                // Note: For true passwordless login, additional authentication setup is needed
                setTimeout(() => {
                    this.redirectToCommunityHome();
                }, 500);
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

    redirectToCommunityHome() {
        // Get the current Experience Cloud site URL
        const siteUrl = window.location.origin;
        const communityPath = '/s'; // Standard Salesforce community path
        
        // Redirect to community home page
        // After OTP verification, redirect to the home page
        // Note: For true passwordless login, you may need to implement
        // additional authentication using Site.login() or Auth.SessionManagement
        window.location.href = `${siteUrl}${communityPath}/`;
    }

    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
}

