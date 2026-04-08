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

  @IsTest
  static void getDisplayDensity_returnsLowercaseFrom200() {
    Test.setMock(HttpCalloutMock.class, new ThemesActiveMock(200, '{"density":"COMPACT"}'));
    Test.startTest();
    String d = DisplayDensityController.getDisplayDensity();
    Test.stopTest();
    System.assertEquals('compact', d);
  }

  @IsTest
  static void getDisplayDensity_defaultsComfyWhenDensityNull() {
    Test.setMock(HttpCalloutMock.class, new ThemesActiveMock(200, '{}'));
    Test.startTest();
    String d = DisplayDensityController.getDisplayDensity();
    Test.stopTest();
    System.assertEquals('comfy', d);
  }

  @IsTest
  static void getDisplayDensity_defaultsComfyOnNon200() {
    Test.setMock(HttpCalloutMock.class, new ThemesActiveMock(500, 'error'));
    Test.startTest();
    String d = DisplayDensityController.getDisplayDensity();
    Test.stopTest();
    System.assertEquals('comfy', d);
  }
}
