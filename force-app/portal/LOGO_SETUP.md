# Logo Setup Instructions

## Milestone Consulting Logos

You have two logo versions:
- **Black Logo**: For light backgrounds
- **White Logo**: For dark backgrounds

## Option 1: Using Content Assets (Recommended for LWR)

1. **Upload Logos to Salesforce CMS:**
   - Go to Experience Builder for your site
   - Navigate to **Content** → **Assets**
   - Upload both logo images (black and white versions)
   - Note the Content Asset IDs

2. **Configure in Theme Layout:**
   - The logos will be automatically available in the theme layout
   - Use the black logo for the main header (light background)
   - Use the white logo for dark sections if needed

## Option 2: Using Static Resources

1. **Add Image Files:**
   - Place `MilestoneLogo_Black.png` in: `force-app/portal/main/default/staticresources/`
   - Place `MilestoneLogo_White.png` in: `force-app/portal/main/default/staticresources/`

2. **Deploy:**
   ```bash
   sf project deploy start --source-dir force-app/portal/main/default/staticresources
   ```

3. **Reference in Code:**
   - Static Resources can be referenced as: `/resource/MilestoneLogo_Black`
   - However, for LWR sites, Content Assets are preferred

## Current Configuration

The theme layout is configured to use logos at:
- Desktop: `imageInfo` field in `scopedHeaderAndFooter/content.json`
- Mobile: `imageInfoMobile` field in `scopedHeaderAndFooter/content.json`

After uploading your logos, update the `imageInfo` fields with the Content Asset references.

