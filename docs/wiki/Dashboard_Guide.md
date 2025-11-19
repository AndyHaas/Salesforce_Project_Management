# Dashboard Guide

## Overview

The Project Task Dashboard surfaces the key Lightning Web Components and Apex services that power project visibility in Salesforce. The dashboard now drives its task table dynamically from the `Project_Task_Dashboard_Table` field set, letting admins control which columns appear without touching code.

Core elements:

- `projectTaskDashboard`: container component that orchestrates filter messages and refreshes
- `taskListComponent`: paginated datatable driven by the field set
- Metric cards (Hours, Progress, Priority, Due Dates, Review Status) backed by `ProjectTaskDashboardController`

## Field Set–Driven Task List

### How It Works

1. `ProjectTaskDashboardController.getTaskListFieldSetDefinition()` reads the `Project_Task_Dashboard_Table` field set on `Project_Task__c`, returning API names, labels, data types, and reference metadata.
2. `taskListComponent` wires both the task list data and the field-set definition. When either changes:
   - Columns are rebuilt dynamically with the right datatable types, type attributes, and cell decorations (e.g., status badges, numeric alignment, percent formatting).
   - Row data is reprocessed to inject helper display fields (URL for `Name`, reference labels, percent normalization, CSS status classes).
3. Admin changes to the field set automatically flow to the dashboard table after a deploy/refresh.

### Customizing Columns

1. In Salesforce Setup, open Object Manager → `Project Task` → Field Sets.
2. Edit `Project_Task_Dashboard_Table` and drag/drop fields to adjust order or inclusion.
3. Save and deploy metadata (`force-app/main/default/objects/Project_Task__c/fieldSets/Project_Task_Dashboard_Table.fieldSet-meta.xml`).
4. Reload the dashboard—no code edits required.

### Supported Field Types

The component auto-detects standard types:

- `Name`: rendered as a record link using `taskUrl`.
- References: automatically display the related record’s `Name`.
- Numbers/Currency/Percent: right-aligned with percent values scaled (e.g., `50` → `50%`).
- Dates/DateTimes: formatted as `MMM DD, YYYY` (with time for DateTime).
- Textual fields: shown as plain text.

If a field type is not explicitly mapped, it falls back to `text`.

## Field Set Retrieval via CLI

To pull the latest field-set definition into the repo:

```bash
sf project retrieve start --metadata "FieldSet:Project_Task__c.Project_Task_Dashboard_Table"
```

This checkpoints admin changes before committing.

## Testing & Deployment

1. Run Apex tests covering the dashboard controller (specifically `ProjectTaskDashboardControllerTest`) to ensure field-set metadata is valid:

```bash
sf apex run test --tests ProjectTaskDashboardControllerTest
```

2. Deploy updated metadata:

```bash
sf project deploy start --source-dir force-app/main/default/lwc/taskListComponent \
  --source-dir force-app/main/default/classes/ProjectTaskDashboardController.cls \
  --source-dir force-app/main/default/classes/ProjectTaskDashboardControllerTest.cls \
  --source-dir force-app/main/default/objects/Project_Task__c/fieldSets/Project_Task_Dashboard_Table.fieldSet-meta.xml
```

## Troubleshooting

| Symptom | Likely Cause | Resolution |
| --- | --- | --- |
| Task list shows no columns | Field-set wire failed or field set empty | Verify `Project_Task_Dashboard_Table` contains at least one field and rerun retrieve/deploy |
| Column shows API name instead of label | Field set entry missing label | Update field set label in Setup |
| Reference columns display Ids | Relationship not accessible or missing from query | Ensure the field is reference type and has relationship access; controller auto-adds `relationship.Name` |
| Percent field displays 0–1 values | Field stored as decimal fraction | Confirm field is defined as Percent (metadata) so scaling logic applies |

## Related Files

- `force-app/main/default/lwc/taskListComponent/taskListComponent.js`
- `force-app/main/default/classes/ProjectTaskDashboardController.cls`
- `force-app/main/default/classes/ProjectTaskDashboardControllerTest.cls`
- `force-app/main/default/objects/Project_Task__c/fieldSets/Project_Task_Dashboard_Table.fieldSet-meta.xml`

