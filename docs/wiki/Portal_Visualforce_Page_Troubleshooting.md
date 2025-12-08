# Portal Visualforce Page Troubleshooting

## Issue: Page Still Redirects to Login After Adding to Site

If you've added the `PortalAutoLogin` Visualforce page to your Experience Cloud site but are still getting redirected to login, follow these steps:

### Step 1: Verify the Page is Added

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click on your site → **Administration**
3. Scroll to **Pages** section
4. Under **Visualforce Pages**, verify `PortalAutoLogin` is in the **Selected Pages** list
5. If not, add it and click **Save**

### Step 2: Publish the Site

**This is often the missing step!**

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click the dropdown next to your site → **Builder**
3. In the Experience Cloud Builder, click **Publish** (top right)
4. Wait for the publish to complete
5. Try accessing the page again

### Step 3: Verify Guest User Profile Permissions

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click on your site → **Administration**
3. Click **Members** in the left sidebar
4. Find the **Guest User Profile** (usually named something like "Client - Project Management Portal Guest User")
5. Click on the profile name
6. Go to **Apex Class Access** (or search for it)
7. Verify `PortalAutoLoginController` is in the **Enabled Apex Classes** list
8. If not, click **Edit**, add it, and **Save**

### Step 4: Verify Visualforce Page Access

1. Still in the Guest User Profile
2. Go to **Visualforce Page Access**
3. Verify `PortalAutoLogin` is in the **Enabled Visualforce Pages** list
4. If not, click **Edit**, add it, and **Save**

### Step 5: Clear Browser Cache

1. Open an **Incognito/Private** browser window
2. Navigate to: `https://milestoneconsulting--dev.sandbox.my.site.com/s/apex/PortalAutoLogin?token=test123`
3. You should see "Logging you in..." instead of being redirected to login

### Step 6: Check Site Status

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Verify your site status is **Published** (not "Under Construction")
3. If it's "Under Construction", you need to publish it (see Step 2)

### Step 7: Verify URL Format

Make sure you're using the correct URL format:
- ✅ Correct: `/s/apex/PortalAutoLogin?token=...`
- ❌ Wrong: `/apex/PortalAutoLogin?token=...` (missing `/s/`)

### Common Issues

1. **Site Not Published**: Most common issue - changes require publishing
2. **Profile Permissions**: Guest user profile doesn't have access to the Apex class or Visualforce page
3. **Browser Cache**: Old redirects cached in browser
4. **Site Status**: Site is in "Under Construction" mode

### Testing

After completing the steps above, test by:
1. Going through the full OTP login flow
2. Or directly accessing: `https://milestoneconsulting--dev.sandbox.my.site.com/s/apex/PortalAutoLogin?token=test123`

You should see the "Logging you in..." page, not a redirect to login.

