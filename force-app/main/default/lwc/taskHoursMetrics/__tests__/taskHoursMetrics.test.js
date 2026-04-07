import { createElement } from "lwc";
import TaskHoursMetrics from "c/taskHoursMetrics";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-task-hours-metrics", () => {
  afterEach(teardown);

  it("renders Hours Metrics card", async () => {
    const el = createElement("c-task-hours-metrics", { is: TaskHoursMetrics });
    el.accountId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Hours Metrics");
  });
});
