/**
 * @description Tests for DisplayDensityController (UI API theme density via HTTP callout).
 */
@IsTest
private class DisplayDensityControllerTest {
  private class ThemesActiveMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;
    ThemesActiveMock(Integer code, String jsonBody) {
      this.statusCode = code;
      this.body = jsonBody;
    }
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(statusCode);
      res.setBody(body);
      return res;
    }
  }

  /**
   * Goal: single startTest/stopTest — theme API returns normalized density on 200, defaults to comfy
   * when density missing in JSON or on non-200 (sequential mocks, no nested startTest).
   */
  @IsTest
  static void getDisplayDensity_handles200NullDensityAndNon200() {
    Test.startTest();
    Test.setMock(HttpCalloutMock.class, new ThemesActiveMock(200, '{"density":"COMPACT"}'));
    System.assertEquals('compact', DisplayDensityController.getDisplayDensity());

    Test.setMock(HttpCalloutMock.class, new ThemesActiveMock(200, '{}'));
    System.assertEquals('comfy', DisplayDensityController.getDisplayDensity());

    Test.setMock(HttpCalloutMock.class, new ThemesActiveMock(500, 'error'));
    System.assertEquals('comfy', DisplayDensityController.getDisplayDensity());
    Test.stopTest();
  }
}
