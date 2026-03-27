/**
 * @description Keeps PM_Approver_User__c and Client_Approver_User__c in sync with the Project Manager
 * and Client User contacts. Flow Approval assignees must reference User Ids on $Record; ApprovalWorkflow
 * formulas do not support cross-object paths such as Project__r.OwnerId, so these lookups supply stable
 * assignee targets for packaging and runtime.
 *
 * Resolution rule: for each relevant Contact Id, use the earliest-created active User where User.ContactId
 * matches (typical Experience Cloud / community login for that contact). If none exists, the lookup is
 * cleared when the contact field changes.
 *
 * @author Milestone Consulting
 */
public without sharing class ProjectTaskApproverUserHelper {
  /**
   * @description After insert/update, refreshes approver User lookups when Client_User__c or
   * Project_Manager__c change. Skips work when those contact fields are unchanged to avoid recursion
   * when this class updates only the User lookup fields.
   * @param newTasks Trigger.new for Project_Task__c
   * @param oldMap Trigger.oldMap, or null on insert
   */
  public static void syncApproverUsersFromContacts(
    List<Project_Task__c> newTasks,
    Map<Id, Project_Task__c> oldMap
  ) {
    if (newTasks == null || newTasks.isEmpty()) {
      return;
    }

    Set<Id> contactIds = new Set<Id>();
    for (Project_Task__c task : newTasks) {
      Project_Task__c prior = oldMap != null ? oldMap.get(task.Id) : null;
      if (prior == null) {
        if (task.Client_User__c != null) {
          contactIds.add(task.Client_User__c);
        }
        if (task.Project_Manager__c != null) {
          contactIds.add(task.Project_Manager__c);
        }
      } else {
        if (
          task.Client_User__c != prior.Client_User__c &&
          task.Client_User__c != null
        ) {
          contactIds.add(task.Client_User__c);
        }
        if (
          task.Project_Manager__c != prior.Project_Manager__c &&
          task.Project_Manager__c != null
        ) {
          contactIds.add(task.Project_Manager__c);
        }
      }
    }

    Map<Id, Id> contactIdToUserId = new Map<Id, Id>();
    if (!contactIds.isEmpty()) {
      for (User u : [
        SELECT Id, ContactId
        FROM User
        WHERE ContactId IN :contactIds AND IsActive = TRUE
        ORDER BY CreatedDate ASC
      ]) {
        if (!contactIdToUserId.containsKey(u.ContactId)) {
          contactIdToUserId.put(u.ContactId, u.Id);
        }
      }
    }

    List<Project_Task__c> toUpdate = new List<Project_Task__c>();
    for (Project_Task__c task : newTasks) {
      Project_Task__c prior = oldMap != null ? oldMap.get(task.Id) : null;
      Boolean clientChanged =
        prior == null ||
        task.Client_User__c != prior.Client_User__c;
      Boolean pmChanged =
        prior == null ||
        task.Project_Manager__c != prior.Project_Manager__c;
      if (!clientChanged && !pmChanged) {
        continue;
      }

      Project_Task__c upd = new Project_Task__c(Id = task.Id);
      Boolean needsRow = false;
      if (clientChanged) {
        Id resolvedClient = task.Client_User__c == null
          ? null
          : contactIdToUserId.get(task.Client_User__c);
        if (resolvedClient != task.Client_Approver_User__c) {
          upd.Client_Approver_User__c = resolvedClient;
          needsRow = true;
        }
      }
      if (pmChanged) {
        Id resolvedPm = task.Project_Manager__c == null
          ? null
          : contactIdToUserId.get(task.Project_Manager__c);
        if (resolvedPm != task.PM_Approver_User__c) {
          upd.PM_Approver_User__c = resolvedPm;
          needsRow = true;
        }
      }
      if (needsRow) {
        toUpdate.add(upd);
      }
    }

    if (!toUpdate.isEmpty()) {
      update toUpdate;
    }
  }
}
