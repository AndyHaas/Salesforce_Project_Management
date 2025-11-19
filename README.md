# Salesforce Project Management Package

A comprehensive Salesforce unmanaged package for project and task management with advanced features including task dependencies, progress tracking, and visual dashboards.

## Overview

This package provides a complete project and task management solution for Salesforce, including:

- **Project Task Management**: Custom object for managing project tasks with dependencies
- **Task Dependencies**: Visual dependency tracking and validation
- **Progress Tracking**: Automated progress calculation and metrics
- **Dashboard Components**: Lightning Web Components for visualizing task data
- **Review Workflow**: Built-in review and approval processes

## Package Contents

### Custom Objects
- `Project_Task__c`: Main task object with dependencies, progress tracking, and review status
- `Release_Notes__c`: Release documentation
- `Release_Tag__c`: Release tagging
- `Release_Version__c`: Version management

### Lightning Web Components
- `projectTaskDashboard`: Main dashboard for project task management
- `taskDependencyVisualizer`: Visual representation of task dependencies
- `taskProgressIndicator`: Progress tracking component
- `taskStatusBreakdown`: Status breakdown charts
- `taskPriorityBreakdown`: Priority analysis
- `taskProgressMetrics`: Progress metrics and KPIs
- `taskDueDateMetrics`: Due date tracking
- `taskHoursMetrics`: Hours tracking and reporting
- `taskReviewStatusMetrics`: Review status tracking
- `relatedTasksList`: Related tasks display
- `groupedTaskList`: Grouped task listing
- `accountFilter`: Account filtering component
- `taskListComponent`: Task list component

### Apex Classes
- `ProjectTaskDashboardController`: Dashboard controller logic
- `TaskDependencyHelper`: Dependency validation and management
- `TaskProgressCalculator`: Automated progress calculations

### Flows
- 33 Flow definitions for automation and business processes

### Permission Sets
- `Project_Management_Admin`: Full administrative access
- `Project_Management_Manager`: Manager-level access
- `Project_Management_User`: Standard user access

## Installation

This is an unmanaged package. To install:

1. Clone this repository
2. Deploy to your Salesforce org using Salesforce CLI:
   ```bash
   sf project deploy start
   ```
3. Assign appropriate permission sets to users

## Documentation

- [GitHub Wiki](https://github.com/AndyHaas/Salesforce_Project_Management/wiki) - Comprehensive documentation

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

This is a managed package. For contributions, please follow the development workflow:
1. Create a feature branch
2. Make your changes
3. Commit with descriptive messages
4. Push to the repository

## License

[Add your license here]

## Support

For issues and questions, please use the GitHub Issues page.
