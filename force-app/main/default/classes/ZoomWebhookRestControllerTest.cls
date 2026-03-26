@IsTest
private class ZoomWebhookRestControllerTest {
    @IsTest
    static void urlValidation_returnsEncryptedToken() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/zoom/webhooks/test';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueOf(
            '{"event":"endpoint.url_validation","payload":{"plainToken":"abc123"}}'
        );
        RestContext.request = req;
        RestContext.response = res;

        ZoomWebhookRestController.receive();

        System.assertEquals(200, res.statusCode, res.responseBody?.toString());
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('abc123', body.get('plainToken'));
        System.assertNotEquals(null, body.get('encryptedToken'));
    }
}
