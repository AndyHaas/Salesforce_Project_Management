/**
 * @description Maps Zoom participant payloads to Employee_Zoom_Identity__c and Salesforce Users / Contacts.
 */
public without sharing class ZoomAttendeeResolver {
    public class ResolvedAttendee {
        public Id userId;
        public Id consultantContactId;
        public String email;
        public String zoomUserId;
        public String displayName;
    }

    /**
     * @description Extracts participant maps from Zoom JSON (object.participant, object.participants, or root participants).
     */
    public static List<Map<String, Object>> extractParticipants(Map<String, Object> root) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        if (root == null) {
            return out;
        }
        Map<String, Object> payload = root.containsKey('payload') ? (Map<String, Object>) root.get('payload') : null;
        Map<String, Object> obj = payload != null && payload.containsKey('object') ? (Map<String, Object>) payload.get('object') : null;

        addParticipantList(out, obj != null ? obj.get('participant') : null);
        addParticipantList(out, obj != null ? obj.get('participants') : null);
        addParticipantList(out, root.get('participants'));

        if (obj != null) {
            String hostEmail = stringVal(obj.get('host_email'));
            if (String.isNotBlank(hostEmail)) {
                Map<String, Object> hostRow = new Map<String, Object>();
                hostRow.put('user_email', hostEmail);
                hostRow.put('email', hostEmail);
                hostRow.put('id', stringVal(obj.get('host_id')));
                out.add(hostRow);
            }
        }
        return out;
    }

    private static void addParticipantList(List<Map<String, Object>> out, Object raw) {
        if (raw == null) {
            return;
        }
        if (raw instanceof List<Object>) {
            for (Object item : (List<Object>) raw) {
                if (item instanceof Map<String, Object>) {
                    out.add((Map<String, Object>) item);
                }
            }
        } else if (raw instanceof Map<String, Object>) {
            out.add((Map<String, Object>) raw);
        }
    }

    private static String stringVal(Object o) {
        return o == null ? null : String.valueOf(o);
    }

    /**
     * @description Resolves participants to internal users and consultant contacts for Time_Sheet_Entries__c.
     */
    public static List<ResolvedAttendee> resolve(List<Map<String, Object>> participants) {
        List<ResolvedAttendee> resolved = new List<ResolvedAttendee>();
        if (participants == null || participants.isEmpty()) {
            return resolved;
        }

        Set<String> emails = new Set<String>();
        Set<String> zoomIds = new Set<String>();
        for (Map<String, Object> row : participants) {
            String em = emailFromRow(row);
            if (String.isNotBlank(em)) {
                emails.add(em.toLowerCase());
            }
            String zid = zoomIdFromRow(row);
            if (String.isNotBlank(zid)) {
                zoomIds.add(zid);
            }
        }

        List<Employee_Zoom_Identity__c> identities = [
            SELECT Id, User__c, Zoom_Email__c, Zoom_User_Id__c, Zoom_Display_Name__c, Active__c
            FROM Employee_Zoom_Identity__c
            WHERE Active__c = TRUE AND User__c != NULL
        ];

        Map<String, Employee_Zoom_Identity__c> byEmail = new Map<String, Employee_Zoom_Identity__c>();
        Map<String, Employee_Zoom_Identity__c> byZoomId = new Map<String, Employee_Zoom_Identity__c>();
        for (Employee_Zoom_Identity__c ez : identities) {
            if (String.isNotBlank(ez.Zoom_Email__c)) {
                byEmail.put(ez.Zoom_Email__c.toLowerCase(), ez);
            }
            if (String.isNotBlank(ez.Zoom_User_Id__c)) {
                byZoomId.put(ez.Zoom_User_Id__c, ez);
            }
        }

        Set<Id> userIds = new Set<Id>();
        for (Employee_Zoom_Identity__c ez : identities) {
            userIds.add(ez.User__c);
        }
        Map<Id, User> usersById = new Map<Id, User>(
            [SELECT Id, Email, ContactId FROM User WHERE Id IN :userIds]
        );

        Set<String> userEmails = new Set<String>();
        for (User u : usersById.values()) {
            if (String.isNotBlank(u.Email)) {
                userEmails.add(u.Email.toLowerCase());
            }
        }
        Map<String, Contact> contactsByEmail = new Map<String, Contact>();
        for (Contact c : [SELECT Id, Email FROM Contact WHERE Email IN :userEmails]) {
            if (String.isNotBlank(c.Email)) {
                contactsByEmail.put(c.Email.toLowerCase(), c);
            }
        }

        Set<String> seenKeys = new Set<String>();
        for (Map<String, Object> row : participants) {
            String em = emailFromRow(row);
            String zid = zoomIdFromRow(row);
            Employee_Zoom_Identity__c match = null;
            if (String.isNotBlank(em) && byEmail.containsKey(em.toLowerCase())) {
                match = byEmail.get(em.toLowerCase());
            } else if (String.isNotBlank(zid) && byZoomId.containsKey(zid)) {
                match = byZoomId.get(zid);
            }
            if (match == null) {
                continue;
            }
            User u = usersById.get(match.User__c);
            if (u == null) {
                continue;
            }
            Id contactId = u.ContactId;
            if (contactId == null && String.isNotBlank(u.Email) && contactsByEmail.containsKey(u.Email.toLowerCase())) {
                contactId = contactsByEmail.get(u.Email.toLowerCase()).Id;
            }
            if (contactId == null) {
                continue;
            }
            String dedupe = String.valueOf(u.Id);
            if (seenKeys.contains(dedupe)) {
                continue;
            }
            seenKeys.add(dedupe);

            ResolvedAttendee ra = new ResolvedAttendee();
            ra.userId = u.Id;
            ra.consultantContactId = contactId;
            ra.email = em;
            ra.zoomUserId = zid;
            ra.displayName = stringVal(row.get('name'));
            resolved.add(ra);
        }
        return resolved;
    }

    private static String emailFromRow(Map<String, Object> row) {
        if (row == null) {
            return null;
        }
        String e = stringVal(row.get('user_email'));
        if (String.isBlank(e)) {
            e = stringVal(row.get('email'));
        }
        if (String.isBlank(e)) {
            e = stringVal(row.get('participant_email'));
        }
        return e;
    }

    private static String zoomIdFromRow(Map<String, Object> row) {
        if (row == null) {
            return null;
        }
        String z = stringVal(row.get('participant_user_id'));
        if (String.isBlank(z)) {
            z = stringVal(row.get('user_id'));
        }
        if (String.isBlank(z)) {
            z = stringVal(row.get('id'));
        }
        return z;
    }
}
