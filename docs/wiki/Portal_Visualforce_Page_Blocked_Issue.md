# Visualforce Pages Blocked - ec=302 Redirect Issue

## Problem

Even after completing all setup steps, Visualforce pages redirect to login with `ec=302` error. This happens **before** any page code runs, indicating Experience Cloud is blocking access at the site level.

## Root Cause

Experience Cloud is blocking Visualforce page access at the site configuration level, not at the profile or page level.

## Solution Steps

### Step 1: Verify Pages Are Actually Added (Double-Check)

Sometimes the pages appear to be added but aren't actually saved:

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click your site → **Administration**
3. Scroll to **Pages** → **Visualforce Pages**
4. Click **Edit**
5. **Verify** `PortalAutoLogin` is in **Selected Pages** (right column)
6. If it's there, **remove it** (move back to Available)
7. **Save**
8. **Edit again**
9. **Add it back** to Selected Pages
10. **Save**
11. **Publish the site** (this is critical!)

### Step 2: Check Site Security Settings

There might be a security setting blocking Visualforce pages:

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click your site → **Administration**
3. Look for **Security** or **Access** settings
4. Check for any settings like:
   - "Block Visualforce Pages"
   - "Require Authentication for Visualforce"
   - "Guest Access Restrictions"
5. Ensure Visualforce pages are allowed for guest users

### Step 3: Verify URL Path Prefix

Check if your site has a URL path prefix that affects Visualforce access:

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click your site → **Administration**
3. Look for **URL Path Prefix** or **Site URL**
4. The URL should be: `/s/apex/PortalAutoLogin`
5. NOT: `/apex/PortalAutoLogin` (missing `/s/`)

### Step 4: Check Experience Cloud Builder Settings

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click **Builder** next to your site
3. In Experience Cloud Builder, check:
   - **Settings** (gear icon)
   - Look for **Security** or **Access** settings
   - Ensure Visualforce pages are enabled

### Step 5: Try Alternative URL Format

Sometimes the URL format matters. Try these variations:

1. `/s/apex/PortalAutoLogin?token=test`
2. `/apex/PortalAutoLogin?token=test` (without `/s/`)
3. Check your site's actual URL structure

### Step 6: Check Site Template/Theme

Some Experience Cloud templates restrict Visualforce page access:

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click **Builder** next to your site
3. Check what **Theme** or **Template** is being used
4. Some templates (like LWR) may have restrictions

### Step 7: Verify Site Type

Check if your site is configured as the right type:

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click your site → **Administration**
3. Check the site type/configuration
4. Ensure it's not set to "Lightning Web Runtime Only" or similar restriction

### Step 8: Check Guest User Profile - Site-Level Permissions

The guest user profile might have site-level restrictions:

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click your site → **Administration** → **Members**
3. Click on **Guest User Profile**
4. Look for **Site Permissions** or **Experience Cloud Permissions**
5. Ensure Visualforce pages are allowed

### Step 9: Try Creating a Route Instead

If Visualforce pages continue to be blocked, consider creating an Experience Cloud route:

1. In Experience Cloud Builder, go to **Routes**
2. Create a new route (e.g., `/auto-login`)
3. Point it to the Visualforce page
4. Access via: `/s/auto-login?token=...`

### Step 10: Check Debug Logs

Enable debug logs to see what's happening:

1. Go to **Setup** > **Debug Logs**
2. Create a new trace flag for the guest user
3. Try accessing the page
4. Check the debug log for errors

## Most Likely Causes

1. **Pages not actually saved** - Even though they appear in the list, they might not be persisted
2. **Site not republished** - After adding pages, site must be republished
3. **Site security settings** - A site-level setting blocking Visualforce access
4. **URL path prefix issue** - Wrong URL format for the site

## Nuclear Option: Recreate the Site Configuration

If nothing works, you might need to:
1. Note all your current site settings
2. Create a new Experience Cloud site
3. Migrate your content
4. Configure Visualforce pages from scratch

## Alternative Solution: Use LWC Instead

If Visualforce pages continue to be blocked, consider:
- Moving the auto-login logic to an LWC
- Using Apex to generate a session token
- Redirecting via JavaScript instead of Visualforce

