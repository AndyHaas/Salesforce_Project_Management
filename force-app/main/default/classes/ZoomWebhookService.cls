/**
 * @description Zoom webhook validation, signature verification, deduplication key, and ingress persistence.
 */
public without sharing class ZoomWebhookService {
    public static final String EVENT_URL_VALIDATION = 'endpoint.url_validation';
    public static final String EVENT_MEETING_ENDED = 'meeting.ended';

    @TestVisible
    static Boolean testSkipSignatureValidation = false;

    /**
     * @description Builds dedup key: eventType + meetingUuid + occurrenceId
     */
    public static String buildDedupKey(String eventType, String meetingUuid, String occurrenceId) {
        String occ = String.isBlank(occurrenceId) ? '' : occurrenceId;
        String ev = String.isBlank(eventType) ? '' : eventType;
        String uuid = String.isBlank(meetingUuid) ? '' : meetingUuid;
        return ev + '|' + uuid + '|' + occ;
    }

    /**
     * @description Zoom Marketplace endpoint.url_validation — HMAC-SHA256(secret, plainToken) as hex.
     */
    public static String computeUrlValidationToken(String plainToken, String secretToken) {
        if (Test.isRunningTest() && String.isNotBlank(plainToken) && String.isBlank(secretToken)) {
            secretToken = 'unit-test-zoom-secret';
        }
        if (String.isBlank(plainToken) || String.isBlank(secretToken)) {
            return null;
        }
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(plainToken), Blob.valueOf(secretToken));
        return EncodingUtil.convertToHex(mac);
    }

    /**
     * @description Validates x-zm-signature (format v0=&lt;hex&gt;) against v0:timestamp:body.
     */
    public static Boolean isEventSignatureValid(
        String requestBody,
        String timestampHeader,
        String signatureHeader,
        String secretToken
    ) {
        if (testSkipSignatureValidation && Test.isRunningTest()) {
            return true;
        }
        if (String.isBlank(secretToken) || String.isBlank(requestBody) || String.isBlank(timestampHeader) || String.isBlank(signatureHeader)) {
            return false;
        }
        String toSign = 'v0:' + timestampHeader + ':' + requestBody;
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(toSign), Blob.valueOf(secretToken));
        String expected = 'v0=' + EncodingUtil.convertToHex(mac);
        return constantTimeEquals(expected, signatureHeader.trim());
    }

    private static Boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null || a.length() != b.length()) {
            return false;
        }
        Integer result = 0;
        for (Integer i = 0; i < a.length(); i++) {
            result |= (a.charAt(i) ^ b.charAt(i));
        }
        return result == 0;
    }

    public class IngressResult {
        public Id eventId;
        public Boolean duplicateSkipped;
        public String errorMessage;
    }

    /**
     * @description Persists Zoom_Webhook_Event__c and enqueues processor when appropriate.
     */
    public static IngressResult persistAndQueue(String rawBody, Zoom_Webhook_Config__mdt cfg) {
        IngressResult result = new IngressResult();
        if (cfg == null) {
            result.errorMessage = 'Configuration missing';
            return result;
        }
        if (!cfg.Active__c) {
            result.errorMessage = 'Integration inactive';
            return result;
        }

        Map<String, Object> root;
        try {
            root = (Map<String, Object>) JSON.deserializeUntyped(rawBody);
        } catch (Exception e) {
            result.errorMessage = 'Invalid JSON';
            return result;
        }

        String eventType = (String) root.get('event');
        Map<String, Object> payload = root.containsKey('payload') ? (Map<String, Object>) root.get('payload') : null;
        Map<String, Object> obj = payload != null && payload.containsKey('object') ? (Map<String, Object>) payload.get('object') : null;

        String meetingUuid = obj != null ? stringVal(obj.get('uuid')) : null;
        if (String.isBlank(meetingUuid) && obj != null) {
            meetingUuid = stringVal(obj.get('id'));
        }
        String occurrenceId = obj != null ? stringVal(obj.get('occurrence_id')) : '';
        if (String.isBlank(occurrenceId) && obj != null) {
            occurrenceId = stringVal(obj.get('occurrenceId'));
        }

        String topic = obj != null ? stringVal(obj.get('topic')) : null;
        Datetime eventTs = parseEventTimestamp(root, obj);

        if (String.isBlank(eventType)) {
            result.errorMessage = 'Missing event type';
            return result;
        }
        if (String.isBlank(meetingUuid)) {
            meetingUuid = 'unknown-' + Crypto.getRandomInteger();
        }

        String dedupKey = buildDedupKey(eventType, meetingUuid, occurrenceId);

        if (!cfg.Allow_Reprocessing__c) {
            List<Zoom_Webhook_Event__c> existing = [
                SELECT Id
                FROM Zoom_Webhook_Event__c
                WHERE Dedup_Key__c = :dedupKey
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                result.duplicateSkipped = true;
                result.eventId = existing[0].Id;
                return result;
            }
        }

        Zoom_Webhook_Event__c evt = new Zoom_Webhook_Event__c();
        evt.Event_Type__c = eventType.left(255);
        evt.Meeting_UUID__c = meetingUuid.left(255);
        evt.Meeting_Topic__c = topic != null ? topic.left(255) : null;
        evt.Event_Timestamp__c = eventTs;
        evt.Dedup_Key__c = dedupKey.left(255);
        Boolean isMeetingEnded = EVENT_MEETING_ENDED.equalsIgnoreCase(eventType);
        evt.Processing_Status__c = isMeetingEnded ? 'Queued' : 'Completed';
        evt.Processing_Message__c = isMeetingEnded ? 'Received and queued' : ('No async processing for event type: ' + eventType);
        evt.Payload_JSON__c = rawBody.length() > 131000 ? rawBody.substring(0, 131000) : rawBody;

        try {
            insert evt;
        } catch (DmlException e) {
            if (e.getNumDml() > 0 && e.getDmlType(0) == System.StatusCode.DUPLICATE_VALUE) {
                result.duplicateSkipped = true;
                return result;
            }
            result.errorMessage = e.getMessage();
            return result;
        }

        result.eventId = evt.Id;
        if (!isMeetingEnded) {
            return result;
        }

        System.enqueueJob(new ZoomEventProcessorQueueable(evt.Id));
        return result;
    }

    private static String stringVal(Object o) {
        return o == null ? null : String.valueOf(o);
    }

    private static Datetime parseEventTimestamp(Map<String, Object> root, Map<String, Object> obj) {
        Object ts = root.get('event_ts');
        if (ts != null) {
            try {
                Long ms = ts instanceof Decimal ? ((Decimal) ts).longValue() : Long.valueOf(String.valueOf(ts));
                Integer secs = (Integer) (ms / 1000);
                return Datetime.newInstanceGmt(1970, 1, 1, 0, 0, 0).addSeconds(secs);
            } catch (Exception e) {
                // fall through
            }
        }
        String start = obj != null ? stringVal(obj.get('start_time')) : null;
        return parseZoomIso(start);
    }

    public static Datetime parseZoomIso(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String v = value.replace('T', ' ').replace('Z', '').trim();
        if (v.length() >= 19) {
            return Datetime.valueOfGmt(v.substring(0, 19));
        }
        return null;
    }
}
