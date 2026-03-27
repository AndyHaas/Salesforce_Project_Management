/**
 * @description Grouped Task List Component
 *
 * Displays tasks grouped by status with expandable subtasks, hover field details,
 * and "Me" mode filtering. Task messages use MessagingController / portalMessaging, not this list payload.
 *
 * USAGE:
 * - Used in: Standalone component, can be placed on any Lightning page
 * - Apex Controller: ProjectTaskDashboardController.getGroupedTasksWithSubtasks()
 *
 * Experience Cloud: host context uses CurrentPageReference (comm__ / comm_lwr__) plus browser hints.
 * Set @api portalExperienceMode to "experience" when auto-detect fails (e.g. fully custom domains).
 * Experience Builder reads properties from js-meta targetConfig lightningCommunity__Default (not lightningCommunity__Page).
 */
import { LightningElement, api, wire, track } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { subscribe, MessageContext, unsubscribe, APPLICATION_SCOPE } from "lightning/messageService";
import { deleteRecord } from "lightning/uiRecordApi";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { updateRecord } from "lightning/uiRecordApi";
import PROJECT_TASK_OBJECT from "@salesforce/schema/Project_Task__c";
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import PROJECT_OBJECT from "@salesforce/schema/Project__c";
import getGroupedTasksWithSubtasks from "@salesforce/apex/ProjectTaskDashboardController.getGroupedTasksWithSubtasks";
import getGroupedTasksWithSubtasksByProject from "@salesforce/apex/ProjectTaskDashboardController.getGroupedTasksWithSubtasksByProject";
import getStatusColors from "@salesforce/apex/StatusColorController.getStatusColors";
import getCurrentUserAccountId from "@salesforce/apex/ProjectTaskDashboardController.getCurrentUserAccountId";
import getCurrentUserContactId from "@salesforce/apex/ProjectTaskDashboardController.getCurrentUserContactId";
import getDisplayDensity from "@salesforce/apex/DisplayDensityController.getDisplayDensity";
import { refreshApex } from "@salesforce/apex";
import { ensureSitePath } from "c/experiencePathUtils";
import ACCOUNT_FILTER_MESSAGE_CHANNEL from "@salesforce/messageChannel/AccountFilter__c";
import USER_ID from "@salesforce/user/Id";
import {
  STANDARD_ACCOUNT_KEY_PREFIX,
  salesforceIdsEqual,
  inferExperienceCloudFromBrowserLocation,
  isExperienceCloudPageReferenceType
} from "./groupedTaskListUtils";

/** Status picklist values hidden by default in list filters (users can enable via checkboxes). */
const LIST_FILTER_STATUS_UNCHECKED_BY_DEFAULT = new Set(["Completed", "Removed"]);

export default class GroupedTaskList extends NavigationMixin(LightningElement) {
  @api recordId; // Account or Project Id on record pages (see resolvedProjectId)
  @api accountId; // Can be set manually for App/Home pages
  _projectId;
  @api
  get projectId() {
    return this._projectId;
  }
  set projectId(value) {
    this._projectId = value;
  }
  /**
   * @deprecated Ignored. Use list filters (Account) or @api accountId / AccountFilter message channel.
   * Property remains in js-meta.xml because Salesforce blocks removing in-use properties from deployed pages.
   */
  @api showAccountFilter;
  @api useCurrentUserAccount = false; // When true, default to current user's account if none supplied (for portal use)
  @api context = "portal"; // DEPRECATED. Kept for backward compatibility.
  /** When true, internal Salesforce UX (LEX). On Experience sites use portalExperienceMode=salesforce instead when possible. */
  @api isSalesforceContext = false;
  /**
   * How to treat host UX when auto-detection is wrong (e.g. custom portal domains).
   * auto — use page reference + browser heuristics.
   * experience — always use portal navigation, My Tasks, hide org account combobox.
   * salesforce — never treat as Experience Cloud for chrome (rare on member sites).
   */
  @api portalExperienceMode = "auto";
  /** When true, hides the list-view filter panel and toolbar control. */
  @api hideListViewFilterPanel = false;

  @wire(MessageContext)
  messageContext;

  @wire(CurrentPageReference)
  resolvePageReference(pageRef) {
    if (!pageRef) {
      return;
    }

    if (isExperienceCloudPageReferenceType(pageRef.type)) {
      this._runtimeDetectedExperienceCloud = true;
    }

    const { attributes = {}, state = {} } = pageRef;
    const objectApiName = attributes.objectApiName || "";
    const recordIdFromRef = state.recordId || attributes.recordId;

    /**
     * When @api recordId is missing, capture host Account / Project from the page.
     * Never assign generic recordId to projectId — on Account pages that value is the Account Id and would
     * incorrectly drive getGroupedTasksWithSubtasksByProject.
     */
    if (!this.recordId && recordIdFromRef && typeof recordIdFromRef === "string") {
      const pre = recordIdFromRef.substring(0, 3);
      const matchesProjectPrefix = this._projectKeyPrefix && pre === this._projectKeyPrefix;
      const matchesAccountPrefix =
        pre === STANDARD_ACCOUNT_KEY_PREFIX || (this._accountKeyPrefix && pre === this._accountKeyPrefix);
      const isProjectObject = objectApiName && objectApiName.endsWith("Project__c");
      const isAccountObject = objectApiName === "Account";

      if (isProjectObject || (matchesProjectPrefix && !matchesAccountPrefix)) {
        this._resolvedHostRecordIdFromPage = recordIdFromRef;
        if (!this._projectId) {
          this._projectId = recordIdFromRef;
        }
        return;
      }
      if (
        isAccountObject ||
        (matchesAccountPrefix && !matchesProjectPrefix) ||
        (!objectApiName && pre === STANDARD_ACCOUNT_KEY_PREFIX)
      ) {
        this._resolvedHostRecordIdFromPage = recordIdFromRef;
        return;
      }
    }

    if (this.projectId) {
      return;
    }

    let projectId = state.c__projectId || attributes.c__projectId;

    if (!projectId && typeof window !== "undefined") {
      let pathname = window.location.pathname || "";
      pathname = pathname.replace(/^\/s/, "");
      const parts = pathname.split("/").filter(Boolean);
      const projectIdx = parts.indexOf("project");
      if (projectIdx !== -1 && projectIdx + 1 < parts.length) {
        projectId = decodeURIComponent(parts[projectIdx + 1]);
      }
    }

    if (projectId && projectId !== this._projectId) {
      console.log("[DEBUG] resolvePageReference - projectId from URL:", projectId);
      this._projectId = projectId;
    }

    if (!this.recordId && !this._resolvedHostRecordIdFromPage && typeof window !== "undefined") {
      let pathname = window.location.pathname || "";
      pathname = pathname.replace(/^\/s/, "");
      const parts = pathname.split("/").filter(Boolean);
      const accountIdx = parts.indexOf("account");
      if (accountIdx !== -1 && accountIdx + 1 < parts.length) {
        const candidate = decodeURIComponent(parts[accountIdx + 1]);
        if (candidate.startsWith(STANDARD_ACCOUNT_KEY_PREFIX)) {
          this._resolvedHostRecordIdFromPage = candidate;
        }
      }
    }
  }

  /** Host record id for Account / Project scoping (flexipage recordId or page-ref fallback). */
  get effectiveRecordId() {
    return this.recordId || this._resolvedHostRecordIdFromPage || undefined;
  }

  /** Set true when page ref or browser location indicates Experience Cloud (before portalExperienceMode override). */
  _runtimeDetectedExperienceCloud = false;

  /**
   * Effective Experience Cloud (member site) context for navigation and chrome.
   * Uses portalExperienceMode when not "auto"; otherwise runtime detection.
   */
  get isExperienceSite() {
    const mode = String(this.portalExperienceMode || "auto")
      .trim()
      .toLowerCase();
    if (mode === "experience" || mode === "portal" || mode === "community") {
      return true;
    }
    if (mode === "salesforce" || mode === "internal" || mode === "lex") {
      return false;
    }
    return this._runtimeDetectedExperienceCloud;
  }
  statusGroups = [];
  filteredStatusGroups = []; // Filtered tasks based on "Me" mode and other toggles
  isLoading = true; // Show spinner while fetching tasks
  expandedTasks = new Set(); // Track which tasks have expanded subtasks
  collapsedStatuses = new Set(); // Track collapsed status groups
  subscription = null;
  _filteredAccountIds = [];
  refreshInterval = null; // Interval ID for periodic refresh
  showMyTasksOnly = false; // "Me" mode toggle
  currentUserId = USER_ID; // Current user ID
  currentUserContactId = null; // Current user's Contact ID (for portal)
  @track _listFilterPanelOpen = false;
  @track _lvProject = "";
  @track _lvAccount = "";
  @track _lvPm = "";
  @track _lvDeveloper = "";
  /** Status values included in the list (multi-select); Completed/Removed off by default when present. */
  @track _lvVisibleStatuses = [];
  /** When true, next rebuild of list filter options resets status selection to defaults (e.g. new project). */
  _resetListFilterStatusSelectionOnNextRebuild = false;
  @track _lvPriority = "";
  @track _listFilterOptionsBundle = {
    project: [{ label: "All projects", value: "" }],
    account: [{ label: "All accounts", value: "" }],
    status: [{ label: "All statuses", value: "" }],
    priority: [{ label: "All priorities", value: "" }],
    pm: [{ label: "All project managers", value: "" }],
    developer: [{ label: "All developers", value: "" }]
  };
  error;
  summaryFieldDefinitions = [];
  summaryFieldDefinitionMap = {};
  @track editingTaskId = null; // Track which task is being edited inline
  @track editingTaskName = ""; // Store the task name being edited
  @track editingField = null; // Track which field is being edited: { taskId, fieldApiName, fieldValue }
  objectPermissions = { canEdit: false, canDelete: false }; // Object-level permissions
  statusColors = {}; // Status colors from field metadata (loaded from Apex)
  recordTypes = []; // Available record types for Project_Task__c
  defaultRecordTypeId = null; // Default record type ID

  currentUserAccountId = null; // Account associated to the logged-in user (Experience Cloud)
  @track _resolvedHostRecordIdFromPage;

  /** Key prefixes from getObjectInfo - used to treat recordId as Account vs Project__c */
  _accountKeyPrefix;
  _projectKeyPrefix;

  @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
  wiredAccountObjectInfo({ data, error }) {
    if (data) {
      this._accountKeyPrefix = data.keyPrefix;
    } else if (error) {
      console.warn("groupedTaskList: Account object info failed", error);
    }
  }

  @wire(getObjectInfo, { objectApiName: PROJECT_OBJECT })
  wiredProjectObjectInfo({ data, error }) {
    if (data) {
      this._projectKeyPrefix = data.keyPrefix;
    } else if (error) {
      console.warn("groupedTaskList: Project__c object info failed", error);
    }
  }

  /** True when flexipage host record is an Account */
  get isAccountRecordPage() {
    const rid = this.effectiveRecordId;
    if (!rid || typeof rid !== "string" || rid.length < 3) {
      return false;
    }
    const pre = rid.substring(0, 3);
    return pre === STANDARD_ACCOUNT_KEY_PREFIX || (this._accountKeyPrefix && pre === this._accountKeyPrefix);
  }

  /** True when flexipage host record is a Project__c */
  get isProjectRecordPage() {
    const rid = this.effectiveRecordId;
    if (!rid || typeof rid !== "string" || rid.length < 3) {
      return false;
    }
    return this._projectKeyPrefix && rid.substring(0, 3) === this._projectKeyPrefix;
  }

  /** Load tasks via getGroupedTasksWithSubtasksByProject (not account/global wire) */
  get useProjectScopedWire() {
    if (this.projectId) {
      return true;
    }
    return this.isProjectRecordPage;
  }

  /**
   * Project Id passed to Apex project wire; undefined when account/global path should load data.
   */
  get projectIdForWire() {
    if (!this.useProjectScopedWire) {
      return undefined;
    }
    if (this.projectId) {
      return this.projectId;
    }
    return this.effectiveRecordId;
  }

  /** @deprecated use projectIdForWire - kept for minimal churn in debug logs */
  get resolvedProjectId() {
    return this.projectIdForWire;
  }

  // Density mode: 'comfy' (default) or 'compact' - loaded from user's Salesforce preference
  @track density = "comfy";

  @wire(getCurrentUserAccountId)
  wiredUserAccount({ error, data }) {
    if (data) {
      this.currentUserAccountId = data;
      // If no other filters are set and useCurrentUserAccount is enabled, apply the user account immediately
      if (this.useCurrentUserAccount) {
        this.refreshFilteredStatusGroups();
      }
    } else if (error) {
      console.warn("Error loading current user account:", error);
    }
  }

  @wire(getCurrentUserContactId)
  wiredUserContact({ error, data }) {
    if (data) {
      this.currentUserContactId = data;
    } else if (error) {
      console.warn("Error loading user contact:", error);
    }
  }

  @wire(getDisplayDensity)
  wiredDisplayDensity({ error, data }) {
    if (data) {
      // Set density from user's Salesforce preference
      this.density = data === "compact" ? "compact" : "comfy";
      // If data is already loaded, update row classes
      if (this.statusGroups && this.statusGroups.length > 0) {
        this.updateTaskRowClasses();
        this.refreshFilteredStatusGroups();
      }
    } else if (error) {
      console.warn("Error loading display density preference:", error);
      // Default to 'comfy' if we can't load the preference
      this.density = "comfy";
    }
  }

  get effectiveAccountIds() {
    if (this.useProjectScopedWire) {
      return [];
    }

    let accountIds = [];

    if (this._filteredAccountIds.length > 0) {
      accountIds = this._filteredAccountIds;
    } else if (this.isAccountRecordPage) {
      if (this.effectiveRecordId) {
        accountIds = [this.effectiveRecordId];
      }
    } else if (this.effectiveRecordId) {
      const rid = this.effectiveRecordId;
      const pre = typeof rid === "string" && rid.length >= 3 ? rid.substring(0, 3) : "";
      const matchesProject = this._projectKeyPrefix && pre === this._projectKeyPrefix;
      const matchesAccount =
        pre === STANDARD_ACCOUNT_KEY_PREFIX || (this._accountKeyPrefix && pre === this._accountKeyPrefix);

      if (matchesProject) {
        accountIds = [];
      } else if (matchesAccount) {
        accountIds = [rid];
      } else if (!this._accountKeyPrefix && !this._projectKeyPrefix) {
        accountIds = [rid];
      }
    } else if (this.accountId) {
      accountIds = [this.accountId];
    } else if (this.useCurrentUserAccount && this.currentUserAccountId) {
      accountIds = [this.currentUserAccountId];
    }

    const result = accountIds.filter((id) => id != null && (typeof id === "string" ? id.trim().length > 0 : true));

    if (result.length === 0 && this.isExperienceSite) {
      if (this.isAccountRecordPage || this.isProjectRecordPage) {
        return result;
      }
      return this.currentUserAccountId ? [this.currentUserAccountId] : [];
    }

    return result;
  }

  get isFilteredByAccount() {
    return this.effectiveAccountIds.length > 0;
  }

  get isFilteredByProject() {
    return this.useProjectScopedWire && !!this.projectIdForWire;
  }

  /** Badge only when project scope is non-obvious (e.g. @api projectId on app page). Hidden on Project record pages. */
  get showProjectScopeFilterBadge() {
    return this.isFilteredByProject && !this.isProjectRecordPage;
  }

  /** Internal LEX chrome: isSalesforceContext or portalExperienceMode salesforce/internal/lex (single knob on portals: portalExperienceMode). */
  get prefersInternalSalesforceUx() {
    if (this.isSalesforceContext === true) {
      return true;
    }
    const mode = String(this.portalExperienceMode || "auto")
      .trim()
      .toLowerCase();
    return mode === "salesforce" || mode === "internal" || mode === "lex";
  }

  get isPortalMode() {
    if (this.prefersInternalSalesforceUx) {
      return false;
    }
    if (this.context === "salesforce") {
      return false;
    }
    if (this.isExperienceSite === true) {
      return true;
    }
    return false;
  }

  get showListViewFilterUi() {
    return this.hideListViewFilterPanel !== true;
  }

  get listFilterPanelClass() {
    return this._listFilterPanelOpen ? "list-filter-panel list-filter-panel_open" : "list-filter-panel";
  }

  get listFilterMainClass() {
    return this._listFilterPanelOpen && this.showListViewFilterUi
      ? "list-filter-main list-filter-main_panel-open"
      : "list-filter-main";
  }

  get listFilterPanelHidden() {
    return !this._listFilterPanelOpen;
  }

  get hasNonStatusListFilters() {
    return !!(this._lvProject || this._lvAccount || this._lvPm || this._lvDeveloper || this._lvPriority);
  }

  get listFilterStatusKeysFromOptions() {
    return (this._listFilterOptionsBundle.status || [])
      .map((o) => o.value)
      .filter((v) => v && String(v).trim().length > 0);
  }

  get hasNonDefaultStatusListFilter() {
    const keys = this.listFilterStatusKeysFromOptions;
    if (keys.length === 0) {
      return false;
    }
    const sortedKeys = [...keys].sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" }));
    const defaultVisible = sortedKeys.filter((s) => !LIST_FILTER_STATUS_UNCHECKED_BY_DEFAULT.has(s));
    const cur = [...(this._lvVisibleStatuses || [])].sort((a, b) =>
      a.localeCompare(b, undefined, { sensitivity: "base" })
    );
    if (cur.length !== defaultVisible.length) {
      return true;
    }
    return cur.some((s, i) => s !== defaultVisible[i]);
  }

  get hasActiveListFilters() {
    return this.hasNonStatusListFilters || this.hasNonDefaultStatusListFilter;
  }

  get listViewFilterOptionsProject() {
    return this._listFilterOptionsBundle.project;
  }

  get listViewFilterOptionsAccount() {
    return this._listFilterOptionsBundle.account;
  }

  get listViewStatusCheckboxRows() {
    const opts = (this._listFilterOptionsBundle.status || []).filter((o) => o.value);
    const visible = new Set(this._lvVisibleStatuses || []);
    return opts.map((o) => ({
      value: o.value,
      label: o.label,
      checked: visible.has(o.value)
    }));
  }

  get listViewFilterOptionsPriority() {
    return this._listFilterOptionsBundle.priority;
  }

  get listViewFilterOptionsPm() {
    return this._listFilterOptionsBundle.pm;
  }

  get listViewFilterOptionsDeveloper() {
    return this._listFilterOptionsBundle.developer;
  }

  toggleListFilterPanel() {
    this._listFilterPanelOpen = !this._listFilterPanelOpen;
  }

  handleListFilterProjectChange(event) {
    this._lvProject = event?.detail?.value ?? "";
    this.refreshFilteredStatusGroups();
  }

  handleListFilterAccountChange(event) {
    this._lvAccount = event?.detail?.value ?? "";
    this.refreshFilteredStatusGroups();
  }

  handleListFilterPmChange(event) {
    this._lvPm = event?.detail?.value ?? "";
    this.refreshFilteredStatusGroups();
  }

  handleListFilterDeveloperChange(event) {
    this._lvDeveloper = event?.detail?.value ?? "";
    this.refreshFilteredStatusGroups();
  }

  handleListFilterStatusCheckboxChange(event) {
    const status = event.currentTarget?.dataset?.status;
    if (status === undefined || status === null) {
      return;
    }
    const checked = !!event.detail?.checked;
    const set = new Set(this._lvVisibleStatuses || []);
    if (checked) {
      set.add(status);
    } else {
      set.delete(status);
    }
    this._lvVisibleStatuses = [...set].sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" }));
    this.refreshFilteredStatusGroups();
  }

  handleListFilterPriorityChange(event) {
    this._lvPriority = event?.detail?.value ?? "";
    this.refreshFilteredStatusGroups();
  }

  handleListFilterReset() {
    this._lvProject = "";
    this._lvAccount = "";
    this._lvPm = "";
    this._lvDeveloper = "";
    this._lvPriority = "";
    const keys = this.listFilterStatusKeysFromOptions;
    this._lvVisibleStatuses = keys
      .filter((s) => !LIST_FILTER_STATUS_UNCHECKED_BY_DEFAULT.has(s))
      .sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" }));
    this.refreshFilteredStatusGroups();
  }

  /**
   * Builds combobox options from loaded task rows (parents + subtasks).
   */
  rebuildListViewFilterOptions() {
    const projects = new Set();
    const accounts = new Set();
    const statuses = new Set();
    const priorities = new Set();
    const pmById = new Map();
    const devById = new Map();

    const consider = (t) => {
      if (!t) {
        return;
      }
      const pn = (t.projectName || "").trim();
      if (pn) {
        projects.add(pn);
      }
      const an = (t.accountName || "").trim();
      if (an) {
        accounts.add(an);
      }
      const st = (t.status || "").trim();
      if (st) {
        statuses.add(st);
      }
      const pr = (t.priority || "").trim();
      if (pr) {
        priorities.add(pr);
      }
      const pmId = t.projectManagerId;
      const pmName = (t.projectManagerName || "").trim();
      if (pmId && pmName) {
        pmById.set(pmId, pmName);
      }
      const dId = t.developerId;
      const dName = (t.developerName || "").trim();
      if (dId && dName) {
        devById.set(dId, dName);
      }
    };

    (this.statusGroups || []).forEach((g) => {
      (g.tasks || []).forEach((task) => {
        consider(task);
        (task.subtasks || []).forEach((st) => consider(st));
      });
    });

    const toOpts = (labelAll, values, useIdMap) => {
      const base = [{ label: labelAll, value: "" }];
      if (useIdMap) {
        return base.concat(
          [...useIdMap.entries()]
            .sort((a, b) => a[1].localeCompare(b[1], undefined, { sensitivity: "base" }))
            .map(([id, name]) => ({ label: name, value: id }))
        );
      }
      return base.concat(
        [...values]
          .sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" }))
          .map((v) => ({ label: v, value: v }))
      );
    };

    this._listFilterOptionsBundle = {
      project: toOpts("All projects", projects, null),
      account: toOpts("All accounts", accounts, null),
      status: toOpts("All statuses", statuses, null),
      priority: toOpts("All priorities", priorities, null),
      pm: toOpts("All project managers", null, pmById),
      developer: toOpts("All developers", null, devById)
    };

    const statusKeysSorted = [...statuses].sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" }));
    this._syncListFilterVisibleStatusesAfterRebuild(statusKeysSorted);
  }

  /**
   * Keeps multi-select status filters aligned with values present in the grid.
   * New statuses default to visible except Completed/Removed; project changes can force a full reset.
   *
   * @param {string[]} allStatusesSorted Distinct status picklist values from loaded tasks.
   */
  _syncListFilterVisibleStatusesAfterRebuild(allStatusesSorted) {
    if (this._resetListFilterStatusSelectionOnNextRebuild) {
      this._resetListFilterStatusSelectionOnNextRebuild = false;
      this._lvVisibleStatuses = allStatusesSorted.filter((s) => !LIST_FILTER_STATUS_UNCHECKED_BY_DEFAULT.has(s));
      return;
    }

    const prev = new Set(this._lvVisibleStatuses || []);

    if (prev.size === 0 && allStatusesSorted.length > 0) {
      this._lvVisibleStatuses = allStatusesSorted.filter((s) => !LIST_FILTER_STATUS_UNCHECKED_BY_DEFAULT.has(s));
      return;
    }

    const next = new Set();
    for (const s of allStatusesSorted) {
      if (prev.has(s)) {
        next.add(s);
      } else if (!LIST_FILTER_STATUS_UNCHECKED_BY_DEFAULT.has(s)) {
        next.add(s);
      }
    }
    this._lvVisibleStatuses = [...next].sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" }));
  }

  isTaskStatusVisibleForListFilter(statusValue) {
    const st = (statusValue || "").trim();
    if (!st) {
      return false;
    }
    return (this._lvVisibleStatuses || []).includes(st);
  }

  taskMatchesListFilters(task) {
    if (!task) {
      return false;
    }
    if (this._lvProject) {
      const pn = (task.projectName || "").trim();
      if (pn !== this._lvProject) {
        return false;
      }
    }
    if (this._lvAccount) {
      const an = (task.accountName || "").trim();
      if (an !== this._lvAccount) {
        return false;
      }
    }
    if (this._lvPm && task.projectManagerId !== this._lvPm) {
      return false;
    }
    if (this._lvDeveloper && task.developerId !== this._lvDeveloper) {
      return false;
    }
    if (!this.isTaskStatusVisibleForListFilter(task.status)) {
      return false;
    }
    if (this._lvPriority) {
      const pr = (task.priority || "").trim();
      if (pr !== this._lvPriority) {
        return false;
      }
    }
    return true;
  }

  filterTaskForListView(task) {
    const parentOk = this.taskMatchesListFilters(task);
    const subtasks = (task.subtasks || []).filter((st) => this.taskMatchesListFilters(st));
    if (!parentOk && subtasks.length === 0) {
      return null;
    }
    if (!parentOk) {
      return { ...task, subtasks };
    }
    if (subtasks.length !== (task.subtasks || []).length) {
      return { ...task, subtasks };
    }
    return task;
  }

  filterGroupsForListView(groups) {
    return (groups || [])
      .map((g) => {
        const tasks = (g.tasks || []).map((t) => this.filterTaskForListView(t)).filter(Boolean);
        if (tasks.length === 0) {
          return null;
        }
        let totalEstimatedHours = 0;
        tasks.forEach((task) => {
          if (task.estimatedHours) {
            totalEstimatedHours += task.estimatedHours;
          }
          (task.subtasks || []).forEach((subtask) => {
            if (subtask.estimatedHours) {
              totalEstimatedHours += subtask.estimatedHours;
            }
          });
        });
        return {
          ...g,
          tasks,
          taskCount: tasks.length,
          totalEstimatedHours,
          formattedTotalEstimatedHours: this.formatHours(totalEstimatedHours)
        };
      })
      .filter((g) => g !== null);
  }

  connectedCallback() {
    // Status colors will be loaded via wire service
    // Supplement CurrentPageReference with browser hints (does not override comm__ / comm_lwr__ wire).
    try {
      if (typeof window !== "undefined") {
        const fromBrowser = inferExperienceCloudFromBrowserLocation({
          hostname: window.location.hostname,
          pathname: window.location.pathname
        });
        if (fromBrowser) {
          this._runtimeDetectedExperienceCloud = true;
        }
      }
    } catch {
      /* preserve wire-based _runtimeDetectedExperienceCloud */
    }

    if (this.messageContext) {
      this.subscription = subscribe(
        this.messageContext,
        ACCOUNT_FILTER_MESSAGE_CHANNEL,
        (message) => {
          if (message) {
            if (message.accountIds !== undefined) {
              this._filteredAccountIds = Array.isArray(message.accountIds) ? message.accountIds : [];
            } else if (message.accountId !== undefined) {
              this._filteredAccountIds = message.accountId ? [message.accountId] : [];
            }
          }
        },
        { scope: APPLICATION_SCOPE }
      );
    }

    // Set up resize observer for responsive button handling
  }

  renderedCallback() {
    // No dynamic responsive logic needed
  }

  handleMenuSelect(event) {
    const selectedValue = event.detail.value;

    switch (selectedValue) {
      case "myTasks":
        this.handleMeModeToggle();
        break;
      case "expandCollapseAll":
        this.handleExpandCollapseAll();
        break;
      case "expandCollapseAllSubtasks":
        this.handleExpandCollapseAllSubtasks();
        break;
      default:
        break;
    }
  }

  updateTaskRowClasses() {
    // No longer needed - table structure handles alignment automatically
    // This method is kept for backward compatibility but does nothing
  }

  get densityClass() {
    return this.density === "compact" ? "density-compact" : "density-comfy";
  }

  // Removed grid-related getters - now using HTML table structure

  wiredGroupedTasksResult;

  @wire(getGroupedTasksWithSubtasks, { accountIds: "$effectiveAccountIds" })
  wiredGroupedTasks(result) {
    // DEBUG: Log when this wire is called
    console.log(
      "[DEBUG] wiredGroupedTasks called - useProjectScopedWire:",
      this.useProjectScopedWire,
      "hasData:",
      !!result?.data
    );

    if (this.useProjectScopedWire) {
      console.log("[DEBUG] wiredGroupedTasks - project-scoped wire active, skipping account-based query");
      return;
    }
    this.wiredGroupedTasksResult = result;
    const { error, data } = result;
    this.isLoading = !data && !error;
    if (data) {
      try {
        const statusGroupsData = Array.isArray(data.statusGroups) ? data.statusGroups : [];
        this.summaryFieldDefinitions = Array.isArray(data.summaryFieldDefinitions) ? data.summaryFieldDefinitions : [];
        this.updateSummaryFieldDefinitionMap();
        // Update header classes after definitions are loaded
        this.updateSummaryFieldHeaderClasses();

        // Set up periodic refresh for auto-refresh on task changes
        if (!this.refreshInterval) {
          this.setupPeriodicRefresh();
        }

        // Add status header style to each status group and icon info to each task
        this.statusGroups = statusGroupsData.map((statusGroup) => {
          // Calculate total estimated hours for this status group
          let totalEstimatedHours = 0;
          const tasks = (statusGroup.tasks || []).map((task) => {
            const isExpanded = this.isTaskExpanded(task.id);

            // Add parent task hours
            const parentHours = task.estimatedHours || 0;
            totalEstimatedHours += parentHours;

            // Add subtask hours
            const subtasks = (task.subtasks || []).map((subtask) => {
              const subtaskHours = subtask.estimatedHours || 0;
              totalEstimatedHours += subtaskHours;
              const subtaskPermissions = this.getTaskPermissions();
              const subtaskHasMenu = subtaskPermissions.canEdit || subtaskPermissions.canDelete;
              const decoratedSubtask = this.decorateTaskRecord({
                ...subtask,
                formattedDueDate: subtask.dueDate ? this.formatDate(subtask.dueDate) : "",
                formattedEstimatedHours: subtask.estimatedHours ? this.formatHours(subtask.estimatedHours) : "",
                isEditing: this.editingTaskId === subtask.id,
                canEdit: subtaskPermissions.canEdit,
                canDelete: subtaskPermissions.canDelete,
                showMenu: subtaskHasMenu
              });
              // Update field editing state and computed properties
              if (decoratedSubtask.summaryFields) {
                decoratedSubtask.summaryFields = decoratedSubtask.summaryFields.map((field) => {
                  const dataTypeUpper = (field.dataType || "").toUpperCase();
                  const isEditing = this.isFieldEditing(subtask.id, field.apiName);
                  const isEditable = subtaskPermissions.canEdit && !field.isReference; // Editable if user can edit and field is not a reference
                  let inputValue = "";
                  let inputType = "text";

                  if (isEditing && this.editingField) {
                    if (dataTypeUpper === "BOOLEAN") {
                      inputValue = this.editingField.fieldValue === "true" || this.editingField.fieldValue === true;
                    } else {
                      inputValue = this.editingField.fieldValue || "";
                    }

                    if (dataTypeUpper === "DATE") {
                      inputType = "date";
                    } else if (dataTypeUpper === "DATETIME") {
                      inputType = "datetime-local";
                    } else if (
                      dataTypeUpper === "DOUBLE" ||
                      dataTypeUpper === "CURRENCY" ||
                      dataTypeUpper === "PERCENT" ||
                      dataTypeUpper === "INTEGER"
                    ) {
                      inputType = "number";
                    } else if (dataTypeUpper === "BOOLEAN") {
                      inputType = "checkbox";
                    }
                  } else {
                    // Use raw value when not editing
                    if (dataTypeUpper === "BOOLEAN") {
                      inputValue = field.rawValue === "true" || field.rawValue === true;
                    } else {
                      inputValue = field.rawValue || "";
                    }
                  }

                  return {
                    ...field,
                    isEditing: isEditing,
                    hasDataType: !!field.dataType,
                    isBoolean: dataTypeUpper === "BOOLEAN",
                    inputValue: inputValue,
                    inputType: inputType,
                    isEditable: isEditable
                  };
                });
              }
              return decoratedSubtask;
            });

            const permissions = this.getTaskPermissions();
            const hasMenu = permissions.canEdit || permissions.canDelete;
            const decoratedTask = this.decorateTaskRecord({
              ...task,
              isExpanded: isExpanded,
              iconName: isExpanded ? "utility:chevrondown" : "utility:chevronright",
              iconAltText: isExpanded ? "Collapse" : "Expand",
              subtaskLabel: task.subtaskCount === 1 ? "subtask" : "subtasks",
              formattedDueDate: task.dueDate ? this.formatDate(task.dueDate) : "",
              formattedEstimatedHours: task.estimatedHours ? this.formatHours(task.estimatedHours) : "",
              subtasks: subtasks,
              isEditing: this.editingTaskId === task.id,
              canEdit: permissions.canEdit,
              canDelete: permissions.canDelete,
              showMenu: hasMenu
            });
            // Update field editing state and computed properties
            if (decoratedTask.summaryFields) {
              decoratedTask.summaryFields = decoratedTask.summaryFields.map((field) => {
                const dataTypeUpper = (field.dataType || "").toUpperCase();
                const isEditing = this.isFieldEditing(task.id, field.apiName);
                const isEditable = permissions.canEdit && !field.isReference; // Editable if user can edit and field is not a reference
                let inputValue = "";
                let inputType = "text";

                if (isEditing && this.editingField) {
                  if (dataTypeUpper === "BOOLEAN") {
                    inputValue = this.editingField.fieldValue === "true" || this.editingField.fieldValue === true;
                  } else {
                    inputValue = this.editingField.fieldValue || "";
                  }

                  if (dataTypeUpper === "DATE") {
                    inputType = "date";
                  } else if (dataTypeUpper === "DATETIME") {
                    inputType = "datetime-local";
                  } else if (
                    dataTypeUpper === "DOUBLE" ||
                    dataTypeUpper === "CURRENCY" ||
                    dataTypeUpper === "PERCENT" ||
                    dataTypeUpper === "INTEGER"
                  ) {
                    inputType = "number";
                  } else if (dataTypeUpper === "BOOLEAN") {
                    inputType = "checkbox";
                  }
                } else {
                  // Use raw value when not editing
                  if (dataTypeUpper === "BOOLEAN") {
                    inputValue = field.rawValue === "true" || field.rawValue === true;
                  } else {
                    inputValue = field.rawValue || "";
                  }
                }

                return {
                  ...field,
                  isEditing: isEditing,
                  hasDataType: !!field.dataType,
                  isBoolean: dataTypeUpper === "BOOLEAN",
                  inputValue: inputValue,
                  inputType: inputType,
                  isEditable: isEditable
                };
              });
            }
            return decoratedTask;
          });

          return {
            ...statusGroup,
            statusClass: this.getStatusClass(),
            headerStyle: this.getStatusHeaderStyle(statusGroup.status),
            headerClass:
              `status-header slds-border_bottom ${this.density === "comfy" ? "status-header-comfy" : ""} ${this.density === "compact" ? "status-header-compact" : ""}`.trim(),
            totalEstimatedHours: totalEstimatedHours,
            formattedTotalEstimatedHours: this.formatHours(totalEstimatedHours),
            tasks: tasks
          };
        });
        this.rebuildListViewFilterOptions();
        this.refreshFilteredStatusGroups();
        this.error = undefined;
        this.isLoading = false;
      } catch (e) {
        console.error("Error processing grouped tasks response:", e);
        this.error = e;
        this.statusGroups = [];
        this.filteredStatusGroups = [];
        this.summaryFieldDefinitions = [];
        this.updateSummaryFieldDefinitionMap();
        this.isLoading = false;
      }
    } else if (error) {
      console.error("Error loading grouped tasks:", error);
      this.error = error;
      this.statusGroups = [];
      this.filteredStatusGroups = [];
      this.summaryFieldDefinitions = [];
      this.updateSummaryFieldDefinitionMap();
      this.isLoading = false;
    }
  }

  @wire(getGroupedTasksWithSubtasksByProject, {
    projectId: "$projectIdForWire"
  })
  wiredGroupedTasksByProject(result) {
    // DEBUG: Always log when this wire method is called
    console.log(
      "[DEBUG] wiredGroupedTasksByProject called - projectIdForWire:",
      this.projectIdForWire,
      "hasData:",
      !!result?.data,
      "hasError:",
      !!result?.error
    );

    if (!this.projectIdForWire) {
      console.log("[DEBUG] wiredGroupedTasksByProject - No projectIdForWire; leaving list to account/global wire");
      return;
    }

    // Validate projectId format (should be 15 or 18 character Salesforce ID)
    const pid = this.projectIdForWire;
    if (typeof pid !== "string" || (pid.length !== 15 && pid.length !== 18)) {
      console.error("[DEBUG] wiredGroupedTasksByProject - Invalid projectId format:", pid);
      this.error = { message: "Invalid project ID format" };
      return;
    }

    this.wiredGroupedTasksResult = result;
    const { error, data } = result;
    this.isLoading = !data && !error;
    if (data) {
      try {
        // DEBUG: Log project ID and data received
        console.log("[DEBUG] wiredGroupedTasksByProject - Project ID:", this.projectIdForWire);
        console.log("[DEBUG] wiredGroupedTasksByProject - Status groups count:", data.statusGroups?.length || 0);

        // Clear any existing statusGroups first to prevent data mixing
        // This ensures we only use project-specific data
        this.statusGroups = [];
        this.filteredStatusGroups = [];
        this._resetListFilterStatusSelectionOnNextRebuild = true;
        const statusGroupsData = Array.isArray(data.statusGroups) ? data.statusGroups : [];

        // DEBUG: Log status groups and their tasks
        console.log(
          "[DEBUG] wiredGroupedTasksByProject - Status groups (raw):",
          statusGroupsData.map((sg) => ({
            status: sg.status,
            taskCount: sg.tasks?.length || 0,
            taskNames: sg.tasks?.map((t) => t.name).slice(0, 5) || [],
            hasTasks: !!(sg.tasks && sg.tasks.length > 0)
          }))
        );
        this.summaryFieldDefinitions = Array.isArray(data.summaryFieldDefinitions) ? data.summaryFieldDefinitions : [];
        this.updateSummaryFieldDefinitionMap();
        this.updateSummaryFieldHeaderClasses();

        // Add status header style to each status group and icon info to each task
        this.statusGroups = statusGroupsData.map((statusGroup) => {
          // Calculate total estimated hours for this status group
          let totalEstimatedHours = 0;
          const tasks = (statusGroup.tasks || []).map((task) => {
            const isExpanded = this.isTaskExpanded(task.id);

            // Add parent task hours
            const parentHours = task.estimatedHours || 0;
            totalEstimatedHours += parentHours;

            // Add subtask hours
            const subtasks = (task.subtasks || []).map((subtask) => {
              const subtaskHours = subtask.estimatedHours || 0;
              totalEstimatedHours += subtaskHours;
              const subtaskPermissions = this.getTaskPermissions();
              const subtaskHasMenu = subtaskPermissions.canEdit || subtaskPermissions.canDelete;
              const decoratedSubtask = this.decorateTaskRecord({
                ...subtask,
                formattedDueDate: subtask.dueDate ? this.formatDate(subtask.dueDate) : "",
                formattedEstimatedHours: subtask.estimatedHours ? this.formatHours(subtask.estimatedHours) : "",
                isEditing: this.editingTaskId === subtask.id,
                canEdit: subtaskPermissions.canEdit,
                canDelete: subtaskPermissions.canDelete,
                showMenu: subtaskHasMenu
              });
              // Update field editing state and computed properties
              if (decoratedSubtask.summaryFields) {
                decoratedSubtask.summaryFields = decoratedSubtask.summaryFields.map((field) => {
                  const dataTypeUpper = (field.dataType || "").toUpperCase();
                  const isEditing = this.isFieldEditing(subtask.id, field.apiName);
                  const isEditable = subtaskPermissions.canEdit && !field.isReference;
                  let inputValue = "";
                  let inputType = "text";

                  if (isEditing && this.editingField) {
                    if (dataTypeUpper === "BOOLEAN") {
                      inputValue = this.editingField.fieldValue === "true" || this.editingField.fieldValue === true;
                    } else {
                      inputValue = this.editingField.fieldValue || "";
                    }

                    if (dataTypeUpper === "DATE") {
                      inputType = "date";
                    } else if (dataTypeUpper === "DATETIME") {
                      inputType = "datetime-local";
                    } else if (
                      dataTypeUpper === "DOUBLE" ||
                      dataTypeUpper === "CURRENCY" ||
                      dataTypeUpper === "PERCENT" ||
                      dataTypeUpper === "INTEGER"
                    ) {
                      inputType = "number";
                    } else if (dataTypeUpper === "BOOLEAN") {
                      inputType = "checkbox";
                    }
                  } else {
                    // Use raw value when not editing
                    if (dataTypeUpper === "BOOLEAN") {
                      inputValue = field.rawValue === "true" || field.rawValue === true;
                    } else {
                      inputValue = field.rawValue || "";
                    }
                  }

                  return {
                    ...field,
                    isEditing: isEditing,
                    hasDataType: !!field.dataType,
                    isBoolean: dataTypeUpper === "BOOLEAN",
                    inputValue: inputValue,
                    inputType: inputType,
                    isEditable: isEditable
                  };
                });
              }
              return decoratedSubtask;
            });

            const permissions = this.getTaskPermissions();
            const hasMenu = permissions.canEdit || permissions.canDelete;
            const decoratedTask = this.decorateTaskRecord({
              ...task,
              isExpanded: isExpanded,
              iconName: isExpanded ? "utility:chevrondown" : "utility:chevronright",
              iconAltText: isExpanded ? "Collapse" : "Expand",
              subtaskLabel: task.subtaskCount === 1 ? "subtask" : "subtasks",
              formattedDueDate: task.dueDate ? this.formatDate(task.dueDate) : "",
              formattedEstimatedHours: task.estimatedHours ? this.formatHours(task.estimatedHours) : "",
              subtasks: subtasks,
              isEditing: this.editingTaskId === task.id,
              canEdit: permissions.canEdit,
              canDelete: permissions.canDelete,
              showMenu: hasMenu
            });
            // Update field editing state and computed properties
            if (decoratedTask.summaryFields) {
              decoratedTask.summaryFields = decoratedTask.summaryFields.map((field) => {
                const dataTypeUpper = (field.dataType || "").toUpperCase();
                const isEditing = this.isFieldEditing(task.id, field.apiName);
                const isEditable = permissions.canEdit && !field.isReference;
                let inputValue = "";
                let inputType = "text";

                if (isEditing && this.editingField) {
                  if (dataTypeUpper === "BOOLEAN") {
                    inputValue = this.editingField.fieldValue === "true" || this.editingField.fieldValue === true;
                  } else {
                    inputValue = this.editingField.fieldValue || "";
                  }

                  if (dataTypeUpper === "DATE") {
                    inputType = "date";
                  } else if (dataTypeUpper === "DATETIME") {
                    inputType = "datetime-local";
                  } else if (
                    dataTypeUpper === "DOUBLE" ||
                    dataTypeUpper === "CURRENCY" ||
                    dataTypeUpper === "PERCENT" ||
                    dataTypeUpper === "INTEGER"
                  ) {
                    inputType = "number";
                  } else if (dataTypeUpper === "BOOLEAN") {
                    inputType = "checkbox";
                  }
                } else {
                  // Use raw value when not editing
                  if (dataTypeUpper === "BOOLEAN") {
                    inputValue = field.rawValue === "true" || field.rawValue === true;
                  } else {
                    inputValue = field.rawValue || "";
                  }
                }

                return {
                  ...field,
                  isEditing: isEditing,
                  hasDataType: !!field.dataType,
                  isBoolean: dataTypeUpper === "BOOLEAN",
                  inputValue: inputValue,
                  inputType: inputType,
                  isEditable: isEditable
                };
              });
            }
            return decoratedTask;
          });

          return {
            ...statusGroup,
            statusClass: this.getStatusClass(),
            headerStyle: this.getStatusHeaderStyle(statusGroup.status),
            headerClass:
              `status-header slds-border_bottom ${this.density === "comfy" ? "status-header-comfy" : ""} ${this.density === "compact" ? "status-header-compact" : ""}`.trim(),
            totalEstimatedHours: totalEstimatedHours,
            formattedTotalEstimatedHours: this.formatHours(totalEstimatedHours),
            tasks: tasks,
            taskCount: tasks.length
          };
        });

        // DEBUG: Log status groups after processing
        console.log(
          "[DEBUG] wiredGroupedTasksByProject - Status groups (processed):",
          this.statusGroups.map((sg) => ({
            status: sg.status,
            taskCount: sg.tasks?.length || 0,
            taskNames: sg.tasks?.map((t) => t.name).slice(0, 5) || [],
            hasTasks: !!(sg.tasks && sg.tasks.length > 0)
          }))
        );

        // List filters (including multi-select status) applied in refreshFilteredStatusGroups
        this.rebuildListViewFilterOptions();
        this.refreshFilteredStatusGroups();
        this.error = undefined;
        this.isLoading = false;
      } catch (e) {
        console.error("Error processing grouped tasks by project response:", e);
        this.error = e;
        this.statusGroups = [];
        this.filteredStatusGroups = [];
        this.summaryFieldDefinitions = [];
        this.updateSummaryFieldDefinitionMap();
        this.isLoading = false;
      }
    } else if (error) {
      console.error("Error loading grouped tasks by project:", error);
      this.error = { message: this.getErrorMessage(error) };
    }
  }

  handleToggleSubtasks(event) {
    const taskId = event.currentTarget.dataset.taskId;
    if (this.expandedTasks.has(taskId)) {
      this.expandedTasks.delete(taskId);
    } else {
      this.expandedTasks.add(taskId);
    }
    // Force re-render by creating a new Set
    this.expandedTasks = new Set(this.expandedTasks);

    // Update icon info for all tasks
    this.updateTaskIcons();
  }

  updateTaskIcons() {
    this.statusGroups = this.statusGroups.map((statusGroup) => ({
      ...statusGroup,
      tasks: statusGroup.tasks.map((task) => {
        const isExpanded = this.isTaskExpanded(task.id);
        const permissions = this.getTaskPermissions();
        return {
          ...task,
          isExpanded: isExpanded,
          iconName: isExpanded ? "utility:chevrondown" : "utility:chevronright",
          iconAltText: isExpanded ? "Collapse" : "Expand",
          subtaskLabel: task.subtaskCount === 1 ? "subtask" : "subtasks",
          isEditing: this.editingTaskId === task.id,
          canEdit: permissions.canEdit,
          canDelete: permissions.canDelete,
          showMenu: permissions.canEdit || permissions.canDelete
        };
      })
    }));
    // Reapply filter after updating icons
    this.refreshFilteredStatusGroups();
  }

  isTaskExpanded(taskId) {
    return this.expandedTasks.has(taskId);
  }

  getTaskToggleTitle(taskId) {
    return this.isTaskExpanded(taskId) ? "Collapse subtasks" : "Expand subtasks";
  }

  getTaskIconName(taskId) {
    return this.isTaskExpanded(taskId) ? "utility:chevrondown" : "utility:chevronright";
  }

  getTaskIconAltText(taskId) {
    return this.isTaskExpanded(taskId) ? "Collapse" : "Expand";
  }

  /**
   * Path segment for /project-task/:segment — prefers SEO UrlName from Apex when present.
   */
  buildPortalTaskHref(pathSegment) {
    const raw = pathSegment ? String(pathSegment).trim() : "";
    if (!raw) {
      return "/";
    }
    const isSalesforceId = /^[a-zA-Z0-9]{15}$|^[a-zA-Z0-9]{18}$/.test(raw);
    const segment = isSalesforceId ? raw : encodeURIComponent(raw);
    const path = `/project-task/${segment}`;
    return ensureSitePath(path, {
      currentPathname: typeof window !== "undefined" ? window.location.pathname : ""
    });
  }

  navigateToTask(taskId, portalPathSegment) {
    if (!taskId) {
      return;
    }
    const segment =
      portalPathSegment && String(portalPathSegment).trim().length > 0 ? String(portalPathSegment).trim() : taskId;
    if (this.isExperienceSite) {
      window.location.assign(this.buildPortalTaskHref(segment));
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: taskId,
        actionName: "view"
      }
    });
  }

  handleTaskClick(event) {
    const taskId = event.currentTarget.dataset.taskId;
    const portalPathSegment = event.currentTarget.dataset.portalUrlSegment;
    this.navigateToTask(taskId, portalPathSegment);
  }

  getStatusClass() {
    // Keep for backward compatibility if needed
    return "";
  }

  getStatusHeaderStyle(status) {
    // Use colors from Apex (which reads from field metadata)
    // If not loaded yet, use default colors
    const backgroundColor = this.statusColors[status] || this.getDefaultStatusColors()[status] || "#F3F3F3";

    // Determine text color based on background brightness
    const textColor = this.getContrastTextColor(backgroundColor);

    return `background-color: ${backgroundColor}; color: ${textColor};`;
  }

  /**
   * @description Get contrasting text color (black or white) based on background color
   */
  getContrastTextColor(hexColor) {
    if (!hexColor) return "#080707";

    // Remove # if present
    const hex = hexColor.replace("#", "");

    // Convert to RGB
    const r = parseInt(hex.substr(0, 2), 16);
    const g = parseInt(hex.substr(2, 2), 16);
    const b = parseInt(hex.substr(4, 2), 16);

    // Calculate relative luminance
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    // Return black for light colors, white for dark colors
    return luminance > 0.5 ? "#080707" : "#ffffff";
  }

  formatDate(dateValue) {
    if (!dateValue) return "";
    const date = new Date(dateValue);
    return date.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric"
    });
  }

  formatHours(hours) {
    if (!hours && hours !== 0) return "";
    if (hours >= 1) {
      const wholeHours = Math.floor(hours);
      const minutes = Math.round((hours - wholeHours) * 60);
      if (minutes > 0) {
        return `${wholeHours}h ${minutes}m`;
      }
      return `${wholeHours}h`;
    }
    const minutes = Math.round(hours * 60);
    return `${minutes}m`;
  }

  isTaskAssignedToMe(task) {
    const projectManagerId = task.projectManagerId ? String(task.projectManagerId) : "";
    const developerId = task.developerId ? String(task.developerId) : "";
    const clientUserId = task.clientUserId ? String(task.clientUserId) : "";

    // Portal "My tasks": match PM, Developer, or Client User to the logged-in Contact
    if (this.isPortalMode && this.showMyTasksOnly) {
      const uid = this.currentUserContactId ? String(this.currentUserContactId) : null;
      if (!uid) {
        return false;
      }
      return (
        salesforceIdsEqual(projectManagerId, uid) ||
        salesforceIdsEqual(developerId, uid) ||
        salesforceIdsEqual(clientUserId, uid)
      );
    }

    return false;
  }

  getStatusBadgeClass(status) {
    const statusClasses = {
      Backlog: "slds-badge slds-badge_lightest",
      Pending: "slds-badge slds-badge_warning",
      "In Progress": "slds-badge slds-badge_info",
      "In Review": "slds-badge slds-badge_inverse",
      Blocked: "slds-badge slds-badge_error",
      Completed: "slds-badge slds-badge_success",
      Removed: "slds-badge slds-badge_offline"
    };
    return statusClasses[status] || "slds-badge";
  }

  decorateTaskRecord(record) {
    // Note: hoverFields decoration is now handled by taskHoverCard component
    // Only decorate summaryFields here

    const summaryFields = (record.summaryFields || []).map((field) => {
      const definition = this.summaryFieldDefinitionMap[field.apiName] || {};
      const rawValue = field.rawValue;
      let displayValue = field.displayValue;
      const dataType = (definition.dataType || "").toUpperCase();

      if (rawValue) {
        if (dataType === "DATE" || dataType === "DATETIME") {
          displayValue = this.formatDate(rawValue);
        } else if (dataType === "PERCENT") {
          const percentValue = parseFloat(rawValue);
          if (!isNaN(percentValue)) {
            displayValue = `${percentValue.toFixed(2)}%`;
          }
        }
      }

      if (field.apiName && field.apiName.endsWith("_Hours__c") && rawValue) {
        const hoursValue = parseFloat(rawValue);
        if (!isNaN(hoursValue)) {
          displayValue = this.formatHours(hoursValue);
        }
      }

      const hasValue =
        displayValue !== null &&
        displayValue !== undefined &&
        (!(typeof displayValue === "string") || displayValue.trim().length > 0);
      const dataTypeUpper = (definition.dataType || "").toUpperCase();
      return {
        ...field,
        displayValue: hasValue ? displayValue : "",
        // Add field definition info for inline editing
        dataType: definition.dataType,
        isReference: definition.isReference,
        label: definition.label || field.label,
        // Add computed properties for template (will be updated in wiredGroupedTasks)
        isEditing: false,
        hasDataType: !!definition.dataType,
        isBoolean: dataTypeUpper === "BOOLEAN"
      };
    });

    const portalSeg =
      record.portalUrlName && String(record.portalUrlName).trim().length > 0
        ? String(record.portalUrlName).trim()
        : record.id;

    return {
      ...record,
      // hoverFields passed as-is to taskHoverCard component
      summaryFields,
      portalUrlSegment: portalSeg
    };
  }

  updateSummaryFieldDefinitionMap() {
    this.summaryFieldDefinitionMap = (this.summaryFieldDefinitions || []).reduce((acc, definition) => {
      if (definition && definition.apiName) {
        acc[definition.apiName] = definition;
      }
      return acc;
    }, {});
  }

  get hasData() {
    return this.filteredStatusGroups && this.filteredStatusGroups.length > 0;
  }

  /** True when the wire payload still has at least one task (before list-view filters). */
  get hasRawTasks() {
    return (this.statusGroups || []).some((g) => (g.tasks || []).length > 0);
  }

  /** Show filter shell + empty state when list filters hide every row. */
  get showListFilterEmptyState() {
    return !this.hasData && this.hasRawTasks && this.hasActiveListFilters;
  }

  /** Main list area (table + optional left filter panel) when the wire returned tasks. */
  get showGroupedListShell() {
    return this.hasRawTasks;
  }

  get listFilterResetDisabled() {
    return !this.hasActiveListFilters;
  }

  get listFilterToggleVariant() {
    return this._listFilterPanelOpen || this.hasActiveListFilters ? "brand" : "border-filled";
  }

  get hasSummaryFields() {
    return this.summaryFieldDefinitions && this.summaryFieldDefinitions.length > 0;
  }

  get displayStatusGroups() {
    return this.filteredStatusGroups;
  }

  get meModeButtonLabel() {
    // In Salesforce LEX, don't show this button (use List filters > Project manager)
    if (!this.isPortalMode) {
      return null;
    }
    return this.showMyTasksOnly ? "Show All" : "My Tasks";
  }

  get showMyTasksButton() {
    // Only show button in Portal mode
    return this.isPortalMode;
  }

  get meModeButtonTitle() {
    return this.showMyTasksOnly
      ? "Show all tasks"
      : "Show only tasks where you are the Owner, Developer, or Client User";
  }

  get meModeButtonVariant() {
    return this.showMyTasksOnly ? "brand" : "neutral";
  }

  get meModeButtonIcon() {
    return this.showMyTasksOnly ? "utility:user" : "utility:user";
  }

  get expandCollapseAllLabel() {
    return this.areAllStatusesCollapsed ? "Expand All Statuses" : "Collapse All Statuses";
  }

  get expandCollapseAllTitle() {
    return this.areAllStatusesCollapsed ? "Expand all visible status groups" : "Collapse all visible status groups";
  }

  get expandCollapseAllIcon() {
    return this.areAllStatusesCollapsed ? "utility:chevrondown" : "utility:chevronup";
  }

  get expandCollapseAllDisabled() {
    return !this.hasData;
  }

  get areAllStatusesCollapsed() {
    if (!this.filteredStatusGroups || this.filteredStatusGroups.length === 0) {
      return false;
    }
    return this.filteredStatusGroups.every((group) => this.isStatusCollapsed(group.status));
  }

  get areAllSubtasksExpanded() {
    if (!this.filteredStatusGroups || this.filteredStatusGroups.length === 0) {
      return false;
    }
    // Get all tasks that have subtasks
    const tasksWithSubtasks = [];
    this.filteredStatusGroups.forEach((group) => {
      group.tasks.forEach((task) => {
        if (task.hasSubtasks && task.subtaskCount > 0) {
          tasksWithSubtasks.push(task.id);
        }
      });
    });

    if (tasksWithSubtasks.length === 0) {
      return false; // No tasks with subtasks, so can't be "all expanded"
    }

    // Check if all tasks with subtasks are expanded
    return tasksWithSubtasks.every((taskId) => this.isTaskExpanded(taskId));
  }

  get expandCollapseAllSubtasksLabel() {
    return this.areAllSubtasksExpanded ? "Collapse All Subtasks" : "Expand All Subtasks";
  }

  get expandCollapseAllSubtasksTitle() {
    return this.areAllSubtasksExpanded ? "Collapse all subtasks" : "Expand all subtasks";
  }

  get expandCollapseAllSubtasksIcon() {
    return this.areAllSubtasksExpanded ? "utility:chevronup" : "utility:chevrondown";
  }

  get expandCollapseAllSubtasksDisabled() {
    if (!this.filteredStatusGroups || this.filteredStatusGroups.length === 0) {
      return true;
    }
    // Disable if no tasks have subtasks
    return !this.filteredStatusGroups.some((group) =>
      group.tasks.some((task) => task.hasSubtasks && task.subtaskCount > 0)
    );
  }

  handleMeModeToggle() {
    // Portal: toggle filter using current user's Contact ID
    if (this.isPortalMode) {
      this.showMyTasksOnly = !this.showMyTasksOnly;
      this.refreshFilteredStatusGroups();
    }
  }

  handleStatusToggle(event) {
    const status = event.currentTarget?.dataset?.status;
    if (!status) {
      return;
    }
    const newSet = new Set(this.collapsedStatuses);
    if (newSet.has(status)) {
      newSet.delete(status);
    } else {
      newSet.add(status);
    }
    this.collapsedStatuses = new Set(newSet);
    this.refreshFilteredStatusGroups();
  }

  handleExpandCollapseAll() {
    const shouldCollapse = !this.areAllStatusesCollapsed;
    const visibleStatuses = (this.filteredStatusGroups || []).map((group) => group.status);
    const updatedSet = new Set(this.collapsedStatuses);

    if (shouldCollapse) {
      visibleStatuses.forEach((status) => updatedSet.add(status));
    } else {
      visibleStatuses.forEach((status) => updatedSet.delete(status));
    }

    this.collapsedStatuses = new Set(updatedSet);
    this.refreshFilteredStatusGroups();
  }

  handleExpandCollapseAllSubtasks() {
    const shouldExpand = !this.areAllSubtasksExpanded;
    const updatedSet = new Set(this.expandedTasks);

    // Get all task IDs that have subtasks
    const tasksWithSubtasks = [];
    this.filteredStatusGroups.forEach((group) => {
      group.tasks.forEach((task) => {
        if (task.hasSubtasks && task.subtaskCount > 0) {
          tasksWithSubtasks.push(task.id);
        }
      });
    });

    if (shouldExpand) {
      // Expand all subtasks
      tasksWithSubtasks.forEach((taskId) => updatedSet.add(taskId));
    } else {
      // Collapse all subtasks
      tasksWithSubtasks.forEach((taskId) => updatedSet.delete(taskId));
    }

    this.expandedTasks = new Set(updatedSet);
    this.updateTaskIcons();
  }

  refreshFilteredStatusGroups() {
    if (!this.statusGroups || this.statusGroups.length === 0) {
      this.filteredStatusGroups = [];
      return;
    }

    let groups = [...this.statusGroups];

    // DEBUG: Log initial state
    if (this.resolvedProjectId) {
      console.log("[DEBUG] refreshFilteredStatusGroups - Project ID:", this.resolvedProjectId);
      console.log(
        "[DEBUG] refreshFilteredStatusGroups - Initial groups:",
        groups.map((sg) => ({
          status: sg.status,
          taskCount: sg.tasks?.length || 0
        }))
      );
    }

    // Portal "My tasks": restrict to tasks involving the logged-in contact
    if (this.showMyTasksOnly) {
      groups = this.filterGroupsForCurrentUser(groups);
    }

    groups = this.filterGroupsForListView(groups);

    this.filteredStatusGroups = this.decorateStatusGroupsForDisplay(groups);

    // DEBUG: Log filtered status groups after decoration
    if (this.resolvedProjectId) {
      console.log("[DEBUG] refreshFilteredStatusGroups - After decoration:", {
        filteredGroupsCount: this.filteredStatusGroups.length,
        groupsWithTasks: this.filteredStatusGroups.filter((g) => g.tasks && g.tasks.length > 0).length,
        totalTasks: this.filteredStatusGroups.reduce((sum, g) => sum + (g.tasks?.length || 0), 0),
        hasData: this.hasData,
        groups: this.filteredStatusGroups.map((g) => ({
          status: g.status,
          taskCount: g.tasks?.length || 0,
          isCollapsed: g.isCollapsed
        }))
      });
    }
  }

  filterGroupsForCurrentUser(groups) {
    return groups
      .map((statusGroup) => {
        const filteredTasks = statusGroup.tasks
          .map((task) => {
            const isMyTask = this.isTaskAssignedToMe(task);

            if (isMyTask) {
              const mySubtasks = (task.subtasks || []).filter((subtask) => this.isTaskAssignedToMe(subtask));
              return {
                ...task,
                subtasks: mySubtasks,
                subtaskCount: mySubtasks.length,
                hasSubtasks: mySubtasks.length > 0
              };
            }

            if (task.subtasks && task.subtasks.length > 0) {
              const mySubtasks = task.subtasks.filter((subtask) => this.isTaskAssignedToMe(subtask));
              if (mySubtasks.length > 0) {
                return {
                  ...task,
                  subtasks: mySubtasks,
                  subtaskCount: mySubtasks.length,
                  hasSubtasks: true
                };
              }
            }
            return null;
          })
          .filter((task) => task !== null)
          .map((task) => {
            const isExpanded = this.isTaskExpanded(task.id);
            return {
              ...task,
              isExpanded: isExpanded,
              iconName: isExpanded ? "utility:chevrondown" : "utility:chevronright",
              iconAltText: isExpanded ? "Collapse" : "Expand",
              subtaskLabel: task.subtaskCount === 1 ? "subtask" : "subtasks"
            };
          });

        if (filteredTasks.length > 0) {
          let totalEstimatedHours = 0;
          filteredTasks.forEach((task) => {
            if (task.estimatedHours) {
              totalEstimatedHours += task.estimatedHours;
            }
            if (task.subtasks) {
              task.subtasks.forEach((subtask) => {
                if (subtask.estimatedHours) {
                  totalEstimatedHours += subtask.estimatedHours;
                }
              });
            }
          });

          return {
            ...statusGroup,
            tasks: filteredTasks,
            taskCount: filteredTasks.length,
            totalEstimatedHours: totalEstimatedHours,
            formattedTotalEstimatedHours: this.formatHours(totalEstimatedHours)
          };
        }
        return null;
      })
      .filter((group) => group !== null);
  }

  decorateStatusGroupsForDisplay(groups) {
    return groups.map((group) => {
      const isCollapsed = this.isStatusCollapsed(group.status);
      // Update field editing state for all tasks and subtasks
      const tasks = (group.tasks || []).map((task) => {
        const updatedTask = { ...task };
        const taskPermissions = this.getTaskPermissions();
        // Update field editing state for task fields
        if (updatedTask.summaryFields) {
          updatedTask.summaryFields = updatedTask.summaryFields.map((field) => {
            const dataTypeUpper = (field.dataType || "").toUpperCase();
            const isEditing = this.isFieldEditing(task.id, field.apiName);
            const isEditable = taskPermissions.canEdit && !field.isReference; // Editable if user can edit and field is not a reference
            let inputValue = "";
            let inputType = "text";

            if (isEditing && this.editingField) {
              if (dataTypeUpper === "BOOLEAN") {
                inputValue = this.editingField.fieldValue === "true" || this.editingField.fieldValue === true;
              } else {
                inputValue = this.editingField.fieldValue || "";
              }

              if (dataTypeUpper === "DATE") {
                inputType = "date";
              } else if (dataTypeUpper === "DATETIME") {
                inputType = "datetime-local";
              } else if (
                dataTypeUpper === "DOUBLE" ||
                dataTypeUpper === "CURRENCY" ||
                dataTypeUpper === "PERCENT" ||
                dataTypeUpper === "INTEGER"
              ) {
                inputType = "number";
              } else if (dataTypeUpper === "BOOLEAN") {
                inputType = "checkbox";
              }
            } else {
              // Use raw value when not editing
              if (dataTypeUpper === "BOOLEAN") {
                inputValue = field.rawValue === "true" || field.rawValue === true;
              } else {
                inputValue = field.rawValue || "";
              }
            }

            return {
              ...field,
              isEditing: isEditing,
              hasDataType: !!field.dataType,
              isBoolean: dataTypeUpper === "BOOLEAN",
              inputValue: inputValue,
              inputType: inputType,
              isEditable: isEditable
            };
          });
        }
        // Update field editing state for subtask fields
        if (updatedTask.subtasks) {
          updatedTask.subtasks = updatedTask.subtasks.map((subtask) => {
            const updatedSubtask = { ...subtask };
            const subtaskPermissions = this.getTaskPermissions();
            if (updatedSubtask.summaryFields) {
              updatedSubtask.summaryFields = updatedSubtask.summaryFields.map((field) => {
                const dataTypeUpper = (field.dataType || "").toUpperCase();
                const isEditing = this.isFieldEditing(subtask.id, field.apiName);
                const isEditable = subtaskPermissions.canEdit && !field.isReference; // Editable if user can edit and field is not a reference
                let inputValue = "";
                let inputType = "text";

                if (isEditing && this.editingField) {
                  if (dataTypeUpper === "BOOLEAN") {
                    inputValue = this.editingField.fieldValue === "true" || this.editingField.fieldValue === true;
                  } else {
                    inputValue = this.editingField.fieldValue || "";
                  }

                  if (dataTypeUpper === "DATE") {
                    inputType = "date";
                  } else if (dataTypeUpper === "DATETIME") {
                    inputType = "datetime-local";
                  } else if (
                    dataTypeUpper === "DOUBLE" ||
                    dataTypeUpper === "CURRENCY" ||
                    dataTypeUpper === "PERCENT" ||
                    dataTypeUpper === "INTEGER"
                  ) {
                    inputType = "number";
                  } else if (dataTypeUpper === "BOOLEAN") {
                    inputType = "checkbox";
                  }
                } else {
                  // Use raw value when not editing
                  if (dataTypeUpper === "BOOLEAN") {
                    inputValue = field.rawValue === "true" || field.rawValue === true;
                  } else {
                    inputValue = field.rawValue || "";
                  }
                }

                return {
                  ...field,
                  isEditing: isEditing,
                  hasDataType: !!field.dataType,
                  isBoolean: dataTypeUpper === "BOOLEAN",
                  inputValue: inputValue,
                  inputType: inputType,
                  isEditable: isEditable
                };
              });
            }
            return updatedSubtask;
          });
        }
        return updatedTask;
      });
      return {
        ...group,
        tasks: tasks,
        isCollapsed,
        statusToggleIconName: isCollapsed ? "utility:chevronright" : "utility:chevrondown",
        statusToggleAltText: isCollapsed ? "Expand status group" : "Collapse status group"
      };
    });
  }

  isStatusCollapsed(status) {
    return this.collapsedStatuses.has(status);
  }

  // Wire service to get status colors from Apex
  @wire(getStatusColors)
  wiredStatusColors({ error, data }) {
    if (data) {
      // Convert the map from Apex to a JavaScript object
      this.statusColors = data || {};
    } else if (error) {
      console.error("Error loading status colors:", error);
      // Fall back to default colors
      this.statusColors = this.getDefaultStatusColors();
    }
  }

  // Check object-level permissions using wire adapter
  @wire(getObjectInfo, { objectApiName: PROJECT_TASK_OBJECT })
  wiredObjectInfo({ error, data }) {
    if (data) {
      this.objectPermissions = {
        canEdit: data.updateable || false,
        canDelete: data.deletable || false
      };

      // Extract record types
      if (data.recordTypeInfos) {
        const recordTypeEntries = Object.entries(data.recordTypeInfos);
        this.recordTypes = recordTypeEntries
          .filter(([, value]) => !value.master) // Exclude master record type
          .map(([key, value]) => ({
            label: value.name,
            value: key
          }))
          .sort((a, b) => a.label.localeCompare(b.label));

        // Set default record type (first available or master)
        if (this.recordTypes.length > 0) {
          this.defaultRecordTypeId = this.recordTypes[0].value;
        } else if (data.defaultRecordTypeId) {
          this.defaultRecordTypeId = data.defaultRecordTypeId;
        }
      }

      // Update summaryFieldDefinitions header classes when permissions are loaded
      this.updateSummaryFieldHeaderClasses();
    } else if (error) {
      console.error("Error loading object info:", error);
      this.objectPermissions = { canEdit: false, canDelete: false };
      this.updateSummaryFieldHeaderClasses();
    }
  }

  /**
   * @description Get default status colors (fallback)
   * These match the colors in Status__c.field-meta.xml
   */
  getDefaultStatusColors() {
    return {
      Backlog: "#E5E5E5",
      Pending: "#FFB75D",
      "In Progress": "#0176D3",
      "In Review": "#5B21B6",
      Blocked: "#C23934",
      Completed: "#2E844A",
      Removed: "#706E6B"
    };
  }

  updateSummaryFieldHeaderClasses() {
    // Update header classes for summary field definitions based on editability
    if (this.summaryFieldDefinitions && this.summaryFieldDefinitions.length > 0) {
      this.summaryFieldDefinitions = this.summaryFieldDefinitions.map((field) => {
        const isEditable = !this.isPortalMode && this.isFieldEditable(field.apiName);
        return {
          ...field,
          headerClass: `summary-header${isEditable ? " summary-header-editable" : ""}`
        };
      });
    }
  }

  getTaskPermissions() {
    // In portal mode, disable edit/delete
    if (this.isPortalMode) {
      return { canEdit: false, canDelete: false };
    }
    // Use object-level permissions for all tasks
    // Record-level permissions will be enforced by Salesforce when actions are attempted
    return this.objectPermissions;
  }

  hasAnyPermission() {
    const perms = this.getTaskPermissions();
    return perms.canEdit || perms.canDelete;
  }

  isFieldEditable(fieldApiName) {
    // A field is editable if user has edit permissions and field is not a reference
    if (!this.objectPermissions.canEdit) {
      return false;
    }
    const definition = this.summaryFieldDefinitionMap[fieldApiName];
    if (!definition) {
      return false;
    }
    return !definition.isReference;
  }

  // Inline editing handlers
  handleTaskNameClick(event) {
    const taskId = event.currentTarget.dataset.taskId;
    if (!taskId) {
      return;
    }

    // Navigate with portal-aware routing
    event.preventDefault();
    event.stopPropagation();
    const portalPathSegment = event.currentTarget.dataset.portalUrlSegment;
    this.navigateToTask(taskId, portalPathSegment);
  }

  handleTaskNameChange(event) {
    this.editingTaskName = event.target.value;
  }

  async handleTaskNameSave() {
    const taskId = this.editingTaskId;
    if (!taskId || !this.editingTaskName || this.editingTaskName.trim() === "") {
      this.cancelEdit();
      return;
    }

    try {
      const fields = {
        Id: taskId,
        Name: this.editingTaskName.trim()
      };

      await updateRecord({ fields });

      // Update the task in our local data
      this.updateTaskName(taskId, this.editingTaskName.trim());

      this.showToast("Success", "Task name updated successfully", "success");
      this.cancelEdit();
    } catch (error) {
      console.error("Error updating task name:", error);
      this.showToast("Error", this.getErrorMessage(error), "error");
    }
  }

  handleTaskNameKeyDown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.handleTaskNameSave(event);
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.cancelEdit();
    }
  }

  cancelEdit() {
    this.editingTaskId = null;
    this.editingTaskName = "";
    this.editingField = null;
    // Trigger reactive update to hide edit mode
    this.refreshFilteredStatusGroups();
  }

  // Inline field editing handlers
  isFieldEditing(taskId, fieldApiName) {
    return this.editingField && this.editingField.taskId === taskId && this.editingField.fieldApiName === fieldApiName;
  }

  handleFieldHover(event) {
    const taskId = event.currentTarget.dataset.taskId;
    const fieldApiName = event.currentTarget.dataset.fieldApiName;

    if (!taskId || !fieldApiName) {
      return;
    }

    const permissions = this.getTaskPermissions();
    if (!permissions.canEdit) {
      return; // Don't show edit on hover if user can't edit
    }

    // Find the field to check if it's a reference field
    const task = this.findTaskById(taskId);
    if (task) {
      const field = (task.summaryFields || []).find((f) => f.apiName === fieldApiName);
      if (field && field.isReference) {
        return; // Don't show edit on hover for reference fields
      }
    }

    // Add hover class for visual feedback (pencil icon will show via CSS)
    event.currentTarget.classList.add("field-hover");
  }

  handleFieldLeave(event) {
    // Only remove hover class if not editing
    if (
      !this.editingField ||
      this.editingField.taskId !== event.currentTarget.dataset.taskId ||
      this.editingField.fieldApiName !== event.currentTarget.dataset.fieldApiName
    ) {
      event.currentTarget.classList.remove("field-hover");
    }
  }

  handleFieldClick(event) {
    // Prevent event from bubbling up (e.g., to task row click handlers)
    event.preventDefault();
    event.stopPropagation();

    // Get taskId and fieldApiName from the clicked element or its parent
    let taskId = event.currentTarget.dataset.taskId;
    let fieldApiName = event.currentTarget.dataset.fieldApiName;

    // If clicked on icon or child element, get from parent
    if (!taskId || !fieldApiName) {
      const parent = event.currentTarget.closest("[data-task-id]");
      if (parent) {
        taskId = parent.dataset.taskId;
        fieldApiName = parent.dataset.fieldApiName;
      }
    }

    if (!taskId || !fieldApiName) {
      return;
    }

    const permissions = this.getTaskPermissions();
    if (!permissions.canEdit) {
      return; // Don't allow editing if user can't edit
    }

    // Find the field value
    const task = this.findTaskById(taskId);
    if (!task) {
      return;
    }

    const field = (task.summaryFields || []).find((f) => f.apiName === fieldApiName);
    if (!field) {
      return;
    }

    // Don't allow editing reference fields (like OwnerId) - they need lookup components
    if (field.isReference) {
      return;
    }

    // Open modal for editing
    const modal = this.template.querySelector("c-field-edit-modal");
    if (modal) {
      const definition = this.summaryFieldDefinitionMap[fieldApiName] || {};
      const picklistOptions = definition.picklistValues || [];

      modal.open(
        taskId,
        fieldApiName,
        field.label || fieldApiName,
        field.rawValue || "",
        field.dataType || definition.dataType || "STRING",
        picklistOptions
      );
    }
  }

  async handleFieldSaveFromModal(event) {
    const { recordId, fieldApiName, newValue } = event.detail;

    // Update the local data immediately for responsive UI
    this.updateFieldValue(recordId, fieldApiName, newValue, this.getFieldDataType(fieldApiName));

    // Refresh the wire to get latest data from server
    try {
      await refreshApex(this.wiredGroupedTasksResult);
    } catch (error) {
      console.warn("Error refreshing data after save:", error);
      // Continue with local update even if refresh fails
    }
  }

  getFieldDataType(fieldApiName) {
    const definition = this.summaryFieldDefinitionMap[fieldApiName];
    return definition?.dataType || "STRING";
  }

  handleFieldValueChange(event) {
    if (this.editingField) {
      // For checkboxes, use checked property; for other inputs, use value
      if (event.target.type === "checkbox") {
        this.editingField.fieldValue = event.target.checked;
        // Auto-save boolean fields on change
        this.handleFieldSave();
        return;
      }
      this.editingField.fieldValue = event.target.value;
      // Create a new object to trigger reactivity
      this.editingField = { ...this.editingField };
      // Trigger reactive update
      this.refreshFilteredStatusGroups();
    }
  }

  async handleFieldSave() {
    if (!this.editingField) {
      return;
    }

    const { taskId, fieldApiName, fieldValue, dataType } = this.editingField;

    try {
      const fields = {
        Id: taskId
      };

      // Convert value based on field type
      const dataTypeUpper = (dataType || "").toUpperCase();
      if (dataTypeUpper === "DATE") {
        // For date fields, ensure proper format
        fields[fieldApiName] = fieldValue || null;
      } else if (dataTypeUpper === "DATETIME") {
        // For datetime fields, ensure proper format
        fields[fieldApiName] = fieldValue || null;
      } else if (dataTypeUpper === "DOUBLE" || dataTypeUpper === "CURRENCY" || dataTypeUpper === "PERCENT") {
        const numValue = fieldValue ? parseFloat(fieldValue) : null;
        fields[fieldApiName] = isNaN(numValue) ? null : numValue;
      } else if (dataTypeUpper === "INTEGER") {
        const intValue = fieldValue ? parseInt(fieldValue, 10) : null;
        fields[fieldApiName] = isNaN(intValue) ? null : intValue;
      } else if (dataTypeUpper === "BOOLEAN") {
        // Handle boolean values - can be true, false, 'true', 'false', or null
        if (fieldValue === null || fieldValue === undefined || fieldValue === "") {
          fields[fieldApiName] = false;
        } else {
          fields[fieldApiName] = fieldValue === "true" || fieldValue === true;
        }
      } else {
        // STRING, TEXTAREA, etc.
        fields[fieldApiName] = fieldValue || null;
      }

      await updateRecord({ fields });

      // Update the field in our local data
      this.updateFieldValue(taskId, fieldApiName, fieldValue, dataType);

      this.showToast("Success", "Field updated successfully", "success");
      this.cancelEdit();
    } catch (error) {
      console.error("Error updating field:", error);
      this.showToast("Error", this.getErrorMessage(error), "error");
    }
  }

  handleFieldKeyDown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.handleFieldSave();
    } else if (event.key === "Escape") {
      event.preventDefault();
      this.cancelEdit();
    }
  }

  getFieldInputType(field) {
    if (!field || !field.dataType) {
      return "text";
    }

    const dataType = field.dataType.toUpperCase();

    switch (dataType) {
      case "DATE":
        return "date";
      case "DATETIME":
        return "datetime-local";
      case "DOUBLE":
      case "CURRENCY":
      case "PERCENT":
      case "INTEGER":
        return "number";
      case "BOOLEAN":
        return "checkbox";
      default:
        return "text";
    }
  }

  getFieldInputValue(field) {
    if (!this.editingField) {
      return "";
    }

    const dataType = (field.dataType || "").toUpperCase();
    if (dataType === "BOOLEAN") {
      return this.editingField.fieldValue === "true" || this.editingField.fieldValue === true;
    }

    return this.editingField.fieldValue || "";
  }

  isBooleanField(field) {
    if (!field || !field.dataType) {
      return false;
    }
    return (field.dataType || "").toUpperCase() === "BOOLEAN";
  }

  hasDataType(field) {
    return field && field.dataType;
  }

  findTaskById(taskId) {
    for (const statusGroup of this.statusGroups) {
      for (const task of statusGroup.tasks) {
        if (task.id === taskId) {
          return task;
        }
        if (task.subtasks) {
          for (const subtask of task.subtasks) {
            if (subtask.id === taskId) {
              return subtask;
            }
          }
        }
      }
    }
    return null;
  }

  updateFieldValue(taskId, fieldApiName, newValue, dataType) {
    // Update field value in statusGroups
    for (const statusGroup of this.statusGroups) {
      for (const task of statusGroup.tasks) {
        if (task.id === taskId) {
          const field = (task.summaryFields || []).find((f) => f.apiName === fieldApiName);
          if (field) {
            // Update rawValue
            field.rawValue = newValue;
            // Format displayValue based on data type
            field.displayValue = this.formatFieldDisplayValue(fieldApiName, newValue, dataType);
            // Re-decorate the entire task to ensure all computed properties are updated
            const decorated = this.decorateTaskRecord(task);
            // Update the task with decorated properties
            Object.assign(task, decorated);
            // Force reactive update
            this.statusGroups = [...this.statusGroups];
            this.refreshFilteredStatusGroups();
            return;
          }
        }
        if (task.subtasks) {
          for (const subtask of task.subtasks) {
            if (subtask.id === taskId) {
              const field = (subtask.summaryFields || []).find((f) => f.apiName === fieldApiName);
              if (field) {
                // Update rawValue
                field.rawValue = newValue;
                // Format displayValue based on data type
                field.displayValue = this.formatFieldDisplayValue(fieldApiName, newValue, dataType);
                // Re-decorate the entire subtask to ensure all computed properties are updated
                const decorated = this.decorateTaskRecord(subtask);
                // Update the subtask with decorated properties
                Object.assign(subtask, decorated);
                // Force reactive update
                this.statusGroups = [...this.statusGroups];
                this.refreshFilteredStatusGroups();
                return;
              }
            }
          }
        }
      }
    }
  }

  formatFieldDisplayValue(fieldApiName, rawValue, dataType) {
    if (!rawValue && rawValue !== 0 && rawValue !== false) {
      return "";
    }

    const dataTypeUpper = (dataType || "").toUpperCase();

    // Format based on data type
    if (dataTypeUpper === "DATE" || dataTypeUpper === "DATETIME") {
      return this.formatDate(rawValue);
    } else if (dataTypeUpper === "PERCENT") {
      const percentValue = parseFloat(rawValue);
      if (!isNaN(percentValue)) {
        return `${percentValue.toFixed(2)}%`;
      }
    } else if (dataTypeUpper === "BOOLEAN") {
      return rawValue === true || rawValue === "true" ? "Yes" : "No";
    } else if (fieldApiName && fieldApiName.endsWith("_Hours__c")) {
      const hoursValue = parseFloat(rawValue);
      if (!isNaN(hoursValue)) {
        return this.formatHours(hoursValue);
      }
    }

    // For picklist fields, return the raw value (it's already the label from the server)
    // For other types, return as string
    return String(rawValue);
  }

  updateTaskName(taskId, newName) {
    this.statusGroups = this.statusGroups.map((statusGroup) => ({
      ...statusGroup,
      tasks: statusGroup.tasks.map((task) => {
        if (task.id === taskId) {
          const permissions = this.getTaskPermissions();
          return {
            ...task,
            name: newName,
            isEditing: false,
            canEdit: permissions.canEdit,
            canDelete: permissions.canDelete,
            showMenu: permissions.canEdit || permissions.canDelete
          };
        }
        if (task.subtasks) {
          return {
            ...task,
            subtasks: task.subtasks.map((subtask) => {
              if (subtask.id === taskId) {
                const subtaskPermissions = this.getTaskPermissions();
                return {
                  ...subtask,
                  name: newName,
                  isEditing: false,
                  canEdit: subtaskPermissions.canEdit,
                  canDelete: subtaskPermissions.canDelete,
                  showMenu: subtaskPermissions.canEdit || subtaskPermissions.canDelete
                };
              }
              return subtask;
            })
          };
        }
        return task;
      })
    }));
    this.refreshFilteredStatusGroups();
  }

  isEditingTask(taskId) {
    return this.editingTaskId === taskId;
  }

  // Helper methods for template expressions (LWC doesn't allow function calls in templates)
  getEditingTaskId() {
    return this.editingTaskId;
  }

  getEditingTaskName() {
    return this.editingTaskName;
  }

  getObjectPermissions() {
    return this.objectPermissions;
  }

  // Menu handlers
  handleMenuAction(event) {
    const action = event.detail.value;
    const taskId = event.currentTarget.dataset.taskId;

    if (action === "edit") {
      this.handleEditTask(taskId);
    } else if (action === "delete") {
      this.handleDeleteTask(taskId);
    }
  }

  handleEditTask(taskId) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: taskId,
        actionName: "edit"
      }
    });
  }

  handleCreateNewTask() {
    // Build navigation state with record type selection
    const state = {};

    // Add URL parameters to force record type selection dialog
    state.nooverride = "1";
    state.useRecordTypeCheck = "1";

    // If there are multiple record types, don't pass recordTypeId to show the picker
    // If there's only one record type, use it directly
    if (this.recordTypes.length === 1 && this.defaultRecordTypeId) {
      // Single record type - use it directly
      state.recordTypeId = this.defaultRecordTypeId;
    } else if (this.recordTypes.length > 1) {
      // Multiple record types - don't pass recordTypeId so Salesforce shows the picker
      // Optionally, we can pre-select the default if desired
      // For now, we'll let Salesforce show the picker by not setting recordTypeId
    } else if (this.defaultRecordTypeId) {
      // Fallback: use default if available
      state.recordTypeId = this.defaultRecordTypeId;
    }

    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: {
        objectApiName: "Project_Task__c",
        actionName: "new"
      },
      state: state
    });
  }

  async handleDeleteTask(taskId) {
    // Note: In a production environment, you might want to add a confirmation modal
    // For now, we'll proceed with delete and show appropriate toast messages

    try {
      await deleteRecord(taskId);
      this.showToast("Success", "Task deleted successfully", "success");

      // Remove task from local data
      this.removeTaskFromData(taskId);
    } catch (error) {
      console.error("Error deleting task:", error);
      this.showToast("Error", this.getErrorMessage(error), "error");
    }
  }

  removeTaskFromData(taskId) {
    this.statusGroups = this.statusGroups
      .map((statusGroup) => {
        const filteredTasks = statusGroup.tasks.filter((task) => task.id !== taskId);

        // Also check subtasks
        const tasksWithFilteredSubtasks = filteredTasks.map((task) => {
          if (task.subtasks) {
            const filteredSubtasks = task.subtasks.filter((subtask) => subtask.id !== taskId);
            return {
              ...task,
              subtasks: filteredSubtasks,
              subtaskCount: filteredSubtasks.length,
              hasSubtasks: filteredSubtasks.length > 0
            };
          }
          return task;
        });

        // Remove status group if no tasks remain
        if (tasksWithFilteredSubtasks.length === 0) {
          return null;
        }

        return {
          ...statusGroup,
          tasks: tasksWithFilteredSubtasks,
          taskCount: tasksWithFilteredSubtasks.length
        };
      })
      .filter((group) => group !== null);

    this.rebuildListViewFilterOptions();
    this.refreshFilteredStatusGroups();
  }

  getErrorMessage(error) {
    if (error.body) {
      if (Array.isArray(error.body)) {
        return error.body.map((e) => e.message).join(", ");
      } else if (error.body.message) {
        return error.body.message;
      } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
        return error.body.pageErrors[0].message;
      }
    }
    return error.message || "An unexpected error occurred";
  }

  showToast(title, message, variant) {
    const evt = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant,
      mode: "dismissable"
    });
    this.dispatchEvent(evt);
  }

  /**
   * @description Set up periodic refresh check for task changes
   * This provides auto-refresh functionality to catch task changes (CDC)
   * The wire service will also automatically refresh when reactive parameters change
   * @private
   */
  setupPeriodicRefresh() {
    // Clear any existing interval
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
    }

    // Check for changes every 30 seconds to catch task updates
    // This ensures the list stays up-to-date when tasks are created or modified
    this.refreshInterval = setInterval(() => {
      if (this.wiredGroupedTasksResult && this.wiredGroupedTasksResult.data) {
        // Refresh the wire service to get latest data
        refreshApex(this.wiredGroupedTasksResult).catch((error) => {
          console.warn("Error during periodic refresh:", error);
        });
      }
    }, 30000); // 30 seconds
  }

  /**
   * @description Handle manual refresh button click
   * Refreshes the task list data immediately
   * @private
   */
  async handleManualRefresh() {
    if (this.wiredGroupedTasksResult) {
      try {
        await refreshApex(this.wiredGroupedTasksResult);
        this.showToast("Success", "Task list refreshed", "success");
      } catch (error) {
        console.error("Error refreshing task list:", error);
        this.showToast("Error", "Failed to refresh task list", "error");
      }
    }
  }

  disconnectedCallback() {
    // Clean up existing resources
    // Clean up periodic refresh interval
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
      this.refreshInterval = null;
    }

    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = null;
    }
  }
}
