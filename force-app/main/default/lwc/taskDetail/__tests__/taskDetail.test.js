import { createElement } from "lwc";
import TaskDetail from "c/taskDetail";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

describe("c-task-detail", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders lightning-card with Task Detail title", async () => {
    const element = createElement("c-task-detail", {
      is: TaskDetail
    });
    document.body.appendChild(element);
    await flushPromises();

    const card = element.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Task Detail");
  });
});
