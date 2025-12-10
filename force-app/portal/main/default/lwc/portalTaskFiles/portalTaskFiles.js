import { LightningElement, api, wire } from 'lwc';
import getTaskFiles from '@salesforce/apex/PortalTaskController.getTaskFiles';

export default class PortalTaskFiles extends LightningElement {
    @api recordId;
    
    _files = [];
    _filesError = null;
    
    // Wire service to get files for the task
    @wire(getTaskFiles, { taskId: '$recordId' })
    wiredTaskFiles({ error, data }) {
        if (data) {
            this._files = data || [];
            this._filesError = null;
        } else if (error) {
            console.error('Error loading task files:', error);
            this._files = [];
            this._filesError = error;
        }
    }
    
    /**
     * @description Get files for display
     */
    get files() {
        if (!this._files || this._files.length === 0) {
            return [];
        }
        
        return this._files.map(file => ({
            ...file,
            downloadUrl: `/sfc/servlet.shepherd/document/download/${file.versionId}`,
            formattedSize: this.formatFileSize(file.size),
            formattedDate: this.formatFileDate(file.createdDate)
        }));
    }
    
    get hasFiles() {
        return this._files && this._files.length > 0;
    }
    
    get filesCount() {
        return this._files ? this._files.length : 0;
    }
    
    /**
     * @description Format file size for display
     */
    formatFileSize(bytes) {
        if (!bytes || bytes === 0) {
            return '0 B';
        }
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
    }
    
    /**
     * @description Format file date for display
     */
    formatFileDate(dateValue) {
        if (!dateValue) {
            return '';
        }
        const date = new Date(dateValue);
        return date.toLocaleDateString('en-US', { 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric' 
        });
    }
}
