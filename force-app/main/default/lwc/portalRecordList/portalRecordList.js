import { api, LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { getListUi } from 'lightning/uiListApi';

export default class PortalRecordList extends LightningElement {
    @api objectApiName;
    @api filterName;

    listViewData;
    error;
    columns = [];

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

        // Fallback: parse the URL path directly for /project-task/:objectApiName/:filterName
        if ((!this.objectApiName || !this.filterName) && typeof window !== 'undefined') {
            const pathParts = window.location.pathname.split('/').filter(Boolean);

            // Look for a known route segment; otherwise, just use the last two parts.
            const routeIndex = pathParts.indexOf('project-task');
            const objectIndex = routeIndex !== -1 ? routeIndex + 1 : pathParts.length - 2;
            const filterIndex = routeIndex !== -1 ? routeIndex + 2 : pathParts.length - 1;

            if (objectIndex >= 0 && filterIndex >= 0 && filterIndex < pathParts.length) {
                this.objectApiName = this.objectApiName || decodeURIComponent(pathParts[objectIndex]);
                this.filterName = this.filterName || decodeURIComponent(pathParts[filterIndex]);
            }
        }
    }

    @wire(getListUi, {
        objectApiName: '$objectApiName',
        listViewApiName: '$filterName',
        pageSize: 10
    })
    wiredListView({ error, data }) {
        if (data) {
            this.listViewData = data;
            this.error = undefined;
            // Extract columns from list view metadata
            if (data.info && data.info.displayColumns) {
                this.columns = data.info.displayColumns.map(col => ({
                    label: col.label,
                    fieldName: col.fieldApiName || col.fieldName,
                    type: col.type || 'text',
                    sortable: col.sortable !== false
                }));
            }
        } else if (error) {
            this.error = error;
            this.listViewData = undefined;
        }
    }

    get isReady() {
        return Boolean(this.objectApiName && this.filterName);
    }

    get records() {
        return this.listViewData?.records?.records || [];
    }

    get hasData() {
        return this.records && this.records.length > 0;
    }

    get errorMessage() {
        if (!this.error) return '';
        return this.error.body?.message || this.error.message || 'Unknown error';
    }
}
