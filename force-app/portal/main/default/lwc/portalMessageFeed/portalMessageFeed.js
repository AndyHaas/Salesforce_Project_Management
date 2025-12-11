import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { MessageContext, subscribe, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import { ensureSitePath } from 'c/portalCommon';
import getLatestMessages from '@salesforce/apex/PortalMessagingController.getLatestMessages';
import MESSAGE_UPDATE_CHANNEL from '@salesforce/messageChannel/MessageUpdate__c';

export default class PortalMessageFeed extends NavigationMixin(LightningElement) {
    @api recipientType = 'Client';
    @api limitCount = 5;
    @api orderByField = 'CreatedDate';
    @api orderDirection = 'DESC';
    @api showContext = false;
    @api showHeader = false;

    _relatedAccountId;
    _relatedProjectId;
    _relatedTaskId;

    @track messages = [];
    isLoading = false;
    _hasConnected = false;
    _messageSubscription;

    _messageContext;

    @wire(MessageContext)
    wiredMessageContext(value) {
        this._messageContext = value;
        this.subscribeToUpdates();
    }

    @api
    get relatedAccountId() {
        return this._relatedAccountId;
    }
    set relatedAccountId(value) {
        this._relatedAccountId = value;
        this.refreshIfReady();
    }

    @api
    get relatedProjectId() {
        return this._relatedProjectId;
    }
    set relatedProjectId(value) {
        this._relatedProjectId = value;
        this.refreshIfReady();
    }

    @api
    get relatedTaskId() {
        return this._relatedTaskId;
    }
    set relatedTaskId(value) {
        this._relatedTaskId = value;
        this.refreshIfReady();
    }

    connectedCallback() {
        this._hasConnected = true;
        this.loadMessages();
        this.subscribeToUpdates();
    }

    disconnectedCallback() {
        if (this._messageSubscription) {
            unsubscribe(this._messageSubscription);
            this._messageSubscription = null;
        }
    }

    refreshIfReady() {
        if (this._hasConnected) {
            this.loadMessages();
        }
    }

    subscribeToUpdates() {
        if (this._messageSubscription || !this._messageContext) {
            return;
        }

        this._messageSubscription = subscribe(
            this._messageContext,
            MESSAGE_UPDATE_CHANNEL,
            (payload) => this.handleMessageUpdate(payload),
            { scope: APPLICATION_SCOPE }
        );
    }

    async handleMessageUpdate(message) {
        if (!message) {
            return;
        }

        const isRelevant =
            (message.relatedAccountId && message.relatedAccountId === this._relatedAccountId) ||
            (message.relatedProjectId && message.relatedProjectId === this._relatedProjectId) ||
            (message.relatedTaskId && message.relatedTaskId === this._relatedTaskId) ||
            (!message.relatedAccountId && !message.relatedProjectId && !message.relatedTaskId);

        if (isRelevant) {
            await this.loadMessages();
        }
    }

    async loadMessages() {
        this.isLoading = true;
        try {
            const data = await getLatestMessages({
                limitCount: this.limitCount
            });

            this.messages = data || [];
        } catch (error) {
            console.error('Error loading message feed:', error);
            this.messages = [];
        } finally {
            this.isLoading = false;
        }
    }

    get hasMessages() {
        return this.messages && this.messages.length > 0;
    }

    get containerClass() {
        return this.showHeader ? 'message-feed' : 'message-feed embed';
    }

    get formattedMessages() {
        if (!this.messages) {
            return [];
        }

        return this.messages.map((msg) => ({
            ...msg,
            formattedDate: this.formatMessageDate(msg.createdDate),
            preview: this.stripHtmlPreview(msg.body || '')
        }));
    }

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

        if (diffMins < 1) {
            return 'Just now';
        } else if (diffMins < 60) {
            return `${diffMins}m ago`;
        } else if (diffHours < 24) {
            return `${diffHours}h ago`;
        } else if (diffDays < 7) {
            return `${diffDays}d ago`;
        } else {
            return date.toLocaleDateString();
        }
    }

    stripHtmlPreview(html) {
        if (!html) {
            return '';
        }
        const tmp = document.createElement('DIV');
        tmp.innerHTML = html;
        let text = tmp.textContent || tmp.innerText || '';
        if (text.length > 120) {
            text = text.substring(0, 120) + '...';
        }
        return text;
    }

    handleMessageClick(event) {
        const taskId = event.currentTarget.dataset.taskId;
        if (taskId) {
            this.navigateToUrl(`/project-task/${taskId}`);
        }
    }

    navigateToUrl(url) {
        const targetUrl = ensureSitePath(url, { currentPathname: window.location.pathname });
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: targetUrl
            }
        });
    }
}

