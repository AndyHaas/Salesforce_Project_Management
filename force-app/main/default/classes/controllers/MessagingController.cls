/**
 * @description Apex controller for the portalMessaging LWC: send, list, pin, context, mentions, and read state.
 * Handles messaging between clients and the Milestone team. Uses without sharing so portal users can insert Message__c.
 */
public without sharing class MessagingController {
  // SOQL field constants to avoid typos and keep query readable
  private static final String FIELD_ID = 'Id';
  private static final String FIELD_ACCOUNT = 'Account__c';
  private static final String FIELD_PROJECT = 'Related_Project__c';
  private static final String FIELD_TASK = 'Related_Task__c';
  private static final String FIELD_RECIPIENT_TYPE = 'Recipient_Type__c';
  private static final String FIELD_VISIBLE_TO_CLIENT = 'Visible_To_Client__c';
  private static final String FIELD_DELETED = 'Deleted__c';
  private static final String FIELD_SENDER = 'Sender__c';
  private static final String RECIPIENT_CLIENT = 'Client';
  private static final String RECIPIENT_TEAM = 'Milestone Team';

  // Query limits
  private static final Integer MAX_MESSAGE_LIMIT = 200;
  private static final Integer DEFAULT_MESSAGE_LIMIT = 50;
  private static final Integer MAX_CONTACT_SEARCH_LIMIT = 20;
  /** SOSL RETURNING row cap — keeps Id IN (:bind) within platform limits without batching. */
  private static final Integer SOSL_MESSAGE_ID_LIMIT = 2000;
  /** Minimum characters for SOSL body search; shorter terms return no rows. */
  private static final Integer SOSL_MIN_TERM_LENGTH = 2;

  private static final String GET_MESSAGES_SELECT_LIST =
    'SELECT Id, Name, CreatedById, Body__c, Sender__c, Sender__r.Name, Sender__r.Email, ' +
    'Recipient_Type__c, Related_Project__c, Related_Project__r.Name, ' +
    'Related_Task__c, Related_Task__r.Name, Related_Task__r.Project__c, ' +
    'Mentioned_Contacts__c, Is_Read_By_Client__c, Is_Read_By_Milestone_Team__c, Deleted__c, Visible_To_Client__c, ' +
    'Is_Edited__c, Last_Edited_Date__c, CreatedDate, CreatedBy.Name, ' +
    'Account__c, Account__r.Name, Reply_To__c, Reply_To__r.Id, Reply_To__r.Body__c, ' +
    'Reply_To__r.Sender__r.Name, Reply_To__r.CreatedDate, Reply_To__r.Related_Task__c, ' +
    'Is_Pinned__c ';

  // Normalize potentially undefined/blank strings coming from JS
  private static String normalizeOptional(String value) {
    if (value == null) {
      return null;
    }
    String trimmed = value.trim();
    return (trimmed == '' ||
      trimmed.equalsIgnoreCase('undefined') ||
      trimmed.equalsIgnoreCase('null'))
      ? null
      : trimmed;
  }

  /**
   * Strips * and % so substring SOSL uses our own leading/trailing wildcards only.
   */
  private static String normalizeTermForSosl(String term) {
    if (String.isBlank(term)) {
      return null;
    }
    String t = term.trim().replace('*', ' ').replace('%', ' ');
    t = t.replaceAll('\\s+', ' ').trim();
    return String.isBlank(t) ? null : t;
  }

  /**
   * Single SOSL call; materializes Message__c Ids into a Set (no SOQL in this method).
   */
  private static Set<Id> searchMessageIdsBySosl(String term) {
    Set<Id> searchCandidateIds = new Set<Id>();
    if (String.isBlank(term) || term.length() < SOSL_MIN_TERM_LENGTH) {
      return searchCandidateIds;
    }
    String escapedForSosl = String.escapeSingleQuotes(term);
    String sosl =
      'FIND \'*' +
      escapedForSosl +
      '*\' IN ALL FIELDS RETURNING Message__c(Id) LIMIT ' +
      SOSL_MESSAGE_ID_LIMIT;
    try {
      List<List<SObject>> searchResults = Search.query(sosl);
      if (searchResults != null && !searchResults.isEmpty()) {
        for (SObject row : searchResults[0]) {
          if (row != null && row.get(FIELD_ID) != null) {
            searchCandidateIds.add((Id) row.get(FIELD_ID));
          }
        }
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.WARN, 'SOSL search failed: ' + e.getMessage());
    }
    return searchCandidateIds;
  }

  /**
   * @description Get current user with Contact fields needed for messaging
   * @return User record with Id, ContactId, AccountId, Name, Email
   */
  private static User getCurrentUserWithContactFields() {
    return [
      SELECT Id, ContactId, AccountId, Name, Email
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
  }

  /**
   * Portal users may only send messages tied to their own Account__c (closes IDOR on related Ids).
   */
  private static void assertPortalUserMessageContext(Message__c message, Id portalUserAccountId) {
    if (portalUserAccountId == null) {
      return;
    }
    if (message.Account__c == null || message.Account__c != portalUserAccountId) {
      throw new AuraHandledException('You can only send messages in your account context.');
    }
  }

  /**
   * Same eligibility rules as getMentionableContacts: only these Ids may be stored and notified.
   *
   * @param candidateIds Raw mention Ids from the client (may be empty or invalid).
   * @param currentUser User row with AccountId (portal vs internal).
   * @return Validated Ids in stable order (query order).
   */
  private static List<String> filterToMentionableContactIds(List<String> candidateIds, User currentUser) {
    if (candidateIds == null || candidateIds.isEmpty()) {
      return new List<String>();
    }
    Set<Id> idSet = new Set<Id>();
    for (String s : candidateIds) {
      if (String.isBlank(s)) {
        continue;
      }
      try {
        idSet.add((Id) s.trim());
      } catch (Exception ignore) {
        // Non-Id strings ignored
      }
    }
    if (idSet.isEmpty()) {
      return new List<String>();
    }
    List<Contact> contacts;
    if (currentUser.AccountId != null) {
      Id currentUserAccountId = currentUser.AccountId;
      contacts = [
        SELECT Id
        FROM Contact
        WHERE
          Id IN :idSet
          AND Portal_Access_Enabled__c = TRUE
          AND (AccountId = :currentUserAccountId OR AccountId = NULL)
        ORDER BY Name
      ];
    } else {
      contacts = [
        SELECT Id
        FROM Contact
        WHERE Id IN :idSet AND Portal_Access_Enabled__c = TRUE
        ORDER BY Name
      ];
    }
    List<String> out = new List<String>();
    for (Contact c : contacts) {
      out.add(String.valueOf(c.Id));
    }
    return out;
  }

  /**
   * @description Send a message
   * @param messageBody The message body (rich text)
   * @param recipientType The recipient type (Client or Milestone Team)
   * @param relatedAccountId Optional related account ID
   * @param relatedProjectId Optional related project ID
   * @param relatedTaskId Optional related task ID
   * @param mentionedContactIds List of mentioned contact IDs
   * @param isVisibleToClient Whether the message is visible to clients (default true)
   * @param replyToMessageId Optional ID of the message being replied to
   * @return Message ID
   */
  @AuraEnabled
  public static String sendMessage(
    String messageBody,
    String recipientType,
    String relatedAccountId,
    String relatedProjectId,
    String relatedTaskId,
    List<String> mentionedContactIds,
    Boolean isVisibleToClient,
    String replyToMessageId
  ) {
    if (String.isBlank(messageBody)) {
      throw new AuraHandledException('Message body is required');
    }

    if (String.isBlank(recipientType)) {
      throw new AuraHandledException('Recipient type is required');
    }

    try {
      // Get current user
      User currentUser = getCurrentUserWithContactFields();
      Id currentUserAccountId = currentUser.AccountId;

      // Get or create Contact for the user (Sender__c field requires Contact, not User)
      // Milestone team members don't have ContactId, so we create/find one
      Id senderContactId = getOrCreateContactForUser(currentUser);

      // Create message record
      Message__c message = new Message__c();
      message.Body__c = messageBody;
      message.Sender__c = senderContactId;
      message.Recipient_Type__c = recipientType;
      // Initialize read status based on user type
      // Sender always sees their own message as "read", but recipient status starts as unread
      if (currentUserAccountId != null) {
        // Portal user (client) sending - mark client read as true (they sent it), team read as false
        message.Is_Read_By_Client__c = true;
        message.Is_Read_By_Milestone_Team__c = false;
      } else {
        // Milestone team member sending - mark team read as true (they sent it), client read as false
        message.Is_Read_By_Milestone_Team__c = true;
        message.Is_Read_By_Client__c = false;
      }

      // Set related account, project, or task
      // Priority: Task > Project > Account
      if (String.isNotBlank(relatedTaskId)) {
        message.Related_Task__c = relatedTaskId;
        List<Project_Task__c> tasks = [
          SELECT Account__c, Project__c, Project__r.Account__c
          FROM Project_Task__c
          WHERE Id = :relatedTaskId
          LIMIT 1
        ];
        if (tasks.isEmpty()) {
          throw new AuraHandledException('The related task was not found or is not available.');
        }
        Project_Task__c task = tasks[0];
        if (task.Project__c != null) {
          message.Related_Project__c = task.Project__c;
        }
        if (task.Account__c != null) {
          message.Account__c = task.Account__c;
        } else if (task.Project__r?.Account__c != null) {
          message.Account__c = task.Project__r.Account__c;
        }
      } else if (String.isNotBlank(relatedProjectId)) {
        message.Related_Project__c = relatedProjectId;
        // Get account from project
        Project__c project = [
          SELECT Account__c
          FROM Project__c
          WHERE Id = :relatedProjectId
          LIMIT 1
        ];
        if (project.Account__c != null) {
          message.Account__c = project.Account__c;
        }
      } else if (String.isNotBlank(relatedAccountId)) {
        message.Account__c = relatedAccountId;
      } else if (currentUser.AccountId != null) {
        // Fallback to user's account if no specific context provided
        message.Account__c = currentUser.AccountId;
      }

      // Set visibility to client (default true, only Milestone team can set to false)
      // Note: In portal context, all users are clients, so internal messages are not allowed
      if (isVisibleToClient != null) {
        message.Visible_To_Client__c = isVisibleToClient;
      } else {
        message.Visible_To_Client__c = true;
      }

      // Portal users are all clients - they cannot send internal messages
      // Milestone Consulting team members don't use the portal
      if (message.Visible_To_Client__c == false && currentUser.AccountId != null) {
        throw new AuraHandledException(
          'Only Milestone Consulting team members can send internal messages. Portal users are clients and cannot send internal messages.'
        );
      }

      // Set reply relationship if replying to a message
      if (String.isNotBlank(replyToMessageId)) {
        // Verify the reply-to message exists and get its context
        List<Message__c> replyToMessages = [
          SELECT Id, Related_Task__c, Related_Project__c, Account__c, Recipient_Type__c
          FROM Message__c
          WHERE Id = :replyToMessageId AND Deleted__c = FALSE
          LIMIT 1
        ];

        if (!replyToMessages.isEmpty()) {
          Message__c replyToMessage = replyToMessages[0];
          message.Reply_To__c = replyToMessage.Id;

          // Inherit context from the message being replied to if not explicitly provided
          if (String.isBlank(relatedTaskId) && String.isBlank(relatedProjectId) && String.isBlank(relatedAccountId)) {
            if (replyToMessage.Related_Task__c != null) {
              message.Related_Task__c = replyToMessage.Related_Task__c;
              // Populate project and account from the inherited task (same logic as when task is provided as parameter)
              List<Project_Task__c> tasks = [
                SELECT Account__c, Project__c, Project__r.Account__c
                FROM Project_Task__c
                WHERE Id = :replyToMessage.Related_Task__c
                LIMIT 1
              ];
              if (!tasks.isEmpty()) {
                Project_Task__c task = tasks[0];
                if (task.Project__c != null) {
                  message.Related_Project__c = task.Project__c;
                }
                if (task.Account__c != null) {
                  message.Account__c = task.Account__c;
                } else if (task.Project__r?.Account__c != null) {
                  message.Account__c = task.Project__r.Account__c;
                }
              }
            } else if (replyToMessage.Related_Project__c != null) {
              message.Related_Project__c = replyToMessage.Related_Project__c;
              // Populate account from the inherited project
              Project__c project = [
                SELECT Account__c
                FROM Project__c
                WHERE Id = :replyToMessage.Related_Project__c
                LIMIT 1
              ];
              if (project.Account__c != null) {
                message.Account__c = project.Account__c;
              }
            } else if (replyToMessage.Account__c != null) {
              message.Account__c = replyToMessage.Account__c;
            }
          }

          // Inherit recipient type from the message being replied to if not explicitly provided
          if (String.isBlank(recipientType)) {
            message.Recipient_Type__c = replyToMessage.Recipient_Type__c;
          }
        }
      }

      List<String> mentionIdsForSave = filterToMentionableContactIds(mentionedContactIds, currentUser);
      if (!mentionIdsForSave.isEmpty()) {
        message.Mentioned_Contacts__c = String.join(mentionIdsForSave, ',');
      } else {
        message.Mentioned_Contacts__c = null;
      }

      assertPortalUserMessageContext(message, currentUserAccountId);

      insert message;

      if (!mentionIdsForSave.isEmpty()) {
        sendMentionNotifications(message.Id, mentionIdsForSave, messageBody);
      }

      return message.Id;
    } catch (DmlException e) {
      System.debug(
        LoggingLevel.ERROR,
        'DML Error sending message: ' +
          e.getMessage() +
          ' DmlType: ' +
          e.getDmlType(0) +
          ' Stack: ' +
          e.getStackTraceString()
      );
      String errorMsg = 'Error sending message: ' + e.getMessage();
      if (e.getNumDml() > 0) {
        errorMsg += ' (DML Type: ' + e.getDmlType(0) + ')';
      }
      throw new AuraHandledException(errorMsg);
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error sending message: ' + e.getMessage() + ' Type: ' + e.getTypeName() + ' Stack: ' + e.getStackTraceString()
      );
      throw new AuraHandledException('Error sending message: ' + e.getMessage() + ' (Type: ' + e.getTypeName() + ')');
    }
  }

  /**
   * @description Resolve Contact for Message__c.Sender__c: use User.ContactId when set; otherwise reuse an existing
   * Contact with the same Email (avoids duplicate-email validation when the User is not linked to that Contact),
   * or insert a new Contact.
   * @param user User row including ContactId, Name, Email
   * @return Contact Id to use as sender
   */
  private static Id getOrCreateContactForUser(User user) {
    if (user.ContactId != null) {
      return user.ContactId;
    }

    if (String.isNotBlank(user.Email)) {
      List<Contact> existingByEmail = [
        SELECT Id
        FROM Contact
        WHERE Email = :user.Email
        ORDER BY CreatedDate ASC
        LIMIT 1
      ];
      if (!existingByEmail.isEmpty()) {
        return existingByEmail[0].Id;
      }
    }

    Contact newContact = new Contact();

    if (user.Name != null && user.Name.contains(' ')) {
      List<String> nameParts = user.Name.split(' ', 2);
      newContact.FirstName = nameParts[0];
      newContact.LastName = nameParts.size() > 1 ? nameParts[1] : nameParts[0];
    } else {
      newContact.LastName = String.isNotBlank(user.Name) ? user.Name : 'Milestone Team Member';
    }

    newContact.Email = user.Email;

    try {
      insert newContact;
    } catch (DmlException dmx) {
      // Race or org rule: another row claimed the email between query and insert — reuse it.
      if (String.isNotBlank(user.Email) && isLikelyDuplicateContactEmailException(dmx)) {
        List<Contact> retry = [
          SELECT Id
          FROM Contact
          WHERE Email = :user.Email
          ORDER BY CreatedDate ASC
          LIMIT 1
        ];
        if (!retry.isEmpty()) {
          return retry[0].Id;
        }
      }
      throw dmx;
    }

    return newContact.Id;
  }

  /**
   * @description Test hook for {@link #getOrCreateContactForUser}; accepts an in-memory User row (no insert).
   */
  @TestVisible
  private static Id getOrCreateContactForUserForTest(User user) {
    return getOrCreateContactForUser(user);
  }

  /**
   * @description True when DmlException looks like a unique / validation failure on Contact Email.
   */
  private static Boolean isLikelyDuplicateContactEmailException(DmlException dmx) {
    if (dmx == null || dmx.getNumDml() < 1) {
      return false;
    }
    String msg = dmx.getDmlMessage(0);
    if (String.isBlank(msg)) {
      return false;
    }
    String lower = msg.toLowerCase();
    return lower.contains('email') && (lower.contains('duplicate') || lower.contains('already'));
  }

  /**
   * @description Get current user's contact ID
   * @return Contact ID
   */
  @AuraEnabled(cacheable=true)
  public static String getCurrentUserContactId() {
    try {
      User currentUser = [
        SELECT Id, ContactId
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];

      return currentUser.ContactId;
    } catch (Exception e) {
      return null;
    }
  }

  /**
   * @description Check if current user is a Milestone Consulting team member
   * Discriminator: User.AccountId == null is treated as internal/Milestone team; portal clients have AccountId set.
   * If your org assigns AccountId to some internal users, use a permission set or custom flag instead.
   * @return True when AccountId is null (internal); false for Experience Cloud client users
   */
  @AuraEnabled(cacheable=true)
  public static Boolean isMilestoneTeamMember() {
    try {
      User currentUser = [
        SELECT Id, AccountId, UserType
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];

      // Portal users (Experience Cloud users) always have AccountId and are clients
      // Milestone Consulting team members don't use the portal
      // If user has AccountId, they are a client (portal user)
      // If user doesn't have AccountId, they might be internal, but in portal context this shouldn't happen
      return currentUser.AccountId == null;
    } catch (Exception e) {
      return false;
    }
  }

  /**
   * @description Get messages for the current user
   * @param recipientType Filter by recipient type (optional)
   * @param relatedAccountId Filter by account (optional) - rolls up all projects and tasks
   * @param relatedProjectId Filter by project (optional)
   * @param relatedTaskId Filter by task (optional)
   * @param searchTerm When set, body text is resolved via SOSL (not SOQL LIKE on long text)
   * @param contextRecordId Optional host record Id when explicit related* ids are blank (Account, Project__c, or Project_Task__c)
   * @return List of MessageInfo objects
   */
  @AuraEnabled(cacheable=false)
  public static List<MessageInfo> getMessages(
    String recipientType,
    String relatedAccountId,
    String relatedProjectId,
    String relatedTaskId,
    Integer limitCount,
    Integer offset,
    String orderByField,
    String orderDirection,
    String searchTerm,
    String contextRecordId
  ) {
    try {
      // Normalize incoming params up front
      recipientType = normalizeOptional(recipientType);
      relatedAccountId = normalizeOptional(relatedAccountId);
      relatedProjectId = normalizeOptional(relatedProjectId);
      relatedTaskId = normalizeOptional(relatedTaskId);
      contextRecordId = normalizeOptional(contextRecordId);

      if (
        String.isBlank(relatedTaskId) &&
        String.isBlank(relatedProjectId) &&
        String.isBlank(relatedAccountId) &&
        String.isNotBlank(contextRecordId)
      ) {
        try {
          Id ctxId = (Id) contextRecordId;
          Schema.SObjectType ctxType = ctxId.getSObjectType();
          if (ctxType == Project_Task__c.SObjectType) {
            relatedTaskId = contextRecordId;
          } else if (ctxType == Project__c.SObjectType) {
            relatedProjectId = contextRecordId;
          } else if (ctxType == Account.SObjectType) {
            relatedAccountId = contextRecordId;
          }
        } catch (Exception ignore) {
          // Invalid Id — leave related* filters unset
        }
      }

      // Get current user (need Name and Email for Contact creation if needed)
      User currentUser = getCurrentUserWithContactFields();

      // Get or create Contact for the user (Sender__c field requires Contact)
      Id currentUserContactId = getOrCreateContactForUser(currentUser);
      Id currentUserAccountId = currentUser.AccountId;

      // Validate that we have a ContactId - required for query
      if (currentUserContactId == null) {
        throw new AuraHandledException(
          'Unable to retrieve or create Contact for current user. Please contact your administrator.'
        );
      }

      // Milestone team members (internal Salesforce users) don't have AccountId
      // Portal users (clients) always have AccountId
      Boolean isMilestoneTeamMember = (currentUser.AccountId == null);

      // --- Build filters deterministically and safely ---
      // Access filter: sender is current user OR allowed recipient bucket
      List<String> accessFilters = new List<String>();

      // Include sender filter using ContactId (Sender__c is a Contact lookup)
      // Use bind variables for constants to follow best practices
      String recipientClientValue = RECIPIENT_CLIENT;
      String recipientTeamValue = RECIPIENT_TEAM;

      // Always add sender filter (currentUserContactId is guaranteed to be non-null above)
      accessFilters.add(FIELD_SENDER + ' = :currentUserContactId');

      if (recipientType == RECIPIENT_CLIENT) {
        // Explicitly client-only
        if (currentUserAccountId != null) {
          accessFilters.add(
            FIELD_RECIPIENT_TYPE + ' = :recipientClientValue AND ' + FIELD_ACCOUNT + ' = :currentUserAccountId'
          );
        } else {
          accessFilters.add(FIELD_RECIPIENT_TYPE + ' = :recipientClientValue');
        }
      } else if (recipientType == RECIPIENT_TEAM) {
        accessFilters.add(FIELD_RECIPIENT_TYPE + ' = :recipientTeamValue');
      } else {
        // Default: both buckets (when recipientType is null or empty)
        // For portal users (with AccountId), show client messages for their account
        // For Milestone team members (no AccountId), show all team messages
        if (currentUserAccountId != null) {
          // Portal user: show messages sent to Client for their account OR messages sent to Team
          accessFilters.add(
            '(' + FIELD_RECIPIENT_TYPE + ' = :recipientClientValue AND ' + FIELD_ACCOUNT + ' = :currentUserAccountId)'
          );
        }
        // Always include team messages (both portal users and team members can see team messages)
        accessFilters.add(FIELD_RECIPIENT_TYPE + ' = :recipientTeamValue');
      }

      // Context filter: strict priority Task > Project > Account
      String contextFilter = null;
      if (String.isNotBlank(relatedTaskId)) {
        contextFilter = FIELD_TASK + ' = :relatedTaskId';
      } else if (String.isNotBlank(relatedProjectId)) {
        contextFilter = FIELD_PROJECT + ' = :relatedProjectId';
      } else if (String.isNotBlank(relatedAccountId)) {
        contextFilter = FIELD_ACCOUNT + ' = :relatedAccountId';
      }

      // Base filters always applied
      List<String> baseFilters = new List<String>{ FIELD_DELETED + ' = false' };
      if (currentUserAccountId != null) {
        baseFilters.add(FIELD_VISIBLE_TO_CLIENT + ' = true');
      }

      // Body search: SOSL (long text cannot appear in SOQL WHERE), then materialize Ids for SOQL Id IN
      Set<Id> searchCandidateIds = null;
      if (String.isNotBlank(searchTerm)) {
        String normalizedSearchTerm = normalizeOptional(searchTerm);
        if (String.isNotBlank(normalizedSearchTerm)) {
          String soslTerm = normalizeTermForSosl(normalizedSearchTerm);
          if (String.isBlank(soslTerm) || soslTerm.length() < SOSL_MIN_TERM_LENGTH) {
            return new List<MessageInfo>();
          }
          searchCandidateIds = searchMessageIdsBySosl(soslTerm);
          if (searchCandidateIds.isEmpty()) {
            return new List<MessageInfo>();
          }
        }
      }

      // Assemble WHERE clause - ensure we have at least one valid filter
      List<String> whereParts = new List<String>();

      // Clean up any blanks defensively
      List<String> cleanedAccessFilters = new List<String>();
      for (String f : accessFilters) {
        if (String.isNotBlank(f)) {
          cleanedAccessFilters.add(f);
        }
      }

      // Ensure we have at least one access filter (should always have sender filter)
      if (cleanedAccessFilters.isEmpty()) {
        throw new AuraHandledException('Unable to build query filters. Please contact your administrator.');
      }

      whereParts.add('(' + String.join(cleanedAccessFilters, ' OR ') + ')');

      // Add context filter if present
      if (String.isNotBlank(contextFilter)) {
        whereParts.add(contextFilter);
      }

      // SOSL-derived candidates (bind :searchCandidateIds — populated Set only, never inline SOSL results)
      if (searchCandidateIds != null) {
        whereParts.add('Id IN :searchCandidateIds');
      }

      // Add base filters
      for (String base : baseFilters) {
        if (String.isNotBlank(base)) {
          whereParts.add(base);
        }
      }

      // Final validation - should never be empty at this point, but check anyway
      if (whereParts.isEmpty()) {
        throw new AuraHandledException('Unable to build valid query. Please contact your administrator.');
      }

      // Build WHERE clause - all parts are guaranteed to be non-blank
      String whereClause = 'WHERE ' + String.join(whereParts, ' AND ');

      // Query messages - need to include Related_Task__r.Project__c for project rollup and Reply_To__c for replies
      // Normalize limit, offset, and ordering inputs
      // For reverse chronological (newest at bottom), we need to:
      // 1. Order by CreatedDate ASC (oldest first) so newest are at the end
      // 2. Use offset from the end (total count - offset - limit)
      Integer normalizedLimit = (limitCount != null &&
        limitCount > 0 &&
        limitCount <= MAX_MESSAGE_LIMIT)
        ? limitCount
        : DEFAULT_MESSAGE_LIMIT;
      Integer normalizedOffset = (offset != null && offset >= 0) ? offset : 0;
      // Default to ASC for reverse chronological (newest at bottom)
      String normalizedOrderDirection = (orderDirection != null &&
        orderDirection.toUpperCase() == 'DESC')
        ? 'DESC'
        : 'ASC';

      // Only allow a small, known-safe set of fields for ordering to avoid injection
      Map<String, String> allowedOrderFields = new Map<String, String>{
        'CreatedDate' => 'CreatedDate',
        'LastEditedDate' => 'Last_Edited_Date__c',
        'IsPinned' => 'Is_Pinned__c'
      };
      String normalizedOrderField = allowedOrderFields.containsKey(orderByField)
        ? allowedOrderFields.get(orderByField)
        : 'CreatedDate';

      // Debug: Log WHERE clause and bind variables for troubleshooting
      System.debug(LoggingLevel.DEBUG, '=== getMessages Query Debug ===');
      System.debug(LoggingLevel.DEBUG, 'whereClause: ' + whereClause);
      System.debug(LoggingLevel.DEBUG, 'whereParts size: ' + whereParts.size());
      System.debug(LoggingLevel.DEBUG, 'currentUserContactId: ' + currentUserContactId);
      System.debug(LoggingLevel.DEBUG, 'currentUserAccountId: ' + currentUserAccountId);
      System.debug(LoggingLevel.DEBUG, 'recipientType: ' + recipientType);
      System.debug(LoggingLevel.DEBUG, 'relatedTaskId: ' + relatedTaskId);
      System.debug(LoggingLevel.DEBUG, 'relatedProjectId: ' + relatedProjectId);
      System.debug(LoggingLevel.DEBUG, 'relatedAccountId: ' + relatedAccountId);

      // SOQL: when searchCandidateIds is set, whereClause includes Id IN (SOSL materialized Set)
      String query =
        GET_MESSAGES_SELECT_LIST +
        'FROM Message__c ' +
        whereClause +
        ' WITH SECURITY_ENFORCED ' +
        'ORDER BY Is_Pinned__c DESC, ' +
        normalizedOrderField +
        ' ' +
        normalizedOrderDirection +
        ' ' +
        'LIMIT :normalizedLimit OFFSET :normalizedOffset';

      System.debug(LoggingLevel.DEBUG, 'Full query: ' + query);
      System.debug(
        LoggingLevel.DEBUG,
        'searchCandidateIds size: ' + (searchCandidateIds != null ? searchCandidateIds.size() : 0)
      );
      System.debug(LoggingLevel.DEBUG, 'normalizedLimit: ' + normalizedLimit);
      System.debug(LoggingLevel.DEBUG, 'normalizedOffset: ' + normalizedOffset);

      // Debug logging (remove in production if not needed)
      if (Test.isRunningTest() || LoggingLevel.DEBUG == LoggingLevel.DEBUG) {
        System.debug(LoggingLevel.DEBUG, 'getMessages query: ' + query);
        System.debug(LoggingLevel.DEBUG, 'getMessages relatedTaskId: ' + relatedTaskId);
        System.debug(LoggingLevel.DEBUG, 'getMessages relatedProjectId: ' + relatedProjectId);
        System.debug(LoggingLevel.DEBUG, 'getMessages relatedAccountId: ' + relatedAccountId);
        System.debug(LoggingLevel.DEBUG, 'getMessages currentUserContactId: ' + currentUserContactId);
        System.debug(LoggingLevel.DEBUG, 'getMessages currentUserAccountId: ' + currentUserAccountId);
      }

      // Use standard Database.query - bind variables (e.g. :searchCandidateIds) must be in scope
      List<Message__c> messages;
      try {
        messages = Database.query(query);
      } catch (QueryException qe) {
        String qeMsg = qe.getMessage();
        System.debug(LoggingLevel.ERROR, 'QueryException in getMessages: ' + qeMsg);
        System.debug(LoggingLevel.ERROR, 'Query that failed: ' + query);
        System.debug(LoggingLevel.ERROR, 'searchTerm input: ' + searchTerm);
        System.debug(
          LoggingLevel.ERROR,
          'searchCandidateIds size: ' + (searchCandidateIds != null ? searchCandidateIds.size() : 0)
        );
        System.debug(LoggingLevel.ERROR, 'User: ' + UserInfo.getUserId() + ', Profile: ' + UserInfo.getProfileId());

        if (qeMsg.contains('inaccessible field') || qeMsg.contains('secure query')) {
          String flsError = 'Field-level security error: ' + qeMsg;
          flsError += ' The portal user may not have read access to one or more Message__c fields. ';
          flsError += 'Check the Portal_Messaging permission set field permissions for: ';
          flsError += 'Body__c, Sender__c, Sender__r.Name, Sender__r.Email, Recipient_Type__c, ';
          flsError += 'Related_Project__c, Related_Project__r.Name, Related_Task__c, Related_Task__r.Name, ';
          flsError += 'Mentioned_Contacts__c, Is_Read_By_Client__c, Is_Read_By_Milestone_Team__c, Deleted__c, Visible_To_Client__c, Is_Edited__c, ';
          flsError += 'Last_Edited_Date__c, CreatedDate, CreatedById, CreatedBy.Name, Account__c, Account__r.Name, ';
          flsError += 'Reply_To__c, Reply_To__r fields, Is_Pinned__c.';
          throw new QueryException(flsError);
        }
        throw new QueryException(
          'Query error: ' + qeMsg + ' | Query: ' + query + ' | searchTerm: ' + searchTerm
        );
      }

      if (Test.isRunningTest() || LoggingLevel.DEBUG == LoggingLevel.DEBUG) {
        System.debug(LoggingLevel.DEBUG, 'getMessages found ' + messages.size() + ' messages');
      }

      // Convert to MessageInfo
      List<MessageInfo> messageInfos = new List<MessageInfo>();
      String currentUserContactIdStr = currentUserContactId == null
        ? null
        : String.valueOf(currentUserContactId);
      for (Message__c msg : messages) {
        MessageInfo info = new MessageInfo();
        info.id = msg.Id == null ? null : String.valueOf(msg.Id);
        info.name = msg.Name;
        info.body = msg.Body__c;
        info.senderId = msg.Sender__c == null ? null : String.valueOf(msg.Sender__c);
        Contact senderRel = msg.Sender__r;
        info.senderName = senderRel == null ? null : senderRel.Name;
        info.senderEmail = senderRel == null ? null : senderRel.Email;
        info.recipientType = msg.Recipient_Type__c;
        info.relatedProjectId = msg.Related_Project__c == null
          ? null
          : String.valueOf(msg.Related_Project__c);
        Project__c projRel = msg.Related_Project__r;
        info.relatedProjectName = projRel == null ? null : projRel.Name;
        info.relatedTaskId = msg.Related_Task__c == null ? null : String.valueOf(msg.Related_Task__c);
        Project_Task__c taskRel = msg.Related_Task__r;
        info.relatedTaskName = taskRel == null ? null : taskRel.Name;
        info.mentionedContacts = msg.Mentioned_Contacts__c;
        // Set isRead based on user type: clients use Is_Read_By_Client__c, Milestone team uses Is_Read_By_Milestone_Team__c
        if (currentUserAccountId != null) {
          // Portal user (client) - check client read status
          info.isRead = msg.Is_Read_By_Client__c != null ? msg.Is_Read_By_Client__c : false;
        } else {
          // Milestone team member - check team read status
          info.isRead = msg.Is_Read_By_Milestone_Team__c != null ? msg.Is_Read_By_Milestone_Team__c : false;
        }
        info.createdDate = msg.CreatedDate;
        info.createdById = msg.CreatedById != null ? String.valueOf(msg.CreatedById) : null;
        User createdByUser = msg.CreatedBy;
        info.createdByName = createdByUser == null ? null : createdByUser.Name;
        info.createdBy = createdByUser == null ? null : createdByUser.Name;
        info.accountId = msg.Account__c == null ? null : String.valueOf(msg.Account__c);
        Account accountRel = msg.Account__r;
        info.accountName = accountRel == null ? null : accountRel.Name;
        info.visibleToClient = msg.Visible_To_Client__c != null ? msg.Visible_To_Client__c : true;
        info.isEdited = msg.Is_Edited__c != null ? msg.Is_Edited__c : false;
        info.lastEditedDate = msg.Last_Edited_Date__c;
        info.isPinned = msg.Is_Pinned__c != null ? msg.Is_Pinned__c : false;

        // Set reply information
        info.replyToMessageId = msg.Reply_To__c == null ? null : String.valueOf(msg.Reply_To__c);
        if (msg.Reply_To__r != null) {
          Message__c replyTo = msg.Reply_To__r;
          info.replyToMessageBody = replyTo.Body__c;
          Contact replySender = replyTo.Sender__r;
          info.replyToSenderName = replySender == null ? null : replySender.Name;
          info.replyToCreatedDate = replyTo.CreatedDate;
          info.replyToTaskId = replyTo.Related_Task__c == null
            ? null
            : String.valueOf(replyTo.Related_Task__c);
        }

        // Check if current user is mentioned
        // Note: Mentioned_Contacts__c stores Contact IDs, so we need to check if current user's ContactId is mentioned
        // For Milestone team members without ContactId, they won't be mentioned via this field
        info.isMentioned = false;
        if (String.isNotBlank(msg.Mentioned_Contacts__c) && currentUserContactIdStr != null) {
          List<String> mentionedIds = msg.Mentioned_Contacts__c.split(',');
          for (Integer mi = 0; mi < mentionedIds.size(); mi++) {
            mentionedIds[mi] = mentionedIds[mi].trim();
          }
          info.isMentioned = mentionedIds.contains(currentUserContactIdStr);
        }

        messageInfos.add(info);
      }

      return messageInfos;
    } catch (Exception e) {
      // Provide more detailed error for debugging
      String errorMsg = e.getMessage();
      String errorType = e.getTypeName();

      // Always log detailed error information
      System.debug(LoggingLevel.ERROR, '=== Exception in getMessages ===');
      System.debug(LoggingLevel.ERROR, 'Exception type: ' + errorType);
      System.debug(LoggingLevel.ERROR, 'Exception message: ' + errorMsg);
      System.debug(LoggingLevel.ERROR, 'User ID: ' + UserInfo.getUserId());
      System.debug(LoggingLevel.ERROR, 'Profile ID: ' + UserInfo.getProfileId());

      if (e.getCause() != null) {
        System.debug(LoggingLevel.ERROR, 'Cause: ' + e.getCause().getMessage());
        errorMsg += ' Cause: ' + e.getCause().getMessage();
      }

      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());

      String detail = String.isNotBlank(errorMsg) ? errorMsg : '(no message)';
      errorMsg = 'Error retrieving messages (' + errorType + '): ' + detail;
      throw new AuraHandledException(errorMsg);
    }
  }

  /**
   * @description Latest messages for the home feed (portalMessageFeed). Same visibility rules as before migration.
   * @param limitCount Max rows; null or non-positive defaults to 5; capped at MAX_MESSAGE_LIMIT.
   * @param orderByField CreatedDate, LastEditedDate, or IsPinned
   * @param orderDirection ASC or DESC
   */
  @AuraEnabled(cacheable=true)
  public static List<MessageInfo> getLatestMessages(Integer limitCount, String orderByField, String orderDirection) {
    if (limitCount == null || limitCount <= 0) {
      limitCount = 5;
    } else if (limitCount > MAX_MESSAGE_LIMIT) {
      limitCount = MAX_MESSAGE_LIMIT;
    }

    orderByField = normalizeOptional(orderByField);
    orderDirection = normalizeOptional(orderDirection);

    Map<String, String> allowedOrderFields = new Map<String, String>{
      'CreatedDate' => 'CreatedDate',
      'LastEditedDate' => 'Last_Edited_Date__c',
      'IsPinned' => 'Is_Pinned__c'
    };
    String normalizedOrderField = (orderByField != null && allowedOrderFields.containsKey(orderByField))
      ? allowedOrderFields.get(orderByField)
      : 'CreatedDate';
    String normalizedOrderDirection = (orderDirection != null &&
      orderDirection.toUpperCase() == 'ASC')
      ? 'ASC'
      : 'DESC';

    try {
      // User / Message queries omit WITH SECURITY_ENFORCED for portal compatibility (field access varies by profile).
      User currentUser = [
        SELECT Id, ContactId, AccountId, Name, Email
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];

      // Get or create Contact for the user (Sender__c field requires Contact)
      Id currentUserContactId = getOrCreateContactForUser(currentUser);
      Id currentUserAccountId = currentUser.AccountId;
      String recipientClient = RECIPIENT_CLIENT;
      String recipientTeam = RECIPIENT_TEAM;

      // Build WHERE clause explicitly to avoid malformed query strings
      String whereClause =
        'WHERE (' +
        FIELD_SENDER +
        ' = :currentUserContactId ' +
        'OR (' +
        FIELD_RECIPIENT_TYPE +
        ' = :recipientClient' +
        (currentUserAccountId != null ? ' AND ' + FIELD_ACCOUNT + ' = :currentUserAccountId' : '') +
        ') OR ' +
        FIELD_RECIPIENT_TYPE +
        ' = :recipientTeam' +
        ') AND ' +
        FIELD_DELETED +
        ' = false' +
        (currentUserAccountId != null ? ' AND ' + FIELD_VISIBLE_TO_CLIENT + ' = true' : '') +
        ' AND ' +
        FIELD_TASK +
        ' != null';

      // Query messages - need to include task information for navigation and Reply_To__c for replies
      String query =
        'SELECT Id, Name, CreatedById, Body__c, Sender__c, Sender__r.Name, Sender__r.Email, ' +
        'Recipient_Type__c, Related_Project__c, Related_Project__r.Name, ' +
        'Related_Task__c, Related_Task__r.Name, Related_Task__r.Project__c, ' +
        'Mentioned_Contacts__c, Is_Read_By_Client__c, Is_Read_By_Milestone_Team__c, Deleted__c, Visible_To_Client__c, ' +
        'Is_Edited__c, Last_Edited_Date__c, CreatedDate, CreatedBy.Name, ' +
        'Account__c, Account__r.Name, Reply_To__c, Reply_To__r.Id, Reply_To__r.Body__c, ' +
        'Reply_To__r.Sender__r.Name, Reply_To__r.CreatedDate, Reply_To__r.Related_Task__c, ' +
        'Is_Pinned__c ' +
        'FROM Message__c ' +
        whereClause +
        ' ' +
        'ORDER BY Is_Pinned__c DESC, ' +
        normalizedOrderField +
        ' ' +
        normalizedOrderDirection +
        ' ' +
        'LIMIT :limitCount';

      List<Message__c> messages = Database.query(query);

      // Convert to MessageInfo
      List<MessageInfo> messageInfos = new List<MessageInfo>();
      for (Message__c msg : messages) {
        MessageInfo info = new MessageInfo();
        info.id = msg.Id;
        info.name = msg.Name;
        info.body = msg.Body__c;
        info.senderId = msg.Sender__c;
        info.senderName = msg.Sender__r?.Name;
        info.senderEmail = msg.Sender__r?.Email;
        info.recipientType = msg.Recipient_Type__c;
        info.relatedProjectId = msg.Related_Project__c;
        info.relatedProjectName = msg.Related_Project__r?.Name;
        info.relatedTaskId = msg.Related_Task__c;
        info.relatedTaskName = msg.Related_Task__r?.Name;
        info.mentionedContacts = msg.Mentioned_Contacts__c;
        // Set isRead based on user type: clients use Is_Read_By_Client__c, Milestone team uses Is_Read_By_Milestone_Team__c
        if (currentUserAccountId != null) {
          // Portal user (client) - check client read status
          info.isRead = msg.Is_Read_By_Client__c != null ? msg.Is_Read_By_Client__c : false;
        } else {
          // Milestone team member - check team read status
          info.isRead = msg.Is_Read_By_Milestone_Team__c != null ? msg.Is_Read_By_Milestone_Team__c : false;
        }
        info.createdDate = msg.CreatedDate;
        info.createdById = msg.CreatedById != null ? String.valueOf(msg.CreatedById) : null;
        info.createdByName = msg.CreatedBy?.Name;
        info.createdBy = msg.CreatedBy?.Name;
        info.accountId = msg.Account__c;
        info.accountName = msg.Account__r?.Name;
        info.visibleToClient = msg.Visible_To_Client__c != null ? msg.Visible_To_Client__c : true;
        info.isEdited = msg.Is_Edited__c != null ? msg.Is_Edited__c : false;
        info.lastEditedDate = msg.Last_Edited_Date__c;
        info.isPinned = msg.Is_Pinned__c != null ? msg.Is_Pinned__c : false;

        // Set reply information
        info.replyToMessageId = msg.Reply_To__c;
        if (msg.Reply_To__r != null) {
          info.replyToMessageBody = msg.Reply_To__r.Body__c;
          info.replyToSenderName = msg.Reply_To__r.Sender__r?.Name;
          info.replyToCreatedDate = msg.Reply_To__r.CreatedDate;
          info.replyToTaskId = msg.Reply_To__r.Related_Task__c;
        }

        // Check if current user is mentioned
        // Note: Mentioned_Contacts__c stores Contact IDs, so we need to check if current user's ContactId is mentioned
        // For Milestone team members without ContactId, they won't be mentioned via this field
        info.isMentioned = false;
        if (String.isNotBlank(msg.Mentioned_Contacts__c)) {
          List<String> mentionedIds = msg.Mentioned_Contacts__c.split(',');
          // For portal users, check their ContactId
          // For Milestone team members, they can't be mentioned via Contact mentions
          // Use the ContactId we already have (from getOrCreateContactForUser)
          if (currentUserContactId != null) {
            info.isMentioned = mentionedIds.contains(currentUserContactId);
          }
        }

        messageInfos.add(info);
      }

      return messageInfos;
    } catch (Exception e) {
      throw new AuraHandledException('Error retrieving latest messages: ' + e.getMessage());
    }
  }

  /**
   * @description Get contacts that can be mentioned (for autocomplete)
   * @param searchTerm Search term for contact name/email
   * @return List of ContactInfo objects
   */
  @AuraEnabled(cacheable=true)
  public static List<ContactInfo> getMentionableContacts(String searchTerm) {
    // Declare searchLike outside try block so it's accessible in catch block for error logging
    String searchLike = null;
    try {
      User currentUser = [
        SELECT Id, ContactId, AccountId
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];

      // Build query with proper bind variables
      List<Contact> contacts;
      if (String.isNotBlank(searchTerm)) {
        // Escape LIKE wildcards to avoid injection via pattern characters
        String escaped = searchTerm.replaceAll('([%_\\\\])', '\\\\$1');
        searchLike = '%' + escaped + '%';
      }

      if (currentUser.AccountId != null) {
        // Bind variable must be assigned before Database.query (dynamic SOQL resolution).
        Id currentUserAccountId = currentUser.AccountId;
        // If user has an account, prioritize contacts from same account
        // Also include Milestone Consulting team members (users without account)
        String query =
          'SELECT Id, Name, Email, AccountId, Account.Name ' +
          'FROM Contact ' +
          'WHERE Portal_Access_Enabled__c = true ' +
          'AND (AccountId = :currentUserAccountId OR AccountId = null)';

        if (searchLike != null) {
          query += ' AND (Name LIKE :searchLike ESCAPE \'\\\\\' OR Email LIKE :searchLike ESCAPE \'\\\\\')';
        }

        query += ' ORDER BY Name LIMIT ' + MAX_CONTACT_SEARCH_LIMIT;

        contacts = Database.query(query);
      } else {
        // User doesn't have an account (Milestone team member)
        String query =
          'SELECT Id, Name, Email, AccountId, Account.Name ' +
          'FROM Contact ' +
          'WHERE Portal_Access_Enabled__c = true';

        if (searchLike != null) {
          query += ' AND (Name LIKE :searchLike ESCAPE \'\\\\\' OR Email LIKE :searchLike ESCAPE \'\\\\\')';
        }

        query += ' ORDER BY Name LIMIT ' + MAX_CONTACT_SEARCH_LIMIT;

        contacts = Database.query(query);
      }

      List<ContactInfo> contactInfos = new List<ContactInfo>();
      for (Contact contact : contacts) {
        ContactInfo info = new ContactInfo();
        info.id = contact.Id;
        info.name = contact.Name;
        info.email = contact.Email;
        info.accountId = contact.AccountId;
        info.accountName = contact.Account?.Name;
        contactInfos.add(info);
      }

      return contactInfos;
    } catch (Exception e) {
      // Provide detailed error for debugging
      String errorMsg = e.getMessage();
      String errorType = e.getTypeName();

      System.debug(LoggingLevel.ERROR, '=== Exception in getMentionableContacts ===');
      System.debug(LoggingLevel.ERROR, 'Exception type: ' + errorType);
      System.debug(LoggingLevel.ERROR, 'Exception message: ' + errorMsg);
      System.debug(LoggingLevel.ERROR, 'searchTerm: ' + searchTerm);
      System.debug(LoggingLevel.ERROR, 'searchLike: ' + searchLike);
      System.debug(LoggingLevel.ERROR, 'User ID: ' + UserInfo.getUserId());

      if (e.getCause() != null) {
        System.debug(LoggingLevel.ERROR, 'Cause: ' + e.getCause().getMessage());
        errorMsg += ' Cause: ' + e.getCause().getMessage();
      }

      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());

      throw new AuraHandledException('Error retrieving contacts (' + errorType + '): ' + errorMsg);
    }
  }

  /**
   * @description Mark message as read
   * Sets the appropriate read field based on user type (client vs Milestone team)
   * @param messageId The message ID
   */
  @AuraEnabled
  public static void markAsRead(String messageId) {
    if (String.isBlank(messageId)) {
      return;
    }

    try {
      // Get current user to determine if they're a client or Milestone team member
      User currentUser = [
        SELECT Id, AccountId
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];

      Message__c message = [
        SELECT Id, Is_Read_By_Client__c, Is_Read_By_Milestone_Team__c
        FROM Message__c
        WHERE Id = :messageId
        LIMIT 1
      ];

      // Set the appropriate read field based on user type
      if (currentUser.AccountId != null) {
        // Portal user (client) - mark client read
        message.Is_Read_By_Client__c = true;
      } else {
        // Milestone team member - mark team read
        message.Is_Read_By_Milestone_Team__c = true;
      }

      update message;
    } catch (Exception e) {
      throw new AuraHandledException('Error marking message as read: ' + e.getMessage());
    }
  }

  /**
   * @description Update a message (edit)
   * Only the sender can edit their own message
   * @param messageId The message ID
   * @param messageBody The updated message body
   */
  @AuraEnabled
  public static void updateMessage(String messageId, String messageBody) {
    if (String.isBlank(messageId)) {
      throw new AuraHandledException('Message ID is required');
    }

    if (String.isBlank(messageBody)) {
      throw new AuraHandledException('Message body is required');
    }

    try {
      // Get current user (need Name and Email for Contact creation if needed)
      User currentUser = [
        SELECT Id, ContactId, Name, Email
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];

      // Get or create Contact for the user (Sender__c field requires Contact)
      Id currentUserContactId = getOrCreateContactForUser(currentUser);

      // Get message and verify sender
      // NOTE: FLS bypassed here to allow portal users to edit their own messages.
      // Security is enforced via sender verification below — users can only edit messages they sent.
      // Field-level security would prevent portal users from updating messages even if they are the sender.
      Message__c message = [
        SELECT Id, Sender__c, Body__c, Is_Edited__c, Deleted__c
        FROM Message__c
        WHERE Id = :messageId
        LIMIT 1
      ];

      // Only allow sender to edit their own message
      if (message.Sender__c != currentUserContactId) {
        throw new AuraHandledException('You can only edit messages you sent');
      }

      // Check if message is deleted
      if (message.Deleted__c == true) {
        throw new AuraHandledException('Cannot edit a deleted message');
      }

      // Update message
      message.Body__c = messageBody;
      message.Is_Edited__c = true;
      message.Last_Edited_Date__c = Datetime.now();

      update message;
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException('Error updating message: ' + e.getMessage());
    }
  }

  /**
   * @description Pin or unpin a message
   * Only Milestone team members can pin messages
   * @param messageId The message ID
   * @param isPinned Whether to pin (true) or unpin (false) the message
   */
  @AuraEnabled
  public static void pinMessage(String messageId, Boolean isPinned) {
    if (String.isBlank(messageId)) {
      throw new AuraHandledException('Message ID is required');
    }

    try {
      // Get current user
      User currentUser = [
        SELECT Id, ContactId, AccountId
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];

      // Only Milestone team members (users without AccountId) can pin messages
      if (currentUser.AccountId != null) {
        throw new AuraHandledException('Only Milestone Consulting team members can pin messages');
      }

      // Get message
      Message__c message = [
        SELECT Id, Is_Pinned__c, Deleted__c
        FROM Message__c
        WHERE Id = :messageId
        LIMIT 1
      ];

      // Check if message is deleted
      if (message.Deleted__c == true) {
        throw new AuraHandledException('Cannot pin a deleted message');
      }

      // Update pin status
      message.Is_Pinned__c = isPinned != null ? isPinned : false;

      update message;
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException('Error pinning message: ' + e.getMessage());
    }
  }

  /**
   * @description Delete a message (soft delete - sets Deleted__c flag)
   * Only the sender can delete their own message
   * @param messageId The message ID
   */
  @AuraEnabled
  public static void deleteMessage(String messageId) {
    if (String.isBlank(messageId)) {
      throw new AuraHandledException('Message ID is required');
    }

    try {
      // Get current user (need Name and Email for Contact creation if needed)
      User currentUser = [
        SELECT Id, ContactId, Name, Email
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];

      // Get or create Contact for the user (Sender__c field requires Contact)
      Id currentUserContactId = getOrCreateContactForUser(currentUser);

      // Get message and verify sender
      Message__c message = [
        SELECT Id, Sender__c, Deleted__c
        FROM Message__c
        WHERE Id = :messageId
        LIMIT 1
      ];

      // Only allow sender to delete their own message
      if (message.Sender__c != currentUserContactId) {
        throw new AuraHandledException('You can only delete messages you sent');
      }

      // Check if already deleted
      if (message.Deleted__c == true) {
        throw new AuraHandledException('Message is already deleted');
      }

      // Soft delete - set Deleted__c flag to true
      message.Deleted__c = true;
      update message;
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException('Error deleting message: ' + e.getMessage());
    }
  }

  /**
   * @description Send email notifications to mentioned contacts
   * @param messageId The message ID
   * @param mentionedContactIds List of mentioned contact IDs
   * @param messageBody The message body
   */
  private static void sendMentionNotifications(String messageId, List<String> mentionedContactIds, String messageBody) {
    if (mentionedContactIds == null || mentionedContactIds.isEmpty()) {
      return;
    }

    try {
      // Get mentioned contacts
      List<Contact> mentionedContacts = [
        SELECT Id, Name, Email
        FROM Contact
        WHERE Id IN :mentionedContactIds AND Email != NULL
      ];

      if (mentionedContacts.isEmpty()) {
        return;
      }

      // Get message details for email
      Message__c message = [
        SELECT Id, Name, Sender__r.Name, Related_Project__r.Name, Related_Task__r.Name
        FROM Message__c
        WHERE Id = :messageId
        LIMIT 1
      ];

      // Build email subject
      String subject = 'You were mentioned in a message';
      if (message.Related_Project__r != null) {
        subject += ' - ' + message.Related_Project__r.Name;
      }
      if (message.Related_Task__r != null) {
        subject += ' - ' + message.Related_Task__r.Name;
      }

      // Build email body (strip HTML for plain text)
      String plainTextBody = messageBody.replaceAll('<[^>]+>', '');
      if (plainTextBody.length() > 500) {
        plainTextBody = plainTextBody.substring(0, 500) + '...';
      }

      // Send emails to mentioned contacts
      List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
      for (Contact contact : mentionedContacts) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(contact.Id);
        email.setSaveAsActivity(false);
        email.setSubject(subject);
        email.setPlainTextBody(
          'Hello ' +
            contact.Name +
            ',\n\n' +
            'You were mentioned in a message by ' +
            message.Sender__r.Name +
            '.\n\n' +
            'Message:\n' +
            plainTextBody +
            '\n\n' +
            'Please log into the portal to view the full message.\n\n' +
            'Thank you,\n' +
            'Project Management Portal'
        );
        emails.add(email);
      }

      if (!emails.isEmpty()) {
        Messaging.sendEmail(emails);
      }
    } catch (Exception e) {
      // Log error but don't fail message creation
      System.debug('Error sending mention notifications: ' + e.getMessage());
    }
  }

  /**
   * @description Link files to a message
   * @param messageId The message ID
   * @param contentVersionIds List of ContentVersion IDs
   * @return Boolean indicating success
   */
  @AuraEnabled
  public static Boolean linkFilesToMessage(String messageId, List<String> contentVersionIds) {
    if (String.isBlank(messageId) || contentVersionIds == null || contentVersionIds.isEmpty()) {
      throw new AuraHandledException('Message ID and content version IDs are required');
    }

    try {
      // Get ContentDocument IDs from ContentVersion IDs
      List<ContentVersion> contentVersions = [
        SELECT ContentDocumentId
        FROM ContentVersion
        WHERE Id IN :contentVersionIds
      ];

      if (contentVersions.isEmpty()) {
        throw new AuraHandledException('No content versions found for the provided IDs');
      }

      Set<Id> contentDocumentIds = new Set<Id>();
      for (ContentVersion cv : contentVersions) {
        if (cv.ContentDocumentId != null) {
          contentDocumentIds.add(cv.ContentDocumentId);
        }
      }

      if (contentDocumentIds.isEmpty()) {
        throw new AuraHandledException('No content documents found');
      }

      // Check if links already exist
      List<ContentDocumentLink> existingLinks = [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :messageId AND ContentDocumentId IN :contentDocumentIds
      ];

      Set<Id> existingContentDocumentIds = new Set<Id>();
      for (ContentDocumentLink link : existingLinks) {
        existingContentDocumentIds.add(link.ContentDocumentId);
      }

      // Create new links for documents that aren't already linked
      List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
      for (Id docId : contentDocumentIds) {
        if (!existingContentDocumentIds.contains(docId)) {
          ContentDocumentLink link = new ContentDocumentLink();
          link.LinkedEntityId = messageId;
          link.ContentDocumentId = docId;
          link.ShareType = 'V'; // Viewer access
          link.Visibility = 'AllUsers';
          newLinks.add(link);
        }
      }

      if (!newLinks.isEmpty()) {
        insert newLinks;
      }

      return true;
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error linking files to message: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString()
      );
      throw new AuraHandledException('Error linking files to message: ' + e.getMessage());
    }
  }

  /**
   * @description Get files linked to a message (same underlying query as {@link MessageFilesSupport#getFilesForMessages}).
   * @param messageId The message ID
   * @return List of FileInfo objects
   */
  @AuraEnabled(cacheable=true)
  public static List<FileInfo> getMessageFiles(String messageId) {
    if (String.isBlank(messageId)) {
      return new List<FileInfo>();
    }

    Id msgId;
    try {
      msgId = (Id) messageId;
    } catch (Exception badId) {
      return new List<FileInfo>();
    }

    List<MessageFilesSupport.AttachmentLinkRow> linkRows = MessageFilesSupport.loadMessageAttachmentLinks(
      new Set<Id>{ msgId }
    );

    Id currentUserId = UserInfo.getUserId();
    List<FileInfo> files = new List<FileInfo>();

    for (MessageFilesSupport.AttachmentLinkRow ar : linkRows) {
      FileInfo file = new FileInfo();
      file.id = ar.contentDocumentId != null ? String.valueOf(ar.contentDocumentId) : null;
      file.title = ar.title;
      file.extension = ar.fileExtension;
      file.size = ar.contentSize;
      file.createdDate = ar.createdDate;
      file.createdBy = ar.createdByName;
      file.createdById = ar.createdById != null ? String.valueOf(ar.createdById) : null;
      file.versionId = ar.latestPublishedVersionId != null ? String.valueOf(ar.latestPublishedVersionId) : null;
      file.canDelete = (ar.createdById == currentUserId);
      files.add(file);
    }

    return files;
  }

  /**
   * @description Get context information for messaging component
   * @param relatedAccountId Account ID (optional)
   * @param relatedProjectId Project ID (optional)
   * @param relatedTaskId Task ID (optional)
   * @return ContextInfo with names and context type
   */
  @AuraEnabled(cacheable=true)
  public static ContextInfo getContextInfo(String relatedAccountId, String relatedProjectId, String relatedTaskId) {
    ContextInfo context = new ContextInfo();

    try {
      if (String.isNotBlank(relatedTaskId)) {
        // Task context
        Project_Task__c task = [
          SELECT Id, Name, Project__c, Project__r.Name, Project__r.Account__c, Project__r.Account__r.Name
          FROM Project_Task__c
          WHERE Id = :relatedTaskId
          LIMIT 1
        ];

        context.contextType = 'Task';
        context.taskId = task.Id;
        context.taskName = task.Name;
        context.projectId = task.Project__c;
        context.projectName = task.Project__r?.Name;
        context.accountId = task.Project__r?.Account__c;
        context.accountName = task.Project__r?.Account__r?.Name;
      } else if (String.isNotBlank(relatedProjectId)) {
        // Project context
        Project__c project = [
          SELECT Id, Name, Account__c, Account__r.Name
          FROM Project__c
          WHERE Id = :relatedProjectId
          LIMIT 1
        ];

        context.contextType = 'Project';
        context.projectId = project.Id;
        context.projectName = project.Name;
        context.accountId = project.Account__c;
        context.accountName = project.Account__r?.Name;
      } else if (String.isNotBlank(relatedAccountId)) {
        // Account context
        Account account = [
          SELECT Id, Name
          FROM Account
          WHERE Id = :relatedAccountId
          LIMIT 1
        ];

        context.contextType = 'Account';
        context.accountId = account.Id;
        context.accountName = account.Name;
      }
    } catch (Exception e) {
      // Return empty context on error but log for traceability
      System.debug('Context resolution failed: ' + e.getMessage());
    }

    return context;
  }

  /**
   * @description Wrapper class for context information
   */
  public class ContextInfo {
    @AuraEnabled
    public String contextType; // 'Account', 'Project', or 'Task'
    @AuraEnabled
    public String accountId;
    @AuraEnabled
    public String accountName;
    @AuraEnabled
    public String projectId;
    @AuraEnabled
    public String projectName;
    @AuraEnabled
    public String taskId;
    @AuraEnabled
    public String taskName;
  }

  /**
   * @description Wrapper class for message information
   */
  public class MessageInfo {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String body;
    @AuraEnabled
    public String senderId;
    @AuraEnabled
    public String senderName;
    @AuraEnabled
    public String senderEmail;
    @AuraEnabled
    public String recipientType;
    @AuraEnabled
    public String relatedProjectId;
    @AuraEnabled
    public String relatedProjectName;
    @AuraEnabled
    public String relatedTaskId;
    @AuraEnabled
    public String relatedTaskName;
    @AuraEnabled
    public String mentionedContacts;
    @AuraEnabled
    public Boolean isRead;
    @AuraEnabled
    public DateTime createdDate;
    @AuraEnabled
    public String createdBy;
    @AuraEnabled
    public String createdById;
    @AuraEnabled
    public String createdByName;
    @AuraEnabled
    public String accountId;
    @AuraEnabled
    public String accountName;
    @AuraEnabled
    public Boolean isMentioned;
    @AuraEnabled
    public Boolean visibleToClient;
    @AuraEnabled
    public Boolean isEdited;
    @AuraEnabled
    public DateTime lastEditedDate;
    @AuraEnabled
    public Boolean isPinned;
    @AuraEnabled
    public String replyToMessageId;
    @AuraEnabled
    public String replyToMessageBody;
    @AuraEnabled
    public String replyToSenderName;
    @AuraEnabled
    public DateTime replyToCreatedDate;
    @AuraEnabled
    public String replyToTaskId;
  }

  /**
   * @description Wrapper class for contact information
   */
  public class ContactInfo {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String email;
    @AuraEnabled
    public String accountId;
    @AuraEnabled
    public String accountName;
  }

  /**
   * @description Wrapper class for file information
   */
  public class FileInfo {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String extension;
    @AuraEnabled
    public Long size;
    @AuraEnabled
    public DateTime createdDate;
    @AuraEnabled
    public String createdBy;
    @AuraEnabled
    public String createdById;
    @AuraEnabled
    public String versionId;
    @AuraEnabled
    public Boolean canDelete;
  }
}
