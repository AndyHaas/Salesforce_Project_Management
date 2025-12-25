# Portal Login Setup

## Overview

The Portal Login system provides passwordless authentication for Experience Cloud portal users using One-Time Password (OTP) verification via email. This eliminates the need for users to remember passwords and provides a secure, user-friendly login experience.

**Location**: `force-app/portal/main/default/`

## Key Features

1. **Passwordless Authentication**: Users log in using email and OTP code instead of passwords
2. **Email Verification**: OTP codes are sent to the user's registered email address
3. **Secure OTP Generation**: 6-digit codes with expiration (10 minutes)
4. **User-Friendly Interface**: Two-step process (email entry → OTP verification)
5. **Automatic User Lookup**: Finds users by email and Contact relationship
6. **Security Best Practices**: Doesn't reveal user existence in error messages

## Components

### Lightning Web Component

**`portalLogin`** (`force-app/portal/main/default/lwc/portalLogin/`)
- Two-step login interface
- Email entry step
- OTP verification step
- Error handling and validation
- Responsive design matching Milestone Consulting branding

### Apex Controller

**`PasswordlessLoginController`** (`force-app/portal/main/default/classes/Portal/PasswordlessLoginController.cls`)
- Handles email verification and OTP generation
- Sends OTP emails
- Verifies OTP codes
- Manages temporary password generation for authentication
- Uses `without sharing` to allow portal user access

### Custom Object

**`Login_OTP__c`** (`force-app/portal/main/default/objects/Login_OTP__c/`)
- Stores OTP codes temporarily
- Tracks expiration and usage
- Fields:
  - `Email__c`: User's email address
  - `Code__c`: 6-digit OTP code
  - `User__c`: Lookup to User
  - `Expires_At__c`: DateTime when OTP expires
  - `Used__c`: Boolean indicating if OTP has been used

## Authentication Flow

### Step 1: Email Entry
1. User enters their email address
2. System validates email format
3. System looks up Contact by email with `Portal_Access_Enabled__c = true`
4. System finds associated User by ContactId
5. System generates 6-digit OTP code
6. System stores OTP in `Login_OTP__c` with 10-minute expiration
7. System sends OTP code via email to user
8. User proceeds to OTP verification step

### Step 2: OTP Verification
1. User enters 6-digit OTP code received via email
2. System validates OTP code format
3. System retrieves OTP record from `Login_OTP__c`
4. System verifies:
   - OTP code matches
   - OTP has not expired
   - OTP has not been used
5. System marks OTP as used
6. System generates temporary secure password
7. System sets temporary password for user
8. System redirects user to Experience Cloud login with username pre-filled
9. User completes login (may need to enter password if passwordless login not fully configured)

## Setup Requirements

### 1. Platform Cache

**Required**: Platform Cache must be enabled in your Salesforce org.

**Setup**:
1. Navigate to **Setup > Platform Cache**
2. Enable Platform Cache
3. Allocate cache size (minimum recommended: 10 MB)

**Why**: OTP codes are stored temporarily and Platform Cache provides fast, secure storage.

### 2. Custom Fields

**Contact Object**:
- `Portal_Access_Enabled__c` (Checkbox) - Must be `true` for users to access portal

**Setup**:
1. Ensure `Portal_Access_Enabled__c` field exists on Contact
2. Set `Portal_Access_Enabled__c = true` for contacts that should have portal access
3. Users must have a Contact record with this field enabled

### 3. User Configuration

**Requirements**:
- User must have an associated Contact record
- Contact must have `Portal_Access_Enabled__c = true`
- Contact.Email must match User.Email
- User must be active (`IsActive = true`)
- User must have appropriate Experience Cloud license

### 4. Email Configuration

**Email Deliverability**:
1. Navigate to **Setup > Email Administration > Deliverability**
2. Set "Access to Send Email" to **"All email"**
3. Ensure email templates are configured (if using custom templates)

**Email Templates** (Optional):
- Customize OTP email template in **Setup > Email Templates**
- Default email includes OTP code and expiration time

### 5. Experience Cloud Site Configuration

**Login Route**:
1. Navigate to **Setup > Digital Experiences > All Sites**
2. Select your Experience Cloud site
3. Go to **Builder > Routes**
4. Configure login route to use `portalLogin` component

**Component Placement**:
- Place `portalLogin` component on the login page
- Ensure component has proper styling and layout

## Configuration

### OTP Expiration

**Default**: 10 minutes

**Location**: `PasswordlessLoginController.cls`
```apex
private static final Integer OTP_EXPIRATION_MINUTES = 10;
```

**To Change**: Modify the constant in the controller class.

### Email Template

The OTP email is sent using `Messaging.SingleEmailMessage`. To customize:

1. Navigate to **Setup > Email Templates**
2. Create a new email template
3. Update `sendOTPEmail()` method in `PasswordlessLoginController` to use template

### Redirect URL

**Default**: Home page (`/`)

**Location**: `PasswordlessLoginController.cls`
```apex
private static final String DEFAULT_START_URL = '/';
```

**To Change**: Modify the constant in the controller class.

## Security Considerations

### Best Practices Implemented

1. **No User Enumeration**: Error messages don't reveal if an email exists in the system
2. **OTP Expiration**: Codes expire after 10 minutes
3. **Single Use**: OTP codes can only be used once
4. **Secure Password Generation**: Temporary passwords use secure random generation
5. **Input Validation**: Email format and OTP code format are validated
6. **Rate Limiting**: Consider implementing rate limiting for OTP requests (future enhancement)

### Security Recommendations

1. **Monitor OTP Usage**: Review `Login_OTP__c` records for suspicious activity
2. **Email Security**: Ensure email delivery is secure and not intercepted
3. **Session Management**: Consider implementing session timeout policies
4. **Audit Trail**: Monitor login attempts and OTP usage in debug logs

## Troubleshooting

| Issue | Likely Cause | Resolution |
|-------|--------------|------------|
| OTP not received | Email deliverability settings | Check Setup > Email Administration > Deliverability |
| "No active contact found" | Contact missing or `Portal_Access_Enabled__c = false` | Verify Contact exists and field is enabled |
| "User not found" | User not linked to Contact | Ensure User.ContactId is set |
| OTP expired | User took too long to enter code | Request new OTP code |
| OTP already used | Code was already used | Request new OTP code |
| Platform Cache error | Platform Cache not enabled | Enable Platform Cache in Setup |
| Login redirect fails | Experience Cloud site URL incorrect | Verify site URL in component code |

## Testing

### Test Class

**Location**: `force-app/portal/main/default/classes/Portal/PasswordlessLoginControllerTest.cls`

**Coverage**: Comprehensive test coverage including:
- Email validation
- OTP generation and storage
- OTP expiration
- OTP verification
- Error handling
- Email sending

**Running Tests**:
```bash
sf apex run test --class-names PasswordlessLoginControllerTest --target-org <org-alias>
```

### Manual Testing

1. **Test Email Entry**:
   - Enter valid email with `Portal_Access_Enabled__c = true`
   - Verify OTP email is received
   - Check `Login_OTP__c` record is created

2. **Test OTP Verification**:
   - Enter correct OTP code
   - Verify successful login redirect
   - Check OTP record is marked as used

3. **Test Error Cases**:
   - Invalid email format
   - Email not in system
   - Expired OTP
   - Used OTP
   - Invalid OTP code

## Customization

### Styling

The `portalLogin` component uses custom CSS matching Milestone Consulting branding:
- Primary blue: `#355d7c`
- Secondary blue: `#4d86b2`
- Accent orange: `#f59e0b`

**Location**: `force-app/portal/main/default/lwc/portalLogin/portalLogin.css`

### Component Layout

The component uses a two-step card layout:
- Step 1: Email entry form
- Step 2: OTP verification form

**Location**: `force-app/portal/main/default/lwc/portalLogin/portalLogin.html`

## Related Documentation

- **[Dashboard Guide](Dashboard_Guide.md)**: Portal configuration overview
- **[Permission Sets](Permission_Sets.md)**: User access configuration
- **[Portal Package README](../force-app/portal/README.md)**: Portal component overview

## Related Files

### Apex Classes
- `force-app/portal/main/default/classes/Portal/PasswordlessLoginController.cls`
- `force-app/portal/main/default/classes/Portal/PasswordlessLoginControllerTest.cls`

### Lightning Web Components
- `force-app/portal/main/default/lwc/portalLogin/portalLogin.js`
- `force-app/portal/main/default/lwc/portalLogin/portalLogin.html`
- `force-app/portal/main/default/lwc/portalLogin/portalLogin.css`

### Custom Objects
- `force-app/portal/main/default/objects/Login_OTP__c/`

### Custom Fields
- `force-app/main/default/objects/Contact/fields/Portal_Access_Enabled__c.field-meta.xml`

## Future Enhancements

Potential improvements for future releases:
- Rate limiting for OTP requests
- SMS OTP option (in addition to email)
- Remember device functionality
- Multi-factor authentication integration
- Custom email templates
- OTP resend with cooldown period
- Login attempt logging and monitoring
