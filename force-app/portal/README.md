# Portal Package

This package directory contains all components related to the Experience Cloud portal functionality, including:

- **Custom Login Page** with OTP authentication
- **Experience Cloud Site** configuration
- **Portal Access Fields** on Contact and Account objects

## Contents

### Apex Classes
- `PortalLoginController` - Handles email verification and OTP login

### Lightning Web Components
- `portalLogin` - Custom login component with email and OTP verification

### Networks (Experience Cloud Sites)
- `Client - Project Management Portal` - Experience Cloud site configuration

### Custom Fields
- `Contact.Portal_Access_Enabled__c` - Checkbox to enable portal access for contacts
- `Account.Has_Portal_Access_Enabled_Contact__c` - Checkbox indicating account has enabled contacts

## Deployment

### Deploy Portal Components Only
```bash
sf project deploy start --source-dir force-app/portal
```

### Deploy Everything (Main + Portal)
```bash
sf project deploy start
```

### Exclude Portal from Package
When creating a package, simply don't include the `force-app/portal` directory. The main package will deploy without portal functionality.

## Setup

See `PORTAL_LOGIN_SETUP.md` in the root directory for complete setup instructions.

## Notes

- The portal fields on Contact and Account are included here so they can be excluded if portal functionality is not desired
- If you want to keep the fields but not the portal site, you can deploy just the fields from this package
- Platform Cache must be enabled in your org for OTP functionality to work

