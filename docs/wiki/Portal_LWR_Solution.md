# LWR Site Solution - LWC Auto-Login

## Problem

LWR (Lightning Web Runtime) sites **do not support Visualforce pages**. This is why all Visualforce pages redirect with `ec=302` errors.

## Solution

We've created an **LWC-based auto-login component** that works with LWR sites.

## What Was Created

1. **`portalAutoLogin` LWC Component** - Handles auto-login by:
   - Retrieving credentials from Platform Cache
   - Submitting login form to Experience Cloud
   - Redirecting to home page

2. **Experience Cloud Route** - Needs to be created in Experience Cloud Builder:
   - Route: `/s/autologin`
   - View: Uses `portalAutoLogin` LWC component

## Setup Instructions

Since LWR sites have restrictions on metadata deployment for routes/views, you'll need to create the route manually:

### Step 1: Create the Route in Experience Cloud Builder

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click **Builder** next to your site
3. In Experience Cloud Builder, click **Routes** in the left sidebar
4. Click **+** (New Route)
5. Configure:
   - **URL**: `autologin`
   - **View**: Create new view or select existing
   - **Page Access**: Use Parent
6. Save

### Step 2: Add the LWC Component to the View

1. In the route you just created, click **Edit View**
2. Drag the **`portalAutoLogin`** component onto the page
3. Save and publish

### Step 3: Test

1. Complete OTP verification
2. You should be redirected to `/s/autologin?token=...`
3. The component will automatically log you in

## Alternative: Use Existing Route

If creating a new route is problematic, you could:
1. Use an existing route (like `/s/home`)
2. Pass the token as a URL parameter
3. Have the home page component check for the token and handle login

## Code Changes Made

- ✅ Created `portalAutoLogin` LWC component
- ✅ Updated `PortalLoginController` to return `/s/autologin` URL
- ✅ Updated `portalLogin` LWC to redirect to new route

## Files Created

- `force-app/portal/main/default/lwc/portalAutoLogin/portalAutoLogin.js`
- `force-app/portal/main/default/lwc/portalAutoLogin/portalAutoLogin.html`
- `force-app/portal/main/default/lwc/portalAutoLogin/portalAutoLogin.js-meta.xml`
- `force-app/portal/main/default/lwc/portalAutoLogin/portalAutoLogin.css`

## Next Steps

1. **Deploy the LWC component** (already done)
2. **Create the route in Experience Cloud Builder** (manual step)
3. **Test the login flow**

The LWC component is deployed and ready. You just need to create the route/view in the Experience Cloud Builder UI.

