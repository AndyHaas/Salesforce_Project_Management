/**
 * @description Tests for StatusColorController (task and project status color maps).
 */
@IsTest
private class StatusColorControllerTest {
  /**
   * Goal: both cacheable maps (task + project status) return full key sets and representative hex values.
   */
  @IsTest
  static void statusColorMaps_returnExpectedKeysAndHex() {
    Map<String, String> taskColors = StatusColorController.getStatusColors();
    System.assertEquals(7, taskColors.size(), 'One entry per task status');
    System.assertEquals('#E5E5E5', taskColors.get('Backlog'));
    System.assertEquals('#0176D3', taskColors.get('In Progress'));
    System.assertEquals('#2E844A', taskColors.get('Completed'));

    Map<String, String> projectColors = StatusColorController.getProjectStatusColors();
    System.assertEquals(7, projectColors.size(), 'One entry per project status');
    System.assertEquals('#DDDDDD', projectColors.get('Not Started'));
    System.assertEquals('#33CC00', projectColors.get('Deployed'));
    System.assertEquals('#CC0000', projectColors.get('Cancelled'));
  }
}
