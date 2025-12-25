# Portal Package Info

## Overview

The Portal Package (`force-app/portal/`) contains all components, controllers, and configuration needed for the Experience Cloud (formerly Community Cloud) portal functionality. This package enables client users to access project management information, communicate with the Milestone team, and manage their projects through a secure web portal.

**Location**: `force-app/portal/`

## Package Structure

```
force-app/portal/
├── main/
│   └── default/
│       ├── classes/          # Apex controllers and schedulers
│       ├── lwc/              # Lightning Web Components
│       ├── networks/         # Experience Cloud site configuration
│       ├── digitalExperiences/ # Site pages, routes, and themes
│       └── objects/          # Portal-specific custom objects
└── README.md                 # Package overview
```

## Components

### Lightning Web Components (12 components)

#### Authentication & Navigation
- **`portalLogin`** - Custom login component with email and OTP verification
  - Two-step authentication (email → OTP)
  - Branded UI matching Milestone Consulting design
  - Location: `force-app/portal/main/default/lwc/portalLogin/`

- **`passwordlessLogin`** - Alternative passwordless login component
  - Uses `Login_OTP__c` custom object
  - Compatible with External Apps Login license
  - Location: `force-app/portal/main/default/lwc/passwordlessLogin/`

- **`portalHeader`** - Portal header navigation component
  - Branded header with logo and navigation
  - Responsive design
  - Location: `force-app/portal/main/default/lwc/portalHeader/`

- **`portalFooter`** - Portal footer component
  - Footer with branding and links
  - Location: `force-app/portal/main/default/lwc/portalFooter/`

- **`portalCommon`** - Common utilities and helpers
  - Shared functionality across portal components
  - Location: `force-app/portal/main/default/lwc/portalCommon/`

#### Messaging
- **`portalMessaging`** - Core messaging component
  - Full-featured messaging with infinite scrolling
  - Server-side search, file attachments, mentions, replies
  - Works in both Experience Cloud and Salesforce contexts
  - Location: `force-app/portal/main/default/lwc/portalMessaging/`
  - See: [portalMessaging Component](portalMessaging_Component.md)

- **`portalMessageFeed`** - Read-only message feed component
  - Configurable message feed with limits
  - Reuses Portal Messaging logic
  - Location: `force-app/portal/main/default/lwc/portalMessageFeed/`

#### Project & Task Management
- **`homePage`** - Portal home page component
  - "Coming Soon" page with feature preview cards
  - Location: `force-app/portal/main/default/lwc/homePage/`

- **`projectDetail`** - Project detail view component
  - Displays project information and related tasks
  - Location: `force-app/portal/main/default/lwc/projectDetail/`

- **`portalTaskDetail`** - Task detail view component
  - Displays task information, status, and details
  - Location: `force-app/portal/main/default/lwc/portalTaskDetail/`

- **`portalTaskFiles`** - Task file attachments component
  - Displays and manages file attachments for tasks
  - Location: `force-app/portal/main/default/lwc/portalTaskFiles/`

- **`portalRecordList`** - Generic record list component
  - Displays lists of records (Accounts, Projects, Tasks)
  - Location: `force-app/portal/main/default/lwc/portalRecordList/`

### Apex Classes (11 classes)

#### Controllers
- **`PortalMessagingController`** - Main messaging controller
  - Handles message CRUD operations
  - Search, pagination, file attachments
  - Location: `force-app/portal/main/default/classes/Portal/PortalMessagingController.cls`
  - See: [PortalMessagingController](PortalMessagingController.md)

- **`PasswordlessLoginController`** - Passwordless login controller
  - OTP generation and verification
  - Email sending and user authentication
  - Location: `force-app/portal/main/default/classes/Portal/PasswordlessLoginController.cls`
  - See: [Portal Login Setup](Portal_Login_Setup.md)

- **`PortalLoginController`** - Alternative login controller
  - Email verification and OTP login
  - Location: `force-app/portal/main/default/classes/PortalLoginController.cls`

- **`HomePageController`** - Home page data controller
  - Provides data for home page component
  - Location: `force-app/portal/main/default/classes/Portal/HomePageController.cls`

- **`PortalProjectController`** - Project data controller
  - Retrieves project information for portal
  - Location: `force-app/portal/main/default/classes/Portal/PortalProjectController.cls`

- **`PortalTaskController`** - Task data controller
  - Retrieves task information for portal
  - Location: `force-app/portal/main/default/classes/Portal/PortalTaskController.cls`

- **`PortalRecordListController`** - Record list data controller
  - Generic controller for record lists
  - Location: `force-app/portal/main/default/classes/Portal/PortalRecordListController.cls`

#### Scheduled Jobs
- **`MessageNotificationScheduler`** - Email notification scheduler
  - Sends email notifications for unread messages
  - Runs every 5-10 minutes (configurable)
  - Location: `force-app/portal/main/default/classes/Portal/MessageNotificationScheduler.cls`
  - See: [MessageNotificationScheduler](MessageNotificationScheduler.md)

#### Test Classes
- **`PortalMessagingControllerTest`** - Messaging controller tests
- **`PasswordlessLoginControllerTest`** - Login controller tests
- **`MessageNotificationSchedulerTest`** - Scheduler tests

### Experience Cloud Site

**Network**: `Client - Project Management Portal`
- **Location**: `force-app/portal/main/default/networks/Client - Project Management Portal.network-meta.xml`
- **Site Name**: `Client_Project_Management_Portal1`
- **Type**: Experience Cloud (LWR - Lightning Web Runtime)

**Configuration**:
- Custom login page with OTP authentication
- Branded header and footer
- Custom theme matching Milestone Consulting design
- Routes configured for login, home, account, and project task pages

### Custom Objects

#### Login_OTP__c
- Stores temporary OTP codes for passwordless login
- Fields:
  - `Email__c` - User's email address
  - `Code__c` - 6-digit OTP code
  - `User__c` - Lookup to User
  - `Expires_At__c` - DateTime expiration
  - `Used__c` - Boolean indicating if used
- Location: `force-app/portal/main/default/objects/Login_OTP__c/`

#### Message__c
- Messaging object for client-team communication
- Supports context-aware messaging (Task, Project, Account)
- Includes features: replies, mentions, file attachments, pinning, search
- Location: `force-app/main/default/objects/Message__c/` (shared with main package)
- See: [Portal Messaging System](Portal_Messaging_System.md)

### Custom Fields

#### Contact Object
- **`Portal_Access_Enabled__c`** (Checkbox)
  - Enables portal access for contacts
  - Must be `true` for users to access portal
  - Location: `force-app/main/default/objects/Contact/fields/Portal_Access_Enabled__c.field-meta.xml`

#### Account Object
- **`Has_Portal_Access_Enabled_Contact__c`** (Checkbox)
  - Formula field indicating account has enabled contacts
  - Location: `force-app/main/default/objects/Account/fields/Has_Portal_Access_Enabled_Contact__c.field-meta.xml`

### Message Channels

- **`MessageUpdate__c`** - Lightning Message Service channel
  - Used for inter-component communication
  - Notifies components when messages are created/updated/deleted
  - Location: `force-app/main/default/messageChannels/MessageUpdate.messageChannel-meta.xml`

## Dependencies

### Required Salesforce Features
- **Experience Cloud** (formerly Community Cloud) license
- **Platform Cache** - Required for OTP functionality
- **Email Deliverability** - Must be enabled for OTP emails

### Required Custom Objects (from main package)
- `Project__c` - Project management object
- `Project_Task__c` - Task management object
- `Message__c` - Messaging object (shared)

### Required Permission Sets
- **`Client_Project_Management_Portal_User`** - Portal user access
- **`Project_Management_Team_Member`** - Team member access (for messaging)
- See: [Permission Sets](Permission_Sets.md)

## Deployment

### Deploy Portal Package Only

```bash
sf project deploy start --source-dir force-app/portal --target-org <org-alias>
```

### Deploy Everything (Main + Portal)

```bash
sf project deploy start --target-org <org-alias>
```

### Exclude Portal from Package

When creating a managed package, simply don't include the `force-app/portal` directory. The main package will deploy without portal functionality.

**Note**: If you want to keep portal fields but not the site, deploy only the fields:
```bash
sf project deploy start --source-dir force-app/main/default/objects/Contact/fields/Portal_Access_Enabled__c.field-meta.xml force-app/main/default/objects/Account/fields/Has_Portal_Access_Enabled_Contact__c.field-meta.xml
```

## Setup & Configuration

### Initial Setup

1. **Enable Platform Cache**
   - Navigate to **Setup > Platform Cache**
   - Enable and allocate cache (minimum 10 MB recommended)

2. **Configure Email Deliverability**
   - Navigate to **Setup > Email Administration > Deliverability**
   - Set "Access to Send Email" to **"All email"**

3. **Enable Portal Access for Contacts**
   - Set `Portal_Access_Enabled__c = true` for contacts that should have portal access
   - Ensure User records are linked to Contacts (`User.ContactId`)

4. **Assign Permission Sets**
   - Assign `Client_Project_Management_Portal_User` to portal users
   - Assign `Project_Management_Team_Member` to team members who need messaging access

5. **Configure Experience Cloud Site**
   - Activate the site: **Setup > Digital Experiences > All Sites**
   - Configure routes and pages
   - Set up login page with `portalLogin` component

6. **Schedule Message Notifications** (Optional)
   - See [MessageNotificationScheduler](MessageNotificationScheduler.md) for scheduling instructions

### Post-Deployment Configuration

1. **Customize Branding**
   - Update header/footer components with your branding
   - Modify CSS in component files
   - Update theme colors in Experience Cloud site settings

2. **Configure Routes**
   - Set up routes for login, home, account, and project pages
   - Configure navigation menu

3. **Test Portal Access**
   - Create test portal user
   - Test login flow
   - Verify messaging functionality
   - Test file attachments

## Usage Examples

### Adding Portal Login to Site

1. Navigate to **Setup > Digital Experiences > All Sites**
2. Select your site and click **Builder**
3. Go to **Pages > Login**
4. Add `portalLogin` component to the page
5. Save and publish

### Adding Messaging to Project Task Page

1. In Experience Cloud Builder, navigate to Project Task detail page
2. Add `portalMessaging` component
3. Configure component properties:
   - `related-task-id`: Auto-populated from record
4. Save and publish

### Adding Message Feed to Home Page

1. In Experience Cloud Builder, navigate to Home page
2. Add `portalMessageFeed` component
3. Configure properties:
   - `limitCount`: 5 (default)
   - `orderByField`: "CreatedDate"
   - `orderDirection`: "DESC"
4. Save and publish

## Package Size & Limits

### Component Count
- **Lightning Web Components**: 12
- **Apex Classes**: 11 (7 controllers, 1 scheduler, 3 test classes)
- **Custom Objects**: 1 (`Login_OTP__c`)
- **Custom Fields**: 2 (Contact and Account)
- **Experience Cloud Site**: 1

### API Usage Considerations
- OTP generation and email sending use API calls
- Message notifications use scheduled Apex (doesn't count against API limits)
- Platform Cache reduces database queries

## Maintenance

### Regular Tasks
1. **Monitor OTP Usage**: Review `Login_OTP__c` records for expired/unused codes
2. **Clean Up Old OTP Records**: Consider scheduled job to delete expired OTPs
3. **Monitor Message Notifications**: Check debug logs for notification scheduler
4. **Review Portal Access**: Periodically audit `Portal_Access_Enabled__c` field

### Updates & Enhancements
- Portal components are versioned with API version 65.0
- Test classes should be updated when adding new features
- Consider backward compatibility when updating components

## Troubleshooting

| Issue | Likely Cause | Resolution |
|-------|--------------|------------|
| Portal not accessible | Site not activated | Activate site in Setup > Digital Experiences |
| Login not working | Platform Cache not enabled | Enable Platform Cache in Setup |
| OTP emails not sent | Email deliverability disabled | Enable in Setup > Email Administration |
| Components not showing | Permission sets not assigned | Assign appropriate permission sets |
| Messaging not working | User missing ContactId | Ensure User.ContactId is set |
| Styling issues | Theme not configured | Configure Experience Cloud theme |

## Related Documentation

- **[Portal Login Setup](Portal_Login_Setup.md)**: Passwordless login configuration
- **[Portal Messaging System](Portal_Messaging_System.md)**: Messaging system overview
- **[portalMessaging Component](portalMessaging_Component.md)**: Messaging component details
- **[PortalMessagingController](PortalMessagingController.md)**: Messaging controller API
- **[MessageNotificationScheduler](MessageNotificationScheduler.md)**: Email notification setup
- **[Permission Sets](Permission_Sets.md)**: User access configuration
- **[Dashboard Guide](Dashboard_Guide.md)**: Overall system documentation

## File Locations Reference

### Key Directories
- **Components**: `force-app/portal/main/default/lwc/`
- **Controllers**: `force-app/portal/main/default/classes/Portal/`
- **Site Configuration**: `force-app/portal/main/default/networks/`
- **Digital Experience**: `force-app/portal/main/default/digitalExperiences/`
- **Custom Objects**: `force-app/portal/main/default/objects/`

### Configuration Files
- **Network**: `force-app/portal/main/default/networks/Client - Project Management Portal.network-meta.xml`
- **Site**: `force-app/portal/main/default/digitalExperiences/site/Client_Project_Management_Portal1/`
- **Routes**: `force-app/portal/main/default/digitalExperiences/site/Client_Project_Management_Portal1/sfdc_cms__route/`
- **Theme**: `force-app/portal/main/default/digitalExperiences/site/Client_Project_Management_Portal1/sfdc_cms__themeLayout/`

## Version Information

- **API Version**: 65.0
- **Package Type**: Unmanaged
- **Last Updated**: See git commit history

## Support & Resources

- **Salesforce Experience Cloud Documentation**: [Experience Cloud Setup](https://help.salesforce.com/s/articleView?id=sf.networks_setup.htm)
- **Lightning Web Components**: [LWC Developer Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- **Platform Cache**: [Platform Cache Documentation](https://developer.salesforce.com/docs/atlas.en-us.platform_cache.meta/platform_cache/)
