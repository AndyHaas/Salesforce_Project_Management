/**
 * Loads every pinned Message__c for the current portal / LEX messaging thread, independent of
 * pagination. {@link PortalMessagingController#getMessages} remains paged; this class keeps the
 * pinned summary accurate for older pins that are not yet in the client buffer.
 * Visibility matches portal expectations: non–Milestone-team users only see client-visible rows.
 */
public with sharing class MessagingPinnedSupport {
  /**
   * Wire DTO aligned with {@code PortalMessagingController#getMessages} row shape for LWC reuse.
   */
  public class MessageRow {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String body;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public String senderId;
    @AuraEnabled
    public String senderName;
    @AuraEnabled
    public Boolean isPinned;
    @AuraEnabled
    public Boolean isRead;
    @AuraEnabled
    public Boolean isEdited;
    @AuraEnabled
    public String relatedTaskId;
    @AuraEnabled
    public String relatedTaskName;
    @AuraEnabled
    public String relatedProjectId;
    @AuraEnabled
    public String relatedProjectName;
    @AuraEnabled
    public String accountName;
    @AuraEnabled
    public Boolean visibleToClient;
    @AuraEnabled
    public Datetime lastEditedDate;
    @AuraEnabled
    public String recipientType;
    @AuraEnabled
    public String replyToMessageId;
    @AuraEnabled
    public String replyToMessageBody;
    @AuraEnabled
    public String replyToSenderName;
    @AuraEnabled
    public Datetime replyToCreatedDate;
    @AuraEnabled
    public Boolean isMentioned;
  }

  private static final Integer MAX_PINNED = 500;

  /**
   * @param recipientType Reserved for parity with getMessages; visibility uses {@code isMilestoneTeamMember} and {@code Visible_To_Client__c}.
   * @param relatedAccountId Thread Account__c when viewing account (or broader) context.
   * @param relatedProjectId Thread Related_Project__c when viewing a project.
   * @param relatedTaskId Thread Related_Task__c when viewing a task.
   * @param isMilestoneTeamMember When true, internal viewers see team-only rows as well.
   * @return All pinned, non-deleted messages for the narrowest scope (task, else project, else account).
   */
  @AuraEnabled(cacheable=false)
  public static List<MessageRow> getPinnedMessages(
    String recipientType,
    String relatedAccountId,
    String relatedProjectId,
    String relatedTaskId,
    Boolean isMilestoneTeamMember
  ) {
    Id taskId = parseId(relatedTaskId);
    Id projectId = parseId(relatedProjectId);
    Id accountId = parseId(relatedAccountId);

    if (taskId == null && projectId == null && accountId == null) {
      return new List<MessageRow>();
    }

    Boolean milestone = isMilestoneTeamMember == true;
    List<Message__c> rows;

    if (taskId != null) {
      rows = milestone ? queryPinnedForTask(taskId) : queryPinnedForTaskClientVisible(taskId);
    } else if (projectId != null) {
      rows = milestone ? queryPinnedForProject(projectId) : queryPinnedForProjectClientVisible(projectId);
    } else {
      rows = milestone ? queryPinnedForAccount(accountId) : queryPinnedForAccountClientVisible(accountId);
    }

    return toRows(rows);
  }

  private static Id parseId(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    try {
      return (Id) value;
    } catch (Exception ignored) {
      return null;
    }
  }

  private static List<Message__c> queryPinnedForTask(Id taskId) {
    return [
      SELECT
        Id,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__r.Name,
        Visible_To_Client__c,
        Last_Edited_Date__c,
        Recipient_Type__c,
        Reply_To__c,
        Reply_To__r.Body__c,
        Reply_To__r.CreatedDate,
        Reply_To__r.Sender__r.Name
      FROM Message__c
      WHERE Deleted__c = FALSE AND Is_Pinned__c = TRUE AND Related_Task__c = :taskId
      WITH SECURITY_ENFORCED
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  private static List<Message__c> queryPinnedForTaskClientVisible(Id taskId) {
    return [
      SELECT
        Id,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__r.Name,
        Visible_To_Client__c,
        Last_Edited_Date__c,
        Recipient_Type__c,
        Reply_To__c,
        Reply_To__r.Body__c,
        Reply_To__r.CreatedDate,
        Reply_To__r.Sender__r.Name
      FROM Message__c
      WHERE Deleted__c = FALSE AND Is_Pinned__c = TRUE AND Related_Task__c = :taskId AND Visible_To_Client__c = TRUE
      WITH SECURITY_ENFORCED
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  private static List<Message__c> queryPinnedForProject(Id projectId) {
    return [
      SELECT
        Id,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__r.Name,
        Visible_To_Client__c,
        Last_Edited_Date__c,
        Recipient_Type__c,
        Reply_To__c,
        Reply_To__r.Body__c,
        Reply_To__r.CreatedDate,
        Reply_To__r.Sender__r.Name
      FROM Message__c
      WHERE Deleted__c = FALSE AND Is_Pinned__c = TRUE AND Related_Project__c = :projectId
      WITH SECURITY_ENFORCED
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  private static List<Message__c> queryPinnedForProjectClientVisible(Id projectId) {
    return [
      SELECT
        Id,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__r.Name,
        Visible_To_Client__c,
        Last_Edited_Date__c,
        Recipient_Type__c,
        Reply_To__c,
        Reply_To__r.Body__c,
        Reply_To__r.CreatedDate,
        Reply_To__r.Sender__r.Name
      FROM Message__c
      WHERE
        Deleted__c = FALSE
        AND Is_Pinned__c = TRUE
        AND Related_Project__c = :projectId
        AND Visible_To_Client__c = TRUE
      WITH SECURITY_ENFORCED
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  private static List<Message__c> queryPinnedForAccount(Id accountId) {
    return [
      SELECT
        Id,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__r.Name,
        Visible_To_Client__c,
        Last_Edited_Date__c,
        Recipient_Type__c,
        Reply_To__c,
        Reply_To__r.Body__c,
        Reply_To__r.CreatedDate,
        Reply_To__r.Sender__r.Name
      FROM Message__c
      WHERE Deleted__c = FALSE AND Is_Pinned__c = TRUE AND Account__c = :accountId
      WITH SECURITY_ENFORCED
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  private static List<Message__c> queryPinnedForAccountClientVisible(Id accountId) {
    return [
      SELECT
        Id,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__r.Name,
        Visible_To_Client__c,
        Last_Edited_Date__c,
        Recipient_Type__c,
        Reply_To__c,
        Reply_To__r.Body__c,
        Reply_To__r.CreatedDate,
        Reply_To__r.Sender__r.Name
      FROM Message__c
      WHERE Deleted__c = FALSE AND Is_Pinned__c = TRUE AND Account__c = :accountId AND Visible_To_Client__c = TRUE
      WITH SECURITY_ENFORCED
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  private static List<MessageRow> toRows(List<Message__c> rows) {
    List<MessageRow> out = new List<MessageRow>();
    if (rows == null || rows.isEmpty()) {
      return out;
    }
    for (Message__c msg : rows) {
      MessageRow row = new MessageRow();
      row.id = String.valueOf(msg.Id);
      row.body = msg.Body__c;
      row.createdDate = msg.CreatedDate;
      row.senderId = msg.Sender__c != null ? String.valueOf(msg.Sender__c) : null;
      row.senderName = msg.Sender__r != null ? msg.Sender__r.Name : null;
      row.isPinned = msg.Is_Pinned__c == true;
      row.isRead = msg.Is_Read__c == true;
      row.isEdited = msg.Is_Edited__c == true;
      row.relatedTaskId = msg.Related_Task__c != null ? String.valueOf(msg.Related_Task__c) : null;
      row.relatedTaskName = msg.Related_Task__r != null ? msg.Related_Task__r.Name : null;
      row.relatedProjectId = msg.Related_Project__c != null ? String.valueOf(msg.Related_Project__c) : null;
      row.relatedProjectName = msg.Related_Project__r != null ? msg.Related_Project__r.Name : null;
      row.accountName = msg.Account__r != null ? msg.Account__r.Name : null;
      row.visibleToClient = msg.Visible_To_Client__c == true;
      row.lastEditedDate = msg.Last_Edited_Date__c;
      row.recipientType = msg.Recipient_Type__c;
      row.replyToMessageId = msg.Reply_To__c != null ? String.valueOf(msg.Reply_To__c) : null;
      row.replyToMessageBody = msg.Reply_To__r != null ? msg.Reply_To__r.Body__c : null;
      row.replyToSenderName = msg.Reply_To__r != null &&
        msg.Reply_To__r.Sender__r != null
        ? msg.Reply_To__r.Sender__r.Name
        : null;
      row.replyToCreatedDate = msg.Reply_To__r != null ? msg.Reply_To__r.CreatedDate : null;
      row.isMentioned = false;
      out.add(row);
    }
    return out;
  }
}
