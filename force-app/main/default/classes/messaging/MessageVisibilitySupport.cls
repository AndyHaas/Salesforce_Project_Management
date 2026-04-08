/**
 * Computes Message__c.Visible_To_Client__c for new messages from the intended audience
 * (Recipient_Type__c) and whether the sender is a Milestone team member.
 * <p>
 * Portal / Experience users (not Milestone team) always create client-visible rows so they can
 * see their own outbound messages. Internal users are visible to clients only when sending with
 * Recipient_Type__c = Client; Milestone Team means team-only on the portal.
 * <p>
 * Call this from MessagingController.sendMessage (or equivalent) so Visible_To_Client__c
 * stays aligned with the Visible To picklist even if the client passes a mismatched flag.
 */
public with sharing class MessageVisibilitySupport {
  /**
   * @param isMilestoneTeamMember True when the running user is a Milestone team (internal) sender.
   * @param recipientType Message__c.Recipient_Type__c value (Client or Milestone Team).
   * @return Value to store on Message__c.Visible_To_Client__c.
   */
  public static Boolean visibleToClientForNewMessage(Boolean isMilestoneTeamMember, String recipientType) {
    if (isMilestoneTeamMember != true) {
      return true;
    }
    return recipientType == 'Client';
  }
}
