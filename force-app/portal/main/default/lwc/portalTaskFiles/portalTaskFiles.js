import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTaskFiles from '@salesforce/apex/PortalTaskController.getTaskFiles';
import linkFilesToTask from '@salesforce/apex/PortalTaskController.linkFilesToTask';
import linkRecentFilesToTask from '@salesforce/apex/PortalTaskController.linkRecentFilesToTask';
import deleteFile from '@salesforce/apex/PortalTaskController.deleteFile';
import getFilePreviewUrl from '@salesforce/apex/PortalTaskController.getFilePreviewUrl';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { ensureSitePath } from 'c/portalCommon';

export default class PortalTaskFiles extends LightningElement {
    @api recordId;
    
    _files = [];
    _filesError = null;
    _wiredTaskFilesResult;
    _previewFile = null;
    _showPreview = false;
    
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
            // Format: /sfc/servlet.shepherd/document/download/{ContentDocumentId}
            const baseUrl = `/sfc/servlet.shepherd/document/download/${file.id}`;
            const downloadUrl = ensureSitePath(baseUrl, { 
                currentPathname: window.location.pathname 
            });
            
            // For preview, we'll use ContentDistribution for PDFs and images
            // The preview URL will be generated on-demand when the preview button is clicked
            // For now, set a placeholder that will be replaced
            let previewUrl = downloadUrl;
            // Preview URL will be generated via ContentDistribution when preview is clicked for PDFs and images
            
            // Determine if file can be previewed
            const canPreview = this.isPreviewable(file.extension);
            
            return {
                ...file,
                downloadUrl: downloadUrl,
                previewUrl: previewUrl,
                formattedSize: this.formatFileSize(file.size),
                formattedDate: this.formatFileDate(file.createdDate),
                canPreview: canPreview
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
     * @description Check if a file type can be previewed
     */
    isPreviewable(extension) {
        if (!extension) {
            return false;
        }
        
        const ext = extension.toLowerCase();
        const previewableTypes = [
            'pdf',
            'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'
        ];
        
        return previewableTypes.includes(ext);
    }
    
    /**
     * @description Get preview URL for a file using renditionDownload endpoint
     */
    getPreviewUrl(file) {
        if (!file || !file.versionId) {
            return null;
        }
        
        const ext = (file.extension || '').toLowerCase();
        
        // Use renditionDownload endpoint with appropriate rendition parameter
        if (ext === 'pdf') {
            // For PDFs, use PDF rendition
            const renditionUrl = `/sfc/servlet.shepherd/version/renditionDownload?versionId=${file.versionId}&rendition=PDF`;
            return ensureSitePath(renditionUrl, { 
                currentPathname: window.location.pathname 
            });
        } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].includes(ext)) {
            // For images, use SVGZ rendition
            const renditionUrl = `/sfc/servlet.shepherd/version/renditionDownload?versionId=${file.versionId}&rendition=SVGZ`;
            return ensureSitePath(renditionUrl, { 
                currentPathname: window.location.pathname 
            });
        } else if (ext === 'svg') {
            // For SVG files, use SVGZ rendition
            const renditionUrl = `/sfc/servlet.shepherd/version/renditionDownload?versionId=${file.versionId}&rendition=SVGZ`;
            return ensureSitePath(renditionUrl, { 
                currentPathname: window.location.pathname 
            });
        } else {
            // For other files, try PDF rendition
            const renditionUrl = `/sfc/servlet.shepherd/version/renditionDownload?versionId=${file.versionId}&rendition=PDF`;
            return ensureSitePath(renditionUrl, { 
                currentPathname: window.location.pathname 
            });
        }
    }
    
    /**
     * @description Handle file name click - opens preview if previewable, otherwise downloads
     */
    async handleFileClick(event) {
        const fileId = event.currentTarget.dataset.fileId;
        const file = this.files.find(f => f.id === fileId);
        
        if (!file) {
            return;
        }
        
        // Check if file is previewable using isPreviewable method
        const isPreviewable = this.isPreviewable(file.extension);
        
        // Only open preview if file is previewable
        if (isPreviewable && file.canPreview) {
            // Create a synthetic event for handlePreviewFile
            const syntheticEvent = {
                currentTarget: {
                    dataset: {
                        fileId: fileId
                    }
                }
            };
            await this.handlePreviewFile(syntheticEvent);
        } else {
            // Download non-previewable files directly
            window.open(file.downloadUrl, '_blank');
        }
    }
    
    /**
     * @description Handle download button click
     */
    handleDownloadFile(event) {
        const downloadUrl = event.currentTarget.dataset.fileUrl;
        if (downloadUrl) {
            window.open(downloadUrl, '_blank');
        }
    }
    
    /**
     * @description Handle file preview
     */
    async handlePreviewFile(event) {
        const fileId = event.currentTarget.dataset.fileId;
        
        // Find file from the mapped files array (which includes canPreview flag)
        const file = this.files.find(f => f.id === fileId);
        
        if (file && file.canPreview) {
            // Set the file first
            this._previewFile = file;
            this._showPreview = true;
            
            // For files that need ContentDistribution (PDFs, images, and Office docs),
            // get the public preview URL
            const ext = (file.extension || '').toLowerCase();
            const needsContentDistribution = ext === 'pdf' || 
                ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(ext) ||
                ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].includes(ext);
            
            if (file.versionId && needsContentDistribution) {
                try {
                    const previewUrl = await getFilePreviewUrl({ contentVersionId: file.versionId });
                    // Update the preview file with the new URL
                    this._previewFile = {
                        ...this._previewFile,
                        previewUrl: previewUrl
                    };
                } catch (error) {
                    console.error('Error getting preview URL:', error);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Preview Error',
                            message: 'Unable to generate preview URL. Please try downloading the file.',
                            variant: 'warning'
                        })
                    );
                }
            }
        }
    }
    
    /**
     * @description Close preview modal
     */
    handleClosePreview() {
        this._showPreview = false;
        this._previewFile = null;
    }
    
    /**
     * @description Get preview file data
     */
    get previewFile() {
        return this._previewFile;
    }
    
    /**
     * @description Get preview URL for current preview file
     */
    get previewUrl() {
        if (!this._previewFile) {
            return null;
        }
        // Use the previewUrl that was already generated (either from getter or ContentDistribution)
        // Fallback to downloadUrl or generate one
        return this._previewFile.previewUrl || this._previewFile.downloadUrl || this.getPreviewUrl(this._previewFile);
    }
    
    /**
     * @description Check if preview should be shown
     */
    get showPreview() {
        return this._showPreview && this._previewFile;
    }
    
    /**
     * @description Get preview file type (for rendering logic)
     */
    get previewFileType() {
        if (!this._previewFile || !this._previewFile.extension) {
            return 'unknown';
        }
        
        const ext = this._previewFile.extension.toLowerCase();
        
        if (ext === 'pdf') {
            return 'pdf';
        } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(ext)) {
            return 'image';
        }
        
        return 'unknown';
    }
    
    /**
     * @description Check if preview is PDF
     */
    get isPdfPreview() {
        return this.previewFileType === 'pdf';
    }
    
    /**
     * @description Check if preview is image
     */
    get isImagePreview() {
        return this.previewFileType === 'image';
    }
    
    
    /**
     * @description Check if using ContentDistribution URL (for images and PDFs)
     */
    get isContentDistributionUrl() {
        if (!this._previewFile || !this._previewFile.previewUrl) {
            return false;
        }
        // ContentDistribution URLs typically contain 'contentdistribution' or are external URLs
        const url = this._previewFile.previewUrl.toLowerCase();
        return url.includes('contentdistribution') || url.includes('http://') || url.includes('https://');
    }
    
    /**
     * @description Handle download from preview modal
     */
    handleDownloadFromPreview() {
        if (this._previewFile && this._previewFile.downloadUrl) {
            window.open(this._previewFile.downloadUrl, '_blank');
        }
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
