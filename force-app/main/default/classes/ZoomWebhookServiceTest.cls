@IsTest
private class ZoomWebhookServiceTest {
    @IsTest
    static void buildDedupKey_joinsParts() {
        System.assertEquals('a|b|c', ZoomWebhookService.buildDedupKey('a', 'b', 'c'));
        System.assertEquals('a|b|', ZoomWebhookService.buildDedupKey('a', 'b', null));
    }

    @IsTest
    static void urlValidationToken_hex() {
        String enc = ZoomWebhookService.computeUrlValidationToken('plain', 'secret');
        System.assertNotEquals(null, enc);
        System.assertEquals(64, enc.length());
    }

    @IsTest
    static void parseZoomIso_parsesGmt() {
        Datetime dt = ZoomWebhookService.parseZoomIso('2024-06-01T12:30:00Z');
        System.assertEquals(Datetime.newInstanceGmt(2024, 6, 1, 12, 30, 0), dt);
    }

    @IsTest
    static void signatureValid_whenTestBypass() {
        ZoomWebhookService.testSkipSignatureValidation = true;
        System.assertEquals(
            true,
            ZoomWebhookService.isEventSignatureValid('body', 'ts', 'sig', 'secret')
        );
        ZoomWebhookService.testSkipSignatureValidation = false;
    }

    @IsTest
    static void normalizeTitle_projectResolver() {
        System.assertEquals('a b', ZoomProjectResolver.normalizeTitle('  A   B  '));
    }
}
