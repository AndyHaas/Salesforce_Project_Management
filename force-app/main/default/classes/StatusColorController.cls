/**
 * @description Shared controller for status color utilities
 * Used by both portal and main Salesforce components
 * Returns status colors that match the values defined in Status__c.field-meta.xml
 */
public without sharing class StatusColorController {
    
    /**
     * @description Get status colors from Status__c field metadata
     * Returns colors that match the chart colors defined in Project_Task__c.Status__c.field-meta.xml
     * 
     * NOTE: These values are hardcoded to match the field metadata.
     * When the field metadata is updated, this method should be updated to reflect the new colors.
     * 
     * @return Map<String, String> Status value to color hex code
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getStatusColors() {
        // Chart colors from Project_Task__c.Status__c.field-meta.xml
        // These match the colors defined in the field metadata
        // When the field metadata is updated, update this map to match
        return new Map<String, String>{
            'Backlog' => '#E5E5E5',
            'Pending' => '#FFB75D',
            'In Progress' => '#0176D3',
            'In Review' => '#5B21B6',
            'Blocked' => '#C23934',
            'Completed' => '#2E844A',
            'Removed' => '#706E6B'
        };
    }
}
