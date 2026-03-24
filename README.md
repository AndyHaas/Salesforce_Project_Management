# Milestone Salesforce Project Management

**Commercial Salesforce solution** for delivery organizations that need **projects**, **tasks**, **dependencies**, **time**, and **review workflows** in **your** Salesforce org. **Optional client-facing Experience Cloud** (OTP login, portal UI, portal messaging) is a separate **[Portal Add-On](https://github.com/Milestone-Consulting/Salesforce-Project-Management---Portal-Add-On)** repository that deploys into the same org after core.

> This repository contains **unmanaged metadata** (Apex, LWC, flows, objects, permission sets). **Purchased customers** receive rights to deploy and use it per their agreement with **Milestone Consulting**. [Product overview](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Product-Overview) · [Licensing & support](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Licensing-and-Support) · [Portal Add-On wiki](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/reference/portal-add-on)

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
- **Messaging data model** — `Message__c` and related metadata in core; **portal/Lightning messaging UI and controllers** ship with the **[Portal Add-On](https://github.com/Milestone-Consulting/Salesforce-Project-Management---Portal-Add-On)** when you need Experience Cloud.
- **Flows** — Large bundle of Flow definitions for automation (count may change by release).

## Architecture (source layout)

| Path                     | Role                                                                                                                   |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `force-app/main/default` | **Default (and only) package directory** in this project: objects, LWCs, Apex, flows, internal permission sets, tests. |

**Optional portal:** clone and deploy **[Salesforce-Project-Management---Portal-Add-On](https://github.com/Milestone-Consulting/Salesforce-Project-Management---Portal-Add-On)** as a second Salesforce project after core. See the [deployment overview](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Deployment-Overview) and [Portal Add-On](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/reference/portal-add-on).

**API version:** see `sfdx-project.json` (`sourceApiVersion`).

## Custom objects (inventory)

| API name                                                     | Purpose                                                                |
| ------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `Project__c`                                                 | Engagement / body of work.                                             |
| `Project_Task__c`                                            | Tasks, subtasks, progress, review, assignments.                        |
| `Project_Task_Relationship__c`                               | Task-to-task links and dependency graph.                               |
| `Message__c`                                                 | Messaging records (UI/controllers for portal contexts in add-on).      |
| `Time_Sheet_Entries__c`                                      | Time entry lines.                                                      |
| `Portal_Config__c`                                           | Portal-related configuration records (used with add-on as applicable). |
| `Release_Notes__c` / `Release_Tag__c` / `Release_Version__c` | Release documentation structure.                                       |

Custom metadata types include **`Milestone_Task_Notification_Settings__mdt`** and **`OTP_Cleanup_Config__mdt`** (OTP/schedulers are exercised when the Portal Add-On is deployed—see [Setup Guide](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Setup-Guide)).

## Permission sets (core)

| API name                         | Typical users                                    |
| -------------------------------- | ------------------------------------------------ |
| `Project_Management_User`        | Internal user, limited access.                   |
| `Project_Management_Team_Member` | Internal delivery team.                          |
| `Project_Management_Manager`     | Managers (view-all style patterns per metadata). |
| `Project_Management_Admin`       | Administrators / full config.                    |

**`Client_Project_Management_Portal_User`** and other client portal access ship with the **[Portal Add-On](https://github.com/Milestone-Consulting/Salesforce-Project-Management---Portal-Add-On)**.

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
3. Deploy: `sf project deploy start --source-dir force-app`
4. Assign **core** permission sets to pilot users.
5. Complete **[Setup Guide](https://github.com/Milestone-Consulting/Salesforce-Project-Management/wiki/Setup-Guide)**.
6. If you use Experience Cloud, deploy the **[Portal Add-On](https://github.com/Milestone-Consulting/Salesforce-Project-Management---Portal-Add-On)** and complete its setup (cache, email, site, schedulers).

> Avoid repeatedly deploying **only** individual Apex files from the IDE if you rely on **`TaskProjectTests`** in Setup—keep **`force-app/main/default/testSuites/TaskProjectTests.testSuite-meta.xml`** in sync with a **full** `force-app` deploy when possible.

### Install link (unlocked package — same metadata, subscriber-friendly URL)

Salesforce does not generate a permanent install URL from source on GitHub alone. You create an **unlocked** second-generation package in a **Dev Hub**, publish a **package version**, then share the URL below with the **subscriber package version Id** (`04t…`).

**Install URL (production orgs)**

```text
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tXXXXXXXXXXXXXXX
```

**Install URL (sandbox orgs)**

```text
https://test.salesforce.com/packaging/installPackage.apexp?p0=04tXXXXXXXXXXXXXXX
```

Replace `04tXXXXXXXXXXXXXXX` with your version’s subscriber Id (from the `sf package version create` output, **Setup → Packaging → Package Manager**, or `sf package version list`).

**Maintainer: create the package once (writes `packageAliases` in `sfdx-project.json`)**

```bash
sf package create \
  --name "Milestone Project Management Core" \
  --package-type Unlocked \
  --path force-app \
  --no-namespace \
  --target-dev-hub YourDevHubAlias
```

**Maintainer: create a new installable version**

```bash
sf package version create \
  --package "Milestone Project Management Core" \
  --installation-key-bypass \
  --wait 90 \
  --target-dev-hub YourDevHubAlias
```

After the version is **Available**, copy the `04t` Id into the URLs above. Optional: promote the version for production installs per your release process (`sf package version promote`).

> **Legacy unmanaged (1GP)** packages use **Setup → Package Manager** to upload an unmanaged package; the install link still uses the same `installPackage.apexp?p0=` pattern with the uploaded version’s Id. New work should prefer **unlocked** packages and the CLI flow above.

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
