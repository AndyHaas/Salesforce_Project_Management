/**
 * Loads every pinned Message__c for the current portal / LEX messaging thread, independent of
 * pagination. {@link MessagingController#getMessages} remains paged; this class keeps the
 * pinned summary accurate for older pins that are not yet in the client buffer.
 * Visibility matches portal expectations: non–Milestone-team users only see client-visible rows.
 * <p>SOQL intentionally omits {@code WITH SECURITY_ENFORCED} (same rationale as
 * {@link MessagingController#getLatestMessages}): Experience Cloud profiles often lack FLS on
 * cross-object columns ({@code CreatedBy.Name}, {@code Sender__r.Name}, reply traversals) while
 * still needing the thread UI. Record access is enforced by {@code with sharing} and the same
 * {@code Visible_To_Client__c} / context filters as the client-visible query variants.
 */
public with sharing class MessagingPinnedSupport {
  /**
   * Wire DTO aligned with {@code MessagingController#getMessages} row shape for LWC reuse.
   */
  public class MessageRow {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String createdById;
    @AuraEnabled
    public String createdByName;
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
    public String accountId;
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
    try {
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

      return toRows(rows, milestone);
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'MessagingPinnedSupport.getPinnedMessages: ' + e.getMessage());
      System.debug(LoggingLevel.ERROR, e.getStackTraceString());
      throw new AuraHandledException(
        String.isNotBlank(e.getMessage()) ? e.getMessage() : 'Unable to load pinned messages.'
      );
    }
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
        CreatedById,
        CreatedBy.Name,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read_By_Client__c,
        Is_Read_By_Milestone_Team__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__c,
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
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  private static List<Message__c> queryPinnedForTaskClientVisible(Id taskId) {
    return [
      SELECT
        Id,
        CreatedById,
        CreatedBy.Name,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read_By_Client__c,
        Is_Read_By_Milestone_Team__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__c,
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
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  private static List<Message__c> queryPinnedForProject(Id projectId) {
    return [
      SELECT
        Id,
        CreatedById,
        CreatedBy.Name,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read_By_Client__c,
        Is_Read_By_Milestone_Team__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__c,
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
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  private static List<Message__c> queryPinnedForProjectClientVisible(Id projectId) {
    return [
      SELECT
        Id,
        CreatedById,
        CreatedBy.Name,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read_By_Client__c,
        Is_Read_By_Milestone_Team__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__c,
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
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  private static List<Message__c> queryPinnedForAccount(Id accountId) {
    return [
      SELECT
        Id,
        CreatedById,
        CreatedBy.Name,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read_By_Client__c,
        Is_Read_By_Milestone_Team__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__c,
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
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  private static List<Message__c> queryPinnedForAccountClientVisible(Id accountId) {
    return [
      SELECT
        Id,
        CreatedById,
        CreatedBy.Name,
        Body__c,
        CreatedDate,
        Sender__c,
        Sender__r.Name,
        Is_Pinned__c,
        Is_Read_By_Client__c,
        Is_Read_By_Milestone_Team__c,
        Is_Edited__c,
        Related_Task__c,
        Related_Task__r.Name,
        Related_Project__c,
        Related_Project__r.Name,
        Account__c,
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
      ORDER BY CreatedDate ASC
      LIMIT :MAX_PINNED
    ];
  }

  /**
   * @param isMilestoneTeamMember When true (internal viewer), {@code Is_Read_By_Milestone_Team__c}; otherwise {@code Is_Read_By_Client__c}, matching {@link MessagingController#getMessages}.
   */
  private static List<MessageRow> toRows(List<Message__c> rows, Boolean isMilestoneTeamMember) {
    List<MessageRow> out = new List<MessageRow>();
    if (rows == null || rows.isEmpty()) {
      return out;
    }
    Boolean milestone = isMilestoneTeamMember == true;
    for (Message__c msg : rows) {
      MessageRow row = new MessageRow();
      row.id = String.valueOf(msg.Id);
      row.createdById = msg.CreatedById != null ? String.valueOf(msg.CreatedById) : null;
      row.createdByName = msg.CreatedBy != null ? msg.CreatedBy.Name : null;
      row.body = msg.Body__c;
      row.createdDate = msg.CreatedDate;
      row.senderId = msg.Sender__c != null ? String.valueOf(msg.Sender__c) : null;
      row.senderName = msg.Sender__r != null ? msg.Sender__r.Name : null;
      row.isPinned = msg.Is_Pinned__c == true;
      if (milestone) {
        row.isRead = msg.Is_Read_By_Milestone_Team__c != null ? msg.Is_Read_By_Milestone_Team__c : false;
      } else {
        row.isRead = msg.Is_Read_By_Client__c != null ? msg.Is_Read_By_Client__c : false;
      }
      row.isEdited = msg.Is_Edited__c == true;
      row.relatedTaskId = msg.Related_Task__c != null ? String.valueOf(msg.Related_Task__c) : null;
      row.relatedTaskName = msg.Related_Task__r != null ? msg.Related_Task__r.Name : null;
      row.relatedProjectId = msg.Related_Project__c != null ? String.valueOf(msg.Related_Project__c) : null;
      row.relatedProjectName = msg.Related_Project__r != null ? msg.Related_Project__r.Name : null;
      row.accountId = msg.Account__c != null ? String.valueOf(msg.Account__c) : null;
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
