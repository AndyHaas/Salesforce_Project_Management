/**
 * @description Tests for StatusColorController (task and project status color maps).
 */
@IsTest
private class StatusColorControllerTest {
  @IsTest
  static void getStatusColors_returnsExpectedKeysAndHex() {
    Map<String, String> colors = StatusColorController.getStatusColors();
    System.assertEquals(7, colors.size(), 'One entry per task status');
    System.assertEquals('#E5E5E5', colors.get('Backlog'));
    System.assertEquals('#0176D3', colors.get('In Progress'));
    System.assertEquals('#2E844A', colors.get('Completed'));
  }

  @IsTest
  static void getProjectStatusColors_returnsExpectedKeysAndHex() {
    Map<String, String> colors = StatusColorController.getProjectStatusColors();
    System.assertEquals(7, colors.size(), 'One entry per project status');
    System.assertEquals('#DDDDDD', colors.get('Not Started'));
    System.assertEquals('#33CC00', colors.get('Deployed'));
    System.assertEquals('#CC0000', colors.get('Cancelled'));
  }
}
