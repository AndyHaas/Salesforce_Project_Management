/**
 * Portal Messaging Component
 * 
 * This component works in both Experience Cloud (Portal) and Salesforce contexts.
 * 
 * CONTEXT DETECTION:
 * The component automatically detects its runtime context using multiple methods:
 * 1. Pathname check: Experience Cloud URLs start with '/s/'
 * 2. User type: Milestone team members (no AccountId) are in Salesforce context
 * 3. Page reference type: Experience Cloud pages have 'comm__' prefix, Salesforce has 'standard__'
 * 
 * BEHAVIOR BY CONTEXT:
 * - Portal (Experience Cloud): 
 *   - Users can only send to "Milestone Team"
 *   - Recipient type selector is hidden
 *   - Navigation uses ensureSitePath for portal URLs
 *   - Default recipientType: "Milestone Team"
 * 
 * - Salesforce:
 *   - Milestone team members can send to "Client" or "Milestone Team"
 *   - Recipient type selector is shown
 *   - Can send internal messages (not visible to clients)
 *   - Navigation uses Lightning Navigation Service
 *   - Default recipientType: "Client"
 */

import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE, publish } from 'lightning/messageService';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import sendMessage from '@salesforce/apex/PortalMessagingController.sendMessage';
import getMessages from '@salesforce/apex/PortalMessagingController.getMessages';
import getContextInfo from '@salesforce/apex/PortalMessagingController.getContextInfo';
import getMentionableContacts from '@salesforce/apex/PortalMessagingController.getMentionableContacts';
import getCurrentUserContactId from '@salesforce/apex/PortalMessagingController.getCurrentUserContactId';
import isMilestoneTeamMember from '@salesforce/apex/PortalMessagingController.isMilestoneTeamMember';
import markAsRead from '@salesforce/apex/PortalMessagingController.markAsRead';
import updateMessage from '@salesforce/apex/PortalMessagingController.updateMessage';
import deleteMessage from '@salesforce/apex/PortalMessagingController.deleteMessage';
import pinMessage from '@salesforce/apex/PortalMessagingController.pinMessage';
import linkFilesToMessage from '@salesforce/apex/PortalMessagingController.linkFilesToMessage';
import getMessageFiles from '@salesforce/apex/PortalMessagingController.getMessageFiles';
import { ensureSitePath, formatDate, formatDateTime } from 'c/portalCommon';
import MESSAGE_UPDATE_CHANNEL from '@salesforce/messageChannel/MessageUpdate__c';

export default class PortalMessaging extends NavigationMixin(LightningElement) {
    @api recordId; // Automatically populated when on a Lightning Record Page
    @api relatedAccountId;
    @api relatedProjectId;
    @api relatedTaskId;
    
    @track messageBody = '';
    @track recipientType = null; // Will be set based on user type
    @track isVisibleToClient = true;
    @track searchTerm = '';
    @track selectedMentions = [];
    @track showMentionDropdown = false;
    @track mentionableContacts = [];
    @track filteredContacts = [];
    @track mentionInputValue = '';
    @track currentMentionIndex = -1;
    
    _messages = [];
    _messagesError = null;
    _previousParams;
    _wiredContactsResult;
    _messageContext;
    _messageSubscription;
    @track _editingMessageId = null;
    @track _editingMessageBody = '';
    @track _isModalOpen = false;
    @track _replyingToMessageId = null;
    @track _replyingToMessage = null;
    @track messageSearchTerm = '';
    @track showMessageSearch = false;
    _uploadedFileIds = [];
    
    get showHeaderEnabled() {
        return true;
    }

    
    // Wire service for Lightning Message Service context
    @wire(MessageContext)
    wiredMessageContext(result) {
        // Handle wire result - it might be undefined initially
        if (result) {
            const { data, error } = result;
            
            if (data) {
                this._messageContext = data;
                // Subscribe if we're already connected and haven't subscribed yet
                if (!this._messageSubscription) {
                    this.subscribeToMessageUpdates();
                }
            } else if (error) {
                console.error('Error getting message context:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
            }
        }
    }
    
    _contextInfo = null;
    _isExperienceCloud = null; // Cached value for Experience Cloud detection
    
    /**
     * @description Detect if component is running in Experience Cloud (Portal) vs Salesforce
     * Uses multiple detection methods for reliability
     */
    get isExperienceCloud() {
        // Cache the result to avoid repeated checks
        if (this._isExperienceCloud !== null) {
            return this._isExperienceCloud;
        }
        
        // Method 1: Check pathname for Experience Cloud prefix
        if (typeof window !== 'undefined' && window.location) {
            const pathname = window.location.pathname || '';
            if (pathname.startsWith('/s/') || pathname.includes('/s/')) {
                this._isExperienceCloud = true;
                return true;
            }
        }
        
        // Method 2: Check if user is Milestone team member (no AccountId = Salesforce context)
        // Portal users always have AccountId, Salesforce users typically don't
        if (this._isMilestoneTeamMember === true) {
            this._isExperienceCloud = false;
            return false;
        }
        
        // Method 3: Check page reference type
        // Experience Cloud pages typically have different page reference structure
        // Default to Experience Cloud if we can't determine (safer for portal users)
        this._isExperienceCloud = true; // Default assumption
        return true;
    }
    
    /**
     * @description Getter to check if we're in Salesforce context (opposite of Experience Cloud)
     */
    get isSalesforceContext() {
        return !this.isExperienceCloud;
    }
    
    /**
     * @description Wire service to detect current page reference
     * Extracts record ID from page reference when component is placed on a Lightning Record Page
     * Automatically populates relatedAccountId, relatedProjectId, or relatedTaskId based on object type
     * Also helps detect context
     * 
     * NOTE: This wire service behaves differently on Lightning Record Pages vs Community pages:
     * - Lightning Record Pages: recordId is available via @api AND pageRef.attributes.recordId
     * - Community pages: recordId might only be in pageRef.state or URL parameters
     */
    @wire(CurrentPageReference)
    resolvePageReference(pageRef) {
        if (!pageRef) {
            return;
        }
        
        // Detect context from page reference first
        // Experience Cloud pages typically have type 'comm__namedPage' or 'comm__page'
        // Salesforce pages have type 'standard__recordPage', 'standard__objectPage', etc.
        if (pageRef.type) {
            const pageType = pageRef.type;
            if (pageType.startsWith('comm__')) {
                this._isExperienceCloud = true;
            } else if (pageType.startsWith('standard__')) {
                this._isExperienceCloud = false;
            }
        }
        
        // On Lightning Record Pages, recordId is available via @api
        // On Community pages, we need to extract from pageRef
        const { attributes = {}, state = {} } = pageRef;
        const recordId = this.recordId || state.recordId || attributes.recordId;
        const objectApiName = pageRef.attributes?.objectApiName;
        
        // Auto-populate context based on object type
        if (recordId && objectApiName) {
            if (objectApiName === 'Account' && !this.relatedAccountId) {
                this.relatedAccountId = recordId;
            } else if (objectApiName === 'Project__c' && !this.relatedProjectId) {
                this.relatedProjectId = recordId;
            } else if (objectApiName === 'Project_Task__c' && !this.relatedTaskId) {
                this.relatedTaskId = recordId;
            }
            
            // Trigger message load attempt after context is set
            // Use setTimeout to ensure this happens after all wire services complete
            setTimeout(() => {
                this.attemptLoadMessages();
            }, 0);
        }
    }
    
    // Wire service to get context information
    @wire(getContextInfo, {
        relatedAccountId: '$relatedAccountId',
        relatedProjectId: '$relatedProjectId',
        relatedTaskId: '$relatedTaskId'
    })
    wiredContextInfo({ error, data }) {
        if (data) {
            this._contextInfo = data;
        } else if (error) {
            console.error('Error loading context info:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
        }
    }
    
    /**
     * @description Load messages imperatively (since getMessages is non-cacheable)
     * 
     * NOTE: For Milestone team members, we pass null for recipientType to see ALL messages
     * (both Client and Milestone Team). The recipientType is only used when SENDING messages
     * to specify who the message is sent TO, not when LOADING messages.
     */
    async loadMessages() {
        try {
            // For Milestone team members, pass null to see all messages (both Client and Milestone Team)
            // For portal users, use the recipientType (which is always 'Milestone Team')
            const recipientTypeForQuery = this._isMilestoneTeamMember ? null : this.recipientType;
            
            console.log('Loading messages with params:', JSON.stringify({
                recipientType: recipientTypeForQuery,
                recipientTypeForSending: this.recipientType,
                isMilestoneTeamMember: this._isMilestoneTeamMember,
                relatedAccountId: this.relatedAccountId,
                relatedProjectId: this.relatedProjectId,
                relatedTaskId: this.relatedTaskId
            }, null, 2));
            
            const data = await getMessages({
                recipientType: recipientTypeForQuery,
                relatedAccountId: this.relatedAccountId,
                relatedProjectId: this.relatedProjectId,
                relatedTaskId: this.relatedTaskId
            });
            
            this._messages = data || [];
            this._messagesError = null;
            console.log('Messages loaded:', this._messages.length);
            // Mark unread messages as read
            this.markUnreadMessagesAsRead();
        } catch (error) {
            console.error('Error loading messages:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
            this._messages = [];
            this._messagesError = error;
        }
    }
    
    /**
     * @description Component lifecycle hook - called when component is inserted into DOM
     * Handles initialization differently for Lightning Record Pages vs Community pages
     */
    connectedCallback() {
        // Initialize previous params to track changes
        this._previousParams = {
            recipientType: this.recipientType,
            relatedAccountId: this.relatedAccountId,
            relatedProjectId: this.relatedProjectId,
            relatedTaskId: this.relatedTaskId
        };
        
        // On Lightning Record Pages, recordId is available immediately via @api
        // On Community pages, it might come from URL or page reference
        // We'll wait for wire services to resolve before loading
    }
    
    /**
     * @description Check if we have all required data to load messages
     * Works differently for Lightning Record Pages vs Community pages
     */
    get canLoadMessages() {
        // Must have recipientType set (from wire service)
        if (!this.recipientType) {
            return false;
        }
        return true;
    }
    
    /**
     * @description Attempt to load messages if conditions are met
     * Called from multiple places to handle different initialization scenarios
     */
    attemptLoadMessages() {
        if (!this.canLoadMessages) {
            return;
        }
        
        // Check if params have changed
        const paramsChanged = !this._previousParams ||
            this._previousParams.recipientType !== this.recipientType ||
            this._previousParams.relatedAccountId !== this.relatedAccountId ||
            this._previousParams.relatedProjectId !== this.relatedProjectId ||
            this._previousParams.relatedTaskId !== this.relatedTaskId;
        
        if (paramsChanged) {
            this._previousParams = {
                recipientType: this.recipientType,
                relatedAccountId: this.relatedAccountId,
                relatedProjectId: this.relatedProjectId,
                relatedTaskId: this.relatedTaskId
            };
            this.loadMessages();
        }
    }
    
    /**
     * @description Watch for changes to reactive parameters and reload messages
     * Handles both Lightning Record Pages and Community pages
     */
    renderedCallback() {
        // Use attemptLoadMessages which checks if we can load
        this.attemptLoadMessages();
    }
    
    // Wire service to get mentionable contacts
    @wire(getMentionableContacts, { searchTerm: '$searchTerm' })
    wiredContacts(result) {
        this._wiredContactsResult = result;
        const { error, data } = result;
        
        if (data) {
            this.mentionableContacts = data || [];
            this.filteredContacts = this.mentionableContacts;
        } else if (error) {
            console.error('Error loading contacts:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
            this.mentionableContacts = [];
            this.filteredContacts = [];
        }
    }
    
    _currentUserContactId = null;
    _isMilestoneTeamMember = false;
    
    // Wire service to get current user's contact ID
    @wire(getCurrentUserContactId)
    wiredCurrentUserContact({ error, data }) {
        if (data) {
            this._currentUserContactId = data;
        } else if (error) {
            console.error('Error getting current user contact:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
        }
    }
    
    // Wire service to check if user is Milestone team member
    @wire(isMilestoneTeamMember)
    wiredIsMilestoneTeamMember({ error, data }) {
        if (data !== undefined) {
            this._isMilestoneTeamMember = data;
            
            // Update context detection based on user type
            // Milestone team members (no AccountId) are in Salesforce context
            if (data === true) {
                this._isExperienceCloud = false;
            }
            
            // Set default recipientType based on user type
            // Salesforce users (Milestone team) default to 'Client', Portal users default to 'Milestone Team'
            const previousRecipientType = this.recipientType;
            if (this.recipientType === null) {
                this.recipientType = data ? 'Client' : 'Milestone Team';
            }
            
            // If recipientType was just set, trigger message load attempt
            // This works for both Lightning Record Pages and Community pages
            if (previousRecipientType === null && this.recipientType !== null) {
                // Use setTimeout to ensure this happens after the wire completes
                // attemptLoadMessages will check if all conditions are met
                setTimeout(() => {
                    this.attemptLoadMessages();
                }, 0);
            }
        } else if (error) {
            console.error('Error checking if Milestone team member:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
            this._isMilestoneTeamMember = false;
            // Default to portal behavior if check fails
            const previousRecipientType = this.recipientType;
            if (this.recipientType === null) {
                this.recipientType = 'Milestone Team';
            }
            
            // If recipientType was just set, trigger message load attempt
            if (previousRecipientType === null && this.recipientType !== null) {
                setTimeout(() => {
                    this.attemptLoadMessages();
                }, 0);
            }
        }
    }
    
    /**
     * @description Getter for isMilestoneTeamMember
     */
    get isMilestoneTeamMember() {
        return this._isMilestoneTeamMember;
    }
    
    /**
     * @description Getter for isInternalMessage (inverse of isVisibleToClient)
     */
    get isInternalMessage() {
        return !this.isVisibleToClient;
    }
    
    /**
     * @description Get context information for display
     */
    get contextInfo() {
        return this._contextInfo;
    }
    
    /**
     * @description Get context display text
     */
    get contextDisplayText() {
        if (!this._contextInfo) {
            return '';
        }
        
        const parts = [];
        if (this._contextInfo.accountName) {
            parts.push(`Account: ${this._contextInfo.accountName}`);
        }
        if (this._contextInfo.projectName) {
            parts.push(`Project: ${this._contextInfo.projectName}`);
        }
        if (this._contextInfo.taskName) {
            parts.push(`Task: ${this._contextInfo.taskName}`);
        }
        
        return parts.join(' • ');
    }
    
    /**
     * @description Get context type for display
     */
    get contextType() {
        return this._contextInfo?.contextType || '';
    }
    
    /**
     * @description Get icon name based on context type
     */
    get contextIcon() {
        if (!this._contextInfo) {
            return 'utility:message';
        }
        
        switch (this._contextInfo.contextType) {
            case 'Account':
                return 'utility:account';
            case 'Project':
                return 'utility:record';
            case 'Task':
                return 'utility:task';
            default:
                return 'utility:message';
        }
    }
    
    /**
     * @description Show account context in message list (when viewing at project or task level)
     */
    get showAccountContext() {
        return this._contextInfo && 
               (this._contextInfo.contextType === 'Project' || this._contextInfo.contextType === 'Task');
    }
    
    /**
     * @description Show project context in message list (when viewing at task level)
     */
    get showProjectContext() {
        return this._contextInfo && this._contextInfo.contextType === 'Task';
    }
    
    /**
     * @description Show task context in message list (always show if task exists)
     */
    get showTaskContext() {
        return true; // Always show task if it exists in the message
    }
    
    /**
     * @description Lifecycle hook - component is inserted into the DOM
     */
    connectedCallback() {
        // Load messages on initialization
        this.loadMessages();
        
        // Subscribe to message updates
        if (this._messageContext) {
            this.subscribeToMessageUpdates();
        }
    }
    
    /**
     * @description Lifecycle hook - component is removed from the DOM
     */
    disconnectedCallback() {
        // Unsubscribe from message updates
        if (this._messageSubscription) {
            unsubscribe(this._messageSubscription);
            this._messageSubscription = null;
        }
    }
    
    /**
     * @description Subscribe to message update channel
     */
    subscribeToMessageUpdates() {
        if (!this._messageContext) {
            return;
        }
        
        this._messageSubscription = subscribe(
            this._messageContext,
            MESSAGE_UPDATE_CHANNEL,
            (message) => this.handleMessageUpdate(message),
            { scope: APPLICATION_SCOPE }
        );
    }
    
    /**
     * @description Handle incoming message update
     * Only refresh if the update is relevant to this component's context
     */
    async handleMessageUpdate(message) {
        if (!message) {
            return;
        }
        
        // Check if this update is relevant to this component
        const isRelevant = 
            (message.relatedAccountId && message.relatedAccountId === this.relatedAccountId) ||
            (message.relatedProjectId && message.relatedProjectId === this.relatedProjectId) ||
            (message.relatedTaskId && message.relatedTaskId === this.relatedTaskId) ||
            (!message.relatedAccountId && !message.relatedProjectId && !message.relatedTaskId && 
             !this.relatedAccountId && !this.relatedProjectId && !this.relatedTaskId);
        
        if (isRelevant) {
            // Refresh messages
            await this.loadMessages();
        }
    }
    
    /**
     * @description Publish message update to notify other components
     */
    publishMessageUpdate(action) {
        if (!this._messageContext) {
            return;
        }
        
        const payload = {
            relatedAccountId: this.relatedAccountId,
            relatedProjectId: this.relatedProjectId,
            relatedTaskId: this.relatedTaskId,
            action: action
        };
        
        publish(this._messageContext, MESSAGE_UPDATE_CHANNEL, payload);
    }
    
    /**
     * @description Get messages for display
     */
    get messages() {
        if (!this._messages || this._messages.length === 0) {
            return [];
        }
        
        let filteredMessages = this._messages;
        
        // Apply search filter if search term exists
        if (this.messageSearchTerm && this.messageSearchTerm.trim().length > 0) {
            const searchLower = this.messageSearchTerm.toLowerCase().trim();
            filteredMessages = this._messages.filter(msg => {
                // Search in message body (strip HTML for search)
                const bodyText = this.stripHtmlForSearch(msg.body || '');
                const bodyMatch = bodyText.toLowerCase().includes(searchLower);
                
                // Search in sender name
                const senderMatch = (msg.senderName || '').toLowerCase().includes(searchLower);
                
                return bodyMatch || senderMatch;
            });
        }
        
        return filteredMessages.map(msg => {
            const taskLink = this.buildLink(msg.relatedTaskId, msg.relatedTaskName, '/project-task');
            const projectLink = this.buildLink(msg.relatedProjectId, msg.relatedProjectName, '/project');
            
            // Prepare navigation data for Salesforce links
            let taskNavData = null;
            let projectNavData = null;
            
            if (taskLink && taskLink.type === 'standard__recordPage') {
                taskNavData = JSON.stringify(taskLink);
            }
            if (projectLink && projectLink.type === 'standard__recordPage') {
                projectNavData = JSON.stringify(projectLink);
            }
            
            return {
                ...msg,
                formattedDate: this.formatMessageDate(msg.createdDate),
                formattedEditedDate: msg.lastEditedDate ? this.formatMessageDate(msg.lastEditedDate) : '',
                isFromCurrentUser: this.isFromCurrentUser(msg.senderId),
                isUnread: !msg.isRead,
                isEditing: this._editingMessageId === msg.id,
                isReplying: this._replyingToMessageId === msg.id,
                replyToFormattedDate: msg.replyToCreatedDate ? this.formatMessageDate(msg.replyToCreatedDate) : '',
                replyToPreview: this.stripHtmlPreview(msg.replyToMessageBody || ''),
                taskLink: taskLink,
                projectLink: projectLink,
                // Add flags to determine if link is Salesforce navigation
                taskLinkIsSalesforce: taskLink && taskLink.type === 'standard__recordPage',
                projectLinkIsSalesforce: projectLink && projectLink.type === 'standard__recordPage',
                // JSON strings for navigation data
                taskNavData: taskNavData,
                projectNavData: projectNavData,
                // Hide task footer if we're already on that task's page
                showTaskFooter: !(this.relatedTaskId && msg.relatedTaskId && this.relatedTaskId === msg.relatedTaskId)
            };
        });
    }
    
    /**
     * @description Strip HTML for search purposes (more thorough than preview)
     */
    stripHtmlForSearch(html) {
        if (!html) {
            return '';
        }
        const tmp = document.createElement('DIV');
        tmp.innerHTML = html;
        return tmp.textContent || tmp.innerText || '';
    }
    
    /**
     * @description Check if message is from current user
     */
    isFromCurrentUser(senderId) {
        // Will be set after we get current user contact ID
        return this._currentUserContactId && senderId === this._currentUserContactId;
    }
    
    /**
     * @description Check if has messages
     */
    get hasMessages() {
        return this._messages && this._messages.length > 0;
    }

    /**
     * @description Build link object for project/task navigation
     * Works in both Portal (Experience Cloud) and Salesforce contexts
     * Uses context detection to determine the appropriate navigation method
     */
    buildLink(id, name, basePath) {
        if (!id || !basePath) {
            return null;
        }
        try {
            // Use context detection to determine navigation method
            if (this.isSalesforceContext) {
                // In Salesforce, use Lightning Navigation
                // Extract object type from basePath
                let objectApiName;
                if (basePath.includes('project-task')) {
                    objectApiName = 'Project_Task__c';
                } else if (basePath.includes('project')) {
                    objectApiName = 'Project__c';
                } else {
                    objectApiName = 'Account';
                }
                
                // Return navigation config object for Lightning Navigation
                return {
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: id,
                        objectApiName: objectApiName,
                        actionName: 'view'
                    },
                    label: name && name.length > 0 ? name : 'View',
                    recordId: id // Store for click handler
                };
            } else {
                // Portal/Experience Cloud context - use ensureSitePath
                const href = ensureSitePath(`${basePath}/${id}`, { 
                    currentPathname: typeof window !== 'undefined' ? window.location.pathname : '' 
                });
                return {
                    href,
                    label: name && name.length > 0 ? name : 'View'
                };
            }
        } catch (e) {
            console.error('Error building link:', JSON.stringify(e, Object.getOwnPropertyNames(e), 2));
            return null;
        }
    }
    
    /**
     * @description Handle navigation to record
     * Works in both Salesforce (Lightning Navigation) and Portal (standard href) contexts
     */
    handleNavigateToRecord(event) {
        const link = event.currentTarget.dataset.link;
        if (!link) {
            return;
        }
        
        try {
            const linkData = JSON.parse(link);
            
            // Check if it's a Salesforce navigation config
            if (linkData.type === 'standard__recordPage') {
                // Use Lightning Navigation Service for Salesforce
                this[NavigationMixin.Navigate](linkData);
            } else if (linkData.href) {
                // Portal/Experience Cloud link - use standard navigation
                if (typeof window !== 'undefined' && window.location) {
                    window.location.href = linkData.href;
                }
            }
        } catch (e) {
            console.error('Error navigating to record:', JSON.stringify(e, Object.getOwnPropertyNames(e), 2));
            // Fallback: try to navigate using recordId if available
            const recordId = event.currentTarget.dataset.recordId;
            if (recordId && this.isSalesforceContext) {
                // Try to determine object type from context
                const objectApiName = event.currentTarget.dataset.objectApiName || 'Project_Task__c';
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: recordId,
                        objectApiName: objectApiName,
                        actionName: 'view'
                    }
                });
            }
        }
    }
    
    /**
     * @description Check if has filtered messages (after search)
     */
    get hasFilteredMessages() {
        const filtered = this.messages;
        return filtered && filtered.length > 0;
    }
    
    /**
     * @description Handle search icon click to toggle search field
     */
    handleToggleSearch() {
        this.showMessageSearch = !this.showMessageSearch;
        // Clear search when hiding
        if (!this.showMessageSearch) {
            this.messageSearchTerm = '';
        } else {
            this.focusMessageSearch();
        }
    }
    
    /**
     * @description Handle message search input change
     */
    handleMessageSearchChange(event) {
        this.messageSearchTerm = event.target.value;
    }
    
    /**
     * @description Clear message search
     */
    handleClearSearch() {
        this.messageSearchTerm = '';
        this.showMessageSearch = false;
    }

    /**
     * @description Focus the message search input after it renders
     */
    focusMessageSearch() {
        // Defer to next tick so the input is in the DOM
        window.requestAnimationFrame(() => {
            const searchInput = this.template.querySelector('.message-search-input input');
            if (searchInput) {
                searchInput.focus();
            }
        });
    }
    
    /**
     * @description Format message date with relative time, including time in user's timezone
     */
    formatMessageDate(dateValue) {
        if (!dateValue) {
            return '';
        }
        const date = new Date(dateValue);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);
        
        // Format time in user's timezone (HH:MM)
        const pad = (n) => String(n).padStart(2, '0');
        const timeStr = `${pad(date.getHours())}:${pad(date.getMinutes())}`;
        
        if (diffMins < 1) {
            return `Just now (${timeStr})`;
        } else if (diffMins < 60) {
            return `${diffMins} minute${diffMins > 1 ? 's' : ''} ago (${timeStr})`;
        } else if (diffHours < 24) {
            return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago (${timeStr})`;
        } else if (diffDays < 7) {
            return `${diffDays} day${diffDays > 1 ? 's' : ''} ago (${timeStr})`;
        } else {
            // For older messages, show full date and time in user's timezone
            return formatDateTime(dateValue, '—');
        }
    }
    
    /**
     * @description Get recipient type options
     * Note: Portal users always send to Milestone Team, so this is not used in the UI
     */
    get recipientTypeOptions() {
        return [
            { label: 'Client', value: 'Client' },
            { label: 'Milestone Team', value: 'Milestone Team' }
        ];
    }
    
    /**
     * @description Check if recipient type selector should be shown
     * Only show in Salesforce context for Milestone team members
     */
    get showRecipientTypeSelector() {
        return this.isSalesforceContext && this._isMilestoneTeamMember;
    }
    
    /**
     * @description Check if recipient type is Client
     */
    get isClientRecipient() {
        return this.recipientType === 'Client';
    }
    
    /**
     * @description Handle recipient type change
     * Only used in Salesforce context - Portal users always send to Milestone Team
     */
    handleRecipientTypeChange(event) {
        this.recipientType = event.detail.value;
        // When sending to Client, ensure it's visible to client
        // When sending to Milestone Team, allow internal messages
        if (this.recipientType === 'Client') {
            this.isVisibleToClient = true;
        }
    }
    
    /**
     * @description Handle visibility to client change
     * Checkbox is checked when message is internal (not visible to client)
     */
    handleVisibilityChange(event) {
        // Checkbox checked = internal (not visible to client) = isVisibleToClient = false
        this.isVisibleToClient = !event.target.checked;
    }
    
    /**
     * @description Handle message body change (rich text)
     */
    handleMessageBodyChange(event) {
        this.messageBody = event.detail.value;
        // Parse mentions from the rich text
        this.parseMentions(this.messageBody);
    }
    
    /**
     * @description Parse @mentions from message body
     * Rich text editor stores mentions in format: @[Name](Id)
     */
    parseMentions(body) {
        if (!body) {
            this.selectedMentions = [];
            return;
        }
        
        // Extract @mentions using regex - format: @[Name](Id)
        const mentionRegex = /@\[([^\]]+)\]\(([^\)]+)\)/g;
        const mentions = [];
        let match;
        
        while ((match = mentionRegex.exec(body)) !== null) {
            mentions.push({
                name: match[1],
                id: match[2]
            });
        }
        
        this.selectedMentions = mentions;
    }
    
    /**
     * @description Handle file upload finished
     */
    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        
        if (!uploadedFiles || uploadedFiles.length === 0) {
            return;
        }
        
        // Store uploaded file IDs for linking after message is sent
        this._uploadedFileIds = uploadedFiles
            .map(file => file.contentVersionId)
            .filter(id => id);
    }
    
    /**
     * @description Send message
     */
    async handleSendMessage() {
        // Get the current value from the rich text editor in the modal
        const modalRichTextEditor = this.template.querySelector('.message-rich-text-large');
        const currentMessageBody = modalRichTextEditor ? modalRichTextEditor.value : this.messageBody;
        
        if (!currentMessageBody || currentMessageBody.trim().length === 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please enter a message',
                    variant: 'error'
                })
            );
            return;
        }
        
        try {
            // Extract mentioned contact IDs
            const mentionedContactIds = this.selectedMentions.map(m => m.id);
            
            console.log('Sending message with:', JSON.stringify({
                messageBody: currentMessageBody.substring(0, 100) + '...',
                recipientType: this.recipientType,
                relatedAccountId: this.relatedAccountId,
                relatedProjectId: this.relatedProjectId,
                relatedTaskId: this.relatedTaskId,
                mentionedContactIds: mentionedContactIds,
                isVisibleToClient: this.isVisibleToClient,
                replyToMessageId: this._replyingToMessageId
            }, null, 2));
            
            // Send message
            const messageId = await sendMessage({
                messageBody: currentMessageBody,
                recipientType: this.recipientType,
                relatedAccountId: this.relatedAccountId,
                relatedProjectId: this.relatedProjectId,
                relatedTaskId: this.relatedTaskId,
                mentionedContactIds: mentionedContactIds,
                isVisibleToClient: this.isVisibleToClient,
                replyToMessageId: this._replyingToMessageId
            });
            
            console.log('Message sent successfully, ID:', messageId);
            
            // Link files if any were uploaded
            if (this._uploadedFileIds && this._uploadedFileIds.length > 0) {
                try {
                    await linkFilesToMessage({
                        messageId: messageId,
                        contentVersionIds: this._uploadedFileIds
                    });
                } catch (fileError) {
                    console.error('Error linking files:', JSON.stringify(fileError, Object.getOwnPropertyNames(fileError), 2));
                    // Don't fail the message send if file linking fails
                }
            }
            
            // Clear form
            this.messageBody = '';
            this.selectedMentions = [];
            this.isVisibleToClient = true; // Reset to default
            this._uploadedFileIds = [];
            this._replyingToMessageId = null;
            this._replyingToMessage = null;
            
            // Clear rich text editor (both inline and modal)
            const richTextEditors = this.template.querySelectorAll('lightning-input-rich-text');
            richTextEditors.forEach(editor => {
                if (editor) {
                    editor.value = '';
                }
            });
            
            // Close modal after successful send
            this._isModalOpen = false;
            
            // Publish message update first to notify other components
            this.publishMessageUpdate('sent');
            
            // Reload messages after sending
            console.log('Reloading messages after send...');
            await this.loadMessages();
            console.log('Messages reloaded');
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Message sent successfully',
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error sending message:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
            console.error('Error details:', JSON.stringify({
                body: error.body,
                message: error.message,
                stack: error.stack
            }, null, 2));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to send message: ' + (error.body?.message || error.body?.exceptionMessage || error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }
    
    /**
     * @description Mark unread messages as read
     */
    async markUnreadMessagesAsRead() {
        // Mark unread messages for the current recipient bucket
        const unreadMessages = this._messages.filter(
            (msg) => !msg.isRead && msg.recipientType === this.recipientType
        );
        
        for (const msg of unreadMessages) {
            try {
                await markAsRead({ messageId: msg.id });
            } catch (error) {
                console.error('Error marking message as read:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
            }
        }
        
        if (unreadMessages.length > 0) {
            await this.loadMessages();
        }
    }
    
    /**
     * @description Get accepted file formats
     */
    get acceptedFormats() {
        return '.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.jpg,.jpeg,.png,.gif,.zip,.rar';
    }
    
    /**
     * @description Handle edit message
     */
    handleEditMessage(event) {
        const messageId = event.currentTarget.dataset.messageId;
        const message = this._messages.find(m => m.id === messageId);
        
        if (!message) {
            return;
        }
        
        this._editingMessageId = messageId;
        this._editingMessageBody = message.body;
    }
    
    /**
     * @description Handle cancel edit
     */
    handleCancelEdit() {
        this._editingMessageId = null;
        this._editingMessageBody = '';
    }
    
    /**
     * @description Handle edit body change
     */
    handleEditBodyChange(event) {
        this._editingMessageBody = event.detail.value;
    }
    
    /**
     * @description Handle save edit
     */
    async handleSaveEdit() {
        if (!this._editingMessageBody || this._editingMessageBody.trim().length === 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Message body cannot be empty',
                    variant: 'error'
                })
            );
            return;
        }
        
        try {
            await updateMessage({
                messageId: this._editingMessageId,
                messageBody: this._editingMessageBody
            });
            
            // Clear edit state
            this._editingMessageId = null;
            this._editingMessageBody = '';
            
            // Refresh messages
            await this.loadMessages();
            
            // Publish message update to notify other components
            this.publishMessageUpdate('edited');
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Message updated successfully',
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error updating message:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to update message: ' + (error.body?.message || error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }
    
    /**
     * @description Handle reply to message
     */
    handleReplyToMessage(event) {
        const messageId = event.currentTarget.dataset.messageId;
        const message = this._messages.find(m => m.id === messageId);
        
        if (!message) {
            return;
        }
        
        this._replyingToMessageId = messageId;
        this._replyingToMessage = message;
        
        // Open modal for replying
        this._isModalOpen = true;
    }
    
    /**
     * @description Cancel reply
     */
    handleCancelReply() {
        this._replyingToMessageId = null;
        this._replyingToMessage = null;
    }
    
    /**
     * @description Get replying to message info
     */
    get replyingToMessage() {
        return this._replyingToMessage;
    }
    
    /**
     * @description Check if currently replying to a message
     */
    get isReplying() {
        return !!this._replyingToMessageId;
    }
    
    /**
     * @description Check if modal is open
     */
    get isModalOpen() {
        return this._isModalOpen;
    }
    
    /**
     * @description Open message composition modal
     */
    handleOpenModal() {
        this._isModalOpen = true;
    }
    
    /**
     * @description Close message composition modal
     */
    handleCloseModal() {
        this._isModalOpen = false;
        // Cancel reply if modal is closed
        if (this._replyingToMessageId) {
            this.handleCancelReply();
        }
    }
    
    /**
     * @description Handle backdrop click to close modal
     */
    handleBackdropClick(event) {
        // Only close if clicking the backdrop itself, not the modal content
        if (event.target === event.currentTarget) {
            this.handleCloseModal();
        }
    }
    
    /**
     * @description Strip HTML and create preview text
     */
    stripHtmlPreview(html) {
        if (!html) {
            return '';
        }
        const tmp = document.createElement('DIV');
        tmp.innerHTML = html;
        let text = tmp.textContent || tmp.innerText || '';
        // Limit to 100 characters
        if (text.length > 100) {
            text = text.substring(0, 100) + '...';
        }
        return text;
    }
    
    /**
     * @description Navigate to original message (scroll to it in the list)
     */
    handleNavigateToOriginalMessage(event) {
        const messageId = event.currentTarget.dataset.messageId;
        if (!messageId) {
            return;
        }
        
        // Find the message element in the DOM
        const messageElement = this.template.querySelector(`[data-message-id="${messageId}"]`);
        if (messageElement) {
            messageElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
            // Highlight the message briefly
            messageElement.classList.add('message-highlight');
            setTimeout(() => {
                messageElement.classList.remove('message-highlight');
            }, 2000);
        }
    }
    
    /**
     * @description Handle pin/unpin message
     */
    async handlePinMessage(event) {
        const messageId = event.currentTarget.dataset.messageId;
        const message = this._messages.find(m => m.id === messageId);
        
        if (!message || !messageId) {
            return;
        }
        
        const isPinned = !message.isPinned;
        
        try {
            await pinMessage({ 
                messageId: messageId,
                isPinned: isPinned
            });
            
            // Refresh messages
            await this.loadMessages();
            
            // Publish message update to notify other components
            this.publishMessageUpdate(isPinned ? 'pinned' : 'unpinned');
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: isPinned ? 'Message pinned successfully' : 'Message unpinned successfully',
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error pinning message:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to ' + (isPinned ? 'pin' : 'unpin') + ' message: ' + (error.body?.message || error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }
    
    /**
     * @description Handle delete message
     */
    async handleDeleteMessage(event) {
        const messageId = event.currentTarget.dataset.messageId;
        
        if (!messageId) {
            return;
        }
        
        // Confirm deletion
        if (!confirm('Are you sure you want to delete this message? This action cannot be undone.')) {
            return;
        }
        
        try {
            await deleteMessage({ messageId: messageId });
            
            // Refresh messages
            await this.loadMessages();
            
            // Publish message update to notify other components
            this.publishMessageUpdate('deleted');
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Message deleted successfully',
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error deleting message:', JSON.stringify(error, Object.getOwnPropertyNames(error), 2));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to delete message: ' + (error.body?.message || error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }
}

