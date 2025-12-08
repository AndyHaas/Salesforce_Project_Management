# Portal Visualforce Page Setup

## Problem
After OTP verification, users are redirected back to the login page with an `ec=302` error. This occurs because the `PortalAutoLogin` Visualforce page is not accessible to guest users in the Experience Cloud site.

## Solution
The `PortalAutoLogin` Visualforce page must be added to the Experience Cloud site's allowed pages.

## Steps to Fix

1. **Navigate to Experience Cloud Setup:**
   - Go to **Setup** > **Digital Experiences** > **All Sites**
   - Click on your site (e.g., "Client - Project Management Portal")

2. **Access Administration Settings:**
   - Click on **Administration** in the left sidebar
   - Scroll down to **Pages** section

3. **Add Visualforce Page:**
   - Under **Visualforce Pages**, click **Edit**
   - Find and select **PortalAutoLogin** from the available pages
   - Click **Add** to move it to the selected pages list
   - Click **Save**

4. **Verify Guest Access:**
   - Ensure the page is accessible to guest users
   - The page should appear in the list of allowed Visualforce pages

## Alternative: Using Experience Cloud Builder

1. **Open Experience Cloud Builder:**
   - Go to **Setup** > **Digital Experiences** > **All Sites**
   - Click **Builder** next to your site

2. **Add Visualforce Page:**
   - In the left sidebar, click **Pages**
   - Click **+** to create a new page
   - Select **Visualforce** as the page type
   - Choose **PortalAutoLogin** from the dropdown
   - Configure the page settings and save

## Testing

After adding the page:
1. Complete the OTP verification flow
2. You should be redirected to the `PortalAutoLogin` page
3. The page should automatically log you in and redirect to the home page (`/s/`)

If you still see redirects back to login, verify:
- The page is in the allowed pages list
- Guest user profile has access to the Visualforce page
- The page controller (`PortalAutoLoginController`) is accessible

