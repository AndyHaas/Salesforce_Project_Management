/**
 * @description Controller to retrieve user's Display Density preference from Salesforce
 * Uses the User Interface API to get the active theme's display density setting
 */
public without sharing class DisplayDensityController {
    /**
     * @description Retrieves the current user's Display Density preference
     * @return String - 'Comfy' or 'Compact' (defaults to 'Comfy' if unable to retrieve)
     */
    @AuraEnabled(cacheable=true)
    public static String getDisplayDensity() {
        try {
            HttpRequest request = new HttpRequest();
            // Use the User Interface API to get the active theme
            // Construct the endpoint using OrgDomainUrl (available in API 58.0+)
            String baseUrl = Url.getOrgDomainUrl().toExternalForm();
            String endpoint = baseUrl + '/services/data/v65.0/ui-api/themes/active';
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            request.setTimeout(10000); // 10 second timeout

            Http http = new Http();
            HttpResponse response = http.send(request);

            if (response.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String density = (String) result.get('density');
                // Return lowercase to match our component's expectations
                if (density != null) {
                    return density.toLowerCase();
                }
            }
            // Default to 'comfy' if we can't retrieve the setting
            return 'comfy';
        } catch (Exception e) {
            // Log error but don't throw - default to 'comfy'
            System.debug('Error retrieving display density: ' + e.getMessage());
            return 'comfy';
        }
    }
}

