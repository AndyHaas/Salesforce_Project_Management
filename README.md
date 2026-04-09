# Milestone Salesforce Project Management

**Commercial Salesforce solution** for delivery organizations that need **projects**, **tasks**, **dependencies**, **time**, and **review workflows** in **your** Salesforce org. **This core repo includes Experience Cloud–ready file list and in-page preview** (`c-file-manager`, `c-portal-file-attachments`, ContentDistribution-backed modal). **Optional client-facing portal shell** (OTP login, full portal pages, extended UI) still comes from the separate **[Portal Add-On](https://github.com/Milestone-Consulting/Salesforce-Project-Management---Portal-Add-On)** repository deployed into the same org after core.

> This repository contains **unmanaged metadata** (Apex, LWC, flows, objects, permission sets). **Purchased customers** receive rights to deploy and use it per their agreement with **Milestone Consulting**. [Product overview](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Product-Overview) · [Licensing & support](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Licensing-and-Support) · [Portal Add-On wiki](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/portal-add-on)

---

## Who this is for

| Audience                                    | Value                                                                                                                         |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| **Professional services / consulting**      | One task model with dependencies, roll-ups, and dashboards for every client engagement.                                       |
| **Customer success / implementation teams** | Optional controlled client visibility via the **Portal Add-On** (Experience Cloud) without exporting data to shadow IT tools. |
| **Salesforce admins & architects**          | Field set–driven UI, permission-set-based roles, bulk-safe Apex, and documented data model.                                   |
| **Executives & procurement**                | Clear deployable asset, documented SLAs via contract, no separate hosted app to vet for every engagement.                     |

## What you get (feature summary)

- **Project & task model** — `Project__c`, `Project_Task__c` with hierarchy, progress, review status, and automation via `ProjectTaskTrigger` and helpers.
- **Task relationships & dependencies** — `Project_Task_Relationship__c`, risk/blocking signals, **task context panel**, **hover cards**, **link modal**.
- **Dashboards** — `projectTaskDashboard` and related LWCs; **task list columns** driven by **`Project_Task_Dashboard_Table`** field set (admin-configurable without code).
- **Time** — `Time_Sheet_Entries__c` for time against projects (integrate with your PSA/billing as needed).
- **Release tracking** — `Release_Notes__c`, `Release_Tag__c`, `Release_Version__c`.
- **Messaging data model** — `Message__c` and related metadata in core; **portal file attachments + Experience Cloud file preview** (modal + `MessageFilesSupport.getFilePreviewUrl`) live in **this repo**. Additional **portal shell pages, OTP login, and extended controllers** ship with the **[Portal Add-On](https://github.com/Milestone-Consulting/Salesforce-Project-Management---Portal-Add-On)** when you need the full Experience Cloud package.
- **Flows** — Large bundle of Flow definitions for automation (count may change by release).

## Architecture (source layout)

| Path                     | Role                                                                                                                   |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `force-app/main/default` | **Default (and only) package directory** in this project: objects, LWCs, Apex, flows, internal permission sets, tests. Includes **portal-oriented LWCs** (`c-file-manager`, `c-portal-messaging`, `c-portal-file-attachments`, `c-portal-file-preview-modal`, etc.) for use on Experience Cloud sites. |

**Optional portal:** clone and deploy **[Salesforce-Project-Management---Portal-Add-On](https://github.com/Milestone-Consulting/Salesforce-Project-Management---Portal-Add-On)** as a second Salesforce project after core for the full portal experience. See the [deployment overview](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Deployment-Overview) and [Portal Add-On](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/portal-add-on).

### Experience Cloud file preview (core)

When `c-portal-file-attachments` runs on an **Experience Cloud** site, file name clicks open **`c-portal-file-preview-modal`**, which calls **`MessageFilesSupport.getFilePreviewUrl`**. When **`linked-entity-id`** is set (e.g. **`c-file-manager`** passes the **`Message__c`** Id for thread attachments), access is authorized via **`ContentDocumentLink`** from that record to the file—the same visibility as the attachment list—so portal users are not blocked when a direct **`ContentVersion`** query returns no rows. Otherwise the method falls back to a **`ContentVersion`** visibility check (e.g. record pages). **`MessageFilesLinkWorker`** then creates or reuses a **`ContentDistribution`** and returns **`DistributionPublicUrl`** for the iframe.

**Setup checklist for portal users**

- Portal users should have **`Client_Project_Management_Portal_User`** (core metadata), which includes **Apex** access to **`MessagingController`** (thread), **`MessagingPinnedSupport`** (pinned panel), **`MessageFilesSupport`** (attachments + preview), plus **Read** on **`ContentDocument`**, **`ContentDocumentLink`**, **`ContentVersion`**, and **Create** + **Read** on **`ContentDistribution`**. Without **Create on ContentDistribution**, `getFilePreviewUrl` cannot insert a distribution; `without sharing` does not bypass object CRUD.
- If you use a **custom** portal permission set instead, grant the same **Apex class** and **object permissions**, or mirror them on the Experience Cloud **member** / **guest** profile under **Public Access Settings**.
- Prefer file rows that include **`contentVersionId`**; if only **`contentDocumentId`** is present, core resolves the latest version via **`getLatestContentVersionIdsForDocuments`**.
- **`c-file-manager`** can set **`is-experience-cloud`** when the site URL does not contain `/s/` so preview still uses the modal instead of unsupported LEX **`filePreview`** navigation.
- Fallback for errors or blocked iframes: **Open in new tab** uses shepherd download URLs via **`experiencePathUtils.openShepherdDownloadInNewTab`** (also re-exported from **`messageFilesCore`** and **`portalCommon`** for convenience).

**API version:** see `sfdx-project.json` (`sourceApiVersion`).

## Custom objects (inventory)

| API name                                                     | Purpose                                                           |
| ------------------------------------------------------------ | ----------------------------------------------------------------- |
| `Project__c`                                                 | Engagement / body of work.                                        |
| `Project_Task__c`                                            | Tasks, subtasks, progress, review, assignments.                   |
| `Project_Task_Relationship__c`                               | Task-to-task links and dependency graph.                          |
| `Message__c`                                                 | Messaging records (UI/controllers for portal contexts in add-on). |
| `Time_Sheet_Entries__c`                                      | Time entry lines.                                                 |
| `Release_Notes__c` / `Release_Tag__c` / `Release_Version__c` | Release documentation structure.                                  |

Custom metadata types include **`Milestone_Task_Notification_Settings__mdt`** and **`OTP_Cleanup_Config__mdt`** (OTP/schedulers are exercised when the Portal Add-On is deployed—see [Setup Guide](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Setup-Guide)).

## Permission sets (core)

| API name                         | Typical users                                    |
| -------------------------------- | ------------------------------------------------ |
| `Client_Project_Management_Portal_User` | Experience Cloud portal users (messaging, tasks, projects, file list/preview). |
| `Project_Management_User`        | Internal user, limited access.                   |
| `Project_Management_Team_Member` | Internal delivery team.                          |
| `Project_Management_Manager`     | Managers (view-all style patterns per metadata). |
| `Project_Management_Admin`       | Administrators / full config.                    |

**Portal Add-On** adds **`Customer_Portal_Manager`** (internal users toggling portal flags on Account/Contact) and legacy **`Community_User`**—see the add-on repo and [Permission Sets](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Permission-Sets). **`Client_Project_Management_Portal_User`** ships in **core** (this repo).

Details: [Permission Sets](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Permission-Sets).

## Documentation (wiki)

**Primary documentation** is the **[GitHub Wiki](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki)** (product, requirements, licensing, deployment, setup, data model).

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
3. Deploy: `sf project deploy start --source-dir force-app` (optional: `--test-level RunRelevantTests` for [Run Relevant Tests](https://help.salesforce.com/s/articleView?id=release-notes.rn_apex_run_relevant_tests.htm&release=260&type=5); see wiki **Deployment Overview**).
4. Assign **core** permission sets to pilot users.
5. Complete **[Setup Guide](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Setup-Guide)**.
6. If you use Experience Cloud, deploy the **[Portal Add-On](https://github.com/Milestone-Consulting/Salesforce-Project-Management---Portal-Add-On)** and complete its setup (cache, email, site, schedulers).

> Avoid repeatedly deploying **only** individual Apex files from the IDE if you rely on **`Task_Management_ApexTests_Full`** in Setup—keep **`force-app/main/default/testSuites/Task_Management_ApexTests_Full.testSuite-meta.xml`** in sync with a **full** `force-app` deploy when possible.

**Check-only deploy (recommended before production):** from the repo root, with your default org set (`sf config get target-org`) or add `--target-org <alias>`:

```bash
npm run deploy:validate
```

That runs `sf project deploy start --dry-run --test-level RunRelevantTests` against `force-app`, matching Salesforce’s **Run Relevant Tests** behavior for the components in that deploy. For a **full regression** pass (every core test class in source), still run the **`Task_Management_ApexTests_Full`** suite (`sf apex run test --test-suite Task_Management_ApexTests_Full` — see [Setup Guide](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Setup-Guide)).

### Install unlocked package (released version)

Install **before production** in a **full sandbox** when possible. After install, complete the **[Setup Guide](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Setup-Guide)** and assign **core** permission sets.

**Subscriber package version Id (current released build):** `04tQm0000039aAbIAI`  
_Update this Id in the table below whenever Milestone promotes a new package version (see internal guide)._

| Environment    | Install link                                                                                                                      |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **Production** | [Install in production (login.salesforce.com)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tQm0000039aAbIAI) |
| **Sandbox**    | [Install in sandbox (test.salesforce.com)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tQm0000039aAbIAI)      |

You can also install from the CLI after authorizing the target org:

```bash
sf package install --package 04tQm0000039aAbIAI --target-org yourOrgAlias
```

**Milestone internal:** creating package versions, code coverage, and promotion — see **[Internal Unlocked Package Release](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/internal-unlocked-package-release)** (wiki).

## System requirements (summary)

- Salesforce **Enterprise** (or higher) typical for full Experience Cloud; confirm with your AE.
- **Experience Cloud** licenses for external users **if** you deploy the Portal Add-On.
- **Platform Cache** and related items when using OTP portal login (add-on).
- **Salesforce CLI** (`sf`), **Node.js** for LWC tooling (`npm install`).

Full checklist: [System requirements](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/System-Requirements).

## Development

### Prerequisites

- Salesforce CLI (`sf`)
- Node.js and npm
- VS Code with Salesforce Extensions (recommended)

**Scratch orgs / packaging:** This repo includes **`.sf/config.json`** with **`org-capitalize-record-types=true`** so record types from scratch definitions stay **capitalized** when Salesforce changes the CLI default. Keep that key if you merge local `sf` settings (`target-org`, `target-dev-hub`, etc.) into the same file. Other contents under **`.sf/`** (for example **`orgs/`**) stay gitignored.

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
- **Wiki:** [Licensing and support](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Licensing-and-Support).

Repository issues may be used for **public** bug reports or discussions **if** your program allows—confirm with Milestone before relying on GitHub for SLA-bound support.
