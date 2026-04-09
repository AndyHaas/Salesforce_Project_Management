import { createElement } from "lwc";
import { registerApexTestWireAdapter, registerTestWireAdapter } from "@salesforce/sfdx-lwc-jest";
import { MessageContext } from "lightning/messageService";
import * as messageService from "lightning/messageService";
import getDueDateMetrics from "@salesforce/apex/ProjectTaskDashboardController.getDueDateMetrics";

jest.mock("lightning/navigation", () => {
  const Navigate = Symbol("Navigate");
  const mockNavigate = jest.fn();
  globalThis.__taskDueDateMetricsNavigateMock = mockNavigate;

  function NavigationMixin(Base) {
    return class extends Base {
      [Navigate](pageReference) {
        mockNavigate(pageReference);
      }
    };
  }
  NavigationMixin.Navigate = Navigate;
  return { NavigationMixin };
});

import TaskDueDateMetrics from "c/taskDueDateMetrics";

const messageContextAdapter = registerTestWireAdapter(MessageContext);
const getDueDateMetricsAdapter = registerApexTestWireAdapter(getDueDateMetrics);

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
  jest.restoreAllMocks();
  jest.useRealTimers();
  globalThis.__taskDueDateMetricsNavigateMock?.mockClear();
}

const sampleMetrics = {
  overdueCount: 3,
  dueTodayCount: 2,
  dueThisWeekCount: 5,
  tasksWithDueDate: 10,
  tasksWithoutDueDate: 4,
  overduePercentage: 33.333
};

function emitMessageContext() {
  messageContextAdapter.emit({ data: {}, error: undefined });
}

async function mountWithMetrics(propOverrides = {}, metricsPayload = sampleMetrics) {
  emitMessageContext();
  const el = createElement("c-task-due-date-metrics", {
    is: TaskDueDateMetrics
  });
  Object.assign(el, propOverrides);
  document.body.appendChild(el);
  await flushPromises();
  getDueDateMetricsAdapter.emit(metricsPayload);
  await flushPromises();
  return el;
}

function navigateMock() {
  return globalThis.__taskDueDateMetricsNavigateMock;
}

describe("c-task-due-date-metrics", () => {
  afterEach(teardown);

  it("renders Due Date Metrics card", async () => {
    const el = await mountWithMetrics({ accountId: "001000000000000AAA" });

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Due Date Metrics");
  });

  it("shows metric values when wire returns data", async () => {
    const el = await mountWithMetrics({ accountId: "001000000000000AAA" });

    const text = el.shadowRoot.textContent;
    expect(text).toContain("3");
    expect(text).toContain("2");
    expect(text).toContain("5");
    expect(text).toContain("33.3%");
    expect(text).toContain("10");
    expect(text).toContain("4");
  });

  it("uses success overdue class when overdue count is zero", async () => {
    emitMessageContext();
    const el = createElement("c-task-due-date-metrics", {
      is: TaskDueDateMetrics
    });
    el.accountId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();
    getDueDateMetricsAdapter.emit({
      ...sampleMetrics,
      overdueCount: 0,
      overduePercentage: 0
    });
    await flushPromises();

    const values = [...el.shadowRoot.querySelectorAll(".metric-value.success-value")];
    expect(values.length).toBeGreaterThan(0);
  });

  it("uses alert overdue class when overdue count is positive", async () => {
    const el = await mountWithMetrics({ accountId: "001000000000000AAA" });

    const alerts = [...el.shadowRoot.querySelectorAll(".metric-value.alert-value")];
    expect(alerts.length).toBeGreaterThan(0);
  });

  it("formats overdue percentage as 0.0 when missing on payload", async () => {
    emitMessageContext();
    const el = createElement("c-task-due-date-metrics", {
      is: TaskDueDateMetrics
    });
    el.accountId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();
    getDueDateMetricsAdapter.emit({
      ...sampleMetrics,
      overduePercentage: null
    });
    await flushPromises();

    expect(el.shadowRoot.textContent).toContain("0.0%");
  });

  it("shows no-data message when wire errors", async () => {
    const consoleSpy = jest.spyOn(console, "error").mockImplementation(() => {});
    emitMessageContext();
    const el = createElement("c-task-due-date-metrics", {
      is: TaskDueDateMetrics
    });
    el.accountId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();
    getDueDateMetricsAdapter.emitError({ body: { message: "wire failed" } });
    await flushPromises();

    expect(el.shadowRoot.textContent).toContain("No due date data available");
    expect(consoleSpy).toHaveBeenCalled();
    consoleSpy.mockRestore();
  });

  it("shows no-data when wire has not returned data", async () => {
    emitMessageContext();
    const el = createElement("c-task-due-date-metrics", {
      is: TaskDueDateMetrics
    });
    el.accountId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();

    expect(el.shadowRoot.textContent).toContain("No due date data available");
  });

  it("disconnects and unsubscribes LMS when subscriptions exist", async () => {
    const unsubSpy = jest.spyOn(messageService, "unsubscribe");
    const el = await mountWithMetrics({ accountId: "001000000000000AAA" });
    el.subscription = { mock: "account-filter" };
    el.refreshSubscription = { mock: "refresh" };

    TaskDueDateMetrics.prototype.disconnectedCallback.call(el);

    expect(unsubSpy).toHaveBeenCalledTimes(2);
  });

  it("click handlers call Navigate with expected list filters", async () => {
    const el = await mountWithMetrics({ accountId: "001000000000000AAA" });
    const navSpy = navigateMock();

    const cards = el.shadowRoot.querySelectorAll(".clickable-metric-card");
    expect(cards.length).toBeGreaterThanOrEqual(4);

    cards[0].click();
    expect(navSpy).toHaveBeenLastCalledWith(
      expect.objectContaining({
        type: "standard__objectPage",
        attributes: { objectApiName: "Project_Task__c", actionName: "list" },
        state: expect.objectContaining({
          filterName: "Overdue_Tasks",
          c__accountId: "001000000000000AAA"
        })
      })
    );

    cards[1].click();
    expect(navSpy).toHaveBeenLastCalledWith(
      expect.objectContaining({
        state: expect.objectContaining({ filterName: "Tasks_Due_Today" })
      })
    );

    cards[2].click();
    expect(navSpy).toHaveBeenLastCalledWith(
      expect.objectContaining({
        state: expect.objectContaining({ filterName: "Tasks_Due_This_Week" })
      })
    );

    cards[3].click();
    expect(navSpy).toHaveBeenLastCalledWith(
      expect.objectContaining({
        state: expect.objectContaining({ filterName: "Tasks_Due_This_Week" })
      })
    );
  });

  it("omits c__accountId in navigation when no account scope", async () => {
    const el = await mountWithMetrics({});
    const navSpy = navigateMock();

    el.shadowRoot.querySelector(".clickable-metric-card").click();

    expect(navSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        state: {
          filterName: "Overdue_Tasks"
        }
      })
    );
  });

  it("handleRefresh clears and restores filtered account ids when timestamp present", async () => {
    jest.useFakeTimers();
    emitMessageContext();
    const el = createElement("c-task-due-date-metrics", {
      is: TaskDueDateMetrics
    });
    document.body.appendChild(el);
    await flushPromises();

    el._filteredAccountIds = ["001AAA000000001", "001AAA000000002"];
    TaskDueDateMetrics.prototype.handleRefresh.call(el, { refreshTimestamp: Date.now() });
    expect(el._filteredAccountIds).toEqual([]);
    jest.runAllTimers();
    expect(el._filteredAccountIds).toEqual(["001AAA000000001", "001AAA000000002"]);
  });

  it("handleRefresh does nothing when message has no refreshTimestamp", async () => {
    jest.useFakeTimers();
    emitMessageContext();
    const el = createElement("c-task-due-date-metrics", {
      is: TaskDueDateMetrics
    });
    document.body.appendChild(el);
    await flushPromises();

    el._filteredAccountIds = ["001AAA000000001"];
    TaskDueDateMetrics.prototype.handleRefresh.call(el, {});
    jest.runAllTimers();
    expect(el._filteredAccountIds).toEqual(["001AAA000000001"]);
  });
});
