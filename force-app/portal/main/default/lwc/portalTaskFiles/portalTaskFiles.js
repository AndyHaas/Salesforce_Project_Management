import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTaskFiles from '@salesforce/apex/PortalTaskController.getTaskFiles';
import linkFilesToTask from '@salesforce/apex/PortalTaskController.linkFilesToTask';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PortalTaskFiles extends LightningElement {
    @api recordId;
    
    _files = [];
    _filesError = null;
    _wiredTaskFilesResult;
    
    // Wire service to get files for the task
    @wire(getTaskFiles, { taskId: '$recordId' })
    wiredTaskFiles(result) {
        this._wiredTaskFilesResult = result;
        const { error, data } = result;
        
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
     * @description Handle file upload finished
     */
    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        
        if (uploadedFiles && uploadedFiles.length > 0) {
            const contentVersionIds = uploadedFiles.map(file => file.contentVersionId);
            
            try {
                await linkFilesToTask({ 
                    taskId: this.recordId, 
                    contentVersionIds: contentVersionIds 
                });
                
                // Refresh the file list
                await refreshApex(this._wiredTaskFilesResult);
                
                // Show success toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: `${uploadedFiles.length} file(s) uploaded successfully`,
                        variant: 'success'
                    })
                );
            } catch (error) {
                console.error('Error linking files to task:', error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to link files to task: ' + (error.body?.message || error.message),
                        variant: 'error'
                    })
                );
            }
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
     * @description Accepted file formats for upload
     */
    get acceptedFormats() {
        return '.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.jpg,.jpeg,.png,.gif,.zip,.rar';
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
