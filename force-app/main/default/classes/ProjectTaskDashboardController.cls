/**
 * @description Main Apex controller for Project Task Dashboard components
 * 
 * Provides @AuraEnabled methods for retrieving task metrics, breakdowns, lists,
 * and related data for the Project Task Dashboard LWC components.
 * 
 * USAGE:
 * - Used by LWC components:
 *   - accountFilter: getAccounts(), getCurrentUserAccountId()
 *   - taskStatusBreakdown: getStatusBreakdown()
 *   - taskHoursMetrics: getHoursMetrics()
 *   - taskReviewStatusMetrics: getReviewStatusMetrics()
 *   - taskPriorityBreakdown: getPriorityBreakdown()
 *   - taskProgressMetrics: getProgressMetrics()
 *   - taskDueDateMetrics: getDueDateMetrics()
 *   - taskListComponent: getTaskList(), getTaskListFieldSetDefinition()
 *   - groupedTaskList: getGroupedTasksWithSubtasks(), getAccounts()
 *   - taskContextPanel: getDependencyData()
 */
public with sharing class ProjectTaskDashboardController {

    private static final String TASK_HOVER_FIELD_SET = 'Task_Hover_Fields';
    private static final String TASK_LIST_FIELD_SET = 'Project_Task_Dashboard_Table';
    private static final String TASK_SUMMARY_FIELD_SET = 'Task_Fields';
    private static final List<String> BASE_PARENT_TASK_FIELDS = new List<String>{
        'Id',
        'Name',
        'Status__c',
        'Priority__c',
        'Due_Date__c',
        'Estimated_Hours__c',
        'Actual_Hours__c',
        'Progress_Percentage__c',
        'Owner.Id',
        'Owner.Name',
        'Developer__c',
        'Developer__r.Name',
        'Developer__r.Id',
        'Client_User__c',
        'Client_User__r.Name',
        'Client_User__r.Id',
        'Account__c',
        'Account__r.Name',
        'CreatedDate',
        'Description__c'
    };
    
    private static final List<String> BASE_SUBTASK_FIELDS = new List<String>{
        'Id',
        'Name',
        'Status__c',
        'Priority__c',
        'Due_Date__c',
        'Estimated_Hours__c',
        'Actual_Hours__c',
        'Progress_Percentage__c',
        'Owner.Id',
        'Owner.Name',
        'Developer__c',
        'Developer__r.Name',
        'Developer__r.Id',
        'Client_User__c',
        'Client_User__r.Name',
        'Client_User__r.Id',
        'Account__c',
        'Account__r.Name',
        'CreatedDate',
        'Description__c'
    };

    private static List<Schema.FieldSetMember> getTaskHoverFieldSetMembers() {
        return getFieldSetMembers(TASK_HOVER_FIELD_SET);
    }

    private static List<Schema.FieldSetMember> getTaskListFieldSetMembers() {
        return getFieldSetMembers(TASK_LIST_FIELD_SET);
    }

    private static List<Schema.FieldSetMember> getTaskSummaryFieldSetMembers() {
        return getFieldSetMembers(TASK_SUMMARY_FIELD_SET);
    }

    private static List<Schema.FieldSetMember> getFieldSetMembers(String fieldSetName) {
        Schema.DescribeSObjectResult describe = Project_Task__c.SObjectType.getDescribe();
        Map<String, Schema.FieldSet> fieldSets = describe.fieldSets.getMap();
        if (fieldSets.containsKey(fieldSetName)) {
            return fieldSets.get(fieldSetName).getFields();
        }
        return new List<Schema.FieldSetMember>();
    }
    
    private static List<String> getFieldPaths(List<Schema.FieldSetMember> members) {
        List<String> paths = new List<String>();
        if (members == null) {
            return paths;
        }
        for (Schema.FieldSetMember member : members) {
            if (member != null && String.isNotBlank(member.getFieldPath())) {
                paths.add(member.getFieldPath());
            }
        }
        return paths;
    }
    
    private static List<HoverFieldValue> buildHoverFieldValues(
        SObject record,
        List<Schema.FieldSetMember> members,
        Map<String, Schema.SObjectField> fieldDescribeMap
    ) {
        List<HoverFieldValue> values = new List<HoverFieldValue>();
        if (record == null || members == null || members.isEmpty()) {
            return values;
        }
        
        for (Schema.FieldSetMember member : members) {
            if (member == null) {
                continue;
            }
            String apiName = member.getFieldPath();
            HoverFieldValue hoverField = new HoverFieldValue();
            hoverField.apiName = apiName;
            hoverField.label = member.getLabel();
            
            Schema.DescribeFieldResult describe = null;
            if (fieldDescribeMap != null && fieldDescribeMap.containsKey(apiName)) {
                describe = fieldDescribeMap.get(apiName).getDescribe();
            }
            
            Object rawValue = record.get(apiName);
            hoverField.value = formatHoverFieldValue(rawValue, describe);
            hoverField.isLongText = describe != null && describe.getType() == Schema.DisplayType.TextArea;
            values.add(hoverField);
        }
        return values;
    }
    
    private static String formatHoverFieldValue(Object rawValue, Schema.DescribeFieldResult describe) {
        if (rawValue == null) {
            return '';
        }
        if (rawValue instanceof Date) {
            return ((Date)rawValue).format();
        }
        if (rawValue instanceof Datetime) {
            return ((Datetime)rawValue).format();
        }
        if (rawValue instanceof Decimal && describe != null && describe.getType() == Schema.DisplayType.Percent) {
            return String.valueOf(((Decimal)rawValue).setScale(2)) + '%';
        }
        return String.valueOf(rawValue);
    }
    
    private static void addFieldSetMembersToSelect(
        Set<String> targetFields,
        List<Schema.FieldSetMember> members,
        Map<String, Schema.SObjectField> describeFieldMap
    ) {
        if (targetFields == null || members == null || members.isEmpty()) {
            return;
        }
        
        for (Schema.FieldSetMember member : members) {
            if (member == null || String.isBlank(member.getFieldPath())) {
                continue;
            }
            String fieldPath = member.getFieldPath();
            targetFields.add(fieldPath);
            
            if (describeFieldMap != null && describeFieldMap.containsKey(fieldPath)) {
                Schema.DescribeFieldResult describe = describeFieldMap.get(fieldPath).getDescribe();
                if (describe != null && describe.getType() == Schema.DisplayType.Reference) {
                    String relationshipName = describe.getRelationshipName();
                    if (!String.isBlank(relationshipName)) {
                        targetFields.add(relationshipName + '.Name');
                    }
                }
            }
        }
    }
    
    private static List<FieldSetFieldDefinition> buildFieldSetDefinitions(
        List<Schema.FieldSetMember> members,
        Map<String, Schema.SObjectField> describeFieldMap
    ) {
        List<FieldSetFieldDefinition> definitions = new List<FieldSetFieldDefinition>();
        if (members == null) {
            return definitions;
        }
        
        for (Schema.FieldSetMember member : members) {
            if (member == null || String.isBlank(member.getFieldPath())) {
                continue;
            }
            FieldSetFieldDefinition definition = new FieldSetFieldDefinition();
            definition.apiName = member.getFieldPath();
            definition.label = member.getLabel();
            definition.isNameField = definition.apiName == 'Name';
            
            if (describeFieldMap != null && describeFieldMap.containsKey(definition.apiName)) {
                Schema.DescribeFieldResult describe = describeFieldMap.get(definition.apiName).getDescribe();
                definition.dataType = describe.getType().name();
                definition.isReference = describe.getType() == Schema.DisplayType.Reference;
                if (definition.isReference) {
                    definition.referenceRelationshipName = describe.getRelationshipName();
                }
            } else {
                definition.dataType = 'STRING';
                definition.isReference = false;
            }
            
            definitions.add(definition);
        }
        
        return definitions;
    }
    
    private static List<SummaryFieldValue> buildSummaryFieldValues(
        SObject record,
        List<Schema.FieldSetMember> members,
        Map<String, Schema.SObjectField> describeFieldMap
    ) {
        List<SummaryFieldValue> values = new List<SummaryFieldValue>();
        if (record == null || members == null || members.isEmpty()) {
            return values;
        }
        
        for (Schema.FieldSetMember member : members) {
            if (member == null || String.isBlank(member.getFieldPath())) {
                continue;
            }
            
            SummaryFieldValue summaryValue = new SummaryFieldValue();
            summaryValue.apiName = member.getFieldPath();
            summaryValue.label = member.getLabel();
            
            Schema.DescribeFieldResult describe = null;
            if (describeFieldMap != null && describeFieldMap.containsKey(summaryValue.apiName)) {
                describe = describeFieldMap.get(summaryValue.apiName).getDescribe();
            }
            
            Object rawValue = record.get(summaryValue.apiName);
            if (describe != null && describe.getType() == Schema.DisplayType.Reference) {
                String relationshipName = describe.getRelationshipName();
                if (!String.isBlank(relationshipName)) {
                    SObject relatedRecord = record.getSObject(relationshipName);
                    if (relatedRecord != null && relatedRecord.get('Name') != null) {
                        rawValue = relatedRecord.get('Name');
                    }
                }
            }
            
            summaryValue.rawValue = rawValue != null ? String.valueOf(rawValue) : null;
            summaryValue.displayValue = formatHoverFieldValue(rawValue, describe);
            values.add(summaryValue);
        }
        
        return values;
    }
    
    @AuraEnabled(cacheable=true)
    public static StatusBreakdownResult getStatusBreakdown(List<String> accountIds) {
        // Handle null or empty list
        if (accountIds == null) {
            accountIds = new List<String>();
        }
        List<AggregateResult> results;
        
        if (accountIds != null && !accountIds.isEmpty()) {
            results = [
                SELECT Status__c, COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Account__c IN :accountIds
                GROUP BY Status__c
            ];
        } else {
            results = [
                SELECT Status__c, COUNT(Id) taskCount 
                FROM Project_Task__c 
                GROUP BY Status__c
            ];
        }
        
        StatusBreakdownResult breakdown = new StatusBreakdownResult();
        breakdown.statusCounts = new Map<String, Integer>();
        breakdown.totalTasks = 0;
        
        for (AggregateResult ar : results) {
            String status = (String)ar.get('Status__c');
            Integer count = (Integer)ar.get('taskCount');
            if (status != null) {
                breakdown.statusCounts.put(status, count);
                breakdown.totalTasks += count;
            }
        }
        
        return breakdown;
    }
    
    @AuraEnabled(cacheable=true)
    public static HoursMetricsResult getHoursMetrics(List<String> accountIds) {
        // Handle null or empty list
        if (accountIds == null) {
            accountIds = new List<String>();
        }
        List<AggregateResult> results;
        
        if (accountIds != null && !accountIds.isEmpty()) {
            results = [
                SELECT SUM(Estimated_Hours__c) totalEstimated, 
                       SUM(Actual_Hours__c) totalActual, 
                       SUM(Total_Estimated_Hours__c) totalEstimatedWithSubtasks, 
                       SUM(Total_Actual_Hours__c) totalActualWithSubtasks, 
                       Status__c 
                FROM Project_Task__c 
                WHERE Account__c IN :accountIds
                GROUP BY Status__c
            ];
        } else {
            results = [
                SELECT SUM(Estimated_Hours__c) totalEstimated, 
                       SUM(Actual_Hours__c) totalActual, 
                       SUM(Total_Estimated_Hours__c) totalEstimatedWithSubtasks, 
                       SUM(Total_Actual_Hours__c) totalActualWithSubtasks, 
                       Status__c 
                FROM Project_Task__c 
                GROUP BY Status__c
            ];
        }
        
        HoursMetricsResult metrics = new HoursMetricsResult();
        metrics.totalEstimated = 0;
        metrics.totalActual = 0;
        metrics.totalEstimatedWithSubtasks = 0;
        metrics.totalActualWithSubtasks = 0;
        metrics.hoursByStatus = new List<HoursByStatus>();
        
        for (AggregateResult ar : results) {
            Decimal estimated = (Decimal)ar.get('totalEstimated');
            Decimal actual = (Decimal)ar.get('totalActual');
            Decimal estimatedWithSubtasks = (Decimal)ar.get('totalEstimatedWithSubtasks');
            Decimal actualWithSubtasks = (Decimal)ar.get('totalActualWithSubtasks');
            String status = (String)ar.get('Status__c');
            
            if (estimated != null) metrics.totalEstimated += estimated;
            if (actual != null) metrics.totalActual += actual;
            if (estimatedWithSubtasks != null) metrics.totalEstimatedWithSubtasks += estimatedWithSubtasks;
            if (actualWithSubtasks != null) metrics.totalActualWithSubtasks += actualWithSubtasks;
            
            if (status != null) {
                HoursByStatus hbs = new HoursByStatus();
                hbs.status = status;
                hbs.estimatedHours = estimated != null ? estimated : 0;
                hbs.actualHours = actual != null ? actual : 0;
                metrics.hoursByStatus.add(hbs);
            }
        }
        
        metrics.variance = metrics.totalEstimated - metrics.totalActual;
        metrics.variancePercentage = metrics.totalEstimated != 0 
            ? ((metrics.totalEstimated - metrics.totalActual) / metrics.totalEstimated) * 100 
            : 0;
        
        return metrics;
    }
    
    @AuraEnabled(cacheable=true)
    public static ReviewStatusMetricsResult getReviewStatusMetrics(List<String> accountIds) {
        // Handle null or empty list
        if (accountIds == null) {
            accountIds = new List<String>();
        }
        List<Project_Task__c> tasks;
        
        if (accountIds != null && !accountIds.isEmpty()) {
            tasks = [
                SELECT Id, Status__c, Reviewed_by_PM_Code_Reviewer__c, 
                       Client_Approved_for_Completion__c, Client_Approved_for_Development__c, 
                       Ready_for_Client_Review__c 
                FROM Project_Task__c
                WHERE Account__c IN :accountIds
            ];
        } else {
            tasks = [
                SELECT Id, Status__c, Reviewed_by_PM_Code_Reviewer__c, 
                       Client_Approved_for_Completion__c, Client_Approved_for_Development__c, 
                       Ready_for_Client_Review__c 
                FROM Project_Task__c
            ];
        }
        
        ReviewStatusMetricsResult metrics = new ReviewStatusMetricsResult();
        metrics.pmApprovedCount = 0;
        metrics.pmPendingCount = 0;
        metrics.clientCompletionApprovedCount = 0;
        metrics.clientCompletionPendingCount = 0;
        metrics.clientDevelopmentApprovedCount = 0;
        metrics.clientDevelopmentPendingCount = 0;
        metrics.readyForClientReviewCount = 0;
        metrics.inReviewTotal = 0;
        metrics.backlogTotal = 0;
        
        for (Project_Task__c task : tasks) {
            if (task.Status__c == 'In Review') {
                metrics.inReviewTotal++;
                if (task.Reviewed_by_PM_Code_Reviewer__c) {
                    metrics.pmApprovedCount++;
                } else {
                    metrics.pmPendingCount++;
                }
                if (task.Client_Approved_for_Completion__c) {
                    metrics.clientCompletionApprovedCount++;
                } else {
                    metrics.clientCompletionPendingCount++;
                }
            } else if (task.Status__c == 'Backlog') {
                metrics.backlogTotal++;
                if (task.Ready_for_Client_Review__c) {
                    metrics.readyForClientReviewCount++;
                }
                if (task.Client_Approved_for_Development__c) {
                    metrics.clientDevelopmentApprovedCount++;
                } else {
                    metrics.clientDevelopmentPendingCount++;
                }
            }
        }
        
        return metrics;
    }
    
    @AuraEnabled(cacheable=true)
    public static PriorityBreakdownResult getPriorityBreakdown(List<String> accountIds) {
        // Handle null or empty list
        if (accountIds == null) {
            accountIds = new List<String>();
        }
        List<AggregateResult> results;
        
        if (accountIds != null && !accountIds.isEmpty()) {
            results = [
                SELECT Priority__c, COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Account__c IN :accountIds
                GROUP BY Priority__c
            ];
        } else {
            results = [
                SELECT Priority__c, COUNT(Id) taskCount 
                FROM Project_Task__c 
                GROUP BY Priority__c
            ];
        }
        
        PriorityBreakdownResult breakdown = new PriorityBreakdownResult();
        breakdown.priorityCounts = new Map<String, Integer>();
        breakdown.totalTasks = 0;
        
        for (AggregateResult ar : results) {
            String priority = (String)ar.get('Priority__c');
            Integer count = (Integer)ar.get('taskCount');
            if (priority != null) {
                breakdown.priorityCounts.put(priority, count);
                breakdown.totalTasks += count;
            }
        }
        
        return breakdown;
    }
    
    @AuraEnabled(cacheable=true)
    public static ProgressMetricsResult getProgressMetrics(List<String> accountIds) {
        // Handle null or empty list
        if (accountIds == null) {
            accountIds = new List<String>();
        }
        List<Project_Task__c> tasks;
        
        if (accountIds != null && !accountIds.isEmpty()) {
            tasks = [
                SELECT Progress_Percentage__c, At_Risk_Due_to_Dependencies__c, Status__c 
                FROM Project_Task__c
                WHERE Account__c IN :accountIds
            ];
        } else {
            tasks = [
                SELECT Progress_Percentage__c, At_Risk_Due_to_Dependencies__c, Status__c 
                FROM Project_Task__c
            ];
        }
        
        ProgressMetricsResult metrics = new ProgressMetricsResult();
        metrics.avgProgress = 0;
        metrics.atRiskCount = 0;
        metrics.blockedCount = 0;
        metrics.totalTasks = tasks.size();
        metrics.completedCount = 0;
        metrics.tasksWithProgress = 0;
        metrics.tasksWithoutProgress = 0;
        metrics.nearingCompletionCount = 0;
        metrics.progressDistribution = new Map<String, Integer>();
        metrics.avgProgressByStatus = new Map<String, Decimal>();
        
        // Initialize progress distribution buckets
        metrics.progressDistribution.put('0%', 0);
        metrics.progressDistribution.put('1-25%', 0);
        metrics.progressDistribution.put('26-50%', 0);
        metrics.progressDistribution.put('51-75%', 0);
        metrics.progressDistribution.put('76-99%', 0);
        metrics.progressDistribution.put('100%', 0);
        
        Decimal totalProgress = 0;
        Integer tasksWithProgress = 0;
        Map<String, Decimal> statusProgressTotals = new Map<String, Decimal>();
        Map<String, Integer> statusTaskCounts = new Map<String, Integer>();
        
        for (Project_Task__c task : tasks) {
            // Count completed/closed tasks
            if (task.Status__c == 'Completed' || task.Status__c == 'Closed') {
                metrics.completedCount++;
            }
            
            // Track progress
            if (task.Progress_Percentage__c != null) {
                Decimal progress = task.Progress_Percentage__c;
                totalProgress += progress;
                tasksWithProgress++;
                metrics.tasksWithProgress++;
                
                // Progress distribution buckets
                if (progress == 0) {
                    metrics.progressDistribution.put('0%', metrics.progressDistribution.get('0%') + 1);
                } else if (progress > 0 && progress <= 25) {
                    metrics.progressDistribution.put('1-25%', metrics.progressDistribution.get('1-25%') + 1);
                } else if (progress > 25 && progress <= 50) {
                    metrics.progressDistribution.put('26-50%', metrics.progressDistribution.get('26-50%') + 1);
                } else if (progress > 50 && progress <= 75) {
                    metrics.progressDistribution.put('51-75%', metrics.progressDistribution.get('51-75%') + 1);
                } else if (progress > 75 && progress < 100) {
                    metrics.progressDistribution.put('76-99%', metrics.progressDistribution.get('76-99%') + 1);
                    metrics.nearingCompletionCount++;
                } else if (progress == 100) {
                    metrics.progressDistribution.put('100%', metrics.progressDistribution.get('100%') + 1);
                }
                
                // Track average progress by status
                if (!statusProgressTotals.containsKey(task.Status__c)) {
                    statusProgressTotals.put(task.Status__c, 0);
                    statusTaskCounts.put(task.Status__c, 0);
                }
                statusProgressTotals.put(task.Status__c, statusProgressTotals.get(task.Status__c) + progress);
                statusTaskCounts.put(task.Status__c, statusTaskCounts.get(task.Status__c) + 1);
            } else {
                metrics.tasksWithoutProgress++;
            }
            
            // Count at-risk and blocked tasks
            if (task.At_Risk_Due_to_Dependencies__c == true) {
                metrics.atRiskCount++;
            }
            if (task.Status__c == 'Blocked') {
                metrics.blockedCount++;
            }
        }
        
        metrics.avgProgress = tasksWithProgress > 0 ? totalProgress / tasksWithProgress : 0;
        metrics.completionRate = metrics.totalTasks > 0 
            ? ((Decimal.valueOf(metrics.completedCount) / Decimal.valueOf(metrics.totalTasks)) * 100).setScale(2)
            : 0;
        
        // Calculate average progress by status
        for (String status : statusProgressTotals.keySet()) {
            Integer count = statusTaskCounts.get(status);
            if (count > 0) {
                metrics.avgProgressByStatus.put(status, (statusProgressTotals.get(status) / count).setScale(2));
            }
        }
        
        return metrics;
    }
    
    @AuraEnabled(cacheable=true)
    public static TaskListResult getTaskList(List<String> accountIds, Integer pageSize, Integer pageNumber) {
        if (accountIds == null) {
            accountIds = new List<String>();
        }
        pageSize = (pageSize == null || pageSize <= 0) ? 10 : pageSize;
        pageNumber = (pageNumber == null || pageNumber <= 0) ? 1 : pageNumber;

        List<Schema.FieldSetMember> fieldSetMembers = getTaskListFieldSetMembers();
        Map<String, Schema.SObjectField> describeFieldMap = Project_Task__c.SObjectType.getDescribe().fields.getMap();
        Set<String> selectFields = new Set<String>{
            'Id',
            'Status__c',
            'Review_Status_Icons__c',
            'CreatedDate'
        };

        for (Schema.FieldSetMember member : fieldSetMembers) {
            if (member == null || String.isBlank(member.getFieldPath())) {
                continue;
            }
            String fieldPath = member.getFieldPath();
            selectFields.add(fieldPath);
            if (describeFieldMap.containsKey(fieldPath)) {
                Schema.DescribeFieldResult describe = describeFieldMap.get(fieldPath).getDescribe();
                if (describe.getType() == Schema.DisplayType.Reference) {
                    String relationshipName = describe.getRelationshipName();
                    if (!String.isBlank(relationshipName)) {
                        selectFields.add(relationshipName + '.Name');
                    }
                }
            }
        }

        List<String> fieldList = new List<String>(selectFields);
        fieldList.sort();
        String fieldClause = String.join(fieldList, ', ');

        String baseQuery = 'SELECT ' + fieldClause + ' FROM Project_Task__c';
        if (!accountIds.isEmpty()) {
            baseQuery += ' WHERE Account__c IN :accountIds';
        }
        baseQuery += ' ORDER BY CreatedDate DESC';

        List<Project_Task__c> allTasks = Database.query(baseQuery);

        Integer totalRecords = allTasks.size();
        Integer totalPages = pageSize > 0 ? (Integer)Math.ceil((Double)totalRecords / pageSize) : 0;
        Integer safePageNumber = Math.max(1, Math.min(pageNumber, Math.max(totalPages, 1)));
        Integer offset = (safePageNumber - 1) * pageSize;
        Integer endIndex = Math.min(offset + pageSize, totalRecords);

        TaskListResult result = new TaskListResult();
        result.tasks = new List<Project_Task__c>();
        result.totalRecords = totalRecords;
        result.pageNumber = safePageNumber;
        result.pageSize = pageSize;
        result.totalPages = totalPages;

        for (Integer i = offset; i < endIndex; i++) {
            result.tasks.add(allTasks[i]);
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldSetFieldDefinition> getTaskListFieldSetDefinition() {
        List<Schema.FieldSetMember> members = getTaskListFieldSetMembers();
        Map<String, Schema.SObjectField> describeFieldMap = Project_Task__c.SObjectType.getDescribe().fields.getMap();
        return buildFieldSetDefinitions(members, describeFieldMap);
    }
    
    @AuraEnabled(cacheable=true)
    public static DueDateMetricsResult getDueDateMetrics(List<String> accountIds) {
        // Handle null or empty list
        if (accountIds == null) {
            accountIds = new List<String>();
        }
        
        DueDateMetricsResult metrics = new DueDateMetricsResult();
        
        // Query for overdue tasks
        List<AggregateResult> overdueResults;
        if (accountIds != null && !accountIds.isEmpty()) {
            overdueResults = [
                SELECT COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Account__c IN :accountIds AND Is_Overdue__c = true
            ];
        } else {
            overdueResults = [
                SELECT COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Is_Overdue__c = true
            ];
        }
        metrics.overdueCount = overdueResults.isEmpty() ? 0 : (Integer)overdueResults[0].get('taskCount');
        
        // Query for tasks due today
        List<AggregateResult> dueTodayResults;
        if (accountIds != null && !accountIds.isEmpty()) {
            dueTodayResults = [
                SELECT COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Account__c IN :accountIds 
                AND Due_Date__c = TODAY 
                AND Status__c != 'Completed' 
                AND Status__c != 'Closed'
            ];
        } else {
            dueTodayResults = [
                SELECT COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Due_Date__c = TODAY 
                AND Status__c != 'Completed' 
                AND Status__c != 'Closed'
            ];
        }
        metrics.dueTodayCount = dueTodayResults.isEmpty() ? 0 : (Integer)dueTodayResults[0].get('taskCount');
        
        // Query for tasks due this week
        List<AggregateResult> dueThisWeekResults;
        if (accountIds != null && !accountIds.isEmpty()) {
            dueThisWeekResults = [
                SELECT COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Account__c IN :accountIds 
                AND Due_Date__c = THIS_WEEK 
                AND Status__c != 'Completed' 
                AND Status__c != 'Closed'
            ];
        } else {
            dueThisWeekResults = [
                SELECT COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Due_Date__c = THIS_WEEK 
                AND Status__c != 'Completed' 
                AND Status__c != 'Closed'
            ];
        }
        metrics.dueThisWeekCount = dueThisWeekResults.isEmpty() ? 0 : (Integer)dueThisWeekResults[0].get('taskCount');
        
        // Query for tasks with due dates
        List<AggregateResult> withDueDateResults;
        if (accountIds != null && !accountIds.isEmpty()) {
            withDueDateResults = [
                SELECT COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Account__c IN :accountIds AND Due_Date__c != null
            ];
        } else {
            withDueDateResults = [
                SELECT COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Due_Date__c != null
            ];
        }
        metrics.tasksWithDueDate = withDueDateResults.isEmpty() ? 0 : (Integer)withDueDateResults[0].get('taskCount');
        
        // Query for tasks without due dates
        List<AggregateResult> withoutDueDateResults;
        if (accountIds != null && !accountIds.isEmpty()) {
            withoutDueDateResults = [
                SELECT COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Account__c IN :accountIds AND Due_Date__c = null
            ];
        } else {
            withoutDueDateResults = [
                SELECT COUNT(Id) taskCount 
                FROM Project_Task__c 
                WHERE Due_Date__c = null
            ];
        }
        metrics.tasksWithoutDueDate = withoutDueDateResults.isEmpty() ? 0 : (Integer)withoutDueDateResults[0].get('taskCount');
        
        // Calculate overdue percentage
        if (metrics.tasksWithDueDate > 0) {
            metrics.overduePercentage = (Decimal.valueOf(metrics.overdueCount) / Decimal.valueOf(metrics.tasksWithDueDate)) * 100;
        } else {
            metrics.overduePercentage = 0;
        }
        
        return metrics;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccounts() {
        return [
            SELECT Id, Name 
            FROM Account 
            WHERE Active__c = true 
            AND Type = 'Customer'
            AND Id IN (SELECT Account__c FROM Project_Task__c WHERE Account__c != null)
            ORDER BY Name
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static String getCurrentUserAccountId() {
        // For Experience Cloud users, get account from Contact
        User currentUser = [SELECT Id, ContactId, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        if (currentUser.ContactId != null && currentUser.Contact.AccountId != null) {
            return currentUser.Contact.AccountId;
        }
        
        return null;
    }
    
    // Wrapper classes
    public class StatusBreakdownResult {
        @AuraEnabled public Map<String, Integer> statusCounts;
        @AuraEnabled public Integer totalTasks;
    }
    
    public class HoursMetricsResult {
        @AuraEnabled public Decimal totalEstimated;
        @AuraEnabled public Decimal totalActual;
        @AuraEnabled public Decimal totalEstimatedWithSubtasks;
        @AuraEnabled public Decimal totalActualWithSubtasks;
        @AuraEnabled public Decimal variance;
        @AuraEnabled public Decimal variancePercentage;
        @AuraEnabled public List<HoursByStatus> hoursByStatus;
    }
    
    public class HoursByStatus {
        @AuraEnabled public String status;
        @AuraEnabled public Decimal estimatedHours;
        @AuraEnabled public Decimal actualHours;
    }
    
    public class ReviewStatusMetricsResult {
        @AuraEnabled public Integer pmApprovedCount;
        @AuraEnabled public Integer pmPendingCount;
        @AuraEnabled public Integer clientCompletionApprovedCount;
        @AuraEnabled public Integer clientCompletionPendingCount;
        @AuraEnabled public Integer clientDevelopmentApprovedCount;
        @AuraEnabled public Integer clientDevelopmentPendingCount;
        @AuraEnabled public Integer readyForClientReviewCount;
        @AuraEnabled public Integer inReviewTotal;
        @AuraEnabled public Integer backlogTotal;
    }
    
    public class PriorityBreakdownResult {
        @AuraEnabled public Map<String, Integer> priorityCounts;
        @AuraEnabled public Integer totalTasks;
    }
    
    public class ProgressMetricsResult {
        @AuraEnabled public Decimal avgProgress;
        @AuraEnabled public Integer atRiskCount;
        @AuraEnabled public Integer blockedCount;
        @AuraEnabled public Integer totalTasks;
        @AuraEnabled public Integer completedCount;
        @AuraEnabled public Decimal completionRate;
        @AuraEnabled public Integer tasksWithProgress;
        @AuraEnabled public Integer tasksWithoutProgress;
        @AuraEnabled public Integer nearingCompletionCount;
        @AuraEnabled public Map<String, Integer> progressDistribution;
        @AuraEnabled public Map<String, Decimal> avgProgressByStatus;
    }
    
    public class TaskListResult {
        @AuraEnabled public List<Project_Task__c> tasks;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer totalPages;
    }
    
    public class DueDateMetricsResult {
        @AuraEnabled public Integer overdueCount;
        @AuraEnabled public Integer dueTodayCount;
        @AuraEnabled public Integer dueThisWeekCount;
        @AuraEnabled public Integer tasksWithDueDate;
        @AuraEnabled public Integer tasksWithoutDueDate;
        @AuraEnabled public Decimal overduePercentage;
    }

    public class FieldSetFieldDefinition {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String dataType;
        @AuraEnabled public Boolean isReference;
        @AuraEnabled public String referenceRelationshipName;
        @AuraEnabled public Boolean isNameField;
    }
    
    @AuraEnabled(cacheable=true)
    public static DependencyDataResult getDependencyData(String taskId) {
        if (taskId == null || taskId == '') {
            return null;
        }
        
        Project_Task__c currentTask = [
            SELECT Id, Parent_Task__c, Parent_Task__r.Name, Parent_Task__r.Status__c, Parent_Task__r.Priority__c,
                   At_Risk_Due_to_Dependencies__c, Is_Blocking__c,
                   (SELECT Id, Name, Status__c, Priority__c, Is_Blocking__c, At_Risk_Due_to_Dependencies__c
                    FROM Subtasks__r
                    ORDER BY CreatedDate ASC)
            FROM Project_Task__c
            WHERE Id = :taskId
            LIMIT 1
        ];
        
        // Get relationships where this task is Task A (so Task_B is the related/dependency task)
        List<Project_Task_Relationship__c> relatedRelationships = [
            SELECT Id, Task_B__c, Task_B__r.Name, Task_B__r.Status__c, Task_B__r.Priority__c, Task_B__r.Is_Blocking__c,
                   Task_B__r.At_Risk_Due_to_Dependencies__c, Relationship_Type__c
            FROM Project_Task_Relationship__c
            WHERE Task_A__c = :taskId
            ORDER BY CreatedDate DESC
        ];
        
        // Get relationships where this task is Task B (so Task A is the dependent task)
        List<Project_Task_Relationship__c> dependentRelationships = [
            SELECT Id, Task_A__c, Task_A__r.Name, Task_A__r.Status__c, Task_A__r.Priority__c, Task_A__r.Is_Blocking__c,
                   Task_A__r.At_Risk_Due_to_Dependencies__c,
                   Relationship_Type__c
            FROM Project_Task_Relationship__c
            WHERE Task_B__c = :taskId
            ORDER BY CreatedDate DESC
        ];
        
        DependencyDataResult result = new DependencyDataResult();
        result.isBlocking = currentTask.Is_Blocking__c != null && currentTask.Is_Blocking__c == true;
        
        // Parent Task
        if (currentTask.Parent_Task__c != null) {
            result.parentTask = new DependencyTask();
            result.parentTask.id = currentTask.Parent_Task__c;
            result.parentTask.name = currentTask.Parent_Task__r.Name;
            result.parentTask.status = currentTask.Parent_Task__r.Status__c;
            result.parentTask.priority = currentTask.Parent_Task__r.Priority__c;
            result.parentTask.type = 'Parent Task';
            result.parentTask.isBlocking = false;
        }
        
        // Dependencies (tasks this task depends on) - Get all relationships where this task is Task A
        // In the junction object, Task A depends on Task B
        result.dependencies = new List<DependencyTask>();
        for (Project_Task_Relationship__c rel : relatedRelationships) {
            DependencyTask dep = new DependencyTask();
            dep.id = rel.Task_B__c;
            dep.name = rel.Task_B__r.Name;
            dep.status = rel.Task_B__r.Status__c;
            dep.priority = rel.Task_B__r.Priority__c;
            dep.type = String.isBlank(rel.Relationship_Type__c) ? 'Related' : rel.Relationship_Type__c;
            // A task is blocking if Relationship Type is "Blocking Dependency" AND the related task is actually blocking
            dep.isBlocking = rel.Relationship_Type__c == 'Blocking Dependency' 
                && rel.Task_B__r.Is_Blocking__c == true;
            dep.isAtRisk = rel.Task_B__r.At_Risk_Due_to_Dependencies__c != null && rel.Task_B__r.At_Risk_Due_to_Dependencies__c == true;
            dep.relationshipId = rel.Id; // Include relationship ID for deletion
            result.dependencies.add(dep);
        }
        
        // Set isAtRisk if there are any dependencies and the task is at risk
        if (!result.dependencies.isEmpty()) {
            result.isAtRisk = currentTask.At_Risk_Due_to_Dependencies__c != null && currentTask.At_Risk_Due_to_Dependencies__c == true;
        }
        
        // Tasks that depend on this task (where this task is Task B, so Task A depends on this task)
        result.dependentTasks = new List<DependencyTask>();
        for (Project_Task_Relationship__c rel : dependentRelationships) {
            DependencyTask dt = new DependencyTask();
            dt.id = rel.Task_A__c;
            dt.name = rel.Task_A__r.Name;
            dt.status = rel.Task_A__r.Status__c;
            dt.priority = rel.Task_A__r.Priority__c;
            dt.type = String.isBlank(rel.Relationship_Type__c) ? 'Related' : rel.Relationship_Type__c;
            // A task is blocking if Relationship Type is "Blocking Dependency" AND the task is actually blocking
            dt.isBlocking = rel.Relationship_Type__c == 'Blocking Dependency' 
                && rel.Task_A__r.Is_Blocking__c == true;
            dt.isAtRisk = rel.Task_A__r.At_Risk_Due_to_Dependencies__c != null && rel.Task_A__r.At_Risk_Due_to_Dependencies__c == true;
            dt.relationshipId = rel.Id; // Include relationship ID for deletion
            result.dependentTasks.add(dt);
        }
        
        // Sub tasks and progress calculation
        result.subtasks = new List<DependencyTask>();
        Integer totalSubtaskCount = 0;
        Integer completedSubtaskCount = 0;
        Integer removedSubtaskCount = 0;
        
        if (currentTask.Subtasks__r != null && !currentTask.Subtasks__r.isEmpty()) {
            totalSubtaskCount = currentTask.Subtasks__r.size();
            
            for (Project_Task__c subtask : currentTask.Subtasks__r) {
                DependencyTask st = new DependencyTask();
                st.id = subtask.Id;
                st.name = subtask.Name;
                st.status = subtask.Status__c;
                st.priority = subtask.Priority__c;
                st.type = 'Sub Task';
                st.isBlocking = subtask.Is_Blocking__c != null && subtask.Is_Blocking__c == true;
                st.isAtRisk = subtask.At_Risk_Due_to_Dependencies__c != null && subtask.At_Risk_Due_to_Dependencies__c == true;
                result.subtasks.add(st);
                
                // Calculate progress
                if (subtask.Status__c == 'Completed' || subtask.Status__c == 'Closed') {
                    completedSubtaskCount++;
                } else if (subtask.Status__c == 'Removed') {
                    removedSubtaskCount++;
                }
            }
        }
        
        // Calculate subtask progress
        Integer validSubtaskTotal = totalSubtaskCount - removedSubtaskCount;
        Decimal progressPercentage = validSubtaskTotal > 0 
            ? (Decimal.valueOf(completedSubtaskCount) / Decimal.valueOf(validSubtaskTotal)) * 100 
            : 0;
        
        result.subtaskProgress = new SubtaskProgressInfo();
        result.subtaskProgress.progressPercentage = progressPercentage.setScale(2);
        result.subtaskProgress.completedCount = completedSubtaskCount;
        result.subtaskProgress.totalCount = validSubtaskTotal;
        result.subtaskProgress.hasSubtasks = totalSubtaskCount > 0;
        
        return result;
    }
    
    public class DependencyDataResult {
        @AuraEnabled public DependencyTask parentTask;
        @AuraEnabled public DependencyTask relatedTask; // Kept for backward compatibility, but deprecated - use dependencies instead
        @AuraEnabled public List<DependencyTask> dependencies; // List of tasks this task depends on
        @AuraEnabled public List<DependencyTask> dependentTasks;
        @AuraEnabled public List<DependencyTask> subtasks;
        @AuraEnabled public Boolean isAtRisk;
        @AuraEnabled public Boolean isBlocking;
        @AuraEnabled public SubtaskProgressInfo subtaskProgress;
    }
    
    public class SubtaskProgressInfo {
        @AuraEnabled public Decimal progressPercentage;
        @AuraEnabled public Integer completedCount;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Boolean hasSubtasks;
    }
    
    public class DependencyTask {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean isBlocking;
        @AuraEnabled public Boolean isAtRisk;
        @AuraEnabled public String relationshipId; // ID of the Project_Task_Relationship__c record (null for parent/child relationships)
    }
    
    @AuraEnabled(cacheable=true)
    public static GroupedTasksResult getGroupedTasksWithSubtasks(List<String> accountIds) {
        // Handle null or empty list, and filter out empty strings and null values
        List<String> validAccountIds = new List<String>();
        if (accountIds != null) {
            for (String accountId : accountIds) {
                if (accountId != null && accountId.trim().length() > 0) {
                    validAccountIds.add(accountId);
                }
            }
        }
        
        List<Project_Task__c> allTasks;
        List<Schema.FieldSetMember> hoverFieldMembers = getTaskHoverFieldSetMembers();
        List<Schema.FieldSetMember> summaryFieldMembers = getTaskSummaryFieldSetMembers();
        Map<String, Schema.SObjectField> describeFieldMap = Project_Task__c.SObjectType.getDescribe().fields.getMap();
        List<FieldSetFieldDefinition> summaryFieldDefinitions = buildFieldSetDefinitions(summaryFieldMembers, describeFieldMap);
        
        Set<String> parentFieldSet = new Set<String>(BASE_PARENT_TASK_FIELDS);
        Set<String> subtaskFieldSet = new Set<String>(BASE_SUBTASK_FIELDS);
        
        parentFieldSet.addAll(getFieldPaths(hoverFieldMembers));
        subtaskFieldSet.addAll(getFieldPaths(hoverFieldMembers));
        parentFieldSet.addAll(getFieldPaths(summaryFieldMembers));
        subtaskFieldSet.addAll(getFieldPaths(summaryFieldMembers));
        
        addFieldSetMembersToSelect(parentFieldSet, hoverFieldMembers, describeFieldMap);
        addFieldSetMembersToSelect(subtaskFieldSet, hoverFieldMembers, describeFieldMap);
        addFieldSetMembersToSelect(parentFieldSet, summaryFieldMembers, describeFieldMap);
        addFieldSetMembersToSelect(subtaskFieldSet, summaryFieldMembers, describeFieldMap);
        
        List<String> parentFieldList = new List<String>(parentFieldSet);
        parentFieldList.sort();
        List<String> subtaskFieldList = new List<String>(subtaskFieldSet);
        subtaskFieldList.sort();
        String parentFieldClause = String.join(parentFieldList, ', ');
        String subtaskFieldClause = String.join(subtaskFieldList, ', ');
        String baseQuery = 'SELECT ' + parentFieldClause +
            ', (SELECT ' + subtaskFieldClause + ' FROM Subtasks__r ORDER BY CreatedDate ASC) FROM Project_Task__c ';
        String orderClause = ' ORDER BY Status__c, CreatedDate DESC';
        
        try {
            // Query parent tasks (tasks without a parent)
            if (!validAccountIds.isEmpty()) {
                String soql = baseQuery + 'WHERE Account__c IN :validAccountIds AND Parent_Task__c = null' + orderClause;
                allTasks = Database.query(soql);
            } else {
                String soql = baseQuery + 'WHERE Parent_Task__c = null' + orderClause;
                allTasks = Database.query(soql);
            }
        } catch (Exception e) {
            // Log error and throw AuraHandledException so LWC can display it
            System.debug('Error querying Project_Task__c: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error loading tasks: ' + e.getMessage());
        }
        
        // Get task IDs for querying Chatter feed items
        Set<Id> taskIds = new Set<Id>();
        for (Project_Task__c task : allTasks) {
            taskIds.add(task.Id);
            if (task.Subtasks__r != null) {
                for (Project_Task__c subtask : task.Subtasks__r) {
                    taskIds.add(subtask.Id);
                }
            }
        }
        
        // Query latest Chatter feed items (comments) for all tasks
        Map<Id, FeedItem> latestFeedItems = new Map<Id, FeedItem>();
        if (!taskIds.isEmpty()) {
            try {
                List<FeedItem> feedItems = [
                    SELECT Id, ParentId, Body, CreatedDate, CreatedBy.Name
                    FROM FeedItem
                    WHERE ParentId IN :taskIds
                    AND Type = 'TextPost'
                    ORDER BY CreatedDate DESC
                ];
                
                // Get the latest feed item for each task
                for (FeedItem feedItem : feedItems) {
                    if (!latestFeedItems.containsKey(feedItem.ParentId)) {
                        latestFeedItems.put(feedItem.ParentId, feedItem);
                    }
                }
            } catch (Exception e) {
                // If FeedItem query fails (e.g., no access), continue without comments
                System.debug('Error querying FeedItem: ' + e.getMessage());
            }
        }
        
        // Group tasks by status
        Map<String, List<TaskWithSubtasks>> tasksByStatus = new Map<String, List<TaskWithSubtasks>>();
        
        for (Project_Task__c task : allTasks) {
            String status = task.Status__c != null ? task.Status__c : 'Backlog';
            
            if (!tasksByStatus.containsKey(status)) {
                tasksByStatus.put(status, new List<TaskWithSubtasks>());
            }
            
            TaskWithSubtasks taskWrapper = new TaskWithSubtasks();
            taskWrapper.id = task.Id;
            taskWrapper.name = task.Name;
            taskWrapper.status = task.Status__c;
            taskWrapper.priority = task.Priority__c;
            taskWrapper.dueDate = task.Due_Date__c;
            taskWrapper.estimatedHours = task.Estimated_Hours__c;
            taskWrapper.actualHours = task.Actual_Hours__c;
            taskWrapper.progressPercentage = task.Progress_Percentage__c;
            taskWrapper.ownerName = task.Owner != null ? task.Owner.Name : '';
            taskWrapper.ownerId = task.Owner != null ? task.Owner.Id : '';
            taskWrapper.developerName = (task.Developer__r != null) ? task.Developer__r.Name : '';
            taskWrapper.developerId = (task.Developer__c != null) ? String.valueOf(task.Developer__c) : '';
            taskWrapper.clientUserName = (task.Client_User__r != null) ? task.Client_User__r.Name : '';
            taskWrapper.clientUserId = (task.Client_User__c != null) ? String.valueOf(task.Client_User__c) : '';
            taskWrapper.accountId = (task.Account__c != null) ? String.valueOf(task.Account__c) : '';
            taskWrapper.accountName = (task.Account__r != null) ? task.Account__r.Name : '';
            taskWrapper.createdDate = task.CreatedDate;
            taskWrapper.description = task.Description__c != null ? task.Description__c : '';
            taskWrapper.hasSubtasks = task.Subtasks__r != null && !task.Subtasks__r.isEmpty();
            taskWrapper.subtaskCount = task.Subtasks__r != null ? task.Subtasks__r.size() : 0;
            
            // Get latest Chatter comment for this task
            if (latestFeedItems.containsKey(task.Id)) {
                FeedItem latestComment = latestFeedItems.get(task.Id);
                taskWrapper.latestComment = latestComment.Body != null ? latestComment.Body : '';
                taskWrapper.latestCommentAuthor = latestComment.CreatedBy != null ? latestComment.CreatedBy.Name : '';
                taskWrapper.latestCommentDate = latestComment.CreatedDate;
            } else {
                taskWrapper.latestComment = '';
                taskWrapper.latestCommentAuthor = '';
                taskWrapper.latestCommentDate = null;
            }
            
            taskWrapper.hoverFields = buildHoverFieldValues(task, hoverFieldMembers, describeFieldMap);
            taskWrapper.summaryFields = buildSummaryFieldValues(task, summaryFieldMembers, describeFieldMap);
            
            // Convert subtasks
            taskWrapper.subtasks = new List<TaskInfo>();
            if (task.Subtasks__r != null) {
                for (Project_Task__c subtask : task.Subtasks__r) {
                    TaskInfo subtaskInfo = new TaskInfo();
                    subtaskInfo.id = subtask.Id;
                    subtaskInfo.name = subtask.Name;
                    subtaskInfo.status = subtask.Status__c;
                    subtaskInfo.priority = subtask.Priority__c;
                    subtaskInfo.dueDate = subtask.Due_Date__c;
                    subtaskInfo.estimatedHours = subtask.Estimated_Hours__c;
                    subtaskInfo.actualHours = subtask.Actual_Hours__c;
                    subtaskInfo.progressPercentage = subtask.Progress_Percentage__c;
                    subtaskInfo.ownerName = subtask.Owner != null ? subtask.Owner.Name : '';
                    subtaskInfo.ownerId = subtask.Owner != null ? subtask.Owner.Id : '';
                    subtaskInfo.developerName = (subtask.Developer__r != null) ? subtask.Developer__r.Name : '';
                    subtaskInfo.developerId = (subtask.Developer__c != null) ? String.valueOf(subtask.Developer__c) : '';
                    subtaskInfo.clientUserName = (subtask.Client_User__r != null) ? subtask.Client_User__r.Name : '';
                    subtaskInfo.clientUserId = (subtask.Client_User__c != null) ? String.valueOf(subtask.Client_User__c) : '';
                    subtaskInfo.accountId = (subtask.Account__c != null) ? String.valueOf(subtask.Account__c) : '';
                    subtaskInfo.accountName = (subtask.Account__r != null) ? subtask.Account__r.Name : '';
                    subtaskInfo.createdDate = subtask.CreatedDate;
                    subtaskInfo.description = subtask.Description__c != null ? subtask.Description__c : '';
                    
                    // Get latest Chatter comment for this subtask
                    if (latestFeedItems.containsKey(subtask.Id)) {
                        FeedItem latestComment = latestFeedItems.get(subtask.Id);
                        subtaskInfo.latestComment = latestComment.Body != null ? latestComment.Body : '';
                        subtaskInfo.latestCommentAuthor = latestComment.CreatedBy != null ? latestComment.CreatedBy.Name : '';
                        subtaskInfo.latestCommentDate = latestComment.CreatedDate;
                    } else {
                        subtaskInfo.latestComment = '';
                        subtaskInfo.latestCommentAuthor = '';
                        subtaskInfo.latestCommentDate = null;
                    }
                    
                    subtaskInfo.hoverFields = buildHoverFieldValues(subtask, hoverFieldMembers, describeFieldMap);
                    subtaskInfo.summaryFields = buildSummaryFieldValues(subtask, summaryFieldMembers, describeFieldMap);
                    
                    taskWrapper.subtasks.add(subtaskInfo);
                }
            }
            
            tasksByStatus.get(status).add(taskWrapper);
        }
        
        // Build result with status groups
        GroupedTasksResult result = new GroupedTasksResult();
        result.statusGroups = new List<StatusGroup>();
        result.summaryFieldDefinitions = summaryFieldDefinitions;
        
        // Define status order
        List<String> statusOrder = new List<String>{
            'Completed', 'Closed', 'In Review', 'In Progress', 'Pending', 'Blocked', 'Backlog', 'Removed'
        };
        
        // Create status groups in order
        for (String status : statusOrder) {
            if (tasksByStatus.containsKey(status)) {
                StatusGroup statusGroupItem = new StatusGroup();
                statusGroupItem.status = status;
                statusGroupItem.tasks = tasksByStatus.get(status);
                statusGroupItem.taskCount = tasksByStatus.get(status).size();
                result.statusGroups.add(statusGroupItem);
            }
        }
        
        // Add any remaining statuses not in the predefined order
        for (String status : tasksByStatus.keySet()) {
            Boolean found = false;
            for (StatusGroup existingGroup : result.statusGroups) {
                if (existingGroup.status == status) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                StatusGroup statusGroupItem = new StatusGroup();
                statusGroupItem.status = status;
                statusGroupItem.tasks = tasksByStatus.get(status);
                statusGroupItem.taskCount = tasksByStatus.get(status).size();
                result.statusGroups.add(statusGroupItem);
            }
        }
        
        return result;
    }
    
    public class GroupedTasksResult {
        @AuraEnabled public List<StatusGroup> statusGroups;
        @AuraEnabled public List<FieldSetFieldDefinition> summaryFieldDefinitions;
    }
    
    public class StatusGroup {
        @AuraEnabled public String status;
        @AuraEnabled public List<TaskWithSubtasks> tasks;
        @AuraEnabled public Integer taskCount;
    }
    
    public class TaskWithSubtasks {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Decimal estimatedHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal progressPercentage;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String ownerId;
        @AuraEnabled public String developerName;
        @AuraEnabled public String developerId;
        @AuraEnabled public String clientUserName;
        @AuraEnabled public String clientUserId;
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String description;
        @AuraEnabled public String latestComment;
        @AuraEnabled public String latestCommentAuthor;
        @AuraEnabled public DateTime latestCommentDate;
        @AuraEnabled public Boolean hasSubtasks;
        @AuraEnabled public Integer subtaskCount;
        @AuraEnabled public List<TaskInfo> subtasks;
        @AuraEnabled public List<HoverFieldValue> hoverFields;
        @AuraEnabled public List<SummaryFieldValue> summaryFields;
    }
    
    public class TaskInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Decimal estimatedHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal progressPercentage;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String ownerId;
        @AuraEnabled public String developerName;
        @AuraEnabled public String developerId;
        @AuraEnabled public String clientUserName;
        @AuraEnabled public String clientUserId;
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String description;
        @AuraEnabled public String latestComment;
        @AuraEnabled public String latestCommentAuthor;
        @AuraEnabled public DateTime latestCommentDate;
        @AuraEnabled public List<HoverFieldValue> hoverFields;
        @AuraEnabled public List<SummaryFieldValue> summaryFields;
    }
    
    public class HoverFieldValue {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean isLongText;
    }
    
    public class SummaryFieldValue {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String displayValue;
        @AuraEnabled public String rawValue;
    }
    
    /**
     * @description Create a task relationship between two tasks
     * @param taskAId The ID of the primary Task (the task that depends on the Related Task)
     * @param taskBId The ID of the Related Task (the task that the primary Task depends on)
     * @param relationshipType The type of relationship (Related, Blocking Dependency, Epic/Feature Parent)
     * @return The created Project_Task_Relationship__c record ID
     */
    @AuraEnabled
    public static String createTaskRelationship(String taskAId, String taskBId, String relationshipType) {
        if (String.isBlank(taskAId) || String.isBlank(taskBId)) {
            throw new AuraHandledException('Both Task and Related Task are required');
        }
        
        if (taskAId == taskBId) {
            throw new AuraHandledException('A task cannot be related to itself');
        }
        
        // Check if relationship already exists in either direction
        // Check Task -> Related Task (or reverse)
        List<Project_Task_Relationship__c> existingRelationships = [
            SELECT Id
            FROM Project_Task_Relationship__c
            WHERE (Task_A__c = :taskAId AND Task_B__c = :taskBId)
               OR (Task_A__c = :taskBId AND Task_B__c = :taskAId)
            LIMIT 1
        ];
        
        if (!existingRelationships.isEmpty()) {
            throw new AuraHandledException('A relationship between these tasks already exists');
        }
        
        Project_Task_Relationship__c relationship = new Project_Task_Relationship__c(
            Task_A__c = taskAId,
            Task_B__c = taskBId,
            Relationship_Type__c = String.isNotBlank(relationshipType) ? relationshipType : 'Related'
        );
        
        try {
            insert relationship;
            return relationship.Id;
        } catch (DmlException e) {
            throw new AuraHandledException('Error creating relationship: ' + e.getMessage());
        }
    }
    
    /**
     * @description Delete a task relationship
     * @param relationshipId The ID of the Project_Task_Relationship__c record to delete
     * @return Success message
     */
    @AuraEnabled
    public static String deleteTaskRelationship(String relationshipId) {
        if (String.isBlank(relationshipId)) {
            throw new AuraHandledException('Relationship ID is required');
        }
        
        try {
            Project_Task_Relationship__c relationship = [
                SELECT Id
                FROM Project_Task_Relationship__c
                WHERE Id = :relationshipId
                LIMIT 1
            ];
            
            delete relationship;
            return 'Relationship deleted successfully';
        } catch (QueryException e) {
            throw new AuraHandledException('Relationship not found: ' + e.getMessage());
        } catch (DmlException e) {
            throw new AuraHandledException('Error deleting relationship: ' + e.getMessage());
        }
    }
}

