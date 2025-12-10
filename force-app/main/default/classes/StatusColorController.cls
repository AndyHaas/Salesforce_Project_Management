/**
 * @description Shared controller for status color utilities
 * Used by both portal and main Salesforce components
 */
public without sharing class StatusColorController {
    
    /**
     * @description Get status colors from Status__c field metadata
     * Returns a map of status values to their chart colors
     * 
     * NOTE: Chart colors are stored in the field metadata XML but are not directly
     * accessible via the standard Schema API. This method returns colors that match
     * the chart colors defined in Status__c.field-meta.xml.
     * 
     * When the field metadata is updated (via Salesforce UI or CLI), this method
     * should be updated to reflect the new colors, or enhanced to use Metadata API
     * for true dynamic retrieval.
     * 
     * @return Map<String, String> Status value to color hex code
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getStatusColors() {
        // Chart colors from Status__c.field-meta.xml
        // These match the colors defined in the field metadata
        // When the field metadata is updated, update this map to match
        Map<String, String> statusColors = new Map<String, String>{
            'Backlog' => '#E5E5E5',
            'Pending' => '#FFB75D',
            'In Progress' => '#0176D3',
            'In Review' => '#5B21B6',
            'Blocked' => '#C23934',
            'Completed' => '#2E844A',
            'Removed' => '#706E6B',
            'Closed' => '#2E844A'
        };
        
        // TODO: Enhance this method to use Metadata API or Tooling API
        // to dynamically retrieve colors from the field metadata XML
        // This would make it truly dynamic without code changes
        
        return statusColors;
    }
}
