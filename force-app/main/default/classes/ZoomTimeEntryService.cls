/**
 * @description Creates Time_Sheet_Entries__c rows for resolved Zoom attendees (org object: Time_Sheet_Entries__c).
 */
public without sharing class ZoomTimeEntryService {
    /**
     * @description Inserts one time sheet entry per attendee when config allows; uses External_Time_Sheet_Entry_Id__c for idempotency.
     */
    public static Integer createEntries(
        Id projectId,
        Zoom_Meeting_Map__c mapping,
        List<ZoomAttendeeResolver.ResolvedAttendee> attendees,
        Datetime startDt,
        Datetime endDt,
        String meetingTopic,
        Zoom_Webhook_Config__mdt cfg,
        String dedupKeyBase
    ) {
        if (cfg == null || cfg.Create_Time_Entries__c != true) {
            return 0;
        }
        if (projectId == null || attendees == null || attendees.isEmpty() || startDt == null || endDt == null) {
            return 0;
        }

        Decimal debrief = mapping != null && mapping.Override_Debrief_Minutes__c != null
            ? mapping.Override_Debrief_Minutes__c
            : (cfg.Default_Debrief_Minutes__c != null ? cfg.Default_Debrief_Minutes__c : 0);
        Integer debriefInt = debrief.intValue();
        Datetime endWithDebrief = endDt.addMinutes(debriefInt);

        String entryType = mapping != null && String.isNotBlank(mapping.Default_Time_Entry_Type__c)
            ? mapping.Default_Time_Entry_Type__c
            : 'Meetings';

        String notesTemplate = mapping != null ? mapping.Notes_Template__c : null;
        String notes = applyNotesTemplate(notesTemplate, meetingTopic, startDt, endWithDebrief);

        Set<String> extIds = new Set<String>();
        for (ZoomAttendeeResolver.ResolvedAttendee a : attendees) {
            extIds.add(externalIdFor(dedupKeyBase, a.userId, a.email));
        }
        Set<String> existingIds = new Set<String>();
        for (Time_Sheet_Entries__c ex : [
            SELECT External_Time_Sheet_Entry_Id__c
            FROM Time_Sheet_Entries__c
            WHERE External_Time_Sheet_Entry_Id__c IN :extIds
        ]) {
            existingIds.add(ex.External_Time_Sheet_Entry_Id__c);
        }

        List<Time_Sheet_Entries__c> toInsert = new List<Time_Sheet_Entries__c>();
        for (ZoomAttendeeResolver.ResolvedAttendee a : attendees) {
            String extId = externalIdFor(dedupKeyBase, a.userId, a.email);
            if (existingIds.contains(extId)) {
                continue;
            }
            Time_Sheet_Entries__c row = new Time_Sheet_Entries__c();
            row.Project__c = projectId;
            row.Consultant__c = a.consultantContactId;
            row.Start_Date_Time__c = startDt;
            row.End_Date_Time__c = endWithDebrief;
            row.Type__c = entryType;
            row.Billable_Hours__c = true;
            row.External_Time_Sheet_Entry_Id__c = extId;
            if (String.isNotBlank(notes)) {
                row.Notes__c = notes.left(32000);
            }
            toInsert.add(row);
        }
        if (toInsert.isEmpty()) {
            return 0;
        }
        insert toInsert;
        return toInsert.size();
    }

    private static String externalIdFor(String dedupKeyBase, Id userId, String email) {
        String raw = (dedupKeyBase == null ? '' : dedupKeyBase) + '|' + String.valueOf(userId) + '|' + (email == null ? '' : email.toLowerCase());
        Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(raw));
        return EncodingUtil.convertToHex(hash);
    }

    private static String applyNotesTemplate(String template, String topic, Datetime startDt, Datetime endDt) {
        if (String.isBlank(template)) {
            return 'Zoom meeting' + (String.isNotBlank(topic) ? ': ' + topic : '');
        }
        String out = template;
        out = out.replace('{MeetingTopic}', topic != null ? topic : '');
        out = out.replace('{Start}', startDt != null ? String.valueOfGmt(startDt) : '');
        out = out.replace('{End}', endDt != null ? String.valueOfGmt(endDt) : '');
        return out;
    }
}
