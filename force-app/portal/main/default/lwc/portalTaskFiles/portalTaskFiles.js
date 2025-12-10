import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTaskFiles from '@salesforce/apex/PortalTaskController.getTaskFiles';
import linkFilesToTask from '@salesforce/apex/PortalTaskController.linkFilesToTask';
import linkRecentFilesToTask from '@salesforce/apex/PortalTaskController.linkRecentFilesToTask';
import deleteFile from '@salesforce/apex/PortalTaskController.deleteFile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { ensureSitePath } from 'c/portalCommon';

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
        
        if (!uploadedFiles || uploadedFiles.length === 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'No files were uploaded',
                    variant: 'error'
                })
            );
            return;
        }
        
        // Extract contentVersionIds - check different possible property names
        const contentVersionIds = uploadedFiles
            .map(file => {
                // Try different possible property names
                return file.contentVersionId || file.documentId || file.id || file.versionId;
            })
            .filter(id => id);
        
        if (contentVersionIds.length === 0) {
            // Try fallback method - link recent files
            try {
                const linkedIds = await linkRecentFilesToTask({ taskId: this.recordId });
                
                if (linkedIds && linkedIds.length > 0) {
                    await refreshApex(this._wiredTaskFilesResult);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: `${linkedIds.length} file(s) uploaded and linked successfully`,
                            variant: 'success'
                        })
                    );
                } else {
                    await refreshApex(this._wiredTaskFilesResult);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Warning',
                            message: 'Files uploaded but could not be automatically linked. Please refresh the page.',
                            variant: 'warning'
                        })
                    );
                }
            } catch (fallbackError) {
                console.error('Error linking files:', fallbackError);
                await refreshApex(this._wiredTaskFilesResult);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Files uploaded but could not be linked. Please contact support.',
                        variant: 'error'
                    })
                );
            }
            return;
        }
        
        try {
            const result = await linkFilesToTask({ 
                taskId: this.recordId, 
                contentVersionIds: contentVersionIds 
            });
            
            // Refresh the file list
            await refreshApex(this._wiredTaskFilesResult);
            
            // Show success toast
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `${contentVersionIds.length} file(s) uploaded and linked successfully`,
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error linking files to task:', error);
            
            // Try fallback method
            try {
                const linkedIds = await linkRecentFilesToTask({ taskId: this.recordId });
                
                await refreshApex(this._wiredTaskFilesResult);
                
                if (linkedIds && linkedIds.length > 0) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: `${linkedIds.length} file(s) uploaded and linked successfully`,
                            variant: 'success'
                        })
                    );
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Warning',
                            message: 'Files uploaded but could not be linked. Please refresh the page.',
                            variant: 'warning'
                        })
                    );
                }
            } catch (fallbackError) {
                console.error('Fallback also failed:', fallbackError);
                await refreshApex(this._wiredTaskFilesResult);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to link files: ' + (error.body?.message || error.message || 'Unknown error'),
                        variant: 'error'
                    })
                );
            }
        }
    }
    
    /**
     * @description Handle file upload errors
     */
    handleUploadError(event) {
        const error = event.detail;
        console.error('File upload error:', error);
        
        let errorMessage = 'Failed to upload file';
        if (error && error.message) {
            errorMessage = error.message;
        } else if (error && typeof error === 'string') {
            errorMessage = error;
        }
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Upload Error',
                message: errorMessage,
                variant: 'error'
            })
        );
    }
    
    /**
     * @description Get files for display
     */
    get files() {
        if (!this._files || this._files.length === 0) {
            return [];
        }
        
        return this._files.map(file => {
            // Use the correct download URL format for Experience Cloud
            // The URL should use version/download endpoint with ContentVersion ID
            const baseUrl = `/sfc/servlet.shepherd/version/download/${file.versionId}`;
            const downloadUrl = ensureSitePath(baseUrl, { 
                currentPathname: window.location.pathname 
            });
            
            return {
                ...file,
                downloadUrl: downloadUrl,
                formattedSize: this.formatFileSize(file.size),
                formattedDate: this.formatFileDate(file.createdDate)
            };
        });
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
    
    /**
     * @description Handle file deletion
     */
    async handleDeleteFile(event) {
        const fileId = event.currentTarget.dataset.fileId;
        const fileName = event.currentTarget.dataset.fileName;
        
        if (!fileId) {
            return;
        }
        
        // Confirm deletion
        if (!confirm(`Are you sure you want to delete "${fileName}"?`)) {
            return;
        }
        
        try {
            await deleteFile({ contentDocumentId: fileId });
            
            // Refresh the file list
            await refreshApex(this._wiredTaskFilesResult);
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'File deleted successfully',
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error deleting file:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to delete file: ' + (error.body?.message || error.message || 'Unknown error'),
                    variant: 'error'
                })
            );
        }
    }
}
