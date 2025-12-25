/**
 * @description Apex controller for Portal Messaging component
 * Handles sending and retrieving messages between clients and Milestone Consulting team
 * Uses without sharing to allow portal users to create message records
 */
public without sharing class PortalMessagingController {
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

    // Normalize potentially undefined/blank strings coming from JS
    private static String normalizeOptional(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return (trimmed == '' || trimmed.equalsIgnoreCase('undefined') || trimmed.equalsIgnoreCase('null')) ? null : trimmed;
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
            User currentUser = [
                SELECT Id, ContactId, AccountId, Name, Email
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            // Get or create Contact for the user (Milestone team members won't have ContactId)
            Id senderContactId = getOrCreateContactForUser(currentUser);
            
            // Create message record
            Message__c message = new Message__c();
            message.Body__c = messageBody;
            message.Sender__c = senderContactId;
            message.Recipient_Type__c = recipientType;
            message.Is_Read__c = false;
            
            // Set related account, project, or task
            // Priority: Task > Project > Account
            if (String.isNotBlank(relatedTaskId)) {
                message.Related_Task__c = relatedTaskId;
                // Get project and account from task
                List<Project_Task__c> tasks = [
                    SELECT Project__c, Project__r.Account__c
                    FROM Project_Task__c
                    WHERE Id = :relatedTaskId
                    LIMIT 1
                ];
                if (!tasks.isEmpty()) {
                    Project_Task__c task = tasks[0];
                    if (task.Project__c != null) {
                        message.Related_Project__c = task.Project__c;
                    }
                    if (task.Project__r?.Account__c != null) {
                        message.Account__c = task.Project__r.Account__c;
                    }
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
            
            // Store mentioned contact IDs as comma-separated string
            if (mentionedContactIds != null && !mentionedContactIds.isEmpty()) {
                message.Mentioned_Contacts__c = String.join(mentionedContactIds, ',');
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
                throw new AuraHandledException('Only Milestone Consulting team members can send internal messages. Portal users are clients and cannot send internal messages.');
            }
            
            // Set reply relationship if replying to a message
            if (String.isNotBlank(replyToMessageId)) {
                // Verify the reply-to message exists and get its context
                List<Message__c> replyToMessages = [
                    SELECT Id, Related_Task__c, Related_Project__c, Account__c, Recipient_Type__c
                    FROM Message__c
                    WHERE Id = :replyToMessageId
                    AND Deleted__c = false
                    LIMIT 1
                ];
                
                if (!replyToMessages.isEmpty()) {
                    Message__c replyToMessage = replyToMessages[0];
                    message.Reply_To__c = replyToMessage.Id;
                    
                    // Inherit context from the message being replied to if not explicitly provided
                    if (String.isBlank(relatedTaskId) && String.isBlank(relatedProjectId) && String.isBlank(relatedAccountId)) {
                        if (replyToMessage.Related_Task__c != null) {
                            message.Related_Task__c = replyToMessage.Related_Task__c;
                        } else if (replyToMessage.Related_Project__c != null) {
                            message.Related_Project__c = replyToMessage.Related_Project__c;
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
            
            insert message;
            
            // Send notifications to mentioned contacts
            if (mentionedContactIds != null && !mentionedContactIds.isEmpty()) {
                sendMentionNotifications(message.Id, mentionedContactIds, messageBody);
            }
            
            return message.Id;
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'DML Error sending message: ' + e.getMessage() + ' DmlType: ' + e.getDmlType(0) + ' Stack: ' + e.getStackTraceString());
            String errorMsg = 'Error sending message: ' + e.getMessage();
            if (e.getNumDml() > 0) {
                errorMsg += ' (DML Type: ' + e.getDmlType(0) + ')';
            }
            throw new AuraHandledException(errorMsg);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error sending message: ' + e.getMessage() + ' Type: ' + e.getTypeName() + ' Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error sending message: ' + e.getMessage() + ' (Type: ' + e.getTypeName() + ')');
        }
    }
    
    /**
     * @description Get or create a Contact record for a User
     * Milestone team members don't have ContactId, so we create/find a Contact for them
     * @param user The User record
     * @return Contact ID
     */
    private static Id getOrCreateContactForUser(User user) {
        // If user already has ContactId, use it
        if (user.ContactId != null) {
            return user.ContactId;
        }
        
        // For Milestone team members without ContactId, find or create a Contact
        // Try to find existing Contact by email first
        if (String.isNotBlank(user.Email)) {
            List<Contact> existingContacts = [
                SELECT Id
                FROM Contact
                WHERE Email = :user.Email
                LIMIT 1
            ];
            if (!existingContacts.isEmpty()) {
                return existingContacts[0].Id;
            }
        }
        
        // Create a new Contact for the Milestone team member
        Contact newContact = new Contact();
        
        // Parse name - LastName is required
        if (user.Name.contains(' ')) {
            List<String> nameParts = user.Name.split(' ', 2);
            newContact.FirstName = nameParts[0];
            newContact.LastName = nameParts.size() > 1 ? nameParts[1] : nameParts[0];
        } else {
            // If no space, use entire name as LastName (required field)
            newContact.LastName = String.isNotBlank(user.Name) ? user.Name : 'Milestone Team Member';
        }
        
        newContact.Email = user.Email;
        // Note: AccountId is not required for Contact
        // For Milestone team members, we'll leave AccountId blank
        
        insert newContact;
        return newContact.Id;
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
     * Note: In the portal context, all users are clients (they have AccountId).
     * Milestone Consulting team members do not use the portal - they access Salesforce internally.
     * This method returns false for all portal users since they are all clients.
     * @return Boolean indicating if user is Milestone team member (always false for portal users)
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
     * @return List of MessageInfo objects
     */
    @AuraEnabled(cacheable=false)
    public static List<MessageInfo> getMessages(
        String recipientType,
        String relatedAccountId,
        String relatedProjectId,
        String relatedTaskId,
        Integer limitCount,
        String orderByField,
        String orderDirection
    ) {
        try {
            // Normalize incoming params up front
            recipientType = normalizeOptional(recipientType);
            relatedAccountId = normalizeOptional(relatedAccountId);
            relatedProjectId = normalizeOptional(relatedProjectId);
            relatedTaskId = normalizeOptional(relatedTaskId);
            
            // Get current user's contact and account
            User currentUser = [
                SELECT Id, ContactId, AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            // Extract values for bind variables (can't use dot notation in Database.query)
            Id currentUserContactId = currentUser.ContactId;
            Id currentUserAccountId = currentUser.AccountId;
            
            // Milestone team members (internal Salesforce users) may not have ContactId
            // Portal users (clients) always have ContactId
            Boolean isMilestoneTeamMember = (currentUser.AccountId == null);
            
            // --- Build filters deterministically and safely ---
            // Access filter: sender is current user OR allowed recipient bucket
            List<String> accessFilters = new List<String>();
            
            // Only include sender filter if user has ContactId (portal users)
            if (currentUserContactId != null) {
                accessFilters.add(FIELD_SENDER + ' = :currentUserContactId');
            }
            
            if (recipientType == RECIPIENT_CLIENT) {
                // Explicitly client-only
                if (currentUserAccountId != null) {
                    accessFilters.add(FIELD_RECIPIENT_TYPE + ' = \'' + RECIPIENT_CLIENT + '\' AND ' + FIELD_ACCOUNT + ' = :currentUserAccountId');
                } else {
                    accessFilters.add(FIELD_RECIPIENT_TYPE + ' = \'' + RECIPIENT_CLIENT + '\'');
                }
            } else if (recipientType == RECIPIENT_TEAM) {
                accessFilters.add(FIELD_RECIPIENT_TYPE + ' = \'' + RECIPIENT_TEAM + '\'');
            } else {
                // Default: both buckets
                if (currentUserAccountId != null) {
                    accessFilters.add(FIELD_RECIPIENT_TYPE + ' = \'' + RECIPIENT_CLIENT + '\' AND ' + FIELD_ACCOUNT + ' = :currentUserAccountId');
                } else {
                    accessFilters.add(FIELD_RECIPIENT_TYPE + ' = \'' + RECIPIENT_CLIENT + '\'');
                }
                accessFilters.add(FIELD_RECIPIENT_TYPE + ' = \'' + RECIPIENT_TEAM + '\'');
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
            List<String> baseFilters = new List<String>{
                FIELD_DELETED + ' = false'
            };
            if (currentUserAccountId != null) {
                baseFilters.add(FIELD_VISIBLE_TO_CLIENT + ' = true');
            }
            
            // Assemble WHERE
            List<String> whereParts = new List<String>();
            
            // Clean up any blanks defensively
            List<String> cleanedAccessFilters = new List<String>();
            for (String f : accessFilters) {
                if (String.isNotBlank(f)) {
                    cleanedAccessFilters.add(f);
                }
            }
            if (!cleanedAccessFilters.isEmpty()) {
                whereParts.add('(' + String.join(cleanedAccessFilters, ' OR ') + ')');
            }
            
            if (String.isNotBlank(contextFilter)) {
                whereParts.add(contextFilter);
            }
            
            for (String base : baseFilters) {
                if (String.isNotBlank(base)) {
                    whereParts.add(base);
                }
            }
            
            if (whereParts.isEmpty()) {
                return new List<MessageInfo>(); // Nothing to query
            }
            
            String whereClause = 'WHERE ' + String.join(whereParts, ' AND ');
            
            // Query messages - need to include Related_Task__r.Project__c for project rollup and Reply_To__c for replies
            // Normalize limit and ordering inputs
            Integer normalizedLimit = (limitCount != null && limitCount > 0 && limitCount <= 200) ? limitCount : 100;
            String normalizedOrderDirection = (orderDirection != null && orderDirection.toUpperCase() == 'ASC') ? 'ASC' : 'DESC';
            
            // Only allow a small, known-safe set of fields for ordering to avoid injection
            Map<String, String> allowedOrderFields = new Map<String, String>{
                'CreatedDate' => 'CreatedDate',
                'LastEditedDate' => 'Last_Edited_Date__c',
                'IsPinned' => 'Is_Pinned__c'
            };
            String normalizedOrderField = allowedOrderFields.containsKey(orderByField) ? allowedOrderFields.get(orderByField) : 'CreatedDate';
            
            String query = 'SELECT Id, Name, Body__c, Sender__c, Sender__r.Name, Sender__r.Email, ' +
                         'Recipient_Type__c, Related_Project__c, Related_Project__r.Name, ' +
                         'Related_Task__c, Related_Task__r.Name, Related_Task__r.Project__c, ' +
                         'Mentioned_Contacts__c, Is_Read__c, Deleted__c, Visible_To_Client__c, ' +
                         'Is_Edited__c, Last_Edited_Date__c, CreatedDate, CreatedBy.Name, ' +
                         'Account__c, Account__r.Name, Reply_To__c, Reply_To__r.Id, Reply_To__r.Body__c, ' +
                         'Reply_To__r.Sender__r.Name, Reply_To__r.CreatedDate, Reply_To__r.Related_Task__c, ' +
                         'Is_Pinned__c ' +
                         'FROM Message__c ' + whereClause + ' ' +
                         'ORDER BY Is_Pinned__c DESC, ' + normalizedOrderField + ' ' + normalizedOrderDirection + ' ' +
                         'LIMIT :normalizedLimit';
            
            System.debug('getMessages query: ' + query);
            System.debug('getMessages relatedTaskId: ' + relatedTaskId);
            System.debug('getMessages relatedProjectId: ' + relatedProjectId);
            System.debug('getMessages relatedAccountId: ' + relatedAccountId);
            System.debug('getMessages currentUserContactId: ' + currentUserContactId);
            System.debug('getMessages currentUserAccountId: ' + currentUserAccountId);
            
            // Use standard Database.query - bind variables work with local variables in scope
            // The bind variables like :currentUserContactId and :relevantTaskIds will work
            // as long as the variables are in scope when Database.query is called
            List<Message__c> messages = Database.query(query);
            System.debug('getMessages found ' + messages.size() + ' messages');
            
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
                info.isRead = msg.Is_Read__c;
                info.createdDate = msg.CreatedDate;
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
                info.isMentioned = false;
                if (String.isNotBlank(msg.Mentioned_Contacts__c) && currentUserContactId != null) {
                    List<String> mentionedIds = msg.Mentioned_Contacts__c.split(',');
                    info.isMentioned = mentionedIds.contains(currentUserContactId);
                }
                
                messageInfos.add(info);
            }
            
            return messageInfos;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving messages: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get latest messages across all tasks for the current user's account
     * Returns the most recent messages from all tasks the user has access to
     * @param limit Number of messages to return (default 5)
     * @return List of MessageInfo objects with task information
     */
    @AuraEnabled(cacheable=true)
    public static List<MessageInfo> getLatestMessages(Integer limitCount) {
        if (limitCount == null || limitCount <= 0) {
            limitCount = 5;
        }
        
        try {
            // Get current user's contact and account
            User currentUser = [
                SELECT Id, ContactId, AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (currentUser.ContactId == null) {
                return new List<MessageInfo>();
            }
            
            // Extract values for bind variables (dot notation is not allowed in Database.query)
            Id currentUserContactId = currentUser.ContactId;
            Id currentUserAccountId = currentUser.AccountId;
            String recipientClient = RECIPIENT_CLIENT;
            String recipientTeam = RECIPIENT_TEAM;
            
            // Build WHERE clause explicitly to avoid malformed query strings
            String whereClause = 'WHERE (' +
                FIELD_SENDER + ' = :currentUserContactId ' +
                'OR (' + FIELD_RECIPIENT_TYPE + ' = :recipientClient' +
                    (currentUserAccountId != null ? ' AND ' + FIELD_ACCOUNT + ' = :currentUserAccountId' : '') +
                ') OR ' + FIELD_RECIPIENT_TYPE + ' = :recipientTeam' +
            ') AND ' + FIELD_DELETED + ' = false' +
            (currentUserAccountId != null ? ' AND ' + FIELD_VISIBLE_TO_CLIENT + ' = true' : '') +
            ' AND ' + FIELD_TASK + ' != null';
            
            // Query messages - need to include task information for navigation and Reply_To__c for replies
            String query = 'SELECT Id, Name, Body__c, Sender__c, Sender__r.Name, Sender__r.Email, ' +
                         'Recipient_Type__c, Related_Project__c, Related_Project__r.Name, ' +
                         'Related_Task__c, Related_Task__r.Name, Related_Task__r.Project__c, ' +
                         'Mentioned_Contacts__c, Is_Read__c, Deleted__c, Visible_To_Client__c, ' +
                         'Is_Edited__c, Last_Edited_Date__c, CreatedDate, CreatedBy.Name, ' +
                         'Account__c, Account__r.Name, Reply_To__c, Reply_To__r.Id, Reply_To__r.Body__c, ' +
                         'Reply_To__r.Sender__r.Name, Reply_To__r.CreatedDate, Reply_To__r.Related_Task__c, ' +
                         'Is_Pinned__c ' +
                         'FROM Message__c ' + whereClause + ' ' +
                         'ORDER BY Is_Pinned__c DESC, CreatedDate DESC ' +
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
                info.isRead = msg.Is_Read__c;
                info.createdDate = msg.CreatedDate;
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
                info.isMentioned = false;
                if (String.isNotBlank(msg.Mentioned_Contacts__c) && currentUserContactId != null) {
                    List<String> mentionedIds = msg.Mentioned_Contacts__c.split(',');
                    info.isMentioned = mentionedIds.contains(currentUserContactId);
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
        try {
            User currentUser = [
                SELECT Id, ContactId, AccountId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            // Build query with proper bind variables
            List<Contact> contacts;
            String searchLike = null;
            if (String.isNotBlank(searchTerm)) {
                // Escape LIKE wildcards to avoid injection via pattern characters
                String escaped = searchTerm.replaceAll('([%_\\\\])', '\\\\$1');
                searchLike = '%' + escaped + '%';
            }
            
            if (currentUser.AccountId != null) {
                // If user has an account, prioritize contacts from same account
                // Also include Milestone Consulting team members (users without account)
                String query = 'SELECT Id, Name, Email, AccountId, Account.Name ' +
                              'FROM Contact ' +
                              'WHERE Portal_Access_Enabled__c = true ' +
                              'AND (AccountId = :currentUserAccountId OR AccountId = null)';
                
                if (searchLike != null) {
                    query += ' AND (Name LIKE :searchLike ESCAPE \'\\\\\' OR Email LIKE :searchLike ESCAPE \'\\\\\')';
                }
                
                query += ' WITH SECURITY_ENFORCED ORDER BY Name LIMIT 20';
                
                Id currentUserAccountId = currentUser.AccountId;
                contacts = Database.query(query);
            } else {
                // User doesn't have an account (Milestone team member)
                String query = 'SELECT Id, Name, Email, AccountId, Account.Name ' +
                              'FROM Contact ' +
                              'WHERE Portal_Access_Enabled__c = true';
                
                if (searchLike != null) {
                    query += ' AND (Name LIKE :searchLike ESCAPE \'\\\\\' OR Email LIKE :searchLike ESCAPE \'\\\\\')';
                }
                
                query += ' WITH SECURITY_ENFORCED ORDER BY Name LIMIT 20';
                
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
            throw new AuraHandledException('Error retrieving contacts: ' + e.getMessage());
        }
    }
    
    /**
     * @description Mark message as read
     * @param messageId The message ID
     */
    @AuraEnabled
    public static void markAsRead(String messageId) {
        if (String.isBlank(messageId)) {
            return;
        }
        
        try {
            Message__c message = [
                SELECT Id, Is_Read__c
                FROM Message__c
                WHERE Id = :messageId
                LIMIT 1
            ];
            
            message.Is_Read__c = true;
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
            // Get current user's contact
            User currentUser = [
                SELECT Id, ContactId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            if (currentUser.ContactId == null) {
                throw new AuraHandledException('Current user must be associated with a Contact');
            }
            
            // Get message and verify sender (no WITH SECURITY_ENFORCED to allow portal edits)
            Message__c message = [
                SELECT Id, Sender__c, Body__c, Is_Edited__c, Deleted__c
                FROM Message__c
                WHERE Id = :messageId
                LIMIT 1
            ];
            
            // Only allow sender to edit their own message
            if (message.Sender__c != currentUser.ContactId) {
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
            // Get current user's contact
            User currentUser = [
                SELECT Id, ContactId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            if (currentUser.ContactId == null) {
                throw new AuraHandledException('Current user must be associated with a Contact');
            }
            
            // Get message and verify sender
            Message__c message = [
                SELECT Id, Sender__c, Deleted__c
                FROM Message__c
                WHERE Id = :messageId
                LIMIT 1
            ];
            
            // Only allow sender to delete their own message
            if (message.Sender__c != currentUser.ContactId) {
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
    private static void sendMentionNotifications(
        String messageId,
        List<String> mentionedContactIds,
        String messageBody
    ) {
        if (mentionedContactIds == null || mentionedContactIds.isEmpty()) {
            return;
        }
        
        try {
            // Get mentioned contacts
            List<Contact> mentionedContacts = [
                SELECT Id, Name, Email
                FROM Contact
                WHERE Id IN :mentionedContactIds
                AND Email != null
                WITH SECURITY_ENFORCED
            ];
            
            if (mentionedContacts.isEmpty()) {
                return;
            }
            
            // Get message details for email
            Message__c message = [
                SELECT Id, Name, Sender__r.Name, Related_Project__r.Name, Related_Task__r.Name
                FROM Message__c
                WHERE Id = :messageId
                WITH SECURITY_ENFORCED
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
                    'Hello ' + contact.Name + ',\n\n' +
                    'You were mentioned in a message by ' + message.Sender__r.Name + '.\n\n' +
                    'Message:\n' + plainTextBody + '\n\n' +
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
                WITH SECURITY_ENFORCED
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
                WHERE LinkedEntityId = :messageId
                AND ContentDocumentId IN :contentDocumentIds
                WITH SECURITY_ENFORCED
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
            System.debug(LoggingLevel.ERROR, 'Error linking files to message: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error linking files to message: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get files linked to a message
     * @param messageId The message ID
     * @return List of FileInfo objects
     */
    @AuraEnabled(cacheable=true)
    public static List<FileInfo> getMessageFiles(String messageId) {
        if (String.isBlank(messageId)) {
            return new List<FileInfo>();
        }
        
        List<FileInfo> files = new List<FileInfo>();
        
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension,
                   ContentDocument.ContentSize, ContentDocument.CreatedDate, ContentDocument.CreatedBy.Name,
                   ContentDocument.CreatedBy.Id, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :messageId
            ORDER BY ContentDocument.CreatedDate DESC
        ];
        
        Id currentUserId = UserInfo.getUserId();
        
        for (ContentDocumentLink link : links) {
            FileInfo file = new FileInfo();
            file.id = link.ContentDocumentId;
            file.title = link.ContentDocument.Title;
            file.extension = link.ContentDocument.FileExtension;
            file.size = link.ContentDocument.ContentSize;
            file.createdDate = link.ContentDocument.CreatedDate;
            file.createdBy = link.ContentDocument.CreatedBy?.Name;
            file.createdById = link.ContentDocument.CreatedBy?.Id;
            file.versionId = link.ContentDocument.LatestPublishedVersionId;
            file.canDelete = (link.ContentDocument.CreatedBy?.Id == currentUserId);
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
    public static ContextInfo getContextInfo(
        String relatedAccountId,
        String relatedProjectId,
        String relatedTaskId
    ) {
        ContextInfo context = new ContextInfo();
        
        try {
            if (String.isNotBlank(relatedTaskId)) {
                // Task context
                Project_Task__c task = [
                    SELECT Id, Name, Project__c, Project__r.Name, Project__r.Account__c, Project__r.Account__r.Name
                    FROM Project_Task__c
                    WHERE Id = :relatedTaskId
                    WITH SECURITY_ENFORCED
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
                    WITH SECURITY_ENFORCED
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
                    WITH SECURITY_ENFORCED
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
        @AuraEnabled public String contextType; // 'Account', 'Project', or 'Task'
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String projectId;
        @AuraEnabled public String projectName;
        @AuraEnabled public String taskId;
        @AuraEnabled public String taskName;
    }
    
    /**
     * @description Wrapper class for message information
     */
    public class MessageInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String body;
        @AuraEnabled public String senderId;
        @AuraEnabled public String senderName;
        @AuraEnabled public String senderEmail;
        @AuraEnabled public String recipientType;
        @AuraEnabled public String relatedProjectId;
        @AuraEnabled public String relatedProjectName;
        @AuraEnabled public String relatedTaskId;
        @AuraEnabled public String relatedTaskName;
        @AuraEnabled public String mentionedContacts;
        @AuraEnabled public Boolean isRead;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String createdBy;
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Boolean isMentioned;
        @AuraEnabled public Boolean visibleToClient;
        @AuraEnabled public Boolean isEdited;
        @AuraEnabled public DateTime lastEditedDate;
        @AuraEnabled public Boolean isPinned;
        @AuraEnabled public String replyToMessageId;
        @AuraEnabled public String replyToMessageBody;
        @AuraEnabled public String replyToSenderName;
        @AuraEnabled public DateTime replyToCreatedDate;
        @AuraEnabled public String replyToTaskId;
    }
    
    /**
     * @description Wrapper class for contact information
     */
    public class ContactInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
    }
    
    /**
     * @description Wrapper class for file information
     */
    public class FileInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String extension;
        @AuraEnabled public Long size;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String createdBy;
        @AuraEnabled public String createdById;
        @AuraEnabled public String versionId;
        @AuraEnabled public Boolean canDelete;
    }
}
