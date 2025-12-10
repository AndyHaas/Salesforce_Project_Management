/**
 * @description Portal-facing controller for Project detail data and metrics.
 * Provides scoped access for Experience Cloud users to Project details and
 * summarized Project Task metrics for a single project.
 */
public without sharing class PortalProjectController {

    @AuraEnabled(cacheable=true)
    public static ProjectDetailResult getProjectDetail(Id projectId) {
        if (projectId == null) {
            throw new AuraHandledException('Project Id is required');
        }

        User currentUser = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (currentUser.AccountId == null) {
            throw new AuraHandledException('Access denied');
        }

        List<Project__c> projects = [
            SELECT Id,
                Name,
                Status__c,
                Burn_Rate__c,
                Account__c,
                Account__r.Name,
                Invoiced__c,
                CreatedDate,
                Expected_Completion_Date__c,
                Actual_Completion_Date__c,
                Total_Time__c,
                Projected_Number_of_Hours__c
            FROM Project__c
            WHERE Id = :projectId
            AND Account__c = :currentUser.AccountId
            LIMIT 1
        ];

        if (projects.isEmpty()) {
            throw new AuraHandledException('Project not found or access denied');
        }

        Project__c project = projects[0];

        ProjectDetailResult result = new ProjectDetailResult();
        result.project = new ProjectInfo();
        result.project.id = project.Id;
        result.project.name = project.Name;
        result.project.status = project.Status__c;
        result.project.burnRate = project.Burn_Rate__c;
        result.project.accountId = project.Account__c;
        result.project.accountName = project.Account__r != null ? project.Account__r.Name : null;
        result.project.invoiced = project.Invoiced__c;
        result.project.createdDate = project.CreatedDate;
        result.project.startDate = null; // Not available on Project__c
        result.project.endDate = project.Expected_Completion_Date__c;
        result.project.totalEstimatedHours = project.Projected_Number_of_Hours__c;
        result.project.totalActualHours = project.Total_Time__c;

        // Aggregate task metrics scoped to this project (and account as an extra guard)
        TaskMetrics metrics = new TaskMetrics();

        // Query all tasks to get accurate counts and handle all statuses properly
        List<Project_Task__c> allTasks = [
            SELECT Id, Status__c, Estimated_Hours__c, Actual_Hours__c
            FROM Project_Task__c
            WHERE Project__c = :projectId
            AND Account__c = :project.Account__c
        ];

        // Count tasks by status
        Map<String, Integer> statusCounts = new Map<String, Integer>();
        Integer completedCount = 0;
        Decimal totalEstimated = 0;
        Decimal totalActual = 0;
        
        for (Project_Task__c task : allTasks) {
            String status = task.Status__c;
            String displayStatus = String.isBlank(status) ? 'Backlog' : status.trim();
            
            // Count by status
            Integer currentCount = statusCounts.containsKey(displayStatus) ? statusCounts.get(displayStatus) : 0;
            statusCounts.put(displayStatus, currentCount + 1);
            
            // Count completed tasks
            if (String.isNotBlank(status) && status.trim().equalsIgnoreCase('Completed')) {
                completedCount++;
            }
            
            // Sum hours
            if (task.Estimated_Hours__c != null) {
                totalEstimated += task.Estimated_Hours__c;
            }
            if (task.Actual_Hours__c != null) {
                totalActual += task.Actual_Hours__c;
            }
        }

        // Build status counts list for response
        for (String statusKey : statusCounts.keySet()) {
            StatusCount sc = new StatusCount();
            sc.status = statusKey;
            sc.count = statusCounts.get(statusKey);
            metrics.statusCounts.add(sc);
        }

        // Set metrics
        metrics.totalTasks = allTasks.size();
        metrics.totalEstimatedHours = totalEstimated;
        metrics.totalActualHours = totalActual;
        metrics.completedTasks = completedCount;
        metrics.openTasks = metrics.totalTasks - metrics.completedTasks;
        result.taskMetrics = metrics;

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static GroupedTasksResult getProjectTasks(Id projectId) {
        if (projectId == null) {
            throw new AuraHandledException('Project Id is required');
        }

        User currentUser = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (currentUser.AccountId == null) {
            throw new AuraHandledException('Access denied');
        }

        // Verify the project belongs to the user's account to avoid cross-account access
        List<Project__c> projects = [
            SELECT Id, Account__c
            FROM Project__c
            WHERE Id = :projectId
            AND Account__c = :currentUser.AccountId
            LIMIT 1
        ];

        if (projects.isEmpty()) {
            throw new AuraHandledException('Project not found or access denied');
        }

        List<Project_Task__c> tasks = [
            SELECT Id,
                Name,
                Status__c,
                Priority__c,
                Due_Date__c,
                Estimated_Hours__c,
                Actual_Hours__c,
                Progress_Percentage__c
            FROM Project_Task__c
            WHERE Project__c = :projectId
            AND Account__c = :projects[0].Account__c
            ORDER BY Status__c, CreatedDate DESC
            LIMIT 500
        ];

        Map<String, StatusGroup> grouped = new Map<String, StatusGroup>();

        for (Project_Task__c task : tasks) {
            String statusKey = task.Status__c != null ? task.Status__c : 'Backlog';

            if (!grouped.containsKey(statusKey)) {
                StatusGroup sg = new StatusGroup();
                sg.status = statusKey;
                grouped.put(statusKey, sg);
            }

            TaskSummary summary = new TaskSummary();
            summary.id = task.Id;
            summary.name = task.Name;
            summary.status = task.Status__c;
            summary.priority = task.Priority__c;
            summary.dueDate = task.Due_Date__c;
            summary.estimatedHours = task.Estimated_Hours__c;
            summary.actualHours = task.Actual_Hours__c;
            summary.progressPercentage = task.Progress_Percentage__c;

            grouped.get(statusKey).tasks.add(summary);
        }

        GroupedTasksResult result = new GroupedTasksResult();
        result.statusGroups = grouped.values();
        return result;
    }

    public class ProjectDetailResult {
        @AuraEnabled public ProjectInfo project;
        @AuraEnabled public TaskMetrics taskMetrics;
    }

    public class ProjectInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal burnRate;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Boolean invoiced;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Decimal totalEstimatedHours;
        @AuraEnabled public Decimal totalActualHours;
    }

    public class TaskMetrics {
        @AuraEnabled public Integer totalTasks = 0;
        @AuraEnabled public Integer openTasks = 0;
        @AuraEnabled public Integer completedTasks = 0;
        @AuraEnabled public Decimal totalEstimatedHours = 0;
        @AuraEnabled public Decimal totalActualHours = 0;
        @AuraEnabled public List<StatusCount> statusCounts = new List<StatusCount>();
    }

    public class StatusCount {
        @AuraEnabled public String status;
        @AuraEnabled public Integer count;
    }

    public class GroupedTasksResult {
        @AuraEnabled public List<StatusGroup> statusGroups = new List<StatusGroup>();
    }

    public class StatusGroup {
        @AuraEnabled public String status;
        @AuraEnabled public List<TaskSummary> tasks = new List<TaskSummary>();
    }

    public class TaskSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Decimal estimatedHours;
        @AuraEnabled public Decimal actualHours;
        @AuraEnabled public Decimal progressPercentage;
    }
}
