import { createElement } from "lwc";
import TaskPriorityBreakdown from "c/taskPriorityBreakdown";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-task-priority-breakdown", () => {
  afterEach(teardown);

  it("renders Priority Breakdown card", async () => {
    const el = createElement("c-task-priority-breakdown", {
      is: TaskPriorityBreakdown
    });
    el.accountId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Priority Breakdown");
  });
});
