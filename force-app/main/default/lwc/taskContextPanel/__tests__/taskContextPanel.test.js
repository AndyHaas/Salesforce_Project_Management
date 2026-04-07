import { createElement } from "lwc";
import TaskContextPanel from "c/taskContextPanel";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-task-context-panel", () => {
  afterEach(teardown);

  it("renders root lightning-card", async () => {
    const el = createElement("c-task-context-panel", { is: TaskContextPanel });
    el.recordId = "a0TASK0000000001";
    document.body.appendChild(el);
    await flushPromises();

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
  });
});
