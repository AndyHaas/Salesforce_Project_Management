/**
 * @description Resolves Zoom_Meeting_Map__c rows from meeting topic and validates Project__c eligibility.
 */
public without sharing class ZoomProjectResolver {
    public class Resolution {
        public Zoom_Meeting_Map__c mapping;
        public Project__c project;
        public String failureReason;
    }

    /**
     * @description Finds enabled mapping by normalized title rules, then loads and validates project.
     */
    public static Resolution resolve(String meetingTopic, Zoom_Webhook_Config__mdt cfg) {
        Resolution r = new Resolution();
        if (String.isBlank(meetingTopic)) {
            r.failureReason = 'Meeting topic blank';
            return r;
        }
        String normalizedTopic = normalizeTitle(meetingTopic);

        List<Zoom_Meeting_Map__c> maps = [
            SELECT
                Id,
                Meeting_Name__c,
                Normalized_Meeting_Name__c,
                Project__c,
                Enabled__c,
                Require_Exact_Title__c,
                Override_Debrief_Minutes__c,
                Default_Time_Entry_Type__c,
                Notes_Template__c
            FROM Zoom_Meeting_Map__c
            WHERE Enabled__c = TRUE AND Project__c != NULL
        ];

        Zoom_Meeting_Map__c chosen = null;
        for (Zoom_Meeting_Map__c m : maps) {
            if (m.Require_Exact_Title__c == true) {
                if (meetingTopic.equals(m.Meeting_Name__c)) {
                    chosen = m;
                    break;
                }
            } else {
                String mapNorm = String.isNotBlank(m.Normalized_Meeting_Name__c)
                    ? m.Normalized_Meeting_Name__c.toLowerCase().trim()
                    : normalizeTitle(m.Meeting_Name__c);
                if (normalizedTopic.equals(mapNorm)) {
                    chosen = m;
                    break;
                }
            }
        }

        if (chosen == null && cfg != null && cfg.Require_Project_Mapping__c == true) {
            r.failureReason = 'No meeting mapping';
            return r;
        }
        if (chosen == null) {
            r.failureReason = 'No meeting mapping';
            return r;
        }

        List<Project__c> projects = [
            SELECT Id, Name, Status__c, Invoiced__c
            FROM Project__c
            WHERE Id = :chosen.Project__c
            LIMIT 1
        ];
        if (projects.isEmpty()) {
            r.failureReason = 'Project not found';
            return r;
        }

        Project__c p = projects[0];
        if (p.Invoiced__c == true) {
            r.failureReason = 'Project invoiced';
            return r;
        }
        if (p.Status__c == 'Not Started') {
            r.failureReason = 'Project status Not Started';
            return r;
        }
        if (p.Status__c == 'Cancelled') {
            r.failureReason = 'Project cancelled';
            return r;
        }
        if (cfg != null && cfg.Only_Active_Projects__c == true) {
            Set<String> active = new Set<String>{ 'Development', 'Q&A', 'Deployed', 'R&D', 'Proposal' };
            if (!active.contains(p.Status__c)) {
                r.failureReason = 'Project not in active status list';
                return r;
            }
        }

        r.mapping = chosen;
        r.project = p;
        return r;
    }

    public static String normalizeTitle(String title) {
        if (title == null) {
            return '';
        }
        return title.trim().replaceAll('\\s+', ' ').toLowerCase();
    }
}
