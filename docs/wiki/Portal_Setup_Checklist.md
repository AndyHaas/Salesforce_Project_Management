# Portal Setup Checklist - Step by Step

## Problem: Visualforce Page Redirects to Login (ec=302)

If `PortalAutoLogin` redirects to login instead of showing "Logging you in...", follow this checklist in order.

---

## ✅ Step 1: Verify Visualforce Page Exists

**Check:** Does the page exist in your org?

1. Go to **Setup** > **Apex Pages** (or search "Apex Pages")
2. Look for **PortalAutoLogin**
3. ✅ Should see it in the list
4. ❌ If not found → The page wasn't deployed. Deploy it first.

---

## ✅ Step 2: Add Visualforce Page to Experience Cloud Site

**Check:** Is the page added to your site's allowed pages?

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click on **"Client - Project Management Portal"** (or your site name)
3. Click **Administration** in the left sidebar
4. Scroll down to **Pages** section
5. Under **Visualforce Pages**, click **Edit**
6. Look for **PortalAutoLogin** in the **Selected Pages** list
   - ✅ If it's there → Good, move to Step 3
   - ❌ If it's NOT there:
     - Find it in **Available Pages** (left side)
     - Select it
     - Click **Add** (or arrow button)
     - It should move to **Selected Pages** (right side)
     - Click **Save**

---

## ✅ Step 3: Publish the Site

**CRITICAL:** Changes don't take effect until the site is published!

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click the **dropdown arrow** next to your site
3. Click **Builder**
4. In Experience Cloud Builder, look at the **top right**
5. Click **Publish** button
6. Wait for "Published successfully" message
7. ✅ Site status should now be **Published** (not "Under Construction")

**Note:** You can also check status at:
- **Setup** > **Digital Experiences** > **All Sites** > Your site
- Look at the **Status** column - should say **Published**

---

## ✅ Step 4: Verify Guest User Profile - Apex Class Access

**Check:** Does the guest user profile have access to the controller?

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Click on your site → **Administration**
3. Click **Members** in the left sidebar
4. Find **Guest User Profile** (usually named like "Client - Project Management Portal Guest User")
5. **Click on the profile name** (this opens the profile)
6. In the profile, search for **"Apex Class Access"** (or scroll to find it)
7. Click **Apex Class Access**
8. Look for **PortalAutoLoginController** in the **Enabled Apex Classes** list
   - ✅ If it's there → Good, move to Step 5
   - ❌ If it's NOT there:
     - Click **Edit**
     - Find **PortalAutoLoginController** in **Available Apex Classes**
     - Select it and click **Add** (or use arrow)
     - Click **Save**

---

## ✅ Step 5: Verify Guest User Profile - Visualforce Page Access

**Check:** Does the guest user profile have access to the Visualforce page?

1. Still in the Guest User Profile (from Step 4)
2. Search for **"Visualforce Page Access"** (or scroll to find it)
3. Click **Visualforce Page Access**
4. Look for **PortalAutoLogin** in the **Enabled Visualforce Pages** list
   - ✅ If it's there → Good, move to Step 6
   - ❌ If it's NOT there:
     - Click **Edit**
     - Find **PortalAutoLogin** in **Available Visualforce Pages**
     - Select it and click **Add** (or use arrow)
     - Click **Save**

---

## ✅ Step 6: Verify Platform Cache is Enabled

**Check:** Is Platform Cache enabled and working?

1. Go to **Setup** > **Platform Cache** (or search "Platform Cache")
2. Check if **PortalOTPCache** partition exists
3. Verify it has allocated capacity (should be > 0)
4. ✅ If it exists and has capacity → Good
5. ❌ If not → Platform Cache needs to be set up first

---

## ✅ Step 7: Test in Incognito/Private Window

**Important:** Test as a guest user, not as yourself!

1. Open a **new Incognito/Private** browser window
2. Navigate to: `https://milestoneconsulting--dev.sandbox.my.site.com/s/apex/PortalAutoLogin?token=test123`
3. **Expected Result:**
   - ✅ Should see "Logging you in..." page
   - ❌ If redirected to login → One of the steps above is missing

---

## 🔍 Common Issues

### Issue 1: "Page not found" or "Invalid page"
- **Cause:** Page not added to site (Step 2)
- **Fix:** Add page to site's Visualforce Pages list

### Issue 2: Redirects to login (ec=302)
- **Cause:** Site not published (Step 3) OR profile permissions missing (Steps 4-5)
- **Fix:** Publish site AND verify profile permissions

### Issue 3: "Insufficient privileges" error
- **Cause:** Guest user profile doesn't have Apex class access (Step 4)
- **Fix:** Add PortalAutoLoginController to guest user profile

### Issue 4: Page loads but shows error
- **Cause:** Platform Cache not enabled or controller can't access cache (Step 6)
- **Fix:** Enable Platform Cache and verify partition exists

---

## 📋 Quick Verification Checklist

Print this out and check each item:

- [ ] PortalAutoLogin Visualforce page exists in org
- [ ] PortalAutoLogin added to site's Visualforce Pages list
- [ ] Site is Published (not "Under Construction")
- [ ] PortalAutoLoginController added to Guest User Profile → Apex Class Access
- [ ] PortalAutoLogin added to Guest User Profile → Visualforce Page Access
- [ ] Platform Cache enabled and PortalOTPCache partition exists
- [ ] Tested in incognito window - page loads (not redirected)

---

## 🎯 Most Common Problem

**90% of the time, the issue is:**
1. Site is not published (Step 3) - **Most common!**
2. Guest user profile doesn't have Apex class access (Step 4)

**Fix these two first, then test again.**

---

## Need Help?

If you've completed all steps and still have issues:
1. Check browser console for errors (F12 → Console tab)
2. Check Salesforce debug logs for errors
3. Verify you're testing in incognito mode (not logged in)
4. Make sure you're using the correct URL format: `/s/apex/PortalAutoLogin?token=...`

