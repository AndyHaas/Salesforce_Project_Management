# Connected App Setup for Portal Auto-Login

## Overview

To enable REST API authentication for passwordless login in Experience Cloud, you need to create and configure a Connected App in Salesforce.

## Step 1: Create Connected App

1. Go to **Setup** > **App Manager**
2. Click **New Connected App**
3. Fill in the basic information:
   - **Connected App Name**: `Portal Auto-Login` (or your preferred name)
   - **API Name**: Auto-filled based on name
   - **Contact Email**: Your email address

## Step 2: Enable OAuth Settings

1. Scroll down to **API (Enable OAuth Settings)**
2. Check **Enable OAuth Settings**
3. Set **Callback URL** to:
   ```
   https://your-domain.my.salesforce.com/services/oauth2/success
   ```
   Or for Experience Cloud:
   ```
   https://your-site.my.site.com/services/oauth2/success
   ```
4. Under **Selected OAuth Scopes**, add:
   - `Access and manage your data (api)`
   - `Access unique user identifiers (openid)`
   - `Perform requests on your behalf at any time (refresh_token, offline_access)`
5. Check **Enable Username-Password Flow** (this is critical for server-side authentication)
6. **DO NOT** check "Require Secret for Web Server Flow" (we're using Username-Password flow)
7. Click **Save**

## Step 3: Get Consumer Key and Secret

1. After saving, you'll see the **Consumer Key** and **Consumer Secret**
2. **IMPORTANT**: Copy these values - you'll need them for configuration
3. The Consumer Secret is only shown once - save it securely

## Step 4: Configure Connected App Policies

1. Click **Manage** on your Connected App
2. Click **Edit Policies**
3. Under **OAuth Policies**:
   - **Permitted Users**: Select **All users may self-authorize** (or **Admin approved users are pre-authorized** if you want more control)
   - **IP Relaxation**: Select **Relax IP restrictions** (or configure specific IPs)
   - **Refresh Token Policy**: Select **Refresh token is valid until revoked**
4. Click **Save**

## Step 5: Assign Profiles (if using Admin approved users)

1. Click **Manage Profiles**
2. Select the profiles that should have access (e.g., Experience Cloud user profiles)
3. Click **Save**

## Step 6: Store Credentials Securely

You have two options for storing the Consumer Key and Secret:

### Option A: Custom Metadata Type (Recommended for Consumer Key)

1. Create a Custom Metadata Type called `Portal_Config`
2. Add a field `Connected_App_Consumer_Key__c` (Text)
3. Create a record with your Consumer Key value
4. Update `PortalLoginController.getConnectedAppConsumerKey()` to retrieve from Custom Metadata

### Option B: Named Credential (Recommended for Consumer Secret)

1. Go to **Setup** > **Named Credentials**
2. Create a new Named Credential
3. Set **Label**: `Portal_Connected_App`
4. Set **URL**: Your Salesforce instance URL
5. Set **Identity Type**: **Named Principal**
6. Set **Authentication Protocol**: **OAuth 2.0**
7. Set **Authentication Provider**: Your Connected App
8. This automatically handles the OAuth flow

### Option C: Protected Custom Settings (Simpler but less secure)

1. Create a Protected Custom Setting called `Portal_Config`
2. Add fields for Consumer Key and Secret
3. Store values there
4. Update the getter methods to retrieve from Custom Settings

## Step 7: Update Apex Code

The `PortalLoginController` class has placeholder methods:
- `getConnectedAppConsumerKey()` - Update to retrieve from your storage method
- `getConnectedAppConsumerSecret()` - Update to retrieve from your storage method

## Step 8: Test

1. Complete the OTP flow
2. The system should authenticate via REST API
3. User should be logged in and redirected to home page

## Security Considerations

- **Never** commit Consumer Key/Secret to version control
- Use Named Credentials for the Consumer Secret (most secure)
- Use Custom Metadata for the Consumer Key (less sensitive)
- Consider IP restrictions for additional security
- Regularly rotate credentials

## Troubleshooting

### Error: "invalid_client_id"
- Consumer Key is incorrect or not configured
- Check that the Connected App is active

### Error: "invalid_client"
- Consumer Secret is incorrect
- Check that Username-Password flow is enabled

### Error: "authentication failure"
- Username or password is incorrect
- Check that the user account is active

### Error: "insufficient access rights"
- Connected App policies don't allow the user
- Check Permitted Users setting and profile assignments

