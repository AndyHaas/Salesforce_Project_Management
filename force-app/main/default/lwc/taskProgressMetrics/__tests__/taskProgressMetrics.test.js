import { createElement } from "lwc";
import TaskProgressMetrics from "c/taskProgressMetrics";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-task-progress-metrics", () => {
  afterEach(teardown);

  it("renders Progress Metrics card", async () => {
    const el = createElement("c-task-progress-metrics", {
      is: TaskProgressMetrics
    });
    el.accountId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Progress Metrics");
  });
});
