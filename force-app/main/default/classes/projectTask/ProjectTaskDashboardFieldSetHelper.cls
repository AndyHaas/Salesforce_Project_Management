/**
 * @description Field-set and display helpers for Project Task dashboard data shaping.
 *
 * Extracted from ProjectTaskDashboardController to keep the main controller focused on
 * orchestration and queries. Uses DTO types defined as inner classes on
 * ProjectTaskDashboardController.
 *
 * This class performs no SOQL or DML; sharing is irrelevant but matches the dashboard
 * stack (Experience Cloud + internal) where callers run without sharing when required
 * for portal visibility.
 */
public inherited sharing class ProjectTaskDashboardFieldSetHelper {
  public static List<String> getFieldPaths(
    List<Schema.FieldSetMember> members
  ) {
    List<String> paths = new List<String>();
    if (members == null) {
      return paths;
    }
    for (Schema.FieldSetMember member : members) {
      if (member != null && String.isNotBlank(member.getFieldPath())) {
        paths.add(member.getFieldPath());
      }
    }
    return paths;
  }

  /**
   * @description Build hover field values from a record and field set members
   * @param record The SObject record to extract field values from
   * @param members The field set members to include
   * @param fieldDescribeMap Map of field API names to field describe objects
   * @return List of HoverFieldValue objects
   */
  public static List<ProjectTaskDashboardController.HoverFieldValue> buildHoverFieldValues(
    SObject record,
    List<Schema.FieldSetMember> members,
    Map<String, Schema.SObjectField> fieldDescribeMap
  ) {
    List<ProjectTaskDashboardController.HoverFieldValue> values = new List<ProjectTaskDashboardController.HoverFieldValue>();
    if (record == null || members == null || members.isEmpty()) {
      return values;
    }

    for (Schema.FieldSetMember member : members) {
      if (member == null) {
        continue;
      }
      String apiName = member.getFieldPath();
      ProjectTaskDashboardController.HoverFieldValue hoverField = new ProjectTaskDashboardController.HoverFieldValue();
      hoverField.apiName = apiName;
      hoverField.label = member.getLabel();

      Schema.DescribeFieldResult describe = null;
      if (fieldDescribeMap != null && fieldDescribeMap.containsKey(apiName)) {
        describe = fieldDescribeMap.get(apiName).getDescribe();
      }

      Object rawValue = record.get(apiName);
      hoverField.value = formatHoverFieldValue(rawValue, describe);
      hoverField.isLongText =
        describe != null &&
        describe.getType() == Schema.DisplayType.TextArea;
      hoverField.isRichText =
        describe != null &&
        describe.getType().name() == 'HTML';
      values.add(hoverField);
    }
    return values;
  }

  private static String formatHoverFieldValue(
    Object rawValue,
    Schema.DescribeFieldResult describe
  ) {
    if (rawValue == null) {
      return '';
    }
    if (rawValue instanceof Date) {
      return ((Date) rawValue).format();
    }
    if (rawValue instanceof Datetime) {
      return ((Datetime) rawValue).format();
    }
    if (
      rawValue instanceof Decimal &&
      describe != null &&
      describe.getType() == Schema.DisplayType.Percent
    ) {
      return String.valueOf(((Decimal) rawValue).setScale(2)) + '%';
    }
    return String.valueOf(rawValue);
  }

  public static void addFieldSetMembersToSelect(
    Set<String> targetFields,
    List<Schema.FieldSetMember> members,
    Map<String, Schema.SObjectField> describeFieldMap
  ) {
    if (targetFields == null || members == null || members.isEmpty()) {
      return;
    }

    for (Schema.FieldSetMember member : members) {
      if (member == null || String.isBlank(member.getFieldPath())) {
        continue;
      }
      String fieldPath = member.getFieldPath();
      targetFields.add(fieldPath);

      if (describeFieldMap != null && describeFieldMap.containsKey(fieldPath)) {
        Schema.DescribeFieldResult describe = describeFieldMap.get(fieldPath)
          .getDescribe();
        if (
          describe != null &&
          describe.getType() == Schema.DisplayType.Reference
        ) {
          String relationshipName = describe.getRelationshipName();
          if (!String.isBlank(relationshipName)) {
            targetFields.add(relationshipName + '.Name');
          }
        }
      }
    }
  }

  public static List<ProjectTaskDashboardController.FieldSetFieldDefinition> buildFieldSetDefinitions(
    List<Schema.FieldSetMember> members,
    Map<String, Schema.SObjectField> describeFieldMap
  ) {
    List<ProjectTaskDashboardController.FieldSetFieldDefinition> definitions = new List<ProjectTaskDashboardController.FieldSetFieldDefinition>();
    if (members == null) {
      return definitions;
    }

    for (Schema.FieldSetMember member : members) {
      if (member == null || String.isBlank(member.getFieldPath())) {
        continue;
      }
      ProjectTaskDashboardController.FieldSetFieldDefinition definition = new ProjectTaskDashboardController.FieldSetFieldDefinition();
      definition.apiName = member.getFieldPath();
      definition.isNameField = definition.apiName == 'Name';

      if (
        describeFieldMap != null &&
        describeFieldMap.containsKey(definition.apiName)
      ) {
        Schema.DescribeFieldResult describe = describeFieldMap.get(
            definition.apiName
          )
          .getDescribe();
        definition.label = describe.getLabel();
        definition.dataType = describe.getType().name();
        definition.isReference =
          describe.getType() == Schema.DisplayType.Reference;
        if (definition.isReference) {
          definition.referenceRelationshipName = describe.getRelationshipName();
        }

        if (
          describe.getType() == Schema.DisplayType.Picklist ||
          describe.getType() == Schema.DisplayType.MultiPicklist
        ) {
          List<Schema.PicklistEntry> picklistEntries = describe.getPicklistValues();
          if (picklistEntries != null && !picklistEntries.isEmpty()) {
            definition.picklistValues = new List<ProjectTaskDashboardController.PicklistOption>();
            for (Schema.PicklistEntry entry : picklistEntries) {
              if (entry.isActive()) {
                ProjectTaskDashboardController.PicklistOption option = new ProjectTaskDashboardController.PicklistOption();
                option.label = entry.getLabel();
                option.value = entry.getValue();
                definition.picklistValues.add(option);
              }
            }
          }
        }
      } else {
        definition.label = member.getLabel();
        definition.dataType = 'STRING';
        definition.isReference = false;
      }

      definitions.add(definition);
    }

    return definitions;
  }

  public static List<ProjectTaskDashboardController.SummaryFieldValue> buildSummaryFieldValues(
    SObject record,
    List<Schema.FieldSetMember> members,
    Map<String, Schema.SObjectField> describeFieldMap
  ) {
    List<ProjectTaskDashboardController.SummaryFieldValue> values = new List<ProjectTaskDashboardController.SummaryFieldValue>();
    if (record == null || members == null || members.isEmpty()) {
      return values;
    }

    for (Schema.FieldSetMember member : members) {
      if (member == null || String.isBlank(member.getFieldPath())) {
        continue;
      }

      ProjectTaskDashboardController.SummaryFieldValue summaryValue = new ProjectTaskDashboardController.SummaryFieldValue();
      summaryValue.apiName = member.getFieldPath();

      Schema.DescribeFieldResult describe = null;
      if (
        describeFieldMap != null &&
        describeFieldMap.containsKey(summaryValue.apiName)
      ) {
        describe = describeFieldMap.get(summaryValue.apiName).getDescribe();
        summaryValue.label = describe.getLabel();
      } else {
        summaryValue.label = member.getLabel();
      }

      Object rawValue = record.get(summaryValue.apiName);
      if (
        describe != null &&
        describe.getType() == Schema.DisplayType.Reference
      ) {
        String relationshipName = describe.getRelationshipName();
        if (!String.isBlank(relationshipName)) {
          SObject relatedRecord = record.getSObject(relationshipName);
          if (relatedRecord != null && relatedRecord.get('Name') != null) {
            rawValue = relatedRecord.get('Name');
          }
        }
      }

      summaryValue.rawValue = rawValue != null
        ? String.valueOf(rawValue)
        : null;
      summaryValue.displayValue = formatHoverFieldValue(rawValue, describe);
      summaryValue.isRichText =
        describe != null &&
        describe.getType().name() == 'HTML';
      values.add(summaryValue);
    }

    return values;
  }
}
