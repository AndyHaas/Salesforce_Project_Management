/**
 * @description Account Filter Component
 * 
 * Standalone component for filtering Project Tasks by Account.
 * Uses Lightning Message Service to broadcast filter changes to all
 * dashboard components, allowing them to be placed anywhere on the page.
 * 
 * Features:
 * - Searchable account dropdown
 * - Show/hide toggle
 * - Auto-detects Account record page context
 * - Auto-detects Experience Cloud context
 * - Publishes filter changes via LMS
 * 
 * @component
 */
import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { publish, MessageContext } from 'lightning/messageService';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getAccounts from '@salesforce/apex/ProjectTaskDashboardController.getAccounts';
import getCurrentUserAccountId from '@salesforce/apex/ProjectTaskDashboardController.getCurrentUserAccountId';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import ACCOUNT_FILTER_MESSAGE_CHANNEL from '@salesforce/messageChannel/AccountFilter__c';

export default class AccountFilter extends LightningElement {
    /**
     * @description Record ID if on Account record page (auto-filters to this account)
     * @type {string}
     */
    @api recordId;
    
    /**
     * @description Show/hide toggle for the filter component
     * @type {boolean}
     */
    @api showFilter;
    
    /**
     * @description Message context for LMS
     * @type {MessageContext}
     */
    @wire(MessageContext)
    messageContext;
    
    selectedAccountIds = []; // Array of selected account IDs
    accounts = [];
    filteredAccounts = [];
    searchTerm = '';
    showDropdown = false;
    isLoading = true;
    isCommunity = false;
    _showFilter = true; // Internal state for show/hide
    
    /**
     * @description Wire service to detect Account record page context
     */
    @wire(getRecord, { recordId: '$recordId', fields: [ACCOUNT_OBJECT.Id] })
    wiredAccount({ error, data }) {
        if (data) {
            // We're on an Account record page - auto-filter to this account
            this.selectedAccountIds = [data.id];
            this._showFilter = false; // Hide filter on Account page
            this.isLoading = false;
            this.publishAccountFilter();
        } else if (error) {
            // Not on Account record page
            this.checkCommunityContext();
        }
    }
    
    /**
     * @description Wire service to detect Experience Cloud context
     */
    @wire(getCurrentUserAccountId)
    wiredUserAccount({ error, data }) {
        if (data && !this.recordId) {
            // We're in Experience Cloud and have a user account
            this.selectedAccountIds = [data];
            this._showFilter = false; // Hide filter in Community (auto-filtered)
            this.isCommunity = true;
            this.isLoading = false;
            this.publishAccountFilter();
        } else if (!this.recordId) {
            // We're on Home page, show account filter
            this._showFilter = true;
            this.isLoading = false;
        }
    }
    
    /**
     * @description Component lifecycle hook
     */
    connectedCallback() {
        this.loadAccounts();
    }
    
    /**
     * @description Load accounts for the dropdown
     * @private
     */
    loadAccounts() {
        getAccounts()
            .then(result => {
                this.accounts = result.map(acc => ({
                    label: acc.Name,
                    value: acc.Id
                }));
                // Don't add "All Accounts" option for multi-select
                this.filteredAccounts = [...this.accounts];
            })
            .catch(error => {
                console.error('Error loading accounts:', error);
            });
    }
    
    /**
     * @description Check if we're in Community context
     * @private
     */
    checkCommunityContext() {
        if (!this.recordId && !this.isLoading) {
            this._showFilter = true;
            this.isLoading = false;
        }
    }
    
    /**
     * @description Getter for showFilter (respects @api property and internal state)
     * @returns {boolean} True if filter should be shown
     */
    get shouldShowFilter() {
        // @api property takes precedence if set, otherwise use internal state
        return this.showFilter !== undefined ? this.showFilter : this._showFilter;
    }
    
    /**
     * @description Handle search input change
     * @param {Event} event - Input change event
     */
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.filterAccounts();
        this.showDropdown = true;
    }
    
    /**
     * @description Filter accounts based on search term (exclude already selected)
     * @private
     */
    filterAccounts() {
        if (!this.searchTerm || this.searchTerm.trim() === '') {
            // Filter out already selected accounts
            this.filteredAccounts = this.accounts.filter(acc => 
                !this.selectedAccountIds.includes(acc.value)
            );
        } else {
            const searchLower = this.searchTerm.toLowerCase();
            // Filter by search term and exclude already selected
            this.filteredAccounts = this.accounts.filter(acc => 
                acc.label.toLowerCase().includes(searchLower) &&
                !this.selectedAccountIds.includes(acc.value)
            );
        }
    }
    
    /**
     * @description Handle account selection from dropdown
     * @param {Event} event - Click event
     */
    handleAccountSelect(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const selectedValue = event.currentTarget.dataset.value;
        const selectedAccount = this.accounts.find(acc => acc.value === selectedValue);
        
        if (selectedAccount && !this.selectedAccountIds.includes(selectedValue)) {
            // Add to selected accounts
            this.selectedAccountIds = [...this.selectedAccountIds, selectedValue];
            this.searchTerm = ''; // Clear search term
            this.showDropdown = false;
            this.filterAccounts(); // Update filtered list
            this.publishAccountFilter();
        }
    }
    
    /**
     * @description Handle removing a selected account
     * @param {Event} event - Click event
     */
    handleRemoveAccount(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const accountIdToRemove = event.currentTarget.dataset.accountId;
        this.selectedAccountIds = this.selectedAccountIds.filter(id => id !== accountIdToRemove);
        this.filterAccounts(); // Update filtered list to show removed account
        this.publishAccountFilter();
    }
    
    /**
     * @description Handle clearing all selected accounts
     */
    handleClearAll() {
        this.selectedAccountIds = [];
        this.filterAccounts();
        this.publishAccountFilter();
    }
    
    /**
     * @description Handle input focus to show dropdown
     */
    handleInputFocus() {
        this.showDropdown = true;
        this.filterAccounts();
    }
    
    /**
     * @description Handle input blur to hide dropdown (with delay)
     */
    handleInputBlur() {
        // Delay to allow click events to fire first
        setTimeout(() => {
            this.showDropdown = false;
        }, 200);
    }
    
    /**
     * @description Publish account filter change via Lightning Message Service
     * @private
     */
    publishAccountFilter() {
        if (this.messageContext) {
            const payload = {
                accountIds: this.selectedAccountIds || [],
                accountId: this.selectedAccountIds.length === 1 ? this.selectedAccountIds[0] : (this.selectedAccountIds.length === 0 ? '' : null) // For backward compatibility
            };
            publish(this.messageContext, ACCOUNT_FILTER_MESSAGE_CHANNEL, payload);
        }
    }
    
    /**
     * @description Getter for filtered accounts empty state
     * @returns {boolean} True if no accounts match search
     */
    get filteredAccountsEmpty() {
        return this.filteredAccounts.length === 0;
    }
    
    /**
     * @description Getter for selected accounts with labels
     * @returns {Array} Array of selected account objects with id and label
     */
    get selectedAccounts() {
        return this.selectedAccountIds.map(id => {
            const account = this.accounts.find(acc => acc.value === id);
            return {
                id: id,
                label: account ? account.label : id
            };
        });
    }
    
    /**
     * @description Getter for whether any accounts are selected
     * @returns {boolean} True if accounts are selected
     */
    get hasSelectedAccounts() {
        return this.selectedAccountIds.length > 0;
    }
}

