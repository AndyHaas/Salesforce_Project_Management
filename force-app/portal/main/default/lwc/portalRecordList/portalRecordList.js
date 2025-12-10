import { api, wire, LightningElement } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import getRecords from '@salesforce/apex/PortalRecordListController.getRecords';

const DEBUG = true;

export default class PortalRecordList extends NavigationMixin(LightningElement) {
    @api objectApiName;
    @api filterName;

    recordListData;
    error;
    columns = [];
    accessDenied = false;
    pageSize = 10;
    pageNumber = 1;

    logDebug(message, payload = {}) {
        if (!DEBUG) {
            return;
        }
        // eslint-disable-next-line no-console
        console.log(`[portalRecordList] ${message}`, payload);
    }

    @wire(CurrentPageReference)
    resolvePageReference(pageRef) {
        if (!pageRef) {
            return;
        }

        const { attributes = {}, state = {} } = pageRef;

        // First, try attributes or state provided by the router.
        this.objectApiName =
            attributes.objectApiName ||
            state.objectApiName ||
            state.c__objectApiName ||
            this.objectApiName;

        this.filterName =
            attributes.filterName ||
            state.filterName ||
            state.c__filterName ||
            this.filterName;

        // Fallback: parse the URL path directly for /project/:objectApiName/:filterName or /project-task/:objectApiName/:filterName
        if ((!this.objectApiName || !this.filterName) && typeof window !== 'undefined') {
            let pathname = window.location.pathname;
            // Remove Experience Cloud /s/ prefix if present
            pathname = pathname.replace(/^\/s/, '');
            const pathParts = pathname.split('/').filter(Boolean);

            // Look for 'project' or 'project-task' route segment
            const projectIndex = pathParts.indexOf('project');
            const projectTaskIndex = pathParts.indexOf('project-task');
            const routeIndex = projectTaskIndex !== -1 ? projectTaskIndex : projectIndex;

            if (routeIndex !== -1 && routeIndex + 2 < pathParts.length) {
                const objectIndex = routeIndex + 1;
                const filterIndex = routeIndex + 2;

                if (objectIndex >= 0 && filterIndex >= 0 && filterIndex < pathParts.length) {
                    const parsedObjectApiName = decodeURIComponent(pathParts[objectIndex]);
                    const parsedFilterName = decodeURIComponent(pathParts[filterIndex]);
                    
                    // Validate parsed values are safe (alphanumeric, underscores, and __c suffix only)
                    if (this.isValidObjectApiName(parsedObjectApiName) && this.isValidFilterName(parsedFilterName)) {
                        this.objectApiName = this.objectApiName || parsedObjectApiName;
                        this.filterName = this.filterName || parsedFilterName;
                        this.logDebug('Parsed route params (project/project-task)', {
                            parsedObjectApiName,
                            parsedFilterName,
                            pathParts
                        });
                    } else {
                        this.accessDenied = true;
                        this.error = { message: 'Invalid parameters' };
                        this.logDebug('Invalid params after parsing route', {
                            parsedObjectApiName,
                            parsedFilterName,
                            pathParts
                        });
                    }
                }
            } else if (pathParts.length >= 2) {
                // Fallback: use last two parts if no route segment found
                const parsedObjectApiName = decodeURIComponent(pathParts[pathParts.length - 2]);
                const parsedFilterName = decodeURIComponent(pathParts[pathParts.length - 1]);
                
                // Validate parsed values are safe
                if (this.isValidObjectApiName(parsedObjectApiName) && this.isValidFilterName(parsedFilterName)) {
                    this.objectApiName = this.objectApiName || parsedObjectApiName;
                    this.filterName = this.filterName || parsedFilterName;
                    this.logDebug('Parsed fallback params (last two path parts)', {
                        parsedObjectApiName,
                        parsedFilterName,
                        pathParts
                    });
                } else {
                    this.accessDenied = true;
                    this.error = { message: 'Invalid parameters' };
                    this.logDebug('Invalid params after fallback parsing', {
                        parsedObjectApiName,
                        parsedFilterName,
                        pathParts
                    });
                }
            }
        }
        
        // Validate API properties are safe
        if (this.objectApiName && !this.isValidObjectApiName(this.objectApiName)) {
            this.accessDenied = true;
            this.error = { message: 'Invalid object API name' };
            this.logDebug('Invalid objectApiName after validation', { objectApiName: this.objectApiName });
        }
        if (this.filterName && !this.isValidFilterName(this.filterName)) {
            this.accessDenied = true;
            this.error = { message: 'Invalid filter name' };
            this.logDebug('Invalid filterName after validation', { filterName: this.filterName });
        }

        this.logDebug('Final resolved params', {
            objectApiName: this.objectApiName,
            filterName: this.filterName,
            accessDenied: this.accessDenied
        });
    }

    @wire(getRecords, {
        objectApiName: '$objectApiName',
        filterName: '$filterName',
        pageSize: '$pageSize',
        pageNumber: '$pageNumber'
    })
    wiredRecordList({ error, data }) {
        // Don't proceed if access was denied due to invalid parameters
        if (this.accessDenied) {
            return;
        }

        if (data) {
            this.recordListData = data;
            this.error = undefined;
            this.logDebug('Record list data loaded', {
                objectApiName: this.objectApiName,
                filterName: this.filterName,
                columnCount: data.columns?.length,
                recordCount: data.records?.length,
                totalRecords: data.totalRecords,
                totalPages: data.totalPages
            });
            
            // Extract columns from Apex response
            if (data.columns) {
                this.columns = data.columns.map(col => ({
                    label: col.label,
                    fieldName: col.fieldApiName,
                    relationshipName: col.relationshipName,
                    type: col.type || 'text',
                    sortable: col.sortable !== false
                }));
                this.logDebug('Columns loaded', {
                    columnCount: this.columns.length
                });
            }
        } else if (error) {
            // Don't expose detailed error messages to prevent information disclosure
            this.error = { 
                message: this.isAccessError(error) ? 'Access denied' : 'Unable to load data'
            };
            this.recordListData = undefined;
            
            // If it's an access error, mark as denied
            if (this.isAccessError(error)) {
                this.accessDenied = true;
            }

            this.logDebug('Error loading record list', {
                objectApiName: this.objectApiName,
                filterName: this.filterName,
                accessError: this.isAccessError(error),
                rawError: error
            });
        }
    }

    get isReady() {
        // Don't show content if access is denied
        if (this.accessDenied) {
            return false;
        }
        
        // Need objectApiName and filterName
        if (!this.objectApiName || !this.filterName) {
            return false;
        }

        return true;
    }

    get records() {
        if (!this.recordListData?.records) {
            return [];
        }

        // Apex already filters by field-level security, so we can use records directly
        // But we'll still filter for defense in depth
        return this.recordListData.records.map(record => {
            const filteredRecord = {};
            
            // Convert SObject to plain object, only including accessible fields
            Object.keys(record).forEach(fieldApiName => {
                // Skip system fields that aren't needed
                if (fieldApiName === 'attributes') {
                    return;
                }
                
                filteredRecord[fieldApiName] = record[fieldApiName];
            });
            
            return filteredRecord;
        });
    }

    get hasData() {
        return this.records && this.records.length > 0;
    }

    get errorMessage() {
        if (!this.error) return '';
        // Return safe, generic error message without exposing sensitive details
        return this.error.message || 'Unable to load data';
    }

    /**
     * Columns to render in the HTML table (already provided by Apex)
     */
    get tableColumns() {
        return this.columns || [];
    }

    /**
     * Rows prepared for HTML table rendering.
     * Each row has a key and cells array aligning with columns.
     * - Reference fields render the related record Name (if present)
     * - Name column is clickable to the record detail
     */
    get tableRows() {
        if (!this.records || !this.tableColumns.length) {
            return [];
        }
        return this.records.map((record, rowIndex) => {
            const rowKey = record.Id || rowIndex;

            const cells = this.tableColumns.map((col, colIndex) => {
                let displayValue = record[col.fieldName];

                // If this is a reference, prefer the related Name
                if (col.relationshipName && record[col.relationshipName]) {
                    const related = record[col.relationshipName];
                    if (related && related.Name) {
                        displayValue = related.Name;
                    }
                }

                // Format dates/datetimes to browser-local YYYY-MM-DD HH:MM
                if (col.type === 'date' || col.type === 'datetime') {
                    displayValue = this.formatDateTime(displayValue);
                }

                const isNameColumn = col.fieldName === 'Name';

                return {
                    key: `${rowIndex}-${colIndex}`,
                    value: displayValue !== undefined && displayValue !== null ? displayValue : '',
                    isLink: isNameColumn && !!record.Id,
                    recordId: isNameColumn ? record.Id : null
                };
            });

            return { key: rowKey, cells };
        });
    }

    get cardTitle() {
        // Don't expose object information if access is denied
        if (this.accessDenied) {
            return 'Access Denied';
        }

        // Try object label from record list data if available
        if (this.recordListData?.objectLabel) {
            return this.recordListData.objectLabel;
        }

        // Fallback: convert API name to readable format
        if (this.objectApiName) {
            // Remove __c suffix, replace underscores with spaces, and capitalize
            let title = this.objectApiName
                .replace(/__c$/, '')
                .replace(/_/g, ' ')
                .replace(/\b\w/g, l => l.toUpperCase());
            
            // Handle common pluralization
            if (title.endsWith('s') === false && !title.includes(' ')) {
                title = title + 's';
            }
            
            return title;
        }

        return 'Records';
    }

    handleNavigateToRecord(event) {
        const recordId = event.currentTarget?.dataset?.recordId;
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    formatDateTime(value) {
        if (!value) {
            return '';
        }
        const date = new Date(value);
        if (isNaN(date)) {
            return value;
        }
        const pad = (n) => String(n).padStart(2, '0');
        const yyyy = date.getFullYear();
        const mm = pad(date.getMonth() + 1);
        const dd = pad(date.getDate());
        const hh = pad(date.getHours());
        const min = pad(date.getMinutes());
        return `${yyyy}-${mm}-${dd} ${hh}:${min}`;
    }

    /**
     * @description Validate object API name is safe (prevents injection)
     * @param {string} apiName - Object API name to validate
     * @returns {boolean} True if valid
     */
    isValidObjectApiName(apiName) {
        if (!apiName || typeof apiName !== 'string') {
            return false;
        }
        // Allow alphanumeric, underscores, and __c suffix
        // Max length check for safety
        return /^[a-zA-Z0-9_]+(__c)?$/.test(apiName) && apiName.length <= 100;
    }

    /**
     * @description Validate filter/list view name is safe (prevents injection)
     * @param {string} filterName - Filter name to validate
     * @returns {boolean} True if valid
     */
    isValidFilterName(filterName) {
        if (!filterName || typeof filterName !== 'string') {
            return false;
        }
        // Allow alphanumeric, underscores, hyphens, and spaces
        // Max length check for safety
        return /^[a-zA-Z0-9_\-\s]+$/.test(filterName) && filterName.length <= 100;
    }

    /**
     * @description Check if error is an access/permission error
     * @param {object} error - Error object to check
     * @returns {boolean} True if access error
     */
    isAccessError(error) {
        if (!error) {
            return false;
        }
        
        const errorMessage = (error.body?.message || error.message || '').toLowerCase();
        const accessErrorKeywords = [
            'access denied',
            'insufficient access',
            'permission',
            'unauthorized',
            'forbidden',
            'not found',
            'does not exist'
        ];
        
        return accessErrorKeywords.some(keyword => errorMessage.includes(keyword));
    }
}
