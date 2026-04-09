import { createElement } from "lwc";
import { registerLdsTestWireAdapter, registerTestWireAdapter } from "@salesforce/sfdx-lwc-jest";
import { getRecord } from "lightning/uiRecordApi";
import { CurrentPageReference } from "lightning/navigation";
import { MessageContext, publish } from "lightning/messageService";
import ProjectTaskDashboard from "c/projectTaskDashboard";

jest.mock("lightning/messageService", () => {
  const actual = jest.requireActual("lightning/messageService");
  return {
    ...actual,
    publish: jest.fn()
  };
});

jest.mock(
  "@salesforce/messageChannel/AccountFilter__c",
  () => ({ default: "AccountFilter__c" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/messageChannel/DashboardRefresh__c",
  () => ({ default: "DashboardRefresh__c" }),
  { virtual: true }
);

const messageContextAdapter = registerTestWireAdapter(MessageContext);
const pageReferenceAdapter = registerTestWireAdapter(CurrentPageReference);
const getRecordAdapter = registerLdsTestWireAdapter(getRecord);

const ACCOUNT_ID = "001000000000001AAA";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

function createDashboard(props = {}) {
  const el = createElement("c-project-task-dashboard", {
    is: ProjectTaskDashboard
  });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}

function emitMessageContext(data = {}) {
  messageContextAdapter.emit({ data, error: undefined });
}

async function mountWithMessageContext(props = {}) {
  const el = createDashboard(props);
  emitMessageContext({});
  await flushPromises();
  return el;
}

describe("c-project-task-dashboard", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
    teardown();
  });

  it("renders Project Task Dashboard card", async () => {
    const el = await mountWithMessageContext();

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Project Task Dashboard");
  });

  it("hides account filter when recordId is set and still renders metric sections", async () => {
    const el = await mountWithMessageContext({ recordId: ACCOUNT_ID });

    expect(el.shadowRoot.querySelector("c-account-filter")).toBeNull();
    expect(el.shadowRoot.querySelector("c-task-status-breakdown")).not.toBeNull();
  });

  it("respects show flags to omit sections", async () => {
    const el = await mountWithMessageContext({
      showStatusBreakdown: false,
      showHoursMetrics: false,
      showTaskList: false,
      showDueDateMetrics: false
    });

    expect(el.shadowRoot.querySelector("c-task-status-breakdown")).toBeNull();
    expect(el.shadowRoot.querySelector("c-task-hours-metrics")).toBeNull();
    expect(el.shadowRoot.querySelector("c-task-list-component")).toBeNull();
    expect(el.shadowRoot.querySelector("c-task-due-date-metrics")).toBeNull();
  });

  it("orders child sections by configured order values", async () => {
    const el = await mountWithMessageContext({
      showAccountFilter: false,
      statusBreakdownOrder: 10,
      hoursMetricsOrder: 1
    });

    const sections = el.shadowRoot.querySelectorAll(
      "c-task-hours-metrics, c-task-status-breakdown"
    );
    expect(sections.length).toBe(2);
    expect(sections[0].tagName.toLowerCase()).toBe("c-task-hours-metrics");
    expect(sections[1].tagName.toLowerCase()).toBe("c-task-status-breakdown");
  });

  it("wiredPageReference ignores falsy page reference", async () => {
    const el = await mountWithMessageContext();
    pageReferenceAdapter.emit(undefined);
    await flushPromises();
    expect(el.recordId).toBeUndefined();
  });

  it("wiredPageReference sets account context on Account record page and publishes after delay", async () => {
    await mountWithMessageContext();

    pageReferenceAdapter.emit({
      attributes: { recordId: ACCOUNT_ID, objectApiName: "Account" }
    });
    await flushPromises();

    jest.advanceTimersByTime(200);
    expect(publish).toHaveBeenCalled();
    const filterCalls = publish.mock.calls.filter(
      (c) => c[2] && Array.isArray(c[2].accountIds) && c[2].accountIds[0] === ACCOUNT_ID
    );
    expect(filterCalls.length).toBeGreaterThan(0);
  });

  it("wiredPageReference does not treat non-Account record pages as account context", async () => {
    await mountWithMessageContext();
    publish.mockClear();

    pageReferenceAdapter.emit({
      attributes: { recordId: "006000000000001AAA", objectApiName: "Opportunity" }
    });
    await flushPromises();
    jest.advanceTimersByTime(200);

    const filterCalls = publish.mock.calls.filter(
      (c) => c[2] && Object.prototype.hasOwnProperty.call(c[2], "accountIds")
    );
    expect(filterCalls.length).toBe(0);
  });

  it("publishes pending account filter when MessageContext arrives after page reference", async () => {
    createDashboard();
    await flushPromises();
    publish.mockClear();

    pageReferenceAdapter.emit({
      attributes: { recordId: ACCOUNT_ID, objectApiName: "Account" }
    });
    await flushPromises();
    jest.advanceTimersByTime(200);
    expect(publish).not.toHaveBeenCalled();

    emitMessageContext({});
    await flushPromises();
    expect(publish).toHaveBeenCalled();
  });

  it("wiredAccount success publishes account filter after delay", async () => {
    await mountWithMessageContext({ recordId: ACCOUNT_ID });
    publish.mockClear();

    getRecordAdapter.emit({
      id: ACCOUNT_ID,
      fields: { Id: { value: ACCOUNT_ID, displayValue: null } }
    });
    await flushPromises();
    jest.advanceTimersByTime(200);

    expect(publish).toHaveBeenCalled();
    const msg = publish.mock.calls.find(
      (c) => c[2] && c[2].accountIds && c[2].accountIds[0] === ACCOUNT_ID
    );
    expect(msg).toBeTruthy();
  });

  it("wiredAccount error with no effective record id publishes empty filter after delay", async () => {
    await mountWithMessageContext();
    publish.mockClear();

    getRecordAdapter.emitError({ message: "not found" });
    await flushPromises();
    jest.advanceTimersByTime(200);

    const emptyCall = publish.mock.calls.find(
      (c) => c[2] && Array.isArray(c[2].accountIds) && c[2].accountIds.length === 0
    );
    expect(emptyCall).toBeTruthy();
  });

  it("handleRefresh publishes dashboard refresh when MessageContext is available", async () => {
    const el = await mountWithMessageContext();
    publish.mockClear();

    const btn = el.shadowRoot.querySelector("lightning-button-icon");
    expect(btn).not.toBeNull();
    btn.click();
    await flushPromises();

    expect(publish).toHaveBeenCalled();
    const refreshCall = publish.mock.calls.find(
      (c) => c[2] && Object.prototype.hasOwnProperty.call(c[2], "refreshTimestamp")
    );
    expect(refreshCall).toBeTruthy();
  });

  it("connectedCallback eventually publishes refresh after MessageContext is ready", async () => {
    createDashboard();
    await flushPromises();
    publish.mockClear();

    jest.advanceTimersByTime(500);
    emitMessageContext({});
    await flushPromises();
    jest.advanceTimersByTime(100);

    const refreshCall = publish.mock.calls.find(
      (c) => c[2] && Object.prototype.hasOwnProperty.call(c[2], "refreshTimestamp")
    );
    expect(refreshCall).toBeTruthy();
  });

  it("passes showHoursMetricsChart to hours metrics child", async () => {
    const el = await mountWithMessageContext({ showHoursMetricsChart: false });

    const hours = el.shadowRoot.querySelector("c-task-hours-metrics");
    expect(hours).not.toBeNull();
    expect(hours.showChart).toBe(false);
  });
});
