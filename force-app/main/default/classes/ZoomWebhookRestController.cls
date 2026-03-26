/**
 * @description REST endpoint for Zoom Marketplace webhooks: URL validation, optional signature verification, persist + queue.
 */
@RestResource(urlMapping='/zoom/webhooks/*')
public without sharing class ZoomWebhookRestController {
    @HttpPost
    public static void receive() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json; charset=UTF-8');

        Zoom_Webhook_Config__mdt cfg = ZoomConfigService.getDefault();
        String body = req.requestBody == null ? '' : req.requestBody.toString();

        if (cfg == null) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"ok":false,"error":"config"}');
            return;
        }

        Map<String, Object> root;
        try {
            root = (Map<String, Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{"ok":false,"error":"json"}');
            return;
        }

        String event = (String) root.get('event');

        if (ZoomWebhookService.EVENT_URL_VALIDATION.equals(event)) {
            Map<String, Object> payload = root.containsKey('payload') ? (Map<String, Object>) root.get('payload') : null;
            String plain = payload != null ? (String) payload.get('plainToken') : null;
            String enc = ZoomWebhookService.computeUrlValidationToken(plain, cfg.Webhook_Secret_Token__c);
            if (String.isBlank(enc)) {
                res.statusCode = 500;
                res.responseBody = Blob.valueOf('{"ok":false,"error":"secret"}');
                return;
            }
            Map<String, String> out = new Map<String, String>();
            out.put('plainToken', plain);
            out.put('encryptedToken', enc);
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(out));
            return;
        }

        if (!cfg.Active__c) {
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"ok":true,"ignored":true}');
            return;
        }

        if (cfg.Validate_Signature__c == true) {
            String ts = req.headers.get('x-zm-request-timestamp');
            String sig = req.headers.get('x-zm-signature');
            if (!ZoomWebhookService.isEventSignatureValid(body, ts, sig, cfg.Webhook_Secret_Token__c)) {
                res.statusCode = 401;
                res.responseBody = Blob.valueOf('{"ok":false,"error":"signature"}');
                return;
            }
        }

        ZoomWebhookService.IngressResult ing = ZoomWebhookService.persistAndQueue(body, cfg);
        if (ing.duplicateSkipped) {
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"ok":true,"duplicate":true}');
            return;
        }
        if (String.isNotBlank(ing.errorMessage)) {
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"ok":true,"warning":"ingress"}');
            return;
        }

        res.statusCode = 200;
        res.responseBody = Blob.valueOf('{"ok":true,"eventId":"' + String.valueOf(ing.eventId) + '"}');
    }
}
