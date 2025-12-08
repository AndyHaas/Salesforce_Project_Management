# Portal Authentication Approach

## Overview

We're implementing a **passwordless login** system for the Experience Cloud portal using **OTP (One-Time Password)** authentication. This is a standard web-based passwordless approach, **not** using Salesforce's headless authentication framework.

## Our Approach

### Flow:
1. **User enters email** → Custom LWC login page
2. **OTP sent via email** → Generated and stored in Platform Cache
3. **User enters OTP** → Verified against cache
4. **Temporary password generated** → Set for user account
5. **Auto-login via Visualforce page** → Uses `Site.login()` to authenticate
6. **User redirected to home** → Logged in session

### Components:
- **`portalLogin` LWC** - Custom login UI with email and OTP input
- **`PortalLoginController` Apex** - Handles OTP generation, verification, and temporary password creation
- **`PortalAutoLogin` Visualforce Page** - Performs the actual login using `Site.login()`
- **Platform Cache** - Stores OTP and temporary credentials securely

## Why NOT Headless Authentication?

**Headless Authentication** is designed for:
- Mobile apps
- Single Page Applications (SPAs)
- API-based authentication flows
- Custom authentication UIs outside Salesforce

**Our use case:**
- Traditional web portal
- Experience Cloud site
- Standard browser-based login
- Custom login page within Salesforce

## Best Practices

✅ **What we're doing right:**
- Using OTP for passwordless authentication
- Storing credentials securely in Platform Cache with TTL
- Clearing cache after login for security
- Using `Site.login()` in proper Visualforce context
- Custom login page for better UX

✅ **Standard approach:**
- This is a common pattern for passwordless login in Experience Cloud
- Similar to how many organizations implement OTP-based authentication
- Uses Salesforce's built-in authentication mechanisms

## Configuration Notes

### What we DON'T need:
- ❌ Headless Authentication Handler (`Auth.HeadlessUserDiscoveryHandler`)
- ❌ Headless Login settings in Experience Cloud
- ❌ Custom authentication providers
- ❌ OAuth flows

### What we DO need:
- ✅ Platform Cache enabled
- ✅ Visualforce pages added to Experience Cloud site
- ✅ Guest user profile permissions
- ✅ Site published (not "Under Construction")

## If You See Headless Errors

If you encounter errors about "Auth.HeadlessUserDiscoveryHandler" or headless authentication:

1. **Don't enable headless login** in Experience Cloud settings
2. **Ignore headless-related configuration** - we don't need it
3. **Focus on**:
   - Adding Visualforce pages to the site
   - Publishing the site
   - Setting guest user profile permissions

## Alternative Approaches (Not Using)

### Headless Authentication
- Requires implementing `Auth.HeadlessUserDiscoveryHandler`
- Designed for API/mobile authentication
- More complex setup
- **Not needed for our use case**

### OAuth Flows
- For third-party integrations
- More complex token management
- **Not needed for our use case**

### Custom Auth Providers
- For SSO or external identity providers
- **Not needed for our use case**

## Summary

Our passwordless login implementation is:
- ✅ **Standard** - Common pattern for Experience Cloud
- ✅ **Secure** - Uses Platform Cache with TTL
- ✅ **Simple** - No complex authentication frameworks needed
- ✅ **Maintainable** - Uses standard Salesforce features

We do **NOT** need headless authentication for this implementation.

