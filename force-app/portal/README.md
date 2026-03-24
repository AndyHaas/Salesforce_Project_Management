# Portal Package

This package directory contains all components related to the Experience Cloud portal functionality, including:

- **Custom Login Page** with OTP authentication
- **Experience Cloud Site** configuration
- **Portal Access Fields** on Contact and Account objects

## Contents

### Apex Classes
- `PortalLoginController` - Handles email verification and OTP login
- `PortalMessagingController` - Handles messaging functionality (sending, retrieving, searching messages)
- `PortalMessagingControllerTest` - Test class for messaging controller (70% coverage)

### Lightning Web Components
- `portalLogin` - Custom login component with email and OTP verification
- `portalMessaging` - Core messaging component for client-team communication
  - Features: Infinite scrolling, server-side search, file attachments, mentions, replies
  - Works in both Experience Cloud and Salesforce Lightning contexts
- `salesforceMessaging` - Wrapper component for Salesforce Lightning Experience

### Networks (Experience Cloud Sites)
- `Client - Project Management Portal` - Experience Cloud site configuration (`networks/Client - Project Management Portal.network-meta.xml`)

### Digital Experience bundle & config
- `digitalExperienceConfigs/Client_Project_Management_Portal1.digitalExperienceConfig-meta.xml`
- `digitalExperiences/site/Client_Project_Management_Portal1/` (bundle + `Client_Project_Management_Portal1.digitalExperience-meta.xml`)

### Permission sets
- `Client_Project_Management_Portal_User` — assign to portal users (lives in this package, not `force-app/main`)

### Custom Fields
- `Contact.Portal_Access_Enabled__c` - Checkbox to enable portal access for contacts
- `Account.Has_Portal_Access_Enabled_Contact__c` - Checkbox indicating account has enabled contacts

### Custom Objects
- `Message__c` - Messaging object for client-team communication
  - Supports context-aware messaging (Task, Project, Account)
  - Includes features: replies, mentions, file attachments, pinning, search
  - Auto-creates Contacts for Milestone team members (Users without ContactId)

### Message Channels
- `MessageUpdate__c` - Lightning Message Service channel for inter-component communication

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

Portal setup and dashboard context are documented in the [Project Task Dashboard Guide](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/client-guides/project-task-dashboard#portal-digital-experience-updates) (GitHub Wiki). For detailed portal configuration, refer to the Experience Cloud documentation in Salesforce Setup.

## Notes

- If deploy fails with **no CustomSite named `Client_Project_Management_Portal`**, that site record may exist only in the org. Retrieve it into this package:  
  `sf project retrieve start --metadata CustomSite:Client_Project_Management_Portal --target-org <alias>`  
  then redeploy `force-app/portal`.
- The portal fields on Contact and Account are included here so they can be excluded if portal functionality is not desired
- If you want to keep the fields but not the portal site, you can deploy just the fields from this package
- Platform Cache must be enabled in your org for OTP functionality to work

