/**
 * @description Asynchronous processor for Zoom_Webhook_Event__c — project mapping, attendees, duration, time entries, audit fields.
 */
public without sharing class ZoomEventProcessorQueueable implements Queueable {
    private final Id eventId;

    public ZoomEventProcessorQueueable(Id eventId) {
        this.eventId = eventId;
    }

    public void execute(QueueableContext context) {
        Zoom_Webhook_Config__mdt cfg = ZoomConfigService.getDefault();
        List<Zoom_Webhook_Event__c> rows = [
            SELECT
                Id,
                Event_Type__c,
                Meeting_UUID__c,
                Meeting_Topic__c,
                Dedup_Key__c,
                Payload_JSON__c,
                Processing_Status__c,
                Retry_Count__c
            FROM Zoom_Webhook_Event__c
            WHERE Id = :eventId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return;
        }
        Zoom_Webhook_Event__c evt = rows[0];
        if (cfg == null || cfg.Active__c != true) {
            evt.Processing_Status__c = 'Skipped - Inactive';
            evt.Processing_Message__c = 'Zoom integration disabled in custom metadata';
            update evt;
            return;
        }

        evt.Processing_Status__c = 'Processing';
        evt.Retry_Count__c = evt.Retry_Count__c == null ? 1 : evt.Retry_Count__c + 1;
        update evt;

        try {
            if (String.isBlank(evt.Payload_JSON__c)) {
                finishFailed(evt, 'No payload stored');
                return;
            }
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(evt.Payload_JSON__c);
            String eventType = (String) root.get('event');
            if (!ZoomWebhookService.EVENT_MEETING_ENDED.equalsIgnoreCase(eventType)) {
                evt.Processing_Status__c = 'Skipped - Validation';
                evt.Processing_Message__c = 'Unsupported event: ' + eventType;
                update evt;
                return;
            }

            Map<String, Object> payload = root.containsKey('payload') ? (Map<String, Object>) root.get('payload') : null;
            Map<String, Object> obj = payload != null && payload.containsKey('object') ? (Map<String, Object>) payload.get('object') : null;
            if (obj == null) {
                finishFailed(evt, 'Missing payload.object');
                return;
            }

            String topic = stringVal(obj.get('topic'));
            Datetime startDt = ZoomWebhookService.parseZoomIso(stringVal(obj.get('start_time')));
            Datetime endDt = ZoomWebhookService.parseZoomIso(stringVal(obj.get('end_time')));

            if (startDt == null || endDt == null) {
                finishFailed(evt, 'Missing start_time or end_time');
                return;
            }

            Long durationMs = endDt.getTime() - startDt.getTime();
            if (durationMs < 0) {
                finishFailed(evt, 'End before start');
                return;
            }
            Long minutes = durationMs / 60000;
            if (cfg.Minimum_Meeting_Minutes__c != null && minutes < cfg.Minimum_Meeting_Minutes__c.longValue()) {
                evt.Processing_Status__c = 'Skipped - Validation';
                evt.Processing_Message__c = 'Below minimum meeting minutes: ' + minutes;
                update evt;
                return;
            }

            ZoomProjectResolver.Resolution res = ZoomProjectResolver.resolve(topic, cfg);
            if (res.project == null || res.mapping == null) {
                if (res.failureReason != null && res.failureReason.containsIgnoreCase('mapping')) {
                    evt.Processing_Status__c = 'Failed - No Meeting Mapping';
                } else {
                    evt.Processing_Status__c = 'Failed - Invalid Project';
                }
                evt.Processing_Message__c = res.failureReason;
                update evt;
                return;
            }

            evt.Project__c = res.project.Id;
            update evt;

            List<Map<String, Object>> participantRows = ZoomAttendeeResolver.extractParticipants(root);
            List<ZoomAttendeeResolver.ResolvedAttendee> attendees = ZoomAttendeeResolver.resolve(participantRows);

            if (attendees.isEmpty()) {
                evt.Processing_Status__c = 'Completed - No Attendees';
                evt.Processing_Message__c = 'No mapped internal attendees with consultant contact';
                evt.Time_Entries_Created__c = 0;
                update evt;
                return;
            }

            Integer created = ZoomTimeEntryService.createEntries(
                res.project.Id,
                res.mapping,
                attendees,
                startDt,
                endDt,
                topic,
                cfg,
                evt.Dedup_Key__c
            );

            evt.Processing_Status__c = 'Completed';
            evt.Processing_Message__c = 'Time entries created: ' + created;
            evt.Time_Entries_Created__c = created;
            update evt;
        } catch (Exception e) {
            finishFailed(evt, e.getMessage());
        }
    }

    private void finishFailed(Zoom_Webhook_Event__c evt, String msg) {
        evt.Processing_Status__c = 'Failed';
        evt.Processing_Message__c = msg != null ? msg.left(32000) : 'Error';
        update evt;
    }

    private static String stringVal(Object o) {
        return o == null ? null : String.valueOf(o);
    }
}
