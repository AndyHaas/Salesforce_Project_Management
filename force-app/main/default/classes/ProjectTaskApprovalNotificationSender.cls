/**
 * @description Sends approval-request emails to Contacts (not Salesforce Users). Used with record-triggered
 * flows instead of standard Flow Approvals. Messages include an internal Lightning URL and, when configured in
 * custom metadata, an Experience Cloud task link.
 *
 * SHARING (without sharing): Invoked from automation to email contacts; needs stable access to
 * task and project context for template merge fields across profiles.
 */
public without sharing class ProjectTaskApprovalNotificationSender {
  public static final String TYPE_BACKLOG_CLIENT = 'BACKLOG_CLIENT';
  public static final String TYPE_PM_CODE_REVIEWER = 'PM_CODE_REVIEWER';
  public static final String TYPE_CLIENT_COMPLETION = 'CLIENT_COMPLETION';

  /**
   * When true in a unit test, sendNotifications runs email logic. Default is false so record-triggered
   * flows that call this invocable complete without side effects (avoids org-specific automation
   * failures during DML in other test classes).
   */
  @TestVisible
  private static Boolean sendEmailsInThisTest = false;

  /**
   * @description Invocable input for Flow.
   */
  public class Request {
    @InvocableVariable(required=true label='Project Task Id')
    public Id projectTaskId;

    @InvocableVariable(
      required=true
      label='Approval type'
      description='BACKLOG_CLIENT, PM_CODE_REVIEWER, or CLIENT_COMPLETION'
    )
    public String approvalType;
  }

  /**
   * @description Sends one email per request row to the appropriate contact.
   * @param requests Flow invocations; bulk-safe.
   */
  @InvocableMethod(
    label='Send project task approval email to contact'
    description='Emails the client or PM contact with links to act on the task in Lightning or Experience Cloud.'
    category='Project Management'
  )
  public static void sendNotifications(List<Request> requests) {
    if (requests == null || requests.isEmpty()) {
      return;
    }
    if (Test.isRunningTest() && !sendEmailsInThisTest) {
      return;
    }

    Set<Id> taskIds = new Set<Id>();
    for (Request r : requests) {
      if (r.projectTaskId != null) {
        taskIds.add(r.projectTaskId);
      }
    }
    if (taskIds.isEmpty()) {
      return;
    }

    Map<Id, Project_Task__c> taskById = new Map<Id, Project_Task__c>(
      [
        SELECT
          Id,
          Name,
          Client_User__c,
          Project_Manager__c,
          Client_User__r.Email,
          Client_User__r.FirstName,
          Project_Manager__r.Email,
          Project_Manager__r.FirstName
        FROM Project_Task__c
        WHERE Id IN :taskIds
      ]
    );

    String communityFormat = null;
    List<Milestone_Task_Notification_Settings__mdt> cfg = [
      SELECT Community_Task_URL_Format__c
      FROM Milestone_Task_Notification_Settings__mdt
      WHERE DeveloperName = 'Default'
      LIMIT 1
    ];
    if (
      !cfg.isEmpty() && String.isNotBlank(cfg[0].Community_Task_URL_Format__c)
    ) {
      communityFormat = cfg[0].Community_Task_URL_Format__c.trim();
    }

    List<Messaging.SingleEmailMessage> toSend = new List<Messaging.SingleEmailMessage>();
    for (Request r : requests) {
      if (r.projectTaskId == null || String.isBlank(r.approvalType)) {
        continue;
      }
      Project_Task__c task = taskById.get(r.projectTaskId);
      if (task == null) {
        continue;
      }

      Id recipientContactId;
      String subject;
      String headline;
      if (TYPE_BACKLOG_CLIENT.equalsIgnoreCase(r.approvalType)) {
        recipientContactId = task.Client_User__c;
        subject = 'Action required: approve project task (backlog)';
        headline = 'Please review and approve or reject this backlog task in your portal or reply to your project team.';
      } else if (TYPE_PM_CODE_REVIEWER.equalsIgnoreCase(r.approvalType)) {
        recipientContactId = task.Project_Manager__c;
        subject = 'Action required: PM / code review';
        headline = 'A task has been submitted for PM or code review. Open it below to approve or reject.';
      } else if (TYPE_CLIENT_COMPLETION.equalsIgnoreCase(r.approvalType)) {
        recipientContactId = task.Client_User__c;
        subject = 'Action required: approve task completion';
        headline = 'Please confirm completion of this task in your portal or work with your project team.';
      } else {
        continue;
      }

      if (recipientContactId == null) {
        continue;
      }

      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setTargetObjectId(recipientContactId);
      email.setSaveAsActivity(false);
      email.setSubject(subject);

      String internalUrl =
        Url.getOrgDomainUrl().toExternalForm() +
        '/lightning/r/Project_Task__c/' +
        task.Id +
        '/view';

      String communityUrl = null;
      if (String.isNotBlank(communityFormat)) {
        communityUrl = communityFormat.replace('{0}', String.valueOf(task.Id));
      }

      String firstName = TYPE_PM_CODE_REVIEWER.equalsIgnoreCase(r.approvalType)
        ? task.Project_Manager__r.FirstName
        : task.Client_User__r.FirstName;
      String greeting = String.isNotBlank(firstName)
        ? ('Hello ' + firstName + ',')
        : 'Hello,';

      String bodyPlain =
        greeting +
        '\n\n' +
        headline +
        '\n\n' +
        'Task: ' +
        task.Name +
        '\n\n' +
        'Internal (Salesforce) link:\n' +
        internalUrl;

      if (String.isNotBlank(communityUrl)) {
        bodyPlain += '\n\nPortal link:\n' + communityUrl;
      }

      bodyPlain += '\n\nThank you.';

      String bodyHtml =
        '<p>' +
        escapeHtml(greeting) +
        '</p><p>' +
        escapeHtml(headline) +
        '</p><p><strong>Task:</strong> ' +
        escapeHtml(task.Name) +
        '</p><p><a href="' +
        internalUrl +
        '">Open in Salesforce</a></p>';

      if (String.isNotBlank(communityUrl)) {
        bodyHtml += '<p><a href="' + communityUrl + '">Open in portal</a></p>';
      }

      email.setPlainTextBody(bodyPlain);
      email.setHtmlBody(bodyHtml);

      applyOrgWideEmailIfAvailable(email);
      toSend.add(email);
    }

    if (!toSend.isEmpty()) {
      Messaging.sendEmail(toSend, false);
    }
  }

  private static String escapeHtml(String value) {
    if (String.isBlank(value)) {
      return '';
    }
    return value.replace('&', '&amp;')
      .replace('<', '&lt;')
      .replace('>', '&gt;')
      .replace('"', '&quot;');
  }

  private static void applyOrgWideEmailIfAvailable(
    Messaging.SingleEmailMessage email
  ) {
    try {
      List<OrgWideEmailAddress> rows = [
        SELECT Id
        FROM OrgWideEmailAddress
        WHERE IsAllowAllProfiles = TRUE
        LIMIT 1
      ];
      if (!rows.isEmpty()) {
        email.setOrgWideEmailAddressId(rows[0].Id);
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        'ProjectTaskApprovalNotificationSender: org-wide email not applied: ' +
        e.getMessage()
      );
    }
  }
}
