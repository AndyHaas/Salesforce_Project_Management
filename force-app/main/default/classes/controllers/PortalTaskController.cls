/**
 * @description Apex controller for portal task detail and workflow actions.
 * Task file list and upload are handled by the core fileManager LWC and TaskContextController.
 * Experience Cloud file preview (iframe) uses getFilePreviewUrl with ContentDistribution URLs.
 */
public without sharing class PortalTaskController {
  /**
   * @description Get task detail with all related information
   * @param taskId The Project Task ID
   * @return TaskDetailData wrapper with task and related information
   */
  @AuraEnabled(cacheable=true)
  public static TaskDetailData getTaskDetail(String taskId) {
    if (String.isBlank(taskId)) {
      throw new AuraHandledException('Task ID is required');
    }

    TaskDetailData data = new TaskDetailData();

    // Get current user's account
    User currentUser = [
      SELECT Id, AccountId, ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    Set<Id> accountIds = new Set<Id>();
    if (currentUser.AccountId != null) {
      accountIds.add(currentUser.AccountId);
    }

    // Query task with all necessary fields
    // Check access via Project's Account (Master-Detail relationship)
    // Tasks are linked to Projects, and Projects are linked to Accounts
    List<Project_Task__c> tasks = [
      SELECT
        Id,
        Name,
        Description__c,
        Status__c,
        Priority__c,
        Start_Date__c,
        Due_Date__c,
        Is_Overdue__c,
        At_Risk_Due_to_Dependencies__c,
        Progress_Percentage__c,
        Review_Status_Icons__c,
        Estimated_Hours__c,
        Actual_Hours__c,
        Total_Estimated_Hours__c,
        Total_Actual_Hours__c,
        Project__c,
        Project__r.Name,
        Project__r.Id,
        Project__r.Account__c,
        Account__c,
        Account__r.Name,
        Project_Manager__c,
        Project_Manager__r.Name,
        Developer__c,
        Developer__r.Name,
        Client_User__c,
        Client_User__r.Name,
        Parent_Task__c,
        Parent_Task__r.Name,
        Parent_Task__r.Id,
        Parent_Task__r.Status__c,
        Parent_Task__r.Priority__c,
        Parent_Task__r.Description__c,
        Release_Notes__c,
        Release_Notes__r.Release_Tag__r.Name,
        Release_Notes__r.Release_Version__r.Name,
        Release_Notes__r.Release_Notes_Text__c,
        Has_Client_User_Defined__c,
        Submission_Status__c,
        Approved_by_PM_Code_Reviewer__c,
        CreatedDate
      FROM Project_Task__c
      WHERE
        Id = :taskId
        AND (Project__r.Account__c IN :accountIds
        OR Account__c IN :accountIds)
      LIMIT 1
    ];

    if (tasks.isEmpty()) {
      throw new AuraHandledException('Task not found or access denied');
    }

    Project_Task__c task = tasks[0];
    data.task = task;

    return data;
  }
  /**
   * @description Resolves task Id if the current portal user may access it (same scope as getTaskDetail).
   */
  private static Id requirePortalTaskAccess(String taskId) {
    if (String.isBlank(taskId)) {
      throw new AuraHandledException('Task ID is required');
    }

    User currentUser = [
      SELECT AccountId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    Set<Id> accountIds = new Set<Id>();
    if (currentUser.AccountId != null) {
      accountIds.add(currentUser.AccountId);
    }

    List<Project_Task__c> tasks = [
      SELECT Id
      FROM Project_Task__c
      WHERE
        Id = :taskId
        AND (Project__r.Account__c IN :accountIds
        OR Account__c IN :accountIds)
      LIMIT 1
    ];

    if (tasks.isEmpty()) {
      throw new AuraHandledException('Task not found or access denied');
    }

    return tasks[0].Id;
  }

  /**
   * Client approve/reject modals optionally persist text to Project_Task_Submission__c.Comments__c.
   * Persistence is best-effort (see applyCommentsToSubmissionAfterTaskTransition); task workflow is not blocked if it fails.
   */
  private static final Set<String> CLIENT_REVIEW_COMMENT_ACTION_KEYS = new Set<String>{
    'approveClientBacklog',
    'rejectClientBacklog',
    'approveClientCompletion',
    'rejectClientCompletion'
  };

  /**
   * Runs only after Project_Task__c is updated so the V4 record-triggered flow can insert Project_Task_Submission__c
   * and set Most_Recent_Project_Task_Submission__c (last flow element). Resolves submission Id from that lookup,
   * else falls back to the latest child by CreatedDate. Best-effort: errors are logged; no throw.
   */
  private static void applyCommentsToSubmissionAfterTaskTransition(
    Id projectTaskId,
    String comments
  ) {
    try {
      String v = comments == null ? null : comments.trim();
      if (String.isBlank(v)) {
        return;
      }

      Id submissionId = null;

      List<Project_Task__c> tasks = [
        SELECT Most_Recent_Project_Task_Submission__c
        FROM Project_Task__c
        WHERE Id = :projectTaskId
        LIMIT 1
      ];
      if (
        !tasks.isEmpty() &&
        tasks[0].Most_Recent_Project_Task_Submission__c != null
      ) {
        submissionId = tasks[0].Most_Recent_Project_Task_Submission__c;
      }

      if (submissionId == null) {
        List<Project_Task_Submission__c> rows = [
          SELECT Id
          FROM Project_Task_Submission__c
          WHERE Project_Task__c = :projectTaskId
          ORDER BY CreatedDate DESC
          LIMIT 1
        ];
        if (!rows.isEmpty()) {
          submissionId = rows[0].Id;
        }
      }

      if (submissionId == null) {
        return;
      }

      update new Project_Task_Submission__c(Id = submissionId, Comments__c = v);
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        'PortalTaskController.applyCommentsToSubmissionAfterTaskTransition skipped: ' +
        e.getMessage()
      );
    }
  }

  /**
   * @description Applies a portal task workflow action (field updates) after access check.
   * @param taskId Project Task Id
   * @param actionKey LWC action key (e.g. submitClientApproval, approveClientBacklog)
   * @param comments Optional; for client review approve/reject actions only, written to Project_Task_Submission__c.Comments__c
   * after the task update (flow-created submission; Id from Most_Recent_Project_Task_Submission__c when set).
   */
  @AuraEnabled
  public static void applyPortalTaskAction(
    String taskId,
    String actionKey,
    String comments
  ) {
    Id tid = requirePortalTaskAccess(taskId);
    if (String.isBlank(actionKey)) {
      throw new AuraHandledException('Action is required');
    }

    Project_Task__c u = new Project_Task__c(Id = tid);

    if (actionKey == 'submitClientApproval') {
      u.Status__c = 'Backlog';
      u.Submission_Status__c = 'Project Manager Submits for Client Approval';
    } else if (actionKey == 'approveClientBacklog') {
      u.Status__c = 'Pending';
      u.Submission_Status__c = 'Client Approves Pending';
    } else if (actionKey == 'rejectClientBacklog') {
      u.Status__c = 'Backlog';
      u.Submission_Status__c = 'Client Rejects Backlog Task';
    } else if (actionKey == 'submitPmReview') {
      u.Status__c = 'In Review';
      u.Submission_Status__c = 'Developer Submits for Approval to Project Manager';
    } else if (actionKey == 'approvePmReview') {
      u.Status__c = 'In Review';
      u.Submission_Status__c = 'Project Manager Accepts In Progress Task';
    } else if (actionKey == 'rejectPmReview') {
      u.Status__c = 'In Progress';
      u.Submission_Status__c = 'Project Manager Rejects In Progress Task';
    } else if (actionKey == 'submitClientCompletion') {
      u.Submission_Status__c = 'Project Manager Submits for Client Review';
      u.Approved_by_PM_Code_Reviewer__c = true;
    } else if (actionKey == 'approveClientCompletion') {
      u.Status__c = 'Completed';
      u.Submission_Status__c = 'Client Approves Completion';
    } else if (actionKey == 'rejectClientCompletion') {
      u.Status__c = 'In Progress';
      u.Submission_Status__c = 'Client Rejects Completion';
    } else {
      throw new AuraHandledException('Unknown action: ' + actionKey);
    }

    update u;

    if (CLIENT_REVIEW_COMMENT_ACTION_KEYS.contains(actionKey)) {
      applyCommentsToSubmissionAfterTaskTransition(tid, comments);
    }
  }

  /**
   * @description Returns a browser-viewable URL for a ContentVersion via ContentDistribution
   * (Experience Cloud–friendly preview in c-portal-file-preview-modal).
   *
   * @param contentVersionId The ContentVersion Id.
   * @return Public distribution URL for in-browser preview.
   */
  @AuraEnabled
  public static String getFilePreviewUrl(String contentVersionId) {
    if (String.isBlank(contentVersionId)) {
      throw new AuraHandledException('Content Version ID is required');
    }

    try {
      List<ContentDistribution> existingDistributions = [
        SELECT DistributionPublicUrl
        FROM ContentDistribution
        WHERE
          ContentVersionId = :contentVersionId
          AND PreferencesAllowViewInBrowser = TRUE
        LIMIT 1
      ];

      if (!existingDistributions.isEmpty()) {
        return existingDistributions[0].DistributionPublicUrl;
      }

      ContentDistribution dist = new ContentDistribution();
      dist.ContentVersionId = contentVersionId;
      dist.Name = 'Preview Distribution';
      dist.PreferencesAllowViewInBrowser = true;
      dist.PreferencesLinkLatestVersion = true;
      dist.PreferencesAllowOriginalDownload = true;

      insert dist;

      ContentDistribution createdDist = [
        SELECT DistributionPublicUrl
        FROM ContentDistribution
        WHERE Id = :dist.Id
        LIMIT 1
      ];

      return createdDist.DistributionPublicUrl;
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'getFilePreviewUrl: ' +
          e.getMessage() +
          ' Type: ' +
          e.getTypeName() +
          ' Stack: ' +
          e.getStackTraceString()
      );
      throw new AuraHandledException(
        'Unable to open file preview. Please try again.'
      );
    }
  }

  /**
   * @description Wrapper class for task detail data
   */
  public class TaskDetailData {
    @AuraEnabled
    public Project_Task__c task;
  }
}