# Salesforce Project Management Package

A comprehensive Salesforce unmanaged package for project and task management with advanced features including task dependencies, progress tracking, and visual dashboards.

## Overview

This package provides a complete project and task management solution for Salesforce, including:

- **Project Task Management**: Custom object for managing project tasks with dependencies and relationships
- **Task Relationships**: Junction object-based many-to-many task relationships with dependency tracking
- **Task Dependencies**: Visual dependency tracking, risk assessment, and blocking status management
- **Progress Tracking**: Automated progress calculation and metrics for parent tasks and subtasks
- **Dashboard Components**: Lightning Web Components for visualizing task data with field set-driven configuration
- **Review Workflow**: Built-in review and approval processes
- **Experience Cloud Portal**: Client portal with custom login and task visibility
- **Portal Messaging**: Secure messaging system for client-team communication with infinite scrolling, search, and file attachments

## Package Contents

### Custom Objects
- `Project_Task__c`: Main task object with dependencies, progress tracking, and review status
- `Project_Task_Relationship__c`: Junction object for managing many-to-many task relationships
- `Message__c`: Messaging object for client-team communication
- `Release_Notes__c`: Release documentation
- `Release_Tag__c`: Release tagging
- `Release_Version__c`: Version management

### Lightning Web Components
- `projectTaskDashboard`: Main dashboard container for project task management
- `taskContextPanel`: Unified component displaying task relationships, dependencies, subtasks, and progress
- `taskHoverCard`: Reusable hover card component for displaying task details
- `linkTaskModal`: Modal component for creating and editing task relationships
- `taskStatusBreakdown`: Status breakdown charts
- `taskPriorityBreakdown`: Priority analysis
- `taskProgressMetrics`: Progress metrics and KPIs
- `taskDueDateMetrics`: Due date tracking
- `taskHoursMetrics`: Hours tracking and reporting
- `taskReviewStatusMetrics`: Review status tracking
- `groupedTaskList`: Grouped task listing with expandable subtasks
- `accountFilter`: Account filtering component
- `taskListComponent`: Paginated task list component with field set-driven columns
- `portalMessaging`: Core messaging component for client-team communication
- `salesforceMessaging`: Wrapper component for Salesforce Lightning Experience messaging

### Apex Classes
- `ProjectTaskDashboardController`: Dashboard controller logic for metrics and task lists
- `TaskContextController`: Controller for task relationships, dependencies, and context panel
- `TaskDependencyHelper`: Dependency risk assessment and blocking status management
- `TaskProgressCalculator`: Automated progress calculations for parent tasks
- `TaskSubtaskHelper`: Helper class for subtask management (user population, parent status updates, validation)
- `PortalMessagingController`: Controller for portal messaging functionality (sending, retrieving, searching messages)

### Triggers
- `ProjectTaskTrigger`: Comprehensive trigger handling all automated business logic for Project Tasks including:
  - Subtask user population from parent (before insert)
  - Parent task validation (before update)
  - Progress calculation (after insert/update/delete)
  - Dependency risk assessment (after insert/update)
  - Parent status updates based on subtask changes (after update)

### Flows
- 29 Flow definitions for automation and business processes

### Permission Sets
- `Project_Management_Admin`: Full administrative access
- `Project_Management_Manager`: Manager-level access
- `Project_Management_User`: Standard user access
- `Portal_Messaging`: Permission set for portal messaging functionality

## Installation

This is an unmanaged package. To install:

1. Clone this repository
2. Deploy to your Salesforce org using Salesforce CLI:
   ```bash
   sf project deploy start
   ```
3. Assign appropriate permission sets to users

## Documentation

- [Dashboard Guide](docs/wiki/Dashboard_Guide.md) - Comprehensive documentation for dashboard components, task relationships, and field set configuration

## Development

### Prerequisites
- Salesforce CLI
- Node.js and npm
- VS Code with Salesforce Extensions (recommended)

### Setup
```bash
npm install
```

### Testing
```bash
npm test
```

### Linting
```bash
npm run lint
```

## Contributing

This is an unmanaged package. For contributions, please follow the development workflow:
1. Create a feature branch
2. Make your changes
3. Commit with descriptive messages
4. Push to the repository

## License

[Add your license here]

## Support

For issues and questions, please use the GitHub Issues page.
