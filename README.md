# Milestone Salesforce Project Management

**Commercial Salesforce solution** for delivery organizations that need **projects**, **tasks**, **dependencies**, **time**, **review workflows**, and optional **client-facing Experience Cloud** access with **secure messaging**—all running in **your** Salesforce org.

> This repository contains **unmanaged metadata** (Apex, LWC, flows, objects, portal site definitions). **Purchased customers** receive rights to deploy and use it per their agreement with **Milestone Consulting**. [Product overview](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/getting-started/product-overview) · [Licensing & support](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/reference/licensing-and-support)

---

## Who this is for

| Audience | Value |
| --- | --- |
| **Professional services / consulting** | One task model with dependencies, roll-ups, and dashboards for every client engagement. |
| **Customer success / implementation teams** | Controlled client visibility via portal and messaging without exporting data to shadow IT tools. |
| **Salesforce admins & architects** | Field set–driven UI, permission-set-based roles, bulk-safe Apex, and documented data model. |
| **Executives & procurement** | Clear deployable asset, documented SLAs via contract, no separate hosted app to vet for every engagement. |

## What you get (feature summary)

- **Project & task model** — `Project__c`, `Project_Task__c` with hierarchy, progress, review status, and automation via `ProjectTaskTrigger` and helpers.
- **Task relationships & dependencies** — `Project_Task_Relationship__c`, risk/blocking signals, **task context panel**, **hover cards**, **link modal**.
- **Dashboards** — `projectTaskDashboard` and related LWCs; **task list columns** driven by **`Project_Task_Dashboard_Table`** field set (admin-configurable without code).
- **Time** — `Time_Sheet_Entries__c` for time against projects (integrate with your PSA/billing as needed).
- **Release tracking** — `Release_Notes__c`, `Release_Tag__c`, `Release_Version__c`.
- **Optional Experience Cloud portal** — Passwordless **OTP** login (`portalLogin`), project/task views, **portal messaging** (`portalMessaging`); internal Lightning uses **`salesforceMessaging`** wrapper.
- **Flows** — Large bundle of Flow definitions for automation (count may change by release).

## Architecture (source layout)

| Path | Role |
| --- | --- |
| `force-app/main/default` | Core objects, LWCs, Apex, flows, internal permission sets, tests. |
| `force-app/portal` | Experience Cloud site metadata, portal LWCs, portal Apex (e.g. OTP, portal controllers), **`Client_Project_Management_Portal_User`** permission set. |

Deploy **`force-app`** with Salesforce CLI for a **full** install including portal sources under the same project. You may **exclude** `force-app/portal` from packaging if you only want core Lightning functionality (see [wiki: deployment](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/processes/deployment-overview)).

**API version:** see `sfdx-project.json` (`sourceApiVersion`).

## Custom objects (inventory)

| API name | Purpose |
| --- | --- |
| `Project__c` | Engagement / body of work. |
| `Project_Task__c` | Tasks, subtasks, progress, review, assignments. |
| `Project_Task_Relationship__c` | Task-to-task links and dependency graph. |
| `Message__c` | Client and internal messaging. |
| `Time_Sheet_Entries__c` | Time entry lines. |
| `Portal_Config__c` | Portal configuration records (as shipped). |
| `Release_Notes__c` / `Release_Tag__c` / `Release_Version__c` | Release documentation structure. |

Custom metadata types include **`Milestone_Task_Notification_Settings__mdt`** and **`OTP_Cleanup_Config__mdt`** (see [Setup Guide](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/getting-started/setup-guide)).

## Permission sets

| API name | Typical users |
| --- | --- |
| `Client_Project_Management_Portal_User` | External portal users (`force-app/portal`). |
| `Project_Management_User` | Internal user, limited access. |
| `Project_Management_Team_Member` | Internal delivery team (broader task + messaging). |
| `Project_Management_Manager` | Managers (view-all style patterns per metadata). |
| `Project_Management_Admin` | Administrators / full config. |

Details and field-level notes: [Permission Sets](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/reference/permission-sets).

## Documentation (wiki)

**Primary documentation** is the **[GitHub Wiki](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki)** (product, requirements, licensing, deployment, setup, portal, messaging, data model).

Source Markdown lives in the **`.wiki`** **[git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules)**:

```bash
git clone --recurse-submodules https://github.com/Milestone-Consulting/Salesforce-Project-Management.git
# or after clone:
git submodule update --init .wiki
```

Edit under `.wiki`, commit and push **from `.wiki`** to update the published wiki. A root-level `wiki/` folder is **gitignored** to avoid duplicate trees.

## Installation (quick start)

1. Clone this repository (with submodules if you edit docs).
2. Authorize your org: `sf org login web --alias yourOrg`
3. Deploy: `sf project deploy start --source-dir force-app`
4. Assign **permission sets** to pilot users.
5. Complete **[Setup Guide](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/getting-started/setup-guide)** (Platform Cache, email, schedulers, Experience Cloud if using portal).

> Avoid repeatedly deploying **only** individual Apex files from the IDE if you rely on **`TaskProjectTests`** in Setup—keep **`force-app/main/default/testSuites/TaskProjectTests.testSuite-meta.xml`** in sync with a **full** `force-app` deploy when possible.

## System requirements (summary)

- Salesforce **Enterprise** (or higher) typical for full Experience Cloud; confirm with your AE.
- **Experience Cloud** licenses for external users if using the portal.
- **Platform Cache** enabled for OTP flows.
- **Salesforce CLI** (`sf`), **Node.js** for LWC tooling (`npm install`).

Full checklist: [System requirements](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/reference/system-requirements).

## Development

### Prerequisites

- Salesforce CLI (`sf`)
- Node.js and npm
- VS Code with Salesforce Extensions (recommended)

### Setup

```bash
npm install
```

### Testing

```bash
npm test
```

### Linting

```bash
npm run lint
```

## Contributing

For **Milestone** internal or **partner** contributions: use feature branches, descriptive commits, and open pull requests against the agreed integration branch. **Customers** with a fork should coordinate merges with their Milestone contact to stay alignable with upstream releases.

## License & support

**Software license** and **support** terms are defined in your **Milestone Consulting agreement** (order, SOW, or subscription). This README does not grant rights beyond that contract.

- **Product questions / defects:** use the support channel in your agreement.  
- **Salesforce platform:** open cases with Salesforce as appropriate.  
- **Wiki:** [Licensing and support](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/reference/licensing-and-support).

Repository issues may be used for **public** bug reports or discussions **if** your program allows—confirm with Milestone before relying on GitHub for SLA-bound support.
