# Portal Package Organization

All portal-related components have been organized into a separate package directory: `force-app/portal`

## Benefits

1. **Easy Inclusion/Exclusion**: Deploy portal components only when needed
2. **Clean Separation**: Portal functionality is clearly separated from core project management features
3. **Package Flexibility**: Can create packages with or without portal functionality
4. **No Breaking Changes**: Standard Salesforce DX structure is maintained

## Package Structure

```
force-app/portal/
├── README.md
└── main/
    └── default/
        ├── classes/
        │   ├── PortalLoginController.cls
        │   └── PortalLoginController.cls-meta.xml
        ├── lwc/
        │   └── portalLogin/
        │       ├── portalLogin.css
        │       ├── portalLogin.html
        │       ├── portalLogin.js
        │       └── portalLogin.js-meta.xml
        ├── networks/
        │   └── Client - Project Management Portal.network-meta.xml
        └── objects/
            ├── Account/
            │   └── fields/
            │       └── Has_Portal_Access_Enabled_Contact__c.field-meta.xml
            └── Contact/
                └── fields/
                    └── Portal_Access_Enabled__c.field-meta.xml
```

## Deployment Options

### Deploy Portal Only
```bash
sf project deploy start --source-dir force-app/portal
```

### Deploy Everything (Main + Portal)
```bash
sf project deploy start
```

### Deploy Main Package Only (No Portal)
```bash
sf project deploy start --source-dir force-app/main
```

## Package Creation

When creating packages:

- **With Portal**: Include both `force-app` and `force-app/portal` directories
- **Without Portal**: Include only `force-app/main` directory (exclude `force-app/portal`)

The `sfdx-project.json` is configured with two package directories:
- `force-app` (default: true) - Main package
- `force-app/portal` (default: false) - Portal package

## Notes

- The portal fields on Contact and Account are included in the portal package so they can be excluded if portal functionality is not desired
- If you want the fields but not the site, you can deploy just the objects from the portal package
- Platform Cache must be enabled for OTP functionality to work

