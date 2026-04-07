import { createElement } from "lwc";
import TaskReviewStatusMetrics from "c/taskReviewStatusMetrics";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-task-review-status-metrics", () => {
  afterEach(teardown);

  it("renders Review Status Metrics card", async () => {
    const el = createElement("c-task-review-status-metrics", {
      is: TaskReviewStatusMetrics
    });
    el.accountId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Review Status Metrics");
  });
});
