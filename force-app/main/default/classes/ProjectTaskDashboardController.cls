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
 * 
 * NOTE: Task context panel functionality has been moved to TaskContextController
 */
public without sharing class ProjectTaskDashboardController {

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
        'Project_Manager__c',
        'Project_Manager__r.Name',
        'Project_Manager__r.Id',
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
        'Project_Manager__c',
        'Project_Manager__r.Name',
        'Project_Manager__r.Id',
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
    
    /**
     * @description Build hover field values from a record and field set members
     * @param record The SObject record to extract field values from
     * @param members The field set members to include
     * @param fieldDescribeMap Map of field API names to field describe objects
     * @return List of HoverFieldValue objects
     * @note Made public so TaskContextController can use it
     */
    public static List<HoverFieldValue> buildHoverFieldValues(
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
            hoverField.isRichText = describe != null && describe.getType().name() == 'HTML';
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
            definition.isNameField = definition.apiName == 'Name';
            
            // Use DescribeFieldResult label if available (more accurate for special fields like OwnerId)
            // Otherwise fall back to FieldSetMember label
            if (describeFieldMap != null && describeFieldMap.containsKey(definition.apiName)) {
                Schema.DescribeFieldResult describe = describeFieldMap.get(definition.apiName).getDescribe();
                definition.label = describe.getLabel(); // Use actual field label instead of FieldSetMember label
                definition.dataType = describe.getType().name();
                definition.isReference = describe.getType() == Schema.DisplayType.Reference;
                if (definition.isReference) {
                    definition.referenceRelationshipName = describe.getRelationshipName();
                }
                
                // Add picklist values if this is a picklist field
                if (describe.getType() == Schema.DisplayType.Picklist || describe.getType() == Schema.DisplayType.MultiPicklist) {
                    List<Schema.PicklistEntry> picklistEntries = describe.getPicklistValues();
                    if (picklistEntries != null && !picklistEntries.isEmpty()) {
                        definition.picklistValues = new List<PicklistOption>();
                        for (Schema.PicklistEntry entry : picklistEntries) {
                            if (entry.isActive()) {
                                PicklistOption option = new PicklistOption();
                                option.label = entry.getLabel();
                                option.value = entry.getValue();
                                definition.picklistValues.add(option);
                            }
                        }
                    }
                }
            } else {
                definition.label = member.getLabel(); // Fallback to FieldSetMember label
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
            
            Schema.DescribeFieldResult describe = null;
            if (describeFieldMap != null && describeFieldMap.containsKey(summaryValue.apiName)) {
                describe = describeFieldMap.get(summaryValue.apiName).getDescribe();
                // Use DescribeFieldResult label if available (more accurate for special fields like OwnerId)
                summaryValue.label = describe.getLabel();
            } else {
                // Fallback to FieldSetMember label
                summaryValue.label = member.getLabel();
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
            summaryValue.isRichText = describe != null && describe.getType().name() == 'HTML';
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
    
    @AuraEnabled(cacheable=true)
    public static String getCurrentUserContactId() {
        // Get current user's ContactId (for portal users)
        User currentUser = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return currentUser.ContactId;
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
        @AuraEnabled public List<PicklistOption> picklistValues;
    }
    
    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String color; // Chart color from field metadata
    }
    
    /**
     * @description Get status colors from Status__c field metadata
     * Returns a map of status values to their chart colors
     * 
     * NOTE: Chart colors are stored in the field metadata XML but are not directly
     * accessible via the standard Schema API. This method returns colors that match
     * the chart colors defined in Status__c.field-meta.xml.
     * 
     * When the field metadata is updated (via Salesforce UI or CLI), this method
     * should be updated to reflect the new colors, or enhanced to use Metadata API
     * for true dynamic retrieval.
     * 
     * @return Map<String, String> Status value to color hex code
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getStatusColors() {
        // Chart colors from Status__c.field-meta.xml
        // These match the colors defined in the field metadata
        // When the field metadata is updated, update this map to match
        Map<String, String> statusColors = new Map<String, String>{
            'Backlog' => '#E5E5E5',
            'Pending' => '#FFB75D',
            'In Progress' => '#0176D3',
            'In Review' => '#5B21B6',
            'Blocked' => '#C23934',
            'Completed' => '#2E844A',
            'Removed' => '#706E6B',
            'Closed' => '#2E844A'
        };
        
        // TODO: Enhance this method to use Metadata API or Tooling API
        // to dynamically retrieve colors from the field metadata XML
        // This would make it truly dynamic without code changes
        
        return statusColors;
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
            taskWrapper.projectManagerId = (task.Project_Manager__c != null) ? String.valueOf(task.Project_Manager__c) : '';
            taskWrapper.projectManagerName = (task.Project_Manager__r != null) ? task.Project_Manager__r.Name : '';
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
                    subtaskInfo.projectManagerId = (subtask.Project_Manager__c != null) ? String.valueOf(subtask.Project_Manager__c) : '';
                    subtaskInfo.projectManagerName = (subtask.Project_Manager__r != null) ? subtask.Project_Manager__r.Name : '';
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

    /**
     * @description Get grouped tasks and subtasks filtered by project
     * @param projectId Project__c Id to filter tasks
     * @return GroupedTasksResult with status groups and subtasks
     */
    @AuraEnabled(cacheable=true)
    public static GroupedTasksResult getGroupedTasksWithSubtasksByProject(Id projectId) {
        if (projectId == null) {
            throw new AuraHandledException('Project Id is required');
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
            String soql = baseQuery + 'WHERE Project__c = :projectId AND Parent_Task__c = null' + orderClause;
            allTasks = Database.query(soql);
        } catch (Exception e) {
            System.debug('Error querying Project_Task__c by project: ' + e.getMessage());
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
            taskWrapper.projectManagerId = (task.Project_Manager__c != null) ? String.valueOf(task.Project_Manager__c) : '';
            taskWrapper.projectManagerName = (task.Project_Manager__r != null) ? task.Project_Manager__r.Name : '';
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
            if (task.Subtasks__r != null && !task.Subtasks__r.isEmpty()) {
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
                    subtaskInfo.projectManagerId = (subtask.Project_Manager__c != null) ? String.valueOf(subtask.Project_Manager__c) : '';
                    subtaskInfo.projectManagerName = (subtask.Project_Manager__r != null) ? subtask.Project_Manager__r.Name : '';
                    subtaskInfo.developerName = (subtask.Developer__r != null) ? subtask.Developer__r.Name : '';
                    subtaskInfo.developerId = (subtask.Developer__c != null) ? String.valueOf(subtask.Developer__c) : '';
                    subtaskInfo.clientUserName = (subtask.Client_User__r != null) ? subtask.Client_User__r.Name : '';
                    subtaskInfo.clientUserId = (subtask.Client_User__c != null) ? String.valueOf(subtask.Client_User__c) : '';
                    subtaskInfo.accountId = (subtask.Account__c != null) ? String.valueOf(subtask.Account__c) : '';
                    subtaskInfo.accountName = (subtask.Account__r != null) ? subtask.Account__r.Name : '';
                    subtaskInfo.createdDate = subtask.CreatedDate;
                    subtaskInfo.description = subtask.Description__c != null ? subtask.Description__c : '';
                    subtaskInfo.hoverFields = buildHoverFieldValues(subtask, hoverFieldMembers, describeFieldMap);
                    subtaskInfo.summaryFields = buildSummaryFieldValues(subtask, summaryFieldMembers, describeFieldMap);
                    taskWrapper.subtasks.add(subtaskInfo);
                }
            }

            tasksByStatus.get(status).add(taskWrapper);
        }

        // Convert to list of StatusGroup objects
        List<StatusGroup> statusGroups = new List<StatusGroup>();
        for (String statusKey : tasksByStatus.keySet()) {
            StatusGroup sg = new StatusGroup();
            sg.status = statusKey;
            sg.tasks = tasksByStatus.get(statusKey);
            statusGroups.add(sg);
        }

        GroupedTasksResult result = new GroupedTasksResult();
        result.statusGroups = statusGroups;
        result.summaryFieldDefinitions = summaryFieldDefinitions;
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
        @AuraEnabled public String projectManagerName;
        @AuraEnabled public String projectManagerId;
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
        @AuraEnabled public String projectManagerName;
        @AuraEnabled public String projectManagerId;
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
    
    /**
     * @description Inner class for hover field values
     * @note Made public so TaskContextController can use it
     */
    public class HoverFieldValue {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean isLongText;
        @AuraEnabled public Boolean isRichText;
    }
    
    public class SummaryFieldValue {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String displayValue;
        @AuraEnabled public String rawValue;
        @AuraEnabled public Boolean isRichText;
    }
    
}

