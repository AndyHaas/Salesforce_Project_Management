import { createElement } from "lwc";
import TaskStatusBreakdown from "c/taskStatusBreakdown";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-task-status-breakdown", () => {
  afterEach(teardown);

  it("renders Status Breakdown card", async () => {
    const el = createElement("c-task-status-breakdown", {
      is: TaskStatusBreakdown
    });
    el.accountId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Status Breakdown");
  });
});
