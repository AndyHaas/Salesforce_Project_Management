/**
 * @description Covers ProjectTaskDashboardFieldSetHelper for deployment coverage.
 */
@isTest
private class ProjectTaskDashboardFieldSetHelperTest {
  @isTest
  static void testBuildHoverFieldValues_nullRecord_returnsEmpty() {
    System.assertEquals(
      0,
      ProjectTaskDashboardFieldSetHelper.buildHoverFieldValues(
          null,
          new List<Schema.FieldSetMember>(),
          new Map<String, Schema.SObjectField>()
        )
        .size(),
      'Null record should yield no hover rows'
    );
  }

  @isTest
  static void testGetFieldPaths_nullMembers_returnsEmpty() {
    System.assertEquals(
      0,
      ProjectTaskDashboardFieldSetHelper.getFieldPaths(null).size()
    );
  }
}
