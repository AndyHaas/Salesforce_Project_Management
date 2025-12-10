import { LightningElement, track } from 'lwc';
import startPasswordlessLogin from '@salesforce/apex/PasswordlessLoginController.startPasswordlessLogin';
import verifyPasswordlessLogin from '@salesforce/apex/PasswordlessLoginController.verifyPasswordlessLogin';

export default class PasswordlessLogin extends LightningElement {
    @track email = '';
    @track otpCode = '';
    @track userId = null;
    @track identifier = null; // Login_OTP__c record ID returned from startPasswordlessLogin
    @track step = 'identify'; // 'identify' or 'verify'
    @track isLoading = false;
    @track errorMessage = '';
    @track successMessage = '';
    @track displayOtpCode = ''; // OTP code to display in sandbox

    get showIdentifyStep() {
        return this.step === 'identify';
    }

    get showVerifyStep() {
        return this.step === 'verify';
    }

    handleEmailChange(event) {
        this.email = event.target.value;
        this.errorMessage = '';
        this.successMessage = '';
    }

    handleOTPChange(event) {
        // Auto-format: only allow digits, limit to 6 digits
        let value = event.target.value.replace(/\D/g, '');
        value = value.substring(0, 6);
        this.otpCode = value;
        this.errorMessage = '';
    }

    handleKeyPress(event) {
        // Allow Enter key to submit
        if (event.key === 'Enter' && !this.isLoading) {
            if (this.step === 'identify') {
                this.handleSendCode();
            } else if (this.step === 'verify') {
                this.handleVerifyAndLogin();
            }
        }
    }

    async handleSendCode() {
        // Validate email
        if (!this.email || !this.isValidEmail(this.email)) {
            this.errorMessage = 'Please enter a valid email address.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            // Call Apex to start passwordless login
            const result = await startPasswordlessLogin({ 
                email: this.email
            });

            if (result.success) {
                // Store both userId and identifier (OTP record ID) for verification step
                this.userId = result.userId;
                this.identifier = result.identifier;
                this.successMessage = result.message || 'A verification code has been sent to your email address.';
                
                // If in sandbox, store the OTP code for display
                if (result.otpCode) {
                    this.displayOtpCode = result.otpCode;
                    console.log('PasswordlessLogin: Sandbox detected - OTP code:', this.displayOtpCode);
                }
                
                console.log('PasswordlessLogin: User ID:', this.userId);
                console.log('PasswordlessLogin: Identifier (OTP Record ID):', this.identifier);
                
                // Transition to verify step
                setTimeout(() => {
                    this.step = 'verify';
                    this.errorMessage = '';
                    // Focus on OTP input
                    setTimeout(() => {
                        const otpInput = this.template.querySelector('lightning-input[data-otp-input]');
                        if (otpInput) {
                            otpInput.focus();
                        }
                    }, 100);
                }, 500);
            } else {
                this.errorMessage = result.message || 'Failed to send verification code. Please try again.';
            }
        } catch (error) {
            console.error('Error starting passwordless login:', error);
            console.error('Error details:', JSON.stringify(error, null, 2));
            
            // Extract user-friendly error message
            let errorMsg = 'An error occurred. Please try again.';
            if (error.body?.message) {
                errorMsg = error.body.message;
            } else if (error.message) {
                errorMsg = error.message;
            }
            
            this.errorMessage = errorMsg;
        } finally {
            this.isLoading = false;
        }
    }

    async handleVerifyAndLogin() {
        // Validate OTP
        if (!this.otpCode || this.otpCode.length !== 6) {
            this.errorMessage = 'Please enter the 6-digit verification code.';
            return;
        }

        if (!this.userId) {
            this.errorMessage = 'Session expired. Please start over.';
            this.step = 'identify';
            return;
        }

        if (!this.identifier) {
            this.errorMessage = 'Verification session expired. Please start over.';
            this.step = 'identify';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = 'Verifying code...';

        try {
            // Call Apex to verify OTP and complete login
            // Pass userId, identifier (OTP record ID), and otpCode
            const result = await verifyPasswordlessLogin({ 
                userId: this.userId,
                identifier: this.identifier,
                otpCode: this.otpCode
            });

            if (result.success) {
                this.successMessage = result.message || 'Verification successful. Logging you in...';
                
                // Redirect to the URL returned from verifyPasswordlessLogin
                if (result.redirectUrl) {
                    console.log('PasswordlessLogin: Redirecting to:', result.redirectUrl);
                    // Small delay to show success message, then redirect
                    setTimeout(() => {
                        window.location.href = result.redirectUrl;
                    }, 1000);
                } else {
                    // Fallback: redirect to home page
                    console.log('PasswordlessLogin: No redirect URL, using fallback');
                    setTimeout(() => {
                        window.location.href = '/s/';
                    }, 1000);
                }
            } else {
                this.errorMessage = result.message || 'Invalid verification code. Please try again.';
                this.successMessage = '';
            }
        } catch (error) {
            console.error('Error verifying passwordless login:', error);
            console.error('Error details:', JSON.stringify(error, null, 2));
            
            // Extract user-friendly error message
            let errorMsg = 'Invalid verification code. Please try again.';
            if (error.body?.message) {
                errorMsg = error.body.message;
            } else if (error.message) {
                errorMsg = error.message;
            }
            
            this.errorMessage = errorMsg;
            this.successMessage = '';
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToIdentify() {
        this.otpCode = '';
        this.userId = null;
        this.identifier = null;
        this.displayOtpCode = '';
        this.step = 'identify';
        this.errorMessage = '';
        this.successMessage = '';
    }
    
    get showSandboxOtp() {
        return this.displayOtpCode && this.displayOtpCode.length > 0;
    }

    handleResendCode() {
        // Reset and go back to identify step, then automatically resend
        this.handleBackToIdentify();
        setTimeout(() => {
            this.handleSendCode();
        }, 300);
    }

    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
}
