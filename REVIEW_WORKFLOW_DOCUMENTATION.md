# Project Task Review/Approval Workflows

## Review/Approval Checkboxes

1. **Ready_for_Client_Review__c** - Indicates a Backlog task is ready for client review
2. **Client_Approved_for_Development__c** - Indicates client approved a Backlog task for development (set by workflow)
3. **Reviewed_by_PM_Code_Reviewer__c** - Indicates PM/Code Reviewer approved an In Review task (set by workflow)
4. **Client_Approved_for_Completion__c** - Indicates client approved an In Review task for completion (set by workflow)

## Workflow 1: Backlog → Pending (Client Development Approval)

**Initial State:**
- Status: `Backlog`
- Ready_for_Client_Review__c: `false`
- Client_Approved_for_Development__c: `false`

**Step 1: PM Submits for Client Review**
- PM checks `Ready_for_Client_Review__c = true`
- Status remains `Backlog`
- This triggers approval workflow: `Approval_Process_Project_Task_Waiting_For_Client_Approval_on_Backlog_Task`

**Step 2a: Client Approves**
- Workflow sets: `Client_Approved_for_Development__c = true`
- Workflow sets: Status = `Pending`
- Task moves to development

**Step 2b: Client Rejects**
- Workflow sets: `Client_Approved_for_Development__c = false`
- Status remains `Backlog`
- `Ready_for_Client_Review__c` may remain `true` or be reset

## Workflow 2: In Review → Completed (PM Review + Client Completion Approval)

**Initial State:**
- Status: `In Review`
- Reviewed_by_PM_Code_Reviewer__c: `false`
- Client_Approved_for_Completion__c: `false`

**Step 1: PM/Code Reviewer Approval**
- When Status changes to `In Review` AND `Reviewed_by_PM_Code_Reviewer__c = false`
- Triggers approval workflow: `Approval_Process_Project_Task_PM_Code_Reviewer_Approval`
- When approved: `Reviewed_by_PM_Code_Reviewer__c = true`
- Status remains `In Review`

**Step 2: Client Completion Approval**
- When `Reviewed_by_PM_Code_Reviewer__c = true` AND `Client_Approved_for_Completion__c = false` AND Status = `In Review`
- Triggers approval workflow: `Approval_Process_Project_Task_Client_Completion_Approval`
- When approved: `Client_Approved_for_Completion__c = true` AND Status = `Completed`
- When rejected: `Client_Approved_for_Completion__c = false` AND Status may change back to `In Progress`

## Validation Rules Needed

1. **Ready_for_Client_Review__c** can only be `true` when Status = `Backlog`
2. **Client_Approved_for_Development__c** can only be `true` when Status = `Pending` (after approval) or `Backlog` (during approval process)
3. **Reviewed_by_PM_Code_Reviewer__c** can only be `true` when Status = `In Review`
4. **Client_Approved_for_Completion__c** can only be `true` when Status = `Completed` (after approval) or `In Review` (during approval process)
5. Cannot have `Client_Approved_for_Development__c = true` if Status is not `Pending` or `Backlog`
6. Cannot have `Client_Approved_for_Completion__c = true` if Status is not `Completed` or `In Review`
7. Cannot have `Ready_for_Client_Review__c = true` if Status is not `Backlog`
8. Cannot have `Reviewed_by_PM_Code_Reviewer__c = true` if Status is not `In Review`
9. If `Client_Approved_for_Development__c = true`, Status must be `Pending` (not `Backlog`)
10. If `Client_Approved_for_Completion__c = true`, Status must be `Completed` (not `In Review`)

