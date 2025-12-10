/**
 * @description Apex controller for Portal Record List component
 * 
 * Provides @AuraEnabled methods for retrieving records based on object API name
 * and list view filter name. Designed for Experience Cloud users.
 */
public without sharing class PortalRecordListController {
    
    /**
     * @description Get records for a list view
     * @param objectApiName API name of the object
     * @param filterName List view filter name
     * @param pageSize Number of records per page
     * @param pageNumber Page number (1-based)
     * @return RecordListResult with records, columns, and metadata
     */
    @AuraEnabled(cacheable=true)
    public static RecordListResult getRecords(String objectApiName, String filterName, Integer pageSize, Integer pageNumber) {
        if (String.isBlank(objectApiName) || String.isBlank(filterName)) {
            throw new AuraHandledException('Object API name and filter name are required');
        }
        
        // Validate object API name to prevent injection
        if (!isValidObjectApiName(objectApiName)) {
            throw new AuraHandledException('Invalid object API name');
        }
        
        // Validate filter name to prevent injection
        if (!isValidFilterName(filterName)) {
            throw new AuraHandledException('Invalid filter name');
        }
        
        RecordListResult result = new RecordListResult();
        result.objectApiName = objectApiName;
        result.filterName = filterName;
        result.pageSize = pageSize != null ? pageSize : 10;
        result.pageNumber = pageNumber != null ? pageNumber : 1;
        
        try {
            // Get object describe for label and field metadata
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            if (objType == null) {
                throw new AuraHandledException('Object not found: ' + objectApiName);
            }
            Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
            result.objectLabel = objDescribe.getLabel();

            // Get WHERE clause components
            WhereClauseResult whereResult = getWhereClause(objectApiName, filterName);

            // Get columns from list view metadata or use defaults
            List<String> fieldList = getFieldList(objectApiName, filterName);

            // Build SOQL query with bind variables
            QueryResult queryResult = buildSoqlQuery(objectApiName, fieldList, whereResult, result.pageSize, result.pageNumber);

            // Execute query with bind variables in system mode to avoid community access limits
            List<SObject> records = Database.queryWithBinds(queryResult.soql, queryResult.bindMap, AccessLevel.SYSTEM_MODE);
            result.records = records;
            
            // Get total count
            CountResult countResult = getTotalCount(objectApiName, whereResult);
            result.totalRecords = Database.countQueryWithBinds(countResult.soql, countResult.bindMap, AccessLevel.SYSTEM_MODE);
            result.totalPages = (Integer)Math.ceil((Double)result.totalRecords / result.pageSize);
            
            // Build column metadata
            result.columns = buildColumnMetadata(fieldList, objDescribe);
            
        } catch (Exception e) {
            System.debug('Error in getRecords: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error loading records: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Get WHERE clause based on filter name
     */
    private static WhereClauseResult getWhereClause(String objectApiName, String filterName) {
        WhereClauseResult result = new WhereClauseResult();
        
        // Get current user's account ID for Experience Cloud users
        User currentUser = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        Set<Id> accountIds = new Set<Id>();
        if (currentUser.AccountId != null) {
            accountIds.add(currentUser.AccountId);
        }
        result.accountIds = accountIds;
        
        // Map filter names to WHERE clauses
        Map<String, String> filterMap = getFilterMap(objectApiName);
        String whereClause = filterMap.get(filterName);
        
        if (String.isBlank(whereClause)) {
            // Default: all records
            whereClause = 'Id != null';
        }
        
        // Add account filter for Experience Cloud users if object has Account__c field
        if (!accountIds.isEmpty() && hasAccountField(objectApiName)) {
            if (whereClause == 'Id != null') {
                whereClause = 'Account__c IN :accountIds';
            } else {
                whereClause = 'Account__c IN :accountIds AND (' + whereClause + ')';
            }
        }
        
        result.whereClause = whereClause;
        return result;
    }
    
    /**
     * @description Check if object has Account__c field
     */
    private static Boolean hasAccountField(String objectApiName) {
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
            if (objType == null) {
                return false;
            }
            Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
            return fieldMap.containsKey('Account__c');
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * @description Get filter map for object
     */
    private static Map<String, String> getFilterMap(String objectApiName) {
        Map<String, String> filterMap = new Map<String, String>();
        
        if (objectApiName == 'Project__c') {
            filterMap.put('Open_Projects', 'Invoiced__c = false AND Status__c NOT IN (\'Not Started\', \'R&D\', \'Proposal\', \'Deployed\', \'Cancelled\')');
            filterMap.put('All', 'Id != null');
        } else if (objectApiName == 'Project_Task__c') {
            filterMap.put('All', 'Id != null');
            filterMap.put('My_Tasks', 'OwnerId = :userId');
            filterMap.put('Open_Tasks', 'Status__c != \'Closed\' AND Status__c != \'Completed\' AND Status__c != \'Removed\'');
            filterMap.put('Pending_Tasks', 'Status__c = \'Pending\'');
            filterMap.put('In_Progress_Tasks', 'Status__c = \'In Progress\'');
            filterMap.put('Completed_Tasks', 'Status__c = \'Completed\'');
            filterMap.put('Closed_Tasks', 'Status__c = \'Closed\'');
        }
        
        return filterMap;
    }
    
    /**
     * @description Get field list from list view metadata or use defaults
     */
    private static List<String> getFieldList(String objectApiName, String filterName) {
        // Default fields for common objects
        Map<String, List<String>> defaultFields = new Map<String, List<String>>{
            'Project__c' => new List<String>{ 'Id', 'Name', 'Status__c', 'Burn_Rate__c', 'Account__c', 'CreatedDate' },
            'Project_Task__c' => new List<String>{ 'Id', 'Name', 'Status__c', 'Priority__c', 'Account__c', 'Total_Actual_Hours__c', 'CreatedDate' }
        };
        
        List<String> fields = defaultFields.get(objectApiName);
        if (fields == null) {
            // Fallback: use Id and Name
            fields = new List<String>{ 'Id', 'Name' };
        }
        
        return fields;
    }
    
    /**
     * @description Build SOQL query with bind variables
     */
    private static QueryResult buildSoqlQuery(String objectApiName, List<String> fieldList, WhereClauseResult whereResult, Integer pageSize, Integer pageNumber) {
        // Build select fields and include relationship names for reference fields so we can render the referenced Name
        List<String> selectFields = new List<String>();
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();

        for (String fieldApiName : fieldList) {
            selectFields.add(fieldApiName);

            Schema.SObjectField field = fieldMap.get(fieldApiName);
            if (field != null) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
                    String relationshipName = fieldDescribe.getRelationshipName();
                    if (!String.isBlank(relationshipName)) {
                        selectFields.add(relationshipName + '.Name');
                    }
                }
            }
        }

        String fields = String.join(selectFields, ', ');
        Integer offset = (pageNumber - 1) * pageSize;
        
        String soql = 'SELECT ' + fields + 
                     ' FROM ' + objectApiName + 
                     ' WHERE ' + whereResult.whereClause +
                     ' ORDER BY CreatedDate DESC' +
                     ' LIMIT ' + pageSize +
                     ' OFFSET ' + offset;
        
        QueryResult result = new QueryResult();
        result.soql = soql;
        result.bindMap = new Map<String, Object>();
        
        // Add bind variables
        if (whereResult.whereClause.contains(':accountIds')) {
            result.bindMap.put('accountIds', whereResult.accountIds);
        }
        if (whereResult.whereClause.contains(':userId')) {
            result.bindMap.put('userId', UserInfo.getUserId());
        }
        
        return result;
    }
    
    /**
     * @description Get total count of records
     */
    private static CountResult getTotalCount(String objectApiName, WhereClauseResult whereResult) {
        String countSoql = 'SELECT COUNT() FROM ' + objectApiName + ' WHERE ' + whereResult.whereClause;
        
        CountResult result = new CountResult();
        result.soql = countSoql;
        result.bindMap = new Map<String, Object>();
        
        // Add bind variables
        if (whereResult.whereClause.contains(':accountIds')) {
            result.bindMap.put('accountIds', whereResult.accountIds);
        }
        if (whereResult.whereClause.contains(':userId')) {
            result.bindMap.put('userId', UserInfo.getUserId());
        }
        
        return result;
    }
    
    /**
     * @description Build column metadata from field list
     */
    private static List<ColumnMetadata> buildColumnMetadata(List<String> fieldList, Schema.DescribeSObjectResult objDescribe) {
        List<ColumnMetadata> columns = new List<ColumnMetadata>();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
        
        for (String fieldApiName : fieldList) {
            // Do not render Id column
            if (fieldApiName == 'Id') {
                continue;
            }
            Schema.SObjectField field = fieldMap.get(fieldApiName);
            if (field != null) {
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                
                // Build column metadata (bypassing FLS check since queries run in SYSTEM_MODE)
                ColumnMetadata col = new ColumnMetadata();
                col.fieldApiName = fieldApiName;
                col.relationshipName = fieldDescribe.getRelationshipName();
                col.label = fieldDescribe.getLabel();
                col.type = getFieldType(fieldDescribe.getType());
                col.sortable = true;
                columns.add(col);
            }
        }
        
        return columns;
    }
    
    /**
     * @description Convert Schema.DisplayType to string type for datatable
     */
    private static String getFieldType(Schema.DisplayType displayType) {
        if (displayType == Schema.DisplayType.Currency || 
            displayType == Schema.DisplayType.Double || 
            displayType == Schema.DisplayType.Integer ||
            displayType == Schema.DisplayType.Percent) {
            return 'number';
        } else if (displayType == Schema.DisplayType.Date) {
            return 'date';
        } else if (displayType == Schema.DisplayType.DateTime) {
            return 'date';
        } else if (displayType == Schema.DisplayType.Boolean) {
            return 'boolean';
        } else {
            return 'text';
        }
    }
    
    /**
     * @description Validate object API name
     */
    private static Boolean isValidObjectApiName(String apiName) {
        if (String.isBlank(apiName)) {
            return false;
        }
        return Pattern.matches('^[a-zA-Z0-9_]+(__c)?$', apiName) && apiName.length() <= 100;
    }
    
    /**
     * @description Validate filter name
     */
    private static Boolean isValidFilterName(String filterName) {
        if (String.isBlank(filterName)) {
            return false;
        }
        return Pattern.matches('^[a-zA-Z0-9_\\-\\s]+$', filterName) && filterName.length() <= 100;
    }
    
    /**
     * @description Wrapper class for record list result
     */
    public class RecordListResult {
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public String filterName;
        @AuraEnabled public List<SObject> records;
        @AuraEnabled public List<ColumnMetadata> columns;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer totalPages;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer pageNumber;
    }
    
    /**
     * @description Wrapper class for column metadata
     */
    public class ColumnMetadata {
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String relationshipName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean sortable;
    }
    
    /**
     * @description Wrapper class for WHERE clause result
     */
    private class WhereClauseResult {
        String whereClause;
        Set<Id> accountIds;
    }
    
    /**
     * @description Wrapper class for query result
     */
    private class QueryResult {
        String soql;
        Map<String, Object> bindMap;
    }
    
    /**
     * @description Wrapper class for count result
     */
    private class CountResult {
        String soql;
        Map<String, Object> bindMap;
    }
}
