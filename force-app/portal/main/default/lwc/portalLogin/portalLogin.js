import { LightningElement, track } from 'lwc';
import verifyEmailAndSendOTP from '@salesforce/apex/PortalLoginController.verifyEmailAndSendOTP';
import verifyOTPAndLogin from '@salesforce/apex/PortalLoginController.verifyOTPAndLogin';
import { NavigationMixin } from 'lightning/navigation';

export default class PortalLogin extends NavigationMixin(LightningElement) {
    @track email = '';
    @track otpCode = '';
    @track verificationId = '';
    @track step = 'email'; // 'email' or 'otp'
    @track isLoading = false;
    @track errorMessage = '';
    @track successMessage = '';

    handleEmailChange(event) {
        this.email = event.target.value;
        this.errorMessage = '';
        this.successMessage = '';
    }

    handleOTPChange(event) {
        this.otpCode = event.target.value;
        this.errorMessage = '';
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
                this.step = 'otp';
                this.successMessage = result.message;
            } else {
                this.errorMessage = result.message;
            }
        } catch (error) {
            console.error('Error verifying email:', error);
            this.errorMessage = error.body?.message || 'An error occurred. Please try again.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleOTPSubmit() {
        if (!this.otpCode || this.otpCode.length !== 6) {
            this.errorMessage = 'Please enter the 6-digit verification code.';
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
                // Redirect to Experience Cloud login page with username pre-filled
                // If passwordless login is enabled in the org, the user won't need to enter a password
                // Otherwise, they'll need to enter their password
                this.redirectToLogin(result.username);
            } else {
                this.errorMessage = result.message;
            }
        } catch (error) {
            console.error('Error verifying OTP:', error);
            this.errorMessage = error.body?.message || 'An error occurred. Please try again.';
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToEmail() {
        this.step = 'email';
        this.otpCode = '';
        this.verificationId = '';
        this.errorMessage = '';
        this.successMessage = '';
    }

    handleResendOTP() {
        this.otpCode = '';
        this.verificationId = '';
        this.step = 'email';
        this.errorMessage = '';
        this.successMessage = '';
        // Re-trigger email submission
        setTimeout(() => {
            this.handleEmailSubmit();
        }, 100);
    }

    redirectToLogin(username) {
        // Get the current Experience Cloud site URL
        const siteUrl = window.location.origin;
        const communityPath = '/vforcesite'; // From network config
        
        // Redirect to the Experience Cloud login page
        // Note: In Experience Cloud, after OTP verification, we need to redirect to the standard login
        // The username is pre-filled, but the user may still need to enter password
        // Alternatively, we can use Site.login() from Apex if passwordless login is configured
        const loginUrl = `${siteUrl}${communityPath}/s/login?username=${encodeURIComponent(username)}`;
        
        // Redirect using window.location for external navigation
        window.location.href = loginUrl;
    }

    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    handleKeyPress(event) {
        if (event.key === 'Enter') {
            if (this.step === 'email') {
                this.handleEmailSubmit();
            } else if (this.step === 'otp') {
                this.handleOTPSubmit();
            }
        }
    }

    get showEmailStep() {
        return this.step === 'email';
    }

    get showOTPStep() {
        return this.step === 'otp';
    }
}

