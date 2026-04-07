import { createElement } from "lwc";
import TaskListComponent from "c/taskListComponent";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-task-list-component", () => {
  afterEach(teardown);

  it("renders Task List card", async () => {
    const el = createElement("c-task-list-component", {
      is: TaskListComponent
    });
    document.body.appendChild(el);
    await flushPromises();

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Task List");
  });
});
