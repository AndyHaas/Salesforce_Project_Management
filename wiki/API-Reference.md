# API Reference

API documentation for integrating with the Milestone Task Management System.

## Table of Contents

1. [Apex API Methods](#apex-api-methods)
2. [REST API Integration](#rest-api-integration)
3. [SOQL Queries](#soql-queries)
4. [Platform Events](#platform-events)
5. [Webhooks](#webhooks)
6. [Integration Examples](#integration-examples)

## Apex API Methods

### RelatedTasksController

#### getRelatedTasks

**Method Signature**:
```apex
@AuraEnabled(cacheable=true)
public static List<RelatedTaskWrapper> getRelatedTasks(String taskId)
```

**Purpose**: Get related tasks for a given task

**Parameters**:
- `taskId` (String): ID of the task

**Returns**: List of RelatedTaskWrapper objects

**Cacheable**: Yes

**Usage**:
```javascript
// Lightning Web Component
import getRelatedTasks from '@salesforce/apex/RelatedTasksController.getRelatedTasks';

@wire(getRelatedTasks, { taskId: '$recordId' })
wiredRelatedTasks({ error, data }) {
    if (data) {
        this.relatedTasks = data;
    }
}
```

### ProjectTaskDashboardController

#### getStatusBreakdown

**Method Signature**:
```apex
@AuraEnabled(cacheable=true)
public static List<StatusBreakdownWrapper> getStatusBreakdown(List<String> accountIds)
```

**Purpose**: Get task count grouped by status

**Parameters**:
- `accountIds` (List<String>): Account IDs to filter by (empty = all)

**Returns**: List of status breakdown data

#### getPriorityBreakdown

**Method Signature**:
```apex
@AuraEnabled(cacheable=true)
public static List<PriorityBreakdownWrapper> getPriorityBreakdown(List<String> accountIds)
```

**Purpose**: Get task count grouped by priority

**Parameters**:
- `accountIds` (List<String>): Account IDs to filter by

**Returns**: List of priority breakdown data

#### getHoursMetrics

**Method Signature**:
```apex
@AuraEnabled(cacheable=true)
public static HoursMetricsWrapper getHoursMetrics(List<String> accountIds)
```

**Purpose**: Get hours metrics (estimated vs. actual)

**Parameters**:
- `accountIds` (List<String>): Account IDs to filter by

**Returns**: HoursMetricsWrapper with metrics

#### getProgressMetrics

**Method Signature**:
```apex
@AuraEnabled(cacheable=true)
public static ProgressMetricsWrapper getProgressMetrics(List<String> accountIds)
```

**Purpose**: Get progress metrics

**Parameters**:
- `accountIds` (List<String>): Account IDs to filter by

**Returns**: ProgressMetricsWrapper with metrics

#### getTasks

**Method Signature**:
```apex
@AuraEnabled(cacheable=true)
public static List<Project_Task__c> getTasks(List<String> accountIds, String filters)
```

**Purpose**: Get filtered list of tasks

**Parameters**:
- `accountIds` (List<String>): Account IDs to filter by
- `filters` (String): JSON string of additional filters

**Returns**: List of Project_Task__c records

## REST API Integration

### Authentication

Use standard Salesforce OAuth 2.0 authentication:

```bash
curl https://login.salesforce.com/services/oauth2/token \
  -d "grant_type=password" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "username=YOUR_USERNAME" \
  -d "password=YOUR_PASSWORD"
```

### Create Task

**Endpoint**: `POST /services/data/v65.0/sobjects/Project_Task__c/`

**Request Body**:
```json
{
  "Name": "Implement User Login",
  "Account__c": "001xx000000abc",
  "Status__c": "Backlog",
  "Priority__c": "High",
  "Estimated_Hours__c": 40,
  "Developer__c": "005xx000000xyz"
}
```

**Response**:
```json
{
  "id": "a0Xxx000000abc",
  "success": true,
  "errors": []
}
```

### Update Task

**Endpoint**: `PATCH /services/data/v65.0/sobjects/Project_Task__c/{taskId}`

**Request Body**:
```json
{
  "Status__c": "In Progress",
  "Actual_Hours__c": 10
}
```

**Response**: HTTP 204 No Content (on success)

### Query Tasks

**Endpoint**: `GET /services/data/v65.0/query/?q={SOQL}`

**Example**:
```bash
curl https://yourinstance.salesforce.com/services/data/v65.0/query/?q=SELECT+Id,Name,Status__c+FROM+Project_Task__c \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Get Related Tasks

**Endpoint**: `GET /services/data/v65.0/query/?q={SOQL}`

**SOQL Query**:
```sql
SELECT Id, Name, Status__c, Priority__c, Relationship_Type__c
FROM Project_Task__c
WHERE Related_Task__c = '{taskId}'
```

## SOQL Queries

### Common Queries

#### Get All Tasks for an Account

```sql
SELECT Id, Name, Status__c, Priority__c, Estimated_Hours__c, Actual_Hours__c
FROM Project_Task__c
WHERE Account__c = '001xx000000abc'
```

#### Get Subtasks for a Parent Task

```sql
SELECT Id, Name, Status__c, Estimated_Hours__c, Actual_Hours__c
FROM Project_Task__c
WHERE Parent_Task__c = 'a0Xxx000000abc'
ORDER BY CreatedDate
```

#### Get Tasks with Blocking Dependencies

```sql
SELECT Id, Name, Status__c, Related_Task__c, At_Risk_Due_to_Dependencies__c
FROM Project_Task__c
WHERE Relationship_Type__c = 'Blocking Dependency'
AND At_Risk_Due_to_Dependencies__c = true
```

#### Get Tasks by Status

```sql
SELECT Id, Name, Status__c, Priority__c, Due_Date__c
FROM Project_Task__c
WHERE Status__c = 'In Progress'
ORDER BY Priority__c DESC, Due_Date__c ASC
```

#### Get Overdue Tasks

```sql
SELECT Id, Name, Status__c, Due_Date__c, Is_Overdue__c
FROM Project_Task__c
WHERE Is_Overdue__c = true
AND Status__c != 'Completed'
AND Status__c != 'Closed'
```

#### Get Tasks Awaiting Approval

```sql
SELECT Id, Name, Status__c, Ready_for_Client_Review__c, Client_Approved_for_Development__c
FROM Project_Task__c
WHERE Status__c = 'Backlog'
AND Ready_for_Client_Review__c = true
AND Client_Approved_for_Development__c = false
```

### Aggregate Queries

#### Count Tasks by Status

```sql
SELECT Status__c, COUNT(Id) taskCount
FROM Project_Task__c
GROUP BY Status__c
```

#### Sum Hours by Account

```sql
SELECT Account__c, SUM(Estimated_Hours__c) totalEstimated, SUM(Actual_Hours__c) totalActual
FROM Project_Task__c
WHERE Account__c != null
GROUP BY Account__c
```

#### Average Progress by Priority

```sql
SELECT Priority__c, AVG(Progress_Percentage__c) avgProgress
FROM Project_Task__c
WHERE Progress_Percentage__c != null
GROUP BY Priority__c
```

## Platform Events

### Task Status Changed Event

**Event Name**: `Task_Status_Changed__e`

**Fields**:
- `Task_Id__c`: ID of the task
- `Old_Status__c`: Previous status
- `New_Status__c`: New status
- `Changed_By__c`: User who made the change

**Publish Example**:
```apex
Task_Status_Changed__e event = new Task_Status_Changed__e();
event.Task_Id__c = taskId;
event.Old_Status__c = 'In Progress';
event.New_Status__c = 'In Review';
event.Changed_By__c = UserInfo.getUserId();

List<Database.SaveResult> results = EventBus.publish(new List<Task_Status_Changed__e>{event});
```

**Subscribe Example**:
```apex
public class TaskStatusChangeSubscriber implements PlatformEventSubscriber {
    public void handleEvent(List<SObject> events) {
        for (Task_Status_Changed__e event : (List<Task_Status_Changed__e>)events) {
            // Handle event
        }
    }
}
```

## Webhooks

### Outbound Messages

Configure outbound messages for task events:

1. **Setup Outbound Message**
   - Setup †’ Workflow Actions †’ Outbound Messages
   - Create new outbound message
   - Select object: Project_Task__c
   - Configure endpoint URL
   - Select fields to send

2. **Configure Workflow**
   - Create workflow rule
   - Add outbound message action
   - Set trigger conditions

### HTTP Callouts

Use Apex HTTP callouts for external integrations:

```apex
public class TaskWebhookService {
    public static void sendTaskUpdate(Project_Task__c task) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://your-webhook-url.com/task-update');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(task));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
    }
}
```

## Integration Examples

### Create Task via API

```javascript
// JavaScript/Node.js
const axios = require('axios');

async function createTask(accessToken, taskData) {
    const response = await axios.post(
        'https://yourinstance.salesforce.com/services/data/v65.0/sobjects/Project_Task__c/',
        taskData,
        {
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json'
            }
        }
    );
    return response.data;
}

const task = {
    Name: 'New Feature',
    Account__c: '001xx000000abc',
    Status__c: 'Backlog',
    Priority__c: 'High'
};

createTask(accessToken, task);
```

### Update Task Status

```python
# Python
import requests

def update_task_status(access_token, task_id, new_status):
    url = f'https://yourinstance.salesforce.com/services/data/v65.0/sobjects/Project_Task__c/{task_id}'
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    data = {
        'Status__c': new_status
    }
    response = requests.patch(url, json=data, headers=headers)
    return response.status_code == 204
```

### Query Tasks

```java
// Java
public List<ProjectTask> getTasksByAccount(String accountId, String accessToken) {
    String query = "SELECT Id, Name, Status__c FROM Project_Task__c WHERE Account__c = '" + accountId + "'";
    String url = "https://yourinstance.salesforce.com/services/data/v65.0/query/?q=" + URLEncoder.encode(query, "UTF-8");
    
    HttpRequest req = new HttpRequest();
    req.setEndpoint(url);
    req.setMethod('GET');
    req.setHeader('Authorization', 'Bearer ' + accessToken);
    
    Http http = new Http();
    HttpResponse res = http.send(req);
    
    // Parse response
    return parseTasks(res.getBody());
}
```

---

**Related Documentation**:
- [Apex Classes](./Apex-Classes.md) - Apex class documentation
- [Architecture Overview](./Architecture-Overview.md) - System architecture
- [Development Guide](./Development-Guide.md) - Development practices

