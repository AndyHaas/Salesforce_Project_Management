import { api, LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getRecords from '@salesforce/apex/PortalRecordListController.getRecords';

const DEBUG = true;

export default class PortalRecordList extends LightningElement {
    @api objectApiName;
    @api filterName;

    recordListData;
    error;
    columns = [];
    objectInfo;
    hasObjectAccess = false;
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
        
        // If objectInfo has loaded and shows no access, deny
        if (this.objectInfo && this.objectInfo.permissions && !this.hasObjectAccess) {
            return false;
        }
        
        // Otherwise, allow (objectInfo might still be loading, Salesforce API will enforce permissions)
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
                
                // Only include fields that the user has access to (if objectInfo is loaded)
                if (!this.objectInfo || this.isFieldAccessible(fieldApiName)) {
                    filteredRecord[fieldApiName] = record[fieldApiName];
                }
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

    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredObjectInfo({ error, data }) {
        if (data) {
            this.objectInfo = data;
            // Check object-level read permission
            this.hasObjectAccess = data.permissions?.readable === true;
            if (!this.hasObjectAccess) {
                this.accessDenied = true;
                this.error = { message: 'Access denied' };
            }
            this.logDebug('Object info loaded', {
                objectApiName: this.objectApiName,
                hasObjectAccess: this.hasObjectAccess
            });
        } else if (error) {
            // Don't expose detailed error messages
            this.accessDenied = true;
            this.error = { message: 'Access denied' };
            this.logDebug('Error loading object info', {
                objectApiName: this.objectApiName,
                rawError: error
            });
        }
    }

    get cardTitle() {
        // Don't expose object information if access is denied
        if (this.accessDenied) {
            return 'Access Denied';
        }

        // Use object label from objectInfo if available
        if (this.objectInfo?.label && this.hasObjectAccess) {
            return this.objectInfo.label;
        }

        // Try object label from record list data if available
        if (this.recordListData?.objectApiName && this.hasObjectAccess) {
            // Use objectInfo label if available
            if (this.objectInfo?.label) {
                return this.objectInfo.label;
            }
        }

        // Fallback: convert API name to readable format (only if we have access)
        if (this.objectApiName && this.hasObjectAccess) {
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
     * @description Check if a field is accessible to the current user
     * @param {string} fieldApiName - Field API name to check
     * @returns {boolean} True if field is accessible
     */
    isFieldAccessible(fieldApiName) {
        if (!fieldApiName || !this.objectInfo?.fields) {
            return false;
        }
        
        const field = this.objectInfo.fields[fieldApiName];
        // Field must exist and be accessible
        return field?.accessible === true;
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
