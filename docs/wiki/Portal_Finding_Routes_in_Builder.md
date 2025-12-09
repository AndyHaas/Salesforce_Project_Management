# Finding Routes in Experience Cloud Builder

## Where to Find Routes

Routes in Experience Cloud Builder can be found in different places depending on your site type and Salesforce version:

### Method 1: Left Sidebar Navigation

1. Open **Experience Cloud Builder**
2. Look in the **left sidebar** for:
   - **Routes** (most common)
   - **Navigation** (sometimes routes are here)
   - **Pages** (routes might be listed here)
   - **Site Map** (alternative location)

### Method 2: Settings Menu

1. In Experience Cloud Builder, click the **gear icon** (Settings) in the top right
2. Look for:
   - **Routes**
   - **Navigation Settings**
   - **Site Structure**

### Method 3: Top Navigation Bar

1. In Experience Cloud Builder, look at the **top navigation bar**
2. You might see tabs like:
   - **Pages**
   - **Routes**
   - **Components**
   - **Navigation**

### Method 4: Search/Quick Find

1. In Experience Cloud Builder, use **Ctrl+F** (or Cmd+F on Mac) to search
2. Search for "route" or "navigation"

## Why You Might Not See Routes

### 1. Different Site Template

Some Experience Cloud templates organize routes differently:
- **LWR (Lightning Web Runtime)** sites might call them "Pages" instead of "Routes"
- **Aura** sites typically have a "Routes" section
- **Classic** sites might use "Navigation"

### 2. Permissions

You might not have permission to edit routes:
- Check your user profile permissions
- Verify you're an admin or have Experience Cloud editing rights

### 3. Site Status

If the site is in "Under Construction" mode:
- Routes might be hidden or restricted
- Try publishing the site first

### 4. UI Version

Different Salesforce releases have different UIs:
- **Summer '24 and later**: Routes might be in "Pages" section
- **Spring '24 and earlier**: Routes were typically in left sidebar

## Alternative: Create Route via Pages

If you can't find "Routes", try creating it as a **Page**:

1. In Experience Cloud Builder, click **Pages** in the left sidebar
2. Click **+** (New Page)
3. Select **Standard Page** or **Custom Page**
4. Set the **URL** to `autologin`
5. Add the `portalAutoLogin` component to the page
6. Save

## Alternative: Use Existing Route

If creating a new route is difficult, you could:

1. Use an existing route (like `/s/home`)
2. Modify the home page component to check for a `token` parameter
3. If token exists, handle the auto-login logic

## What to Look For

When you find routes/pages, you should see:
- A list of existing routes (like `/login`, `/home`, etc.)
- A **+** button to create new routes
- Ability to edit route URLs and views

## Still Can't Find It?

1. **Check the Experience Cloud Builder version** - UI changes between releases
2. **Look for "Pages" instead of "Routes"** - Some templates use different terminology
3. **Check the top navigation** - Routes might be in a dropdown menu
4. **Try the search function** - Use browser search (Ctrl+F) to find "route" on the page

## Quick Test

Try this:
1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click **Builder** next to your site
3. Look for any of these in the left sidebar:
   - Routes
   - Pages
   - Navigation
   - Site Map
   - Structure

If none of these exist, the site template might have a different structure.

