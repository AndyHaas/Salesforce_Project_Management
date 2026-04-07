import { createElement } from "lwc";
import TaskDueDateMetrics from "c/taskDueDateMetrics";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-task-due-date-metrics", () => {
  afterEach(teardown);

  it("renders Due Date Metrics card", async () => {
    const el = createElement("c-task-due-date-metrics", {
      is: TaskDueDateMetrics
    });
    el.accountId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Due Date Metrics");
  });
});
