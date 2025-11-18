# Development Guide

Guide for developers extending and customizing the Milestone Task Management System.

## Table of Contents

1. [Development Environment Setup](#development-environment-setup)
2. [Project Structure](#project-structure)
3. [Development Workflow](#development-workflow)
4. [Coding Standards](#coding-standards)
5. [Testing](#testing)
6. [Deployment](#deployment)
7. [Extending the System](#extending-the-system)

## Development Environment Setup

### Prerequisites

- **Node.js**: Version 14.x or later
- **Salesforce CLI**: Latest version
- **Git**: For version control
- **VS Code**: Recommended IDE
- **VS Code Extensions**:
  - Salesforce Extension Pack
  - ESLint
  - Prettier

### Initial Setup

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd Milestone-Task-Management
   ```

2. **Install Dependencies**
   ```bash
   npm install
   ```

3. **Authenticate with Salesforce**
   ```bash
   sf org login web --alias dev
   ```

4. **Open in VS Code**
   ```bash
   code .
   ```

### VS Code Configuration

The project includes configuration for:
- ESLint (code linting)
- Prettier (code formatting)
- Jest (unit testing)
- Salesforce extensions

## Project Structure

```
Milestone-Task-Management/
””” force-app/
”‚   ”””” main/
”‚       ”””” default/
”‚           ””” classes/          # Apex classes
”‚           ””” lwc/              # Lightning Web Components
”‚           ””” triggers/         # Apex triggers
”‚           ””” objects/          # Custom objects and fields
”‚           ””” flows/            # Lightning Flows
”‚           ””” flexipages/       # Lightning pages
”‚           ””” permissionsets/   # Permission sets
”‚           ”””” ...
””” scripts/                      # Utility scripts
””” wiki/                         # Documentation
””” package.json                  # Node.js dependencies
””” sfdx-project.json            # Salesforce project config
”””” README.md                     # Project README
```

## Development Workflow

### Creating a New Feature

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/new-feature
   ```

2. **Develop Feature**
   - Write code
   - Write tests
   - Update documentation

3. **Test Locally**
   ```bash
   npm test
   npm run lint
   ```

4. **Deploy to Scratch Org**
   ```bash
   sf project deploy start
   ```

5. **Test in Scratch Org**
   - Manual testing
   - Automated tests

6. **Commit Changes**
   ```bash
   git add .
   git commit -m "Add new feature"
   ```

7. **Push and Create PR**
   ```bash
   git push origin feature/new-feature
   ```

### Code Review Process

1. Create pull request
2. Code review by team
3. Address feedback
4. Merge to main branch

## Coding Standards

### Apex Code Standards

#### Naming Conventions

- **Classes**: PascalCase (e.g., `TaskProgressCalculator`)
- **Methods**: camelCase (e.g., `calculateProgress`)
- **Variables**: camelCase (e.g., `taskList`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_RECORDS`)

#### Code Structure

```apex
public with sharing class ExampleClass {
    // Constants
    private static final Integer MAX_RECORDS = 1000;
    
    // Public methods
    public static void publicMethod() {
        // Implementation
    }
    
    // Private helper methods
    private static void helperMethod() {
        // Implementation
    }
}
```

#### Best Practices

-  Always use `with sharing` or `without sharing` explicitly
-  Bulkify all code (handle lists, not single records)
-  Use try-catch for error handling
-  Add comments for complex logic
-  Follow Salesforce governor limits
-  Use SOQL best practices (selective queries)

### Lightning Web Component Standards

#### Naming Conventions

- **Components**: camelCase (e.g., `taskProgressIndicator`)
- **Properties**: camelCase (e.g., `accountIds`)
- **Methods**: camelCase (e.g., `handleClick`)
- **Events**: kebab-case (e.g., `task-selected`)

#### Code Structure

```javascript
import { LightningElement, api, wire } from 'lwc';
import getData from '@salesforce/apex/Controller.getData';

export default class ExampleComponent extends LightningElement {
    // Public properties
    @api recordId;
    
    // Private properties
    _data = [];
    
    // Wire services
    @wire(getData, { recordId: '$recordId' })
    wiredData({ error, data }) {
        if (data) {
            this._data = data;
        }
    }
    
    // Event handlers
    handleClick(event) {
        // Handle click
    }
}
```

#### Best Practices

-  Use `@api` for public properties
-  Use `@wire` for data loading
-  Handle errors gracefully
-  Provide loading states
-  Use Lightning Message Service for cross-component communication
-  Optimize for performance

### HTML Templates

```html
<template>
    <lightning-card title="Example">
        <template if:true={hasData}>
            <div class="slds-p-around_medium">
                <!-- Content -->
            </div>
        </template>
        <template if:true={hasError}>
            <div class="slds-text-color_error">
                Error loading data
            </div>
        </template>
    </lightning-card>
</template>
```

### CSS Styling

```css
/* Use SLDS classes when possible */
.container {
    padding: 1rem;
}

/* Custom styles when needed */
.custom-class {
    /* Styles */
}
```

## Testing

### Unit Testing

#### Apex Tests

```apex
@isTest
private class TaskProgressCalculatorTest {
    @isTest
    static void testCalculateProgress() {
        // Setup test data
        Project_Task__c parent = new Project_Task__c(
            Name = 'Parent Task',
            Status__c = 'In Progress'
        );
        insert parent;
        
        // Create subtasks
        List<Project_Task__c> subtasks = new List<Project_Task__c>();
        for (Integer i = 0; i < 5; i++) {
            subtasks.add(new Project_Task__c(
                Name = 'Subtask ' + i,
                Parent_Task__c = parent.Id,
                Status__c = i < 3 ? 'Completed' : 'In Progress'
            ));
        }
        insert subtasks;
        
        // Test
        Test.startTest();
        TaskProgressCalculator.calculateProgress(subtasks);
        Test.stopTest();
        
        // Verify
        parent = [SELECT Progress_Percentage__c FROM Project_Task__c WHERE Id = :parent.Id];
        System.assertEquals(60, parent.Progress_Percentage__c);
    }
}
```

#### LWC Tests

```javascript
import { createElement } from 'lwc';
import TaskProgressIndicator from 'c/taskProgressIndicator';

describe('c-task-progress-indicator', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('displays progress correctly', () => {
        const element = createElement('c-task-progress-indicator', {
            is: TaskProgressIndicator
        });
        element.recordId = '001xx000000abc';
        element.progressPercentage = 75;
        document.body.appendChild(element);

        return Promise.resolve().then(() => {
            const progressBar = element.shadowRoot.querySelector('.progress-bar');
            expect(progressBar).toBeTruthy();
        });
    });
});
```

### Running Tests

```bash
# Run all Apex tests
sf apex run test --result-format human --code-coverage

# Run specific test class
sf apex run test --class-names TaskProgressCalculatorTest --result-format human

# Run LWC tests
npm test

# Run with coverage
npm run test:coverage
```

### Test Coverage Requirements

- **Apex**: Minimum 75% code coverage
- **LWC**: Aim for 80%+ coverage
- **Critical Classes**: 100% coverage

## Deployment

### Deploy to Scratch Org

```bash
sf project deploy start
```

### Deploy to Sandbox

```bash
sf project deploy start --target-org sandbox
```

### Deploy to Production

```bash
# Validate deployment
sf project deploy start --dry-run --target-org production

# Deploy
sf project deploy start --target-org production
```

### Deployment Best Practices

-  Always validate before deploying to production
-  Run tests before deployment
-  Deploy to sandbox first
-  Use change sets for production (if required)
-  Document deployment steps
-  Have rollback plan

## Extending the System

### Adding New Custom Fields

1. **Create Field**
   - Setup †’ Object Manager †’ Project Task †’ Fields & Relationships
   - Or use VS Code: Create `.field-meta.xml` file

2. **Add to Permission Sets**
   - Update permission sets to include new field

3. **Add to Page Layouts**
   - Add field to page layouts

4. **Update Components**
   - Update LWC components if needed
   - Update Apex classes if needed

### Creating New Components

1. **Generate Component**
   ```bash
   sf lightning generate component --name NewComponent --type lwc
   ```

2. **Implement Component**
   - Write JavaScript
   - Create HTML template
   - Add CSS if needed

3. **Add Tests**
   - Write unit tests
   - Test in different scenarios

4. **Document**
   - Update component reference docs
   - Add usage examples

### Adding New Apex Classes

1. **Create Class**
   ```bash
   sf apex generate class --name NewClass
   ```

2. **Implement Logic**
   - Follow coding standards
   - Add error handling
   - Bulkify code

3. **Write Tests**
   - Create test class
   - Achieve >75% coverage

4. **Document**
   - Add JSDoc comments
   - Update API reference

### Creating New Flows

1. **Create Flow**
   - Setup †’ Process Automation †’ Flows
   - Or use VS Code (create `.flow-meta.xml`)

2. **Configure Flow**
   - Set entry criteria
   - Add actions
   - Test flow

3. **Activate Flow**
   - Activate when ready
   - Monitor for errors

### Integration with External Systems

1. **Create Integration Class**
   - Use HTTP callouts
   - Handle authentication
   - Error handling

2. **Configure Remote Sites**
   - Add remote site settings
   - Configure CSP if needed

3. **Test Integration**
   - Test in sandbox first
   - Monitor for errors
   - Handle edge cases

## Best Practices

### Code Quality

-  Follow coding standards
-  Write clean, readable code
-  Add comments for complex logic
-  Use meaningful variable names
-  Keep methods focused and small

### Performance

-  Optimize SOQL queries
-  Use selective queries
-  Minimize DML operations
-  Cache data when appropriate
-  Monitor governor limits

### Security

-  Use `with sharing` appropriately
-  Validate all inputs
-  Don't expose sensitive data
-  Follow field-level security
-  Use secure authentication

### Documentation

-  Document all public methods
-  Update wiki documentation
-  Add inline comments
-  Keep README updated
-  Document breaking changes

---

**Related Documentation**:
- [Architecture Overview](./Architecture-Overview.md) - System architecture
- [Component Reference](./Component-Reference.md) - Component docs
- [Apex Classes](./Apex-Classes.md) - Apex documentation

